-- =====================================================================
-- FRIENDIFY SUPABASE SCHEMA (Production Ready)
-- Platonic Companion Marketplace Backend
-- Run this in your Supabase SQL Editor (Dashboard -> SQL Editor -> New Query)
-- =====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. ENUMS (Safe creation)
DO $$ BEGIN
    CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'completed', 'canceled');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE message_type AS ENUM ('text', 'voice', 'location');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('client', 'companion', 'admin');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 3. PROFILES TABLE (Mirrors auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    phone TEXT,
    display_name TEXT NOT NULL DEFAULT 'User',
    avatar_url TEXT,
    role user_role NOT NULL DEFAULT 'client',
    wallet_balance NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. COMPANIONS TABLE
CREATE TABLE IF NOT EXISTS public.companions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    age INT NOT NULL CHECK (age >= 18),
    city TEXT NOT NULL,
    bio TEXT NOT NULL,
    avatar_url TEXT NOT NULL,
    gallery TEXT[] NOT NULL DEFAULT '{}',
    hourly_rate NUMERIC(10, 2) NOT NULL CHECK (hourly_rate > 0),
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.0 CHECK (rating >= 0 AND rating <= 5),
    review_count INT NOT NULL DEFAULT 0,
    distance_km NUMERIC(5, 2) NOT NULL DEFAULT 1.0,
    verified BOOLEAN NOT NULL DEFAULT false,
    background_checked BOOLEAN NOT NULL DEFAULT false,
    languages TEXT[] NOT NULL DEFAULT '{"English"}',
    tags TEXT[] NOT NULL DEFAULT '{}',
    activities TEXT[] NOT NULL DEFAULT '{}',
    badges TEXT[] NOT NULL DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    companion_id UUID NOT NULL REFERENCES public.companions(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    hours INT NOT NULL CHECK (hours > 0),
    activity TEXT NOT NULL,
    location TEXT NOT NULL,
    status booking_status NOT NULL DEFAULT 'pending',
    subtotal NUMERIC(10, 2) NOT NULL,
    total NUMERIC(10, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. REVIEWS TABLE
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    companion_id UUID NOT NULL REFERENCES public.companions(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    author_name TEXT NOT NULL,
    rating NUMERIC(2, 1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. CHAT MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    companion_id UUID REFERENCES public.companions(id) ON DELETE SET NULL,
    text TEXT NOT NULL,
    type message_type NOT NULL DEFAULT 'text',
    payload JSONB,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. EMERGENCY CONTACTS TABLE
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================================
-- AUTOMATIC PROFILE CREATION TRIGGER (AUTH SYNC)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(COALESCE(NEW.email, 'user@friendify'), '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Companions Policies
DROP POLICY IF EXISTS "Active companions are viewable by all" ON public.companions;
CREATE POLICY "Active companions are viewable by all" ON public.companions
    FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Companions can insert own profile" ON public.companions;
CREATE POLICY "Companions can insert own profile" ON public.companions
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Companions can update own profile" ON public.companions;
CREATE POLICY "Companions can update own profile" ON public.companions
    FOR UPDATE USING (auth.uid() = user_id);

-- Bookings Policies
DROP POLICY IF EXISTS "Users can view their own bookings" ON public.bookings;
CREATE POLICY "Users can view their own bookings" ON public.bookings
    FOR SELECT USING (auth.uid() = client_id OR auth.uid() IN (SELECT user_id FROM public.companions WHERE id = companion_id));

DROP POLICY IF EXISTS "Users can insert their own bookings" ON public.bookings;
CREATE POLICY "Users can insert their own bookings" ON public.bookings
    FOR INSERT WITH CHECK (auth.uid() = client_id);

DROP POLICY IF EXISTS "Users can update their own bookings" ON public.bookings;
CREATE POLICY "Users can update their own bookings" ON public.bookings
    FOR UPDATE USING (auth.uid() = client_id OR auth.uid() IN (SELECT user_id FROM public.companions WHERE id = companion_id));

-- Reviews Policies
DROP POLICY IF EXISTS "Reviews viewable by everyone" ON public.reviews;
CREATE POLICY "Reviews viewable by everyone" ON public.reviews
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert reviews" ON public.reviews;
CREATE POLICY "Authenticated users can insert reviews" ON public.reviews
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Chat Messages Policies
DROP POLICY IF EXISTS "Users can view their own messages" ON public.chat_messages;
CREATE POLICY "Users can view their own messages" ON public.chat_messages
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can insert their own messages" ON public.chat_messages;
CREATE POLICY "Users can insert their own messages" ON public.chat_messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Emergency Contacts Policies
DROP POLICY IF EXISTS "Users manage own emergency contacts" ON public.emergency_contacts;
CREATE POLICY "Users manage own emergency contacts" ON public.emergency_contacts
    FOR ALL USING (auth.uid() = user_id);

-- =====================================================================
-- REALTIME SUBSCRIPTIONS
-- =====================================================================
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

-- =====================================================================
-- INITIAL SEED DATA (POPULATES COMPANION DIRECTORY)
-- =====================================================================
INSERT INTO public.companions (name, age, city, bio, avatar_url, gallery, hourly_rate, rating, review_count, distance_km, verified, background_checked, languages, tags, activities, badges)
SELECT 'Maya Sharma', 24, 'Mumbai', 
 'Passionate about indie cinema, local art exhibits, and specialty pour-over coffee. Always ready for great conversations about literature and architecture. Strictly platonic!',
 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
 ARRAY['https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80'],
 25.00, 4.9, 38, 1.2, true, true, 
 ARRAY['English', 'Hindi'], 
 ARRAY['Coffee', 'Sightseeing', 'Foodie'], 
 ARRAY['Coffee', 'Sightseeing'], 
 ARRAY['Top Rated', 'Great Listener', 'Art Lover']
WHERE NOT EXISTS (SELECT 1 FROM public.companions WHERE name = 'Maya Sharma');

INSERT INTO public.companions (name, age, city, bio, avatar_url, gallery, hourly_rate, rating, review_count, distance_km, verified, background_checked, languages, tags, activities, badges)
SELECT 'Liam Patel', 26, 'Pune', 
 'Fitness enthusiast, weekend marathon runner, and board game geek. Perfect companion if you need a running buddy, gym spotter, or someone to try strategy board games with!',
 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80',
 ARRAY['https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80'],
 30.00, 4.8, 24, 2.5, true, true, 
 ARRAY['English', 'Hindi', 'Marathi'], 
 ARRAY['Gym Buddy', 'Board Games', 'Fitness'], 
 ARRAY['Gym Buddy', 'Board Games'], 
 ARRAY['Punctual', 'Energetic']
WHERE NOT EXISTS (SELECT 1 FROM public.companions WHERE name = 'Liam Patel');

INSERT INTO public.companions (name, age, city, bio, avatar_url, gallery, hourly_rate, rating, review_count, distance_km, verified, background_checked, languages, tags, activities, badges)
SELECT 'Sofia Alvares', 23, 'Mumbai', 
 'Food explorer, street market hunter, and museum buff. Whether you need a plus-one to a cultural exhibition or want to discover hidden cafes in Colaba, I have got you covered!',
 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80',
 ARRAY['https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=800&q=80'],
 20.00, 4.7, 19, 0.9, true, true, 
 ARRAY['English', 'Hindi'], 
 ARRAY['Coffee', 'Event Plus-One', 'Sightseeing'], 
 ARRAY['Coffee', 'Event Plus-One'], 
 ARRAY['Friendly', 'Local Guide']
WHERE NOT EXISTS (SELECT 1 FROM public.companions WHERE name = 'Sofia Alvares');

INSERT INTO public.companions (name, age, city, bio, avatar_url, gallery, hourly_rate, rating, review_count, distance_km, verified, background_checked, languages, tags, activities, badges)
SELECT 'Noah D''Souza', 27, 'Pune', 
 'Live music lover, acoustic guitar player, and avid podcast listener. Great companion for comedy shows, acoustic gigs, or quiet cafe work sessions.',
 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
 ARRAY['https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=800&q=80'],
 35.00, 5.0, 42, 3.1, true, true, 
 ARRAY['English', 'Hindi', 'Konkani'], 
 ARRAY['Event Plus-One', 'Coffee'], 
 ARRAY['Event Plus-One', 'Coffee'], 
 ARRAY['Top Rated', 'Verified ID']
WHERE NOT EXISTS (SELECT 1 FROM public.companions WHERE name = 'Noah D''Souza');

INSERT INTO public.companions (name, age, city, bio, avatar_url, gallery, hourly_rate, rating, review_count, distance_km, verified, background_checked, languages, tags, activities, badges)
SELECT 'Aisha Khan', 25, 'Mumbai', 
 'Book club host and casual badminton player. I love listening to life stories, discussing science fiction, and discovering rooftop sunset spots.',
 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
 ARRAY['https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80'],
 22.00, 4.8, 15, 1.8, true, true, 
 ARRAY['English', 'Hindi', 'Urdu'], 
 ARRAY['Coffee', 'Board Games', 'Sightseeing'], 
 ARRAY['Coffee', 'Board Games'], 
 ARRAY['Empathetic', 'Calm Vibe']
WHERE NOT EXISTS (SELECT 1 FROM public.companions WHERE name = 'Aisha Khan');
