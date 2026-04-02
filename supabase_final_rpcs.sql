-- 1. Drop existing functions to allow for type overrides
DROP FUNCTION IF EXISTS public.collector_claim_pickup(UUID, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS public.collector_complete_pickup(UUID, TEXT, FLOAT);

-- 2. Secure Claim Pickup RPC
CREATE OR REPLACE FUNCTION public.collector_claim_pickup(
    p_pickup_id UUID,
    p_is_immediate BOOLEAN,
    p_scheduled_arrival TEXT
)
RETURNS VOID AS $$
DECLARE
    v_collector_id UUID := auth.uid();
    v_current_collector_id UUID;
    v_current_status TEXT;
BEGIN
    IF v_collector_id IS NULL THEN
        RAISE EXCEPTION 'Not logged in';
    END IF;

    -- Lock the row to prevent race conditions and check assignment
    SELECT collector_id, status INTO v_current_collector_id, v_current_status 
    FROM public.pickups 
    WHERE id = p_pickup_id 
    FOR UPDATE;

    -- If another collector beat them to it, reject it
    IF v_current_collector_id IS NOT NULL THEN
        RAISE EXCEPTION 'This pickup was already claimed by another collector.';
    END IF;

    -- It's safe to assign to them!
    UPDATE public.pickups
    SET collector_id = v_collector_id,
        is_assigned = true,
        status = CASE WHEN p_is_immediate THEN 'in_transit' ELSE 'accepted' END,
        scheduled_arrival = p_scheduled_arrival
    WHERE id = p_pickup_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Secure Complete Pickup RPC
CREATE OR REPLACE FUNCTION public.collector_complete_pickup(
    p_pickup_id UUID,
    p_qr_code TEXT,
    p_actual_weight FLOAT
)
RETURNS VOID AS $$
DECLARE
    v_collector_id UUID := auth.uid();
    v_actual_qr TEXT;
    v_status TEXT;
    res_points INTEGER;
    coll_points INTEGER;
BEGIN
    IF v_collector_id IS NULL THEN
        RAISE EXCEPTION 'Not logged in';
    END IF;

    SELECT qr_code_id, status INTO v_actual_qr, v_status 
    FROM public.pickups 
    WHERE id = p_pickup_id AND collector_id = v_collector_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Pickup not found or you are not the assigned collector.';
    END IF;

    IF v_status = 'completed' THEN
        RAISE EXCEPTION 'This pickup has already been verified and completed.';
    END IF;

    IF v_actual_qr != p_qr_code THEN
        RAISE EXCEPTION 'Invalid QR code. Verification failed.';
    END IF;

    res_points := ROUND(p_actual_weight * 20);
    coll_points := ROUND(p_actual_weight * 10);

    UPDATE public.pickups
    SET status = 'completed',
        weight_kg = p_actual_weight,
        points_awarded = res_points,
        completed_at = NOW()
    WHERE id = p_pickup_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
