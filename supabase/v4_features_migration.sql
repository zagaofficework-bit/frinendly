-- =====================================================================
-- FRIENDIFY SUPABASE V4 MIGRATION: ADVANCED FEATURES & ALL-TAB SYNC
-- Includes: Host Operating Hours & Availability Days, Booking Client Metadata,
-- Photo Messaging Payload Support, and Profile Updates.
-- Run in Supabase Dashboard -> SQL Editor -> New Query -> Run
-- =====================================================================

-- 1. EXTEND COMPANIONS TABLE FOR HOST AVAILABILITY SCHEDULE
ALTER TABLE public.companions
    ADD COLUMN IF NOT EXISTS availability_days TEXT[] NOT NULL DEFAULT '{"Mon","Tue","Wed","Thu","Fri","Sat","Sun"}',
    ADD COLUMN IF NOT EXISTS availability_hours TEXT NOT NULL DEFAULT '10:00 AM - 10:00 PM';

COMMENT ON COLUMN public.companions.availability_days IS 'Active days of the week when companion is open for bookings';
COMMENT ON COLUMN public.companions.availability_hours IS 'Daily operating time range (e.g. 10:00 AM - 10:00 PM)';

-- 2. EXTEND BOOKINGS TABLE FOR HOST DASHBOARD CLIENT VISIBILITY
ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS client_name TEXT,
    ADD COLUMN IF NOT EXISTS client_avatar TEXT;

COMMENT ON COLUMN public.bookings.client_name IS 'Display name of the client who booked the session';
COMMENT ON COLUMN public.bookings.client_avatar IS 'Avatar image URL of the client for host identification';

-- 3. ENSURE CHAT_MESSAGES SUPPORTS MEDIA & IMAGES
-- Message types now supported: 'text', 'voice', 'location', 'image'
ALTER TABLE public.chat_messages
    ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}'::jsonb;

-- 4. PROFILES RLS & UPDATE POLICY FOR USER EDIT PROFILE
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (
        auth.uid() = id
        OR auth.role() = 'authenticated'
        OR auth.role() = 'anon'
    );

-- 5. REFRESH REALTIME SUBSCRIPTION FOR ALL CORE TABLES
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.companions;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;
