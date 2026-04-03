-- ═══════════════════════════════════════════════════════
-- GLOBAL COOLERS — FINAL HARDENED BACKEND LOGIC
-- ═══════════════════════════════════════════════════════

-- 1. Ensure 'archived' status exists in 'pickup_status' enum
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pickup_status') THEN
        CREATE TYPE pickup_status AS ENUM ('scheduled', 'accepted', 'in_transit', 'arrived', 'completed', 'cancelled', 'archived');
    ELSE
        -- Add 'archived' if missing from a previous version of the enum
        BEGIN
            ALTER TYPE pickup_status ADD VALUE 'archived';
        EXCEPTION
            WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

-- 2. Clean up old function signatures to prevent return-type conflicts
DROP FUNCTION IF EXISTS public.resident_schedule_pickup(text, text, float, float, text, text);
DROP FUNCTION IF EXISTS public.collector_claim_pickup(uuid, boolean, text);
DROP FUNCTION IF EXISTS public.collector_complete_pickup(uuid, text, float);
DROP FUNCTION IF EXISTS public.collector_cancel_pickup(uuid);
DROP FUNCTION IF EXISTS public.collector_reschedule_pickup(uuid, text);
DROP FUNCTION IF EXISTS public.resident_cancel_pickup(uuid);
DROP FUNCTION IF EXISTS public.user_clear_history();
DROP FUNCTION IF EXISTS public.increment_points(uuid, integer);

-- 3. Atomic Point Increment Function
CREATE OR REPLACE FUNCTION public.increment_points(p_user_id UUID, p_amount INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET 
        eco_points = COALESCE(eco_points, 0) + p_amount,
        total_waste_diverted = CASE 
            WHEN p_amount > 0 THEN COALESCE(total_waste_diverted, 0) + (p_amount / 20.0)
            ELSE total_waste_diverted
        END
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RESIDENT: SCHEDULE PICKUP (Enforce 1 Active Limit)
CREATE OR REPLACE FUNCTION public.resident_schedule_pickup(
    p_waste_type TEXT,
    p_address TEXT,
    p_latitude FLOAT,
    p_longitude FLOAT,
    p_date TEXT,
    p_qr_code_id TEXT
)
RETURNS JSON AS $$
DECLARE
    v_active_count INTEGER;
    v_new_id UUID;
BEGIN
    -- Only allow ONE active task per resident
    SELECT COUNT(*) INTO v_active_count 
    FROM public.pickups 
    WHERE user_id = auth.uid() 
      AND status NOT IN ('completed', 'cancelled', 'archived');

    IF v_active_count > 0 THEN
        RETURN json_build_object('success', false, 'message', 'You already have an active pickup request.');
    END IF;

    INSERT INTO public.pickups (
        user_id, waste_type, address, latitude, longitude, date, qr_code_id, status
    ) VALUES (
        auth.uid(), p_waste_type, p_address, p_latitude, p_longitude, p_date, p_qr_code_id, 'scheduled'
    ) RETURNING id INTO v_new_id;

    RETURN json_build_object('success', true, 'pickup_id', v_new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. COLLECTOR: CLAIM PICKUP (Enforce 5 Active Limit)
CREATE OR REPLACE FUNCTION public.collector_claim_pickup(
    p_pickup_id UUID,
    p_is_immediate BOOLEAN,
    p_scheduled_arrival TEXT
)
RETURNS JSON AS $$
DECLARE
    v_collector_id UUID := auth.uid();
    v_active_count INTEGER;
    v_current_collector_id UUID;
    v_resident_id UUID;
BEGIN
    IF v_collector_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Session expired. Please log in again.');
    END IF;

    -- Only allow 5 active tasks per collector
    SELECT COUNT(*) INTO v_active_count 
    FROM public.pickups 
    WHERE collector_id = v_collector_id 
      AND status IN ('accepted', 'in_transit', 'arrived');

    IF v_active_count >= 5 THEN
        RETURN json_build_object('success', false, 'message', 'Max capacity reached! You can only handle 5 tasks at a time.');
    END IF;

    -- Lock and check
    SELECT collector_id, user_id INTO v_current_collector_id, v_resident_id 
    FROM public.pickups WHERE id = p_pickup_id FOR UPDATE;

    IF v_current_collector_id IS NOT NULL THEN
        RETURN json_build_object('success', false, 'message', 'Someone else already claimed this pickup.');
    END IF;

    UPDATE public.pickups
    SET 
        collector_id = v_collector_id,
        is_assigned = true,
        status = CASE WHEN p_is_immediate THEN 'in_transit' ELSE 'accepted' END,
        scheduled_arrival = p_scheduled_arrival
    WHERE id = p_pickup_id;

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (v_resident_id, 'Collector Assigned! 🚚', 'A collector has claimed your request and is starting their trip.', 'info');

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. COLLECTOR: CANCEL ASSIGNMENT
CREATE OR REPLACE FUNCTION public.collector_cancel_pickup(p_pickup_id UUID)
RETURNS VOID AS $$
DECLARE
    v_resident_id UUID;
BEGIN
    SELECT user_id INTO v_resident_id FROM public.pickups WHERE id = p_pickup_id;

    UPDATE public.pickups
    SET 
        collector_id = NULL,
        is_assigned = false,
        status = 'scheduled',
        scheduled_arrival = NULL
    WHERE id = p_pickup_id AND collector_id = auth.uid() AND status IN ('accepted', 'in_transit', 'arrived');

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (v_resident_id, 'Collector Update ⚠️', 'The assigned collector had to cancel. Your request is now back in the unassigned pool.', 'warning');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. COLLECTOR: RESCHEDULE
CREATE OR REPLACE FUNCTION public.collector_reschedule_pickup(p_pickup_id UUID, p_new_time TEXT)
RETURNS VOID AS $$
DECLARE
    v_resident_id UUID;
BEGIN
    SELECT user_id INTO v_resident_id FROM public.pickups WHERE id = p_pickup_id;

    UPDATE public.pickups SET scheduled_arrival = p_new_time WHERE id = p_pickup_id AND collector_id = auth.uid();

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (v_resident_id, 'Schedule Updated 🕒', 'Your collector has updated the arrival time to ' || p_new_time || '.', 'info');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RESIDENT: CANCEL PICKUP
CREATE OR REPLACE FUNCTION public.resident_cancel_pickup(p_pickup_id UUID)
RETURNS VOID AS $$
DECLARE
    v_collector_id UUID;
BEGIN
    SELECT collector_id INTO v_collector_id FROM public.pickups WHERE id = p_pickup_id;

    UPDATE public.pickups SET status = 'cancelled', is_assigned = false WHERE id = p_pickup_id AND user_id = auth.uid();

    IF v_collector_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_collector_id, 'Pickup Cancelled ❌', 'The resident has cancelled the pickup request.', 'warning');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. USER: CLEAR HISTORY (Archive Completed/Cancelled)
CREATE OR REPLACE FUNCTION public.user_clear_history()
RETURNS VOID AS $$
BEGIN
    UPDATE public.pickups
    SET status = 'archived'
    WHERE (user_id = auth.uid() OR collector_id = auth.uid())
      AND status IN ('completed', 'cancelled');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. COLLECTOR: COMPLETE PICKUP (Hardware Verification & Rewards)
CREATE OR REPLACE FUNCTION public.collector_complete_pickup(
    p_pickup_id UUID,
    p_qr_code TEXT,
    p_actual_weight FLOAT
)
RETURNS JSON AS $$
DECLARE
    v_pickup RECORD;
    v_res_points INTEGER;
    v_coll_points INTEGER;
BEGIN
    SELECT * INTO v_pickup FROM public.pickups 
    WHERE id = p_pickup_id AND collector_id = auth.uid();

    IF NOT FOUND THEN RETURN json_build_object('success', false, 'message', 'Pickup not found or not assigned to you.'); END IF;
    IF v_pickup.status = 'completed' THEN RETURN json_build_object('success', false, 'message', 'Already completed.'); END IF;
    IF v_pickup.qr_code_id != p_qr_code THEN RETURN json_build_object('success', false, 'message', 'Invalid QR Code scanned.'); END IF;

    -- Resident: 20 pts/kg, Collector: 10 pts/kg
    v_res_points := ROUND(p_actual_weight * 20);
    v_coll_points := ROUND(p_actual_weight * 10);

    UPDATE public.pickups
    SET status = 'completed', weight_kg = p_actual_weight, points_awarded = v_res_points, completed_at = NOW()
    WHERE id = p_pickup_id;

    PERFORM public.increment_points(v_pickup.user_id, v_res_points);
    PERFORM public.increment_points(auth.uid(), v_coll_points);

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES 
        (v_pickup.user_id, 'Points Earned! 🌱', 'You earned ' || v_res_points || ' pts for your collection.', 'success'),
        (auth.uid(), 'Collect Mission Success! 💰', 'Awarded ' || v_coll_points || ' pts for completing this collection.', 'success');

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Status Update Trigger
CREATE OR REPLACE FUNCTION public.handle_pickup_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status != NEW.status) AND (NEW.status = 'arrived') THEN
        INSERT INTO public.notifications (user_id, title, message)
        VALUES (NEW.user_id, 'Collector Arrived! 🏁', 'A collector is waiting for you with their vehicle. Get your QR code ready.');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_pickup_status_update ON public.pickups;
CREATE TRIGGER on_pickup_status_update
    AFTER UPDATE ON public.pickups
    FOR EACH ROW EXECUTE FUNCTION public.handle_pickup_status_change();
