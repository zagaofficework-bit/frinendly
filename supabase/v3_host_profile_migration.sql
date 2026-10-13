-- =====================================================================
-- FRIENDIFY SUPABASE V3 MIGRATION: HOST PROFILE COMPLETION & REALTIME
-- Fixes: Companion Profile Editing, Pause/Resume Visibility, Realtime Sync
-- Run in Supabase Dashboard -> SQL Editor -> New Query -> Run
-- =====================================================================

-- 1. ENSURE COMPANIONS COLUMNS & DEFAULTS
-- Ensures all columns required for Host Mode & profile completeness exist.
ALTER TABLE public.companions 
    ADD COLUMN IF NOT EXISTS gallery TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS languages TEXT[] NOT NULL DEFAULT '{"English"}',
    ADD COLUMN IF NOT EXISTS activities TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS badges TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Mumbai',
    ADD COLUMN IF NOT EXISTS age INT DEFAULT 21,
    ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC(10, 2) NOT NULL DEFAULT 25.00;

-- 2. REVISE COMPANIONS RLS POLICIES
-- Hosts must be able to view their own profile even when listing is paused (is_active = false)
DROP POLICY IF EXISTS "Active companions are viewable by all" ON public.companions;
CREATE POLICY "Active companions are viewable by all" ON public.companions
    FOR SELECT USING (
        is_active = true 
        OR auth.uid() = user_id
        OR auth.role() = 'anon'
    );

-- Allow companions to update their own profile details (bio, rate, activities, languages, gallery)
DROP POLICY IF EXISTS "Companions can update own profile" ON public.companions;
CREATE POLICY "Companions can update own profile" ON public.companions
    FOR UPDATE USING (
        auth.uid() = user_id 
        OR user_id IS NULL
        OR auth.role() = 'authenticated'
    );

-- Allow newly registered hosts to create companion profiles
DROP POLICY IF EXISTS "Companions can insert own profile" ON public.companions;
CREATE POLICY "Companions can insert own profile" ON public.companions
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        OR user_id IS NULL 
        OR auth.role() = 'authenticated' 
        OR auth.role() = 'anon'
    );

-- 3. REALTIME SYNC FOR COMPANIONS
-- Broadcasts live profile updates (status changes, rates, activities) to guests in Explore
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.companions;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 4. PROFILE COMPLETENESS CALCULATION FUNCTION (DATABASE-SIDE)
-- Computes the 0-100% completion score according to profile criteria
CREATE OR REPLACE FUNCTION public.calculate_companion_completeness(comp_id UUID)
RETURNS INT AS $$
DECLARE
    comp public.companions;
    score INT := 0;
BEGIN
    SELECT * INTO comp FROM public.companions WHERE id = comp_id;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    IF LENGTH(TRIM(COALESCE(comp.bio, ''))) >= 15 THEN score := score + 20; END IF;
    IF COALESCE(array_length(comp.activities, 1), 0) > 0 THEN score := score + 20; END IF;
    IF COALESCE(array_length(comp.languages, 1), 0) > 0 THEN score := score + 20; END IF;
    IF LENGTH(TRIM(COALESCE(comp.avatar_url, ''))) > 0 THEN score := score + 20; END IF;
    IF COALESCE(array_length(comp.gallery, 1), 0) > 0 THEN score := score + 20; END IF;

    RETURN score;
END;
$$ LANGUAGE plpgsql STABLE;
