-- ==========================================
-- GLOBAL COOLERS: FINAL COMPREHENSIVE SETUP
-- Description: Complete schema, logic, and automated features.
-- Author: Antigravity AI
-- ==========================================

BEGIN;

-- 1. OVERRIDE: Clear existing state for a clean install
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_pickup_status_update ON public.pickups;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_pickup_updates() CASCADE;
DROP FUNCTION IF EXISTS public.increment_points(uuid, int) CASCADE;
DROP FUNCTION IF EXISTS public.create_notification(uuid, text, text, text) CASCADE;

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
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    email TEXT,
    role TEXT CHECK (role IN ('resident', 'collector')) DEFAULT 'resident',
    eco_points INTEGER DEFAULT 500, 
    co2_saved FLOAT DEFAULT 0.0,
    latitude FLOAT,
    longitude FLOAT,
    is_online BOOLEAN DEFAULT false,
    phone TEXT,
    address TEXT,
    avatar_url TEXT,
    neighborhood TEXT,
    streak_count INTEGER DEFAULT 0,
    referral_code TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. NOTIFICATIONS TABLE
CREATE TABLE public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info', 
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. REWARDS TABLE
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
CREATE TABLE public.pickups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    collector_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    date TEXT NOT NULL, 
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
    scheduled_arrival TEXT, 
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. REDEMPTIONS TABLE
CREATE TABLE public.redemptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reward_id UUID REFERENCES public.rewards(id) ON DELETE SET NULL,
    reward_title TEXT, 
    points_spent INTEGER NOT NULL,
    mpesa_number TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. CHALLENGES & SOCIAL
CREATE TABLE public.challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    points_reward INTEGER NOT NULL,
    category TEXT, -- 'Recycling', 'Community', 'Streak'
    target_value FLOAT DEFAULT 0.0,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.challenge_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    challenge_id UUID REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    current_value FLOAT DEFAULT 0.0,
    is_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(challenge_id, user_id)
);

-- 8. REVIEWS & FEEDBACK
CREATE TABLE public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pickup_id UUID REFERENCES public.pickups(id) ON DELETE CASCADE UNIQUE,
    writer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id UUID REFERENCES public.profiles(id),
    category TEXT, -- 'App Issue', 'Collector Issue', 'Payment'
    subject TEXT,
    description TEXT,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'closed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. MESSAGES TABLE
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
    ref_code TEXT;
BEGIN
    u_role := COALESCE(NEW.raw_user_meta_data->>'role', 'resident');
    u_name := COALESCE(NEW.raw_user_meta_data->>'full_name', 'Eco Hero');
    ref_code := 'GC-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 6));

    INSERT INTO public.profiles (id, full_name, role, email, phone, eco_points, referral_code)
    VALUES (
        NEW.id, 
        u_name,
        u_role,
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        500, -- 500 Bonus Points
        ref_code
    );

    PERFORM public.create_notification(
        NEW.id, 
        'Welcome to Global Coolers! 🎉', 
        'Join the green movement. We''ve started you off with 500 EcoPoints!',
        'success'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Atomic Point Increment
CREATE OR REPLACE FUNCTION public.increment_points(u_id UUID, amount INT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET eco_points = eco_points + amount,
        co2_saved = co2_saved + (amount * 0.45) -- 1kg ≈ 10pts ≈ 4.5kg CO2
    WHERE id = u_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger: Handle Pickup Notifications & Points
CREATE OR REPLACE FUNCTION public.handle_pickup_updates()
RETURNS TRIGGER AS $$
DECLARE
    res_points INTEGER;
    coll_points INTEGER;
BEGIN
    -- Assignment Notification
    IF (OLD.collector_id IS NULL AND NEW.collector_id IS NOT NULL) THEN
        PERFORM public.create_notification(
            NEW.user_id, 
            'Collector Assigned! 📍', 
            'A collector is confirmed for your ' || NEW.waste_type || ' pickup.'
        );
    END IF;

    -- Status Transitions
    IF (OLD.status != NEW.status) THEN
        IF (NEW.status = 'in_transit') THEN
            PERFORM public.create_notification(
                NEW.user_id, 
                'On Relevant Way! 🚛', 
                'The collector is heading to your location right now.'
            );
        ELSIF (NEW.status = 'arrived') THEN
            PERFORM public.create_notification(
                NEW.user_id, 
                'Collector Arrived! 🏁', 
                'Please meet the collector at the agreed location.'
            );
        ELSIF (NEW.status = 'completed') THEN
            res_points := (NEW.weight_kg * 10)::INTEGER;
            coll_points := (NEW.weight_kg * 5)::INTEGER;

            PERFORM public.increment_points(NEW.user_id, res_points);
            
            IF (NEW.collector_id IS NOT NULL) THEN
                PERFORM public.increment_points(NEW.collector_id, coll_points);
                PERFORM public.create_notification(
                    NEW.collector_id, 
                    'Earnings Credited! + ' || coll_points || ' pts', 
                    'Successful collection at ' || NEW.address,
                    'success'
                );
            END IF;

            PERFORM public.create_notification(
                NEW.user_id, 
                'Points Earned! + ' || res_points || ' pts', 
                'Thank you for recycling ' || NEW.weight_kg || 'kg of ' || NEW.waste_type || ' waste!',
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
-- ROW LEVEL SECURITY (RLS)
-- ==========================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pickups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Simple RLS Policies
CREATE POLICY "Public Read Profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Self Update Profiles" ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Own Pickups Select" ON public.pickups FOR SELECT USING (auth.uid() = user_id OR auth.uid() = collector_id OR (status = 'scheduled' AND collector_id IS NULL));
CREATE POLICY "Resident Insert Pickups" ON public.pickups FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Participant Update Pickups" ON public.pickups FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = collector_id);

CREATE POLICY "Own Notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Self Read Messages" ON public.messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.pickups WHERE id = pickup_id AND (user_id = auth.uid() OR collector_id = auth.uid())));
CREATE POLICY "Social Participant" ON public.challenge_participants FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Public Rewards" ON public.rewards FOR SELECT USING (true);
CREATE POLICY "Own redemptions" ON public.redemptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Create redemptions" ON public.redemptions FOR INSERT WITH CHECK (auth.uid() = user_id);

COMMIT;
