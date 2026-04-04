-- ═══════════════════════════════════════════════════════
-- GLOBAL COOLERS — STRICT RPC MIGRATION PATCH
-- ═══════════════════════════════════════════════════════
BEGIN;

-- 1. AUTHENTICATION & PROFILES
DROP FUNCTION IF EXISTS public.create_user_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.create_user_profile(
    p_id UUID,
    p_email TEXT,
    p_full_name TEXT,
    p_role TEXT,
    p_phone TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role, phone, address, created_at)
    VALUES (p_id, p_email, p_full_name, p_role, p_phone, p_address, NOW())
    ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.update_user_profile(TEXT, TEXT, TEXT, FLOAT, FLOAT, BOOLEAN);
CREATE OR REPLACE FUNCTION public.update_user_profile(
    p_full_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_latitude FLOAT DEFAULT NULL,
    p_longitude FLOAT DEFAULT NULL,
    p_is_online BOOLEAN DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET 
        full_name = COALESCE(p_full_name, full_name),
        phone = COALESCE(p_phone, phone),
        address = COALESCE(p_address, address),
        latitude = COALESCE(p_latitude, latitude),
        longitude = COALESCE(p_longitude, longitude),
        is_online = COALESCE(p_is_online, is_online),
        last_active_at = CASE 
            WHEN p_latitude IS NOT NULL OR p_longitude IS NOT NULL THEN NOW() 
            ELSE last_active_at 
        END
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. ADDRESSES
DROP FUNCTION IF EXISTS public.add_user_address(TEXT, TEXT, FLOAT, FLOAT, BOOLEAN);
CREATE OR REPLACE FUNCTION public.add_user_address(
    p_label TEXT,
    p_address TEXT,
    p_lat FLOAT,
    p_lng FLOAT,
    p_is_default BOOLEAN
) RETURNS VOID AS $$
BEGIN
    IF p_is_default THEN
        UPDATE public.addresses SET is_default = false WHERE user_id = auth.uid();
    END IF;

    INSERT INTO public.addresses (user_id, label, address, latitude, longitude, is_default)
    VALUES (auth.uid(), p_label, p_address, p_lat, p_lng, p_is_default);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.update_user_address(UUID, TEXT, TEXT, FLOAT, FLOAT);
CREATE OR REPLACE FUNCTION public.update_user_address(
    p_address_id UUID,
    p_label TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_lat FLOAT DEFAULT NULL,
    p_lng FLOAT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    UPDATE public.addresses
    SET 
        label = COALESCE(p_label, label),
        address = COALESCE(p_address, address),
        latitude = COALESCE(p_lat, latitude),
        longitude = COALESCE(p_lng, longitude)
    WHERE id = p_address_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.set_default_address(UUID);
CREATE OR REPLACE FUNCTION public.set_default_address(
    p_address_id UUID
) RETURNS VOID AS $$
BEGIN
    UPDATE public.addresses SET is_default = false WHERE user_id = auth.uid();
    UPDATE public.addresses SET is_default = true WHERE id = p_address_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.delete_user_address(UUID);
CREATE OR REPLACE FUNCTION public.delete_user_address(
    p_address_id UUID
) RETURNS VOID AS $$
BEGIN
    DELETE FROM public.addresses WHERE id = p_address_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. PICKUPS & RATINGS
DROP FUNCTION IF EXISTS public.collector_reschedule_pickup(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.collector_reschedule_pickup(
    p_pickup_id UUID,
    p_scheduled_arrival TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE public.pickups
    SET scheduled_arrival = p_scheduled_arrival
    WHERE id = p_pickup_id AND collector_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.update_pickup_status(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.update_pickup_status(
    p_pickup_id UUID,
    p_status TEXT
) RETURNS VOID AS $$
BEGIN
    -- Used mainly by collectors for mark_arrived, but allows user update if needed logic fits
    UPDATE public.pickups
    SET status = p_status
    WHERE id = p_pickup_id AND (collector_id = auth.uid() OR user_id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.submit_pickup_rating(UUID, FLOAT, TEXT);
CREATE OR REPLACE FUNCTION public.submit_pickup_rating(
    p_pickup_id UUID,
    p_rating FLOAT,
    p_comment TEXT DEFAULT ''
) RETURNS VOID AS $$
DECLARE
    v_reviewee_id UUID;
    v_pickup RECORD;
BEGIN
    SELECT * INTO v_pickup FROM public.pickups WHERE id = p_pickup_id;
    IF NOT FOUND THEN RETURN; END IF;

    IF auth.uid() = v_pickup.user_id THEN
        v_reviewee_id := v_pickup.collector_id;
    ELSE
        v_reviewee_id := v_pickup.user_id;
    END IF;

    -- Adjust pickup rating column and insert review securely
    UPDATE public.pickups SET rating = p_rating WHERE id = p_pickup_id;
    
    INSERT INTO public.reviews (pickup_id, reviewer_id, reviewee_id, rating, comment)
    VALUES (p_pickup_id, auth.uid(), v_reviewee_id, p_rating, p_comment);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. MESSAGES / CHAT
DROP FUNCTION IF EXISTS public.send_chat_message(UUID, TEXT);
DROP FUNCTION IF EXISTS public.send_chat_message(UUID, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_pickup_id UUID,
    p_message TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.messages (pickup_id, sender_id, message)
    VALUES (p_pickup_id, auth.uid(), p_message);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. REWARDS, NOTIFICATIONS, REPORTS, CHALLENGES
DROP FUNCTION IF EXISTS public.redeem_reward(UUID, INTEGER, TEXT);
CREATE OR REPLACE FUNCTION public.redeem_reward(
    p_reward_id UUID,
    p_points_cost INTEGER,
    p_mpesa_number TEXT
) RETURNS VOID AS $$
DECLARE
    v_current_points INTEGER;
BEGIN
    -- Strict lock for concurrency safety when spending points
    SELECT eco_points INTO v_current_points 
    FROM public.profiles 
    WHERE id = auth.uid() FOR UPDATE;

    IF v_current_points >= p_points_cost THEN
        -- Deduct points
        UPDATE public.profiles 
        SET eco_points = eco_points - p_points_cost 
        WHERE id = auth.uid();
        
        -- Record redemption
        INSERT INTO public.redemptions (user_id, reward_id, points_spent, mpesa_number, status)
        VALUES (auth.uid(), p_reward_id, p_points_cost, p_mpesa_number, 'pending');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.mark_notification_read(UUID);
CREATE OR REPLACE FUNCTION public.mark_notification_read(
    p_notification_id UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF p_notification_id IS NOT NULL THEN
        UPDATE public.notifications SET is_read = true WHERE id = p_notification_id AND user_id = auth.uid();
    ELSE
        UPDATE public.notifications SET is_read = true WHERE user_id = auth.uid();
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.submit_report(TEXT, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.submit_report(
    p_issue_type TEXT,
    p_location TEXT,
    p_description TEXT,
    p_photo_url TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.reports (user_id, issue_type, location, description, photo_url)
    VALUES (auth.uid(), p_issue_type, p_location, p_description, p_photo_url);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.join_challenge(UUID);
CREATE OR REPLACE FUNCTION public.join_challenge(
    p_challenge_id UUID
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.challenge_participants (user_id, challenge_id)
    VALUES (auth.uid(), p_challenge_id)
    ON CONFLICT (user_id, challenge_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
