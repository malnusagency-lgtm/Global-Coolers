-- ═══════════════════════════════════════════════════════
-- GLOBAL COOLERS — UNIFIED DATABASE PATCH
-- Run this ONCE in your Supabase SQL Editor
-- It is fully idempotent (safe to run multiple times)
-- ═══════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────
-- 1. ADD MISSING COLUMNS TO profiles
-- ─────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='total_collections') THEN
    ALTER TABLE public.profiles ADD COLUMN total_collections INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='total_waste_diverted') THEN
    ALTER TABLE public.profiles ADD COLUMN total_waste_diverted FLOAT DEFAULT 0.0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='rating') THEN
    ALTER TABLE public.profiles ADD COLUMN rating FLOAT DEFAULT 0.0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='last_active_at') THEN
    ALTER TABLE public.profiles ADD COLUMN last_active_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='is_online') THEN
    ALTER TABLE public.profiles ADD COLUMN is_online BOOLEAN DEFAULT false;
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 2. ADD MISSING COLUMN TO rewards
-- ─────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='rewards' AND column_name='is_active') THEN
    ALTER TABLE public.rewards ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 3. FIX reports TABLE (add missing columns)
-- ─────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reports' AND column_name='issue_type') THEN
    ALTER TABLE public.reports ADD COLUMN issue_type TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reports' AND column_name='location') THEN
    ALTER TABLE public.reports ADD COLUMN location TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reports' AND column_name='photo_url') THEN
    ALTER TABLE public.reports ADD COLUMN photo_url TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reports' AND column_name='user_id') THEN
    ALTER TABLE public.reports ADD COLUMN user_id UUID REFERENCES public.profiles(id);
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 4. CREATE addresses TABLE (if missing)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    label TEXT DEFAULT 'Home',
    address TEXT NOT NULL,
    latitude FLOAT,
    longitude FLOAT,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for addresses
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='addresses' AND policyname='Own Addresses Select') THEN
    CREATE POLICY "Own Addresses Select" ON public.addresses FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='addresses' AND policyname='Own Addresses Insert') THEN
    CREATE POLICY "Own Addresses Insert" ON public.addresses FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='addresses' AND policyname='Own Addresses Update') THEN
    CREATE POLICY "Own Addresses Update" ON public.addresses FOR UPDATE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='addresses' AND policyname='Own Addresses Delete') THEN
    CREATE POLICY "Own Addresses Delete" ON public.addresses FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- RLS for reports (if missing)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='reports' AND policyname='Own Reports Insert') THEN
    CREATE POLICY "Own Reports Insert" ON public.reports FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='reports' AND policyname='Own Reports Select') THEN
    CREATE POLICY "Own Reports Select" ON public.reports FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

-- RLS for messages (insert policy)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='Send Messages') THEN
    CREATE POLICY "Send Messages" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 5. RPC FUNCTIONS (All CreateOrReplace = idempotent)
-- ─────────────────────────────────────────────

-- Drop old signatures to prevent conflicts
DROP FUNCTION IF EXISTS public.resident_schedule_pickup(text, text, float, float, text, text);
DROP FUNCTION IF EXISTS public.collector_claim_pickup(uuid, boolean, text);
DROP FUNCTION IF EXISTS public.collector_claim_pickup(uuid, text, text);
DROP FUNCTION IF EXISTS public.collector_complete_pickup(uuid, text, float);
DROP FUNCTION IF EXISTS public.collector_cancel_pickup(uuid);
DROP FUNCTION IF EXISTS public.resident_cancel_pickup(uuid);
DROP FUNCTION IF EXISTS public.get_nearby_pickups(float, float, float);
DROP FUNCTION IF EXISTS public.increment_points(uuid, integer);

-- 5a. Atomic Point Increment
CREATE OR REPLACE FUNCTION public.increment_points(p_user_id UUID, p_amount INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET 
        eco_points = COALESCE(eco_points, 0) + p_amount,
        total_waste_diverted = CASE 
            WHEN p_amount > 0 THEN COALESCE(total_waste_diverted, 0) + (p_amount / 20.0)
            ELSE COALESCE(total_waste_diverted, 0)
        END
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5b. RESIDENT: Schedule Pickup (1 active limit)
CREATE OR REPLACE FUNCTION public.resident_schedule_pickup(
    p_waste_type TEXT,
    p_address TEXT,
    p_lat FLOAT,
    p_lng FLOAT,
    p_date TEXT,
    p_qr TEXT
)
RETURNS JSON AS $$
DECLARE
    v_active_count INTEGER;
    v_new_id UUID;
BEGIN
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
        auth.uid(), p_waste_type, p_address, p_lat, p_lng, p_date, p_qr, 'scheduled'
    ) RETURNING id INTO v_new_id;

    RETURN json_build_object('success', true, 'pickup_id', v_new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5c. COLLECTOR: Claim Pickup (accepts p_mode as text for flexibility)
CREATE OR REPLACE FUNCTION public.collector_claim_pickup(
    p_pickup_id UUID,
    p_mode TEXT,
    p_scheduled_arrival TEXT
)
RETURNS JSON AS $$
DECLARE
    v_collector_id UUID := auth.uid();
    v_active_count INTEGER;
    v_current_collector_id UUID;
    v_resident_id UUID;
    v_is_immediate BOOLEAN;
BEGIN
    v_is_immediate := (p_mode = 'immediate');

    IF v_collector_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Session expired. Please log in again.');
    END IF;

    SELECT COUNT(*) INTO v_active_count 
    FROM public.pickups 
    WHERE collector_id = v_collector_id 
      AND status IN ('accepted', 'in_transit', 'arrived');

    IF v_active_count >= 5 THEN
        RETURN json_build_object('success', false, 'message', 'Max capacity reached! You can only handle 5 tasks at a time.');
    END IF;

    SELECT collector_id, user_id INTO v_current_collector_id, v_resident_id 
    FROM public.pickups WHERE id = p_pickup_id FOR UPDATE;

    IF v_current_collector_id IS NOT NULL THEN
        RETURN json_build_object('success', false, 'message', 'Someone else already claimed this pickup.');
    END IF;

    UPDATE public.pickups
    SET 
        collector_id = v_collector_id,
        is_assigned = true,
        status = CASE WHEN v_is_immediate THEN 'in_transit' ELSE 'accepted' END,
        scheduled_arrival = p_scheduled_arrival
    WHERE id = p_pickup_id;

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (v_resident_id, 'Collector Assigned! 🚚', 'A collector has claimed your request and is on their way.', 'info');

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5d. COLLECTOR: Cancel Assignment
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
    VALUES (v_resident_id, 'Collector Update ⚠️', 'The assigned collector had to cancel. Your request is back in the pool.', 'warning');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5e. RESIDENT: Cancel Pickup
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

-- 5f. COLLECTOR: Complete Pickup (QR Verification + Rewards)
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

    v_res_points := ROUND(p_actual_weight * 20);
    v_coll_points := ROUND(p_actual_weight * 10);

    UPDATE public.pickups
    SET status = 'completed', weight_kg = p_actual_weight, points_awarded = v_res_points, completed_at = NOW()
    WHERE id = p_pickup_id;

    -- Increment collector total_collections
    UPDATE public.profiles SET total_collections = COALESCE(total_collections, 0) + 1 WHERE id = auth.uid();

    PERFORM public.increment_points(v_pickup.user_id, v_res_points);
    PERFORM public.increment_points(auth.uid(), v_coll_points);

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES 
        (v_pickup.user_id, 'Points Earned! 🌱', 'You earned ' || v_res_points || ' pts for your collection.', 'success'),
        (auth.uid(), 'Collection Complete! 💰', 'Awarded ' || v_coll_points || ' pts for this collection.', 'success');

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5g. GET NEARBY PICKUPS (Missing function!)
CREATE OR REPLACE FUNCTION public.get_nearby_pickups(
    p_lat FLOAT,
    p_lng FLOAT,
    p_radius_km FLOAT DEFAULT 10.0
)
RETURNS SETOF public.pickups AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.pickups
    WHERE status = 'scheduled'
      AND collector_id IS NULL
      AND latitude IS NOT NULL
      AND longitude IS NOT NULL
      AND (
        6371 * acos(
          cos(radians(p_lat)) * cos(radians(latitude)) *
          cos(radians(longitude) - radians(p_lng)) +
          sin(radians(p_lat)) * sin(radians(latitude))
        )
      ) <= p_radius_km
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────
-- 6. STATUS UPDATE TRIGGER
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_pickup_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status != NEW.status) AND (NEW.status = 'arrived') THEN
        INSERT INTO public.notifications (user_id, title, message)
        VALUES (NEW.user_id, 'Collector Arrived! 🏁', 'A collector is at your location. Get your QR code ready.');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_pickup_status_update ON public.pickups;
CREATE TRIGGER on_pickup_status_update
    AFTER UPDATE ON public.pickups
    FOR EACH ROW EXECUTE FUNCTION public.handle_pickup_status_change();

-- ─────────────────────────────────────────────
-- 7. CLEAN UP STUCK TEST DATA
-- ─────────────────────────────────────────────
-- Cancel any pickups that have been stuck in 'scheduled' with no collector for > 24 hours
UPDATE public.pickups 
SET status = 'cancelled' 
WHERE status = 'scheduled' 
  AND collector_id IS NULL 
  AND created_at < NOW() - INTERVAL '24 hours';

COMMIT;

-- ═══════════════════════════════════════════════════════
-- DONE! Your database is now fully synchronized.
-- ═══════════════════════════════════════════════════════
