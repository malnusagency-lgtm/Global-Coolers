-- ═══════════════════════════════════════════════════════
-- GLOBAL COOLERS — FINAL LOGIC CONSOLIDATION
-- ═══════════════════════════════════════════════════════

-- 1. Atomic Point Increment Function
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

-- 2. HARDENED CLAIM PICKUP RPC
CREATE OR REPLACE FUNCTION public.collector_claim_pickup(
    p_pickup_id UUID,
    p_is_immediate BOOLEAN,
    p_scheduled_arrival TEXT
)
RETURNS VOID AS $$
DECLARE
    v_collector_id UUID := auth.uid();
    v_current_collector_id UUID;
    v_resident_id UUID;
BEGIN
    -- Force check for logged in collector
    IF v_collector_id IS NULL THEN
        RAISE EXCEPTION 'Not logged in';
    END IF;

    -- Lock and check
    SELECT collector_id, user_id INTO v_current_collector_id, v_resident_id 
    FROM public.pickups WHERE id = p_pickup_id FOR UPDATE;

    IF v_current_collector_id IS NOT NULL THEN
        RAISE EXCEPTION 'This pickup was already claimed.';
    END IF;

    -- Assign
    UPDATE public.pickups
    SET 
        collector_id = v_collector_id,
        is_assigned = true,
        status = CASE WHEN p_is_immediate THEN 'in_transit' ELSE 'accepted' END,
        scheduled_arrival = p_scheduled_arrival
    WHERE id = p_pickup_id;

    -- Notify Resident
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (v_resident_id, 'Collector Assigned! 🚚', 'A collector has claimed your request and is scheduled to arrive.', 'info');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. HARDENED COMPLETE PICKUP RPC (Rewards)
CREATE OR REPLACE FUNCTION public.collector_complete_pickup(
    p_pickup_id UUID,
    p_qr_code TEXT,
    p_actual_weight FLOAT
)
RETURNS VOID AS $$
DECLARE
    v_pickup RECORD;
    v_res_points INTEGER;
    v_coll_points INTEGER;
BEGIN
    -- 1. Security Check
    SELECT * INTO v_pickup FROM public.pickups 
    WHERE id = p_pickup_id AND collector_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pickup not found or not assigned to you.';
    END IF;

    IF v_pickup.status = 'completed' THEN
        RAISE EXCEPTION 'This pickup is already completed.';
    END IF;

    -- 2. QR Verification
    IF v_pickup.qr_code_id != p_qr_code THEN
        RAISE EXCEPTION 'Verification Failed: Invalid QR Code.';
    END IF;

    -- 3. Compute Points (20 for Resident, 10 for Collector)
    v_res_points := ROUND(p_actual_weight * 20);
    v_coll_points := ROUND(p_actual_weight * 10);

    -- 4. Atomic Updates
    -- a. Update Pickup record
    UPDATE public.pickups
    SET 
        status = 'completed',
        weight_kg = p_actual_weight,
        points_awarded = v_res_points,
        completed_at = NOW()
    WHERE id = p_pickup_id;

    -- b. Update Resident Points
    PERFORM public.increment_points(v_pickup.user_id, v_res_points);
    
    -- c. Update Collector Points
    PERFORM public.increment_points(auth.uid(), v_coll_points);

    -- 5. Final Notifications
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES 
        (v_pickup.user_id, 'Eco-Rewards Earned! 🌱', 'You earned ' || v_res_points || ' pts for your contribution.', 'success'),
        (auth.uid(), 'Collection Complete! 💰', 'You earned ' || v_coll_points || ' pts for completing the collection.', 'success');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Status Update Trigger (Automated Alerts)
CREATE OR REPLACE FUNCTION public.handle_pickup_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status != NEW.status) THEN
        IF (NEW.status = 'arrived') THEN
            INSERT INTO public.notifications (user_id, title, message)
            VALUES (NEW.user_id, 'Collector Arrived! 🏁', 'A collector is waiting for you. Get your QR code ready.');
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_pickup_status_update ON public.pickups;
CREATE TRIGGER on_pickup_status_update
    AFTER UPDATE ON public.pickups
    FOR EACH ROW EXECUTE FUNCTION public.handle_pickup_status_change();
