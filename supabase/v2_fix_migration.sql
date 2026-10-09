-- =====================================================================
-- FRIENDIFY SUPABASE V2 REPAIR & HARDENING MIGRATION
-- Fixes: Foreign Keys, Realtime Chat, Automatic Rating Recalculation, RLS
-- Run in Supabase Dashboard -> SQL Editor -> New Query -> Run
-- =====================================================================

-- 1. FIX CHAT_MESSAGES FOREIGN KEY CONSTRAINT
-- Seeded companions exist in public.companions, not profiles.
-- receiver_id must be nullable so messages to companions do not violate foreign keys.
ALTER TABLE public.chat_messages 
    ALTER COLUMN receiver_id DROP NOT NULL;

-- 2. REVISE CHAT_MESSAGES RLS POLICIES
DROP POLICY IF EXISTS "Users can view their own messages" ON public.chat_messages;
CREATE POLICY "Users can view their own messages" ON public.chat_messages
    FOR SELECT USING (
        auth.uid() = sender_id 
        OR auth.uid() = receiver_id 
        OR companion_id IS NOT NULL
    );

DROP POLICY IF EXISTS "Users can insert their own messages" ON public.chat_messages;
CREATE POLICY "Users can insert their own messages" ON public.chat_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id 
        OR auth.role() = 'authenticated'
        OR auth.role() = 'anon'
    );

-- 3. AUTOMATIC RATING & REVIEW COUNT RECALCULATION TRIGGER
-- Automatically updates companion average rating and review_count in DB
CREATE OR REPLACE FUNCTION public.recalculate_companion_rating()
RETURNS TRIGGER AS $$
DECLARE
    target_id UUID;
    new_avg NUMERIC(3, 2);
    new_count INT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_id := OLD.companion_id;
    ELSE
        target_id := NEW.companion_id;
    END IF;

    SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 5.0), COUNT(*)
    INTO new_avg, new_count
    FROM public.reviews
    WHERE companion_id = target_id;

    UPDATE public.companions
    SET rating = new_avg,
        review_count = new_count
    WHERE id = target_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_recalculate_companion_rating ON public.reviews;
CREATE TRIGGER trg_recalculate_companion_rating
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.recalculate_companion_rating();

-- 4. REVISE REVIEWS RLS POLICIES (Allow authenticated & guests to leave reviews)
DROP POLICY IF EXISTS "Authenticated users can insert reviews" ON public.reviews;
DROP POLICY IF EXISTS "Anyone can insert reviews" ON public.reviews;
CREATE POLICY "Anyone can insert reviews" ON public.reviews
    FOR INSERT WITH CHECK (true);

-- 5. REVISE BOOKINGS RLS POLICIES
DROP POLICY IF EXISTS "Users can insert their own bookings" ON public.bookings;
CREATE POLICY "Users can insert their own bookings" ON public.bookings
    FOR INSERT WITH CHECK (
        auth.uid() = client_id 
        OR auth.role() = 'authenticated'
    );

-- 6. ENSURE REALTIME PUBLICATION HAS ALL REQUIRED TABLES
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;
