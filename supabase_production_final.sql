-- ═══════════════════════════════════════════════════════
-- GLOBAL COOLERS — PRODUCTION CONSOLIDATED SCHEMA
-- ═══════════════════════════════════════════════════════

-- 1. Ensure 'archived' status exists in 'pickup_status' enum
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pickup_status') THEN
        CREATE TYPE pickup_status AS ENUM ('scheduled', 'accepted', 'in_transit', 'arrived', 'completed', 'cancelled', 'archived');
    ELSE
        BEGIN
            ALTER TYPE pickup_status ADD VALUE 'archived';
        EXCEPTION
            WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

-- 2. Clean up old function signatures
DROP FUNCTION IF EXISTS public.collector_claim_pickup(UUID, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS public.collector_claim_pickup(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.collector_complete_pickup(UUID, TEXT, FLOAT);

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

-- 4. COLLECTOR: CLAIM PICKUP (Uses p_mode for flexibility)
CREATE OR REPLACE FUNCTION public.collector_claim_pickup(
    p_pickup_id UUID,
    p_mode TEXT, -- 'immediate' or 'scheduled'
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
        RETURN json_build_object('success', false, 'message', 'Not logged in');
    END IF;

    -- Only allow 5 active tasks per collector
    SELECT COUNT(*) INTO v_active_count 
    FROM public.pickups 
    WHERE collector_id = v_collector_id 
      AND status IN ('accepted', 'in_transit', 'arrived');

    IF v_active_count >= 5 THEN
        RETURN json_build_object('success', false, 'message', 'Max capacity reached! (5 tasks limit)');
    END IF;

    -- Lock and check
    SELECT collector_id, user_id INTO v_current_collector_id, v_resident_id 
    FROM public.pickups WHERE id = p_pickup_id FOR UPDATE;

    IF v_current_collector_id IS NOT NULL THEN
        RETURN json_build_object('success', false, 'message', 'Already claimed');
    END IF;

    UPDATE public.pickups
    SET 
        collector_id = v_collector_id,
        is_assigned = true,
        status = CASE WHEN p_mode = 'immediate' THEN 'in_transit' ELSE 'accepted' END,
        scheduled_arrival = p_scheduled_arrival
    WHERE id = p_pickup_id;

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (v_resident_id, 'Collector Assigned! 🚚', 'A collector is starting their trip to you.', 'info');

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. COLLECTOR: COMPLETE PICKUP (Hardware Verification & Rewards for BOTH parties)
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

    IF NOT FOUND THEN RETURN json_build_object('success', false, 'message', 'Pickup not found'); END IF;
    IF v_pickup.status = 'completed' THEN RETURN json_build_object('success', false, 'message', 'Already completed'); END IF;
    IF v_pickup.qr_code_id != p_qr_code THEN RETURN json_build_object('success', false, 'message', 'Invalid QR Code'); END IF;

    -- Resident: 20 pts/kg, Collector: 10 pts/kg
    v_res_points := ROUND(p_actual_weight * 20);
    v_coll_points := ROUND(p_actual_weight * 10);

    UPDATE public.pickups
    SET status = 'completed', weight_kg = p_actual_weight, points_awarded = v_res_points, completed_at = NOW()
    WHERE id = p_pickup_id;

    -- AWARD POINTS TO BOTH PARTIES
    PERFORM public.increment_points(v_pickup.user_id, v_res_points);
    PERFORM public.increment_points(auth.uid(), v_coll_points);

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES 
        (v_pickup.user_id, 'Points Earned! 🌱', 'You earned ' || v_res_points || ' pts for your collection.', 'success'),
        (auth.uid(), 'Collect Mission Success! 💰', 'Awarded ' || v_coll_points || ' pts for completing this collection.', 'success');

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RESIDENT: CANCEL PICKUP
CREATE OR REPLACE FUNCTION public.resident_cancel_pickup(p_pickup_id UUID)
RETURNS JSON AS $$
DECLARE
    v_pickup RECORD;
BEGIN
    -- Check ownership and current status
    SELECT * INTO v_pickup FROM public.pickups 
    WHERE id = p_pickup_id AND user_id = auth.uid();

    IF NOT FOUND THEN RETURN json_build_object('success', false, 'message', 'Pickup not found'); END IF;
    IF v_pickup.status IN ('completed', 'cancelled', 'archived') THEN 
        RETURN json_build_object('success', false, 'message', 'Cannot cancel in current status'); 
    END IF;

    -- Update to cancelled
    UPDATE public.pickups
    SET status = 'cancelled', is_assigned = false, collector_id = NULL
    WHERE id = p_pickup_id;

    -- Notify collector if assigned
    IF v_pickup.collector_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_pickup.collector_id, 'Pickup Cancelled By Resident 🛑', 'The resident has cancelled the scheduled collection.', 'error');
    END IF;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. COLLECTOR: CANCEL PICKUP ASSIGNMENT
CREATE OR REPLACE FUNCTION public.collector_cancel_pickup(p_pickup_id UUID)
RETURNS JSON AS $$
DECLARE
    v_pickup RECORD;
BEGIN
    -- Check assignment
    SELECT * INTO v_pickup FROM public.pickups 
    WHERE id = p_pickup_id AND collector_id = auth.uid();

    IF NOT FOUND THEN RETURN json_build_object('success', false, 'message', 'Pickup not found'); END IF;
    
    -- Return to 'scheduled' status so others can claim it
    UPDATE public.pickups
    SET status = 'scheduled', is_assigned = false, collector_id = NULL, scheduled_arrival = NULL
    WHERE id = p_pickup_id;

    -- Notify Resident
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (v_pickup.user_id, 'Collector Rescheduling 📡', 'The assigned collector is no longer available. Your request is back in the queue.', 'info');

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

