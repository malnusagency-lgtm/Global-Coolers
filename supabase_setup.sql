-- ==========================================
-- GLOBAL COOLERS: FINAL COMPREHENSIVE SETUP
-- Description: Complete schema, and automated logic.
-- Author: Antigravity AI
-- ==========================================

BEGIN;

-- 1. OVERRIDE: Clear existing state for a clean install
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_pickup_status_update ON public.pickups;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_pickup_notifications() CASCADE;
DROP FUNCTION IF EXISTS public.increment_points(uuid, int) CASCADE;

DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.reports CASCADE;
DROP TABLE IF EXISTS public.challenge_participants CASCADE;
DROP TABLE IF EXISTS public.challenges CASCADE;
DROP TABLE IF EXISTS public.reviews CASCADE;
DROP TABLE IF EXISTS public.redemptions CASCADE;
DROP TABLE IF EXISTS public.rewards CASCADE;
DROP TABLE IF EXISTS public.pickups CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. PROFILES TABLE
-- Stores user data with 500 bonus points by default
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    email TEXT,
    role TEXT CHECK (role IN ('resident', 'collector')) DEFAULT 'resident',
    eco_points INTEGER DEFAULT 500, -- Initial 500 bonus points
    co2_saved FLOAT DEFAULT 0.0,
    latitude FLOAT,
    longitude FLOAT,
    is_online BOOLEAN DEFAULT false,
    phone TEXT,
    address TEXT,
    avatar_url TEXT,
    neighborhood TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. NOTIFICATIONS TABLE
-- Stores in-app alerts for users
CREATE TABLE public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info', -- 'info', 'success', 'warning', 'error'
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. REWARDS TABLE
-- Items available for eco-point redemption
CREATE TABLE public.rewards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    partner TEXT DEFAULT 'Global Coolers',
    description TEXT,
    points_cost INTEGER NOT NULL,
    image_url TEXT,
    category TEXT,
    icon_name TEXT,
    color_hex TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. PICKUPS TABLE
-- Core operational table with strict status management
CREATE TABLE public.pickups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    collector_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    date TEXT NOT NULL, -- Scheduled date/time string
    waste_type TEXT NOT NULL,
    address TEXT NOT NULL,
    status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'accepted', 'in_transit', 'arrived', 'completed', 'cancelled', 'archived')),
    photo_url TEXT,
    verification_photo_url TEXT,
    latitude FLOAT,
    longitude FLOAT,
    is_assigned BOOLEAN DEFAULT false,
    is_immediate BOOLEAN DEFAULT false,
    weight_kg FLOAT DEFAULT 1.0,
    cost_kes INTEGER DEFAULT 0,
    qr_code_id TEXT UNIQUE,
    points_awarded INTEGER DEFAULT 0,
    rating INTEGER,
    scheduled_arrival TEXT, -- Changed to TEXT to match app structure
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. REDEMPTIONS TABLE
-- Tracks point spending transactions
CREATE TABLE public.redemptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reward_id UUID REFERENCES public.rewards(id) ON DELETE SET NULL,
    reward_title TEXT, -- Snapshot of title for history
    points_spent INTEGER NOT NULL,
    mpesa_number TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. MESSAGES TABLE
-- Chat between Resident and Collector
CREATE TABLE public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pickup_id UUID REFERENCES public.pickups(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.profiles(id),
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- FUNCTIONS & AUTOMATED LOGIC
-- ==========================================

-- 1. Helper: Create Notification
CREATE OR REPLACE FUNCTION public.create_notification(uid UUID, t TEXT, msg TEXT, ntype TEXT DEFAULT 'info')
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (uid, t, msg, ntype);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger: Handle New User Signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    u_role TEXT;
    u_name TEXT;
BEGIN
    u_role := COALESCE(NEW.raw_user_meta_data->>'role', 'resident');
    u_name := COALESCE(NEW.raw_user_meta_data->>'full_name', 'Eco Hero');

    INSERT INTO public.profiles (id, full_name, role, email, phone, eco_points)
    VALUES (
        NEW.id, 
        u_name,
        u_role,
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        500 -- Automatic 500 Bonus Points
    );

    -- Send Welcome Notification
    PERFORM public.create_notification(
        NEW.id, 
        'Welcome to Global Coolers! 🎉', 
        'Thank you for joining. We have awarded you 500 EcoPoints to kickstart your journey.',
        'success'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Atomic Point Increment
CREATE OR REPLACE FUNCTION public.increment_points(user_id UUID, amount INT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET eco_points = eco_points + amount,
        co2_saved = co2_saved + (amount * 0.5)
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger: Handle Pickup Notifications & Points
CREATE OR REPLACE FUNCTION public.handle_pickup_updates()
RETURNS TRIGGER AS $$
DECLARE
    res_points INTEGER;
    coll_points INTEGER;
BEGIN
    -- A: Assignment Notification
    IF (OLD.collector_id IS NULL AND NEW.collector_id IS NOT NULL) THEN
        PERFORM public.create_notification(
            NEW.user_id, 
            'Collector Assigned! 📍', 
            'A collector has been assigned to your ' || NEW.waste_type || ' pickup.'
        );
    END IF;

    -- B: Status Transitions
    IF (OLD.status != NEW.status) THEN
        -- Notify Resident
        IF (NEW.status = 'in_transit') THEN
            PERFORM public.create_notification(
                NEW.user_id, 
                'Driver on the way! 🚛', 
                'Your collector is heading to your location for the ' || NEW.waste_type || ' collection.'
            );
        ELSIF (NEW.status = 'arrived') THEN
            PERFORM public.create_notification(
                NEW.user_id, 
                'Collector Arrived! 🏁', 
                'Your collector is at your doorstep. Please have your QR code ready.'
            );
        ELSIF (NEW.status = 'completed') THEN
            -- Award Points
            res_points := (NEW.weight_kg * 10)::INTEGER;
            coll_points := (NEW.weight_kg * 5)::INTEGER;

            PERFORM public.increment_points(NEW.user_id, res_points);
            IF (NEW.collector_id IS NOT NULL) THEN
                PERFORM public.increment_points(NEW.collector_id, coll_points);
                
                PERFORM public.create_notification(
                    NEW.collector_id, 
                    'Pickup Completed! + ' || coll_points || ' pts', 
                    'You have successfully verified and completed the collection at ' || NEW.address,
                    'success'
                );
            END IF;

            PERFORM public.create_notification(
                NEW.user_id, 
                'Waste Processed! + ' || res_points || ' pts', 
                'Your ' || NEW.waste_type || ' waste has been verified. Thank you for recycling!',
                'success'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_pickup_status_update
    AFTER UPDATE ON public.pickups
    FOR EACH ROW EXECUTE FUNCTION public.handle_pickup_updates();

-- ==========================================
-- ROW LEVEL SECURITY (RLS) policies
-- ==========================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pickups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Profiles: Public Read, Self Write
CREATE POLICY "Profiles viewable by all" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Pickups: Owners and Assigned Collectors
CREATE POLICY "Residents can see own pickups" ON public.pickups FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Collectors can see work-related" ON public.pickups FOR SELECT USING (auth.uid() = collector_id OR (status = 'scheduled' AND collector_id IS NULL));
CREATE POLICY "Residents can insert pickups" ON public.pickups FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Pickup owners can update" ON public.pickups FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = collector_id);

-- Notifications: Self Read
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Messages: Pickup Participants
CREATE POLICY "Participants view messages" ON public.messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.pickups WHERE id = pickup_id AND (user_id = auth.uid() OR collector_id = auth.uid())));
CREATE POLICY "Participants send messages" ON public.messages FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.pickups WHERE id = pickup_id AND (user_id = auth.uid() OR collector_id = auth.uid())));

-- Rewards & Redemptions
CREATE POLICY "Public rewards view" ON public.rewards FOR SELECT USING (true);
CREATE POLICY "Residents can view own redemptions" ON public.redemptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Residents can create redemptions" ON public.redemptions FOR INSERT WITH CHECK (auth.uid() = user_id);

COMMIT;
