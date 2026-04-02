-- ═══════════════════════════════════════════════════════
-- GLOBAL COOLERS — FINAL LOGIC COMPLETION
-- ═══════════════════════════════════════════════════════

-- 1. Ensure increment_points helper exists
CREATE OR REPLACE FUNCTION public.increment_points(p_user_id UUID, p_amount INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET 
        eco_points = COALESCE(eco_points, 0) + p_amount,
        total_waste_diverted = CASE 
            WHEN p_amount > 0 THEN COALESCE(total_waste_diverted, 0) + (p_amount / 20.0) -- Estimate kg if needed
            ELSE total_waste_diverted
        END
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. COMPLETE PICKUP RPC (The engine of the reward system)
CREATE OR REPLACE FUNCTION public.collector_complete_pickup(
    p_pickup_id UUID,
    p_qr_code TEXT,
    p_actual_weight DOUBLE PRECISION
)
RETURNS VOID AS $$
DECLARE
    v_pickup RECORD;
    v_res_points INTEGER;
    v_coll_points INTEGER;
BEGIN
    -- 1. Verify Pickup & Ownership
    SELECT * INTO v_pickup FROM public.pickups 
    WHERE id = p_pickup_id AND collector_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pickup not found or not assigned to you.';
    END IF;

    IF v_pickup.status = 'completed' THEN
        RAISE EXCEPTION 'This pickup is already completed.';
    END IF;

    -- 2. Verify QR Code
    IF v_pickup.qr_code_id != p_qr_code THEN
        RAISE EXCEPTION 'Invalid QR Code. Verification failed.';
    END IF;

    -- 3. Calculate Points (20 for Resident, 10 for Collector)
    v_res_points := (p_actual_weight * 20)::INTEGER;
    v_coll_points := (p_actual_weight * 10)::INTEGER;

    -- 4. Update Pickup Status & Weight
    UPDATE public.pickups
    SET 
        status = 'completed',
        weight_kg = p_actual_weight,
        updated_at = NOW()
    WHERE id = p_pickup_id;

    -- 5. Award Points
    PERFORM public.increment_points(v_pickup.user_id, v_res_points);
    PERFORM public.increment_points(auth.uid(), v_coll_points);

    -- 6. Final Notifications
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES 
        (v_pickup.user_id, 'Eco-Goal Reached! 🌱', 'You earned ' || v_res_points || ' pts for ' || p_actual_weight || 'kg of ' || v_pickup.waste_type || '.', 'success'),
        (auth.uid(), 'Earnings Credited! 💰', 'You earned ' || v_coll_points || ' pts for the collection at ' || v_pickup.address || '.', 'success');

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Final trigger update for real-time sync
CREATE OR REPLACE FUNCTION public.handle_pickup_updates()
RETURNS TRIGGER AS $$
BEGIN
    -- Only handle non-completion triggers here (completion is in the RPC)
    IF (OLD.status != NEW.status) THEN
        IF (NEW.status = 'in_transit') THEN
            INSERT INTO public.notifications (user_id, title, message)
            VALUES (NEW.user_id, 'Collector En Route! 🚚', 'A collector is heading to your location.');
        ELSIF (NEW.status = 'arrived') THEN
            INSERT INTO public.notifications (user_id, title, message)
            VALUES (NEW.user_id, 'Collector Arrived! 🏁', 'Show your QR code to complete the pickup.');
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
