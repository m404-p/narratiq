-- ============================================================
-- NARRATIQ — Supabase Database Schema
-- Run this in your Supabase SQL Editor (Project → SQL Editor)
-- ============================================================

-- ── ENABLE UUID EXTENSION ──
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── PROFILES TABLE ──
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT,
  avatar_initials TEXT DEFAULT 'NQ',
  depth_score INTEGER DEFAULT 0,
  streak INTEGER DEFAULT 0,
  stories_tracked INTEGER DEFAULT 0,
  topics_mastered JSONB DEFAULT '[]',
  last_active TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── STORY ARCS TABLE ──
CREATE TABLE IF NOT EXISTS public.story_arcs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT DEFAULT 'Business',
  summary TEXT,
  created_by UUID REFERENCES public.profiles(id),
  tracking_count INTEGER DEFAULT 0,
  sentiment_pos INTEGER DEFAULT 50,
  timeline_events JSONB DEFAULT '[]',
  key_players JSONB DEFAULT '[]',
  contrarian_views JSONB DEFAULT '[]',
  watch_next JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── USER TRACKED STORIES ──
CREATE TABLE IF NOT EXISTS public.user_tracked_stories (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  story_id UUID REFERENCES public.story_arcs(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, story_id)
);

-- ── DISCUSSIONS TABLE ──
CREATE TABLE IF NOT EXISTS public.discussions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  story_id UUID REFERENCES public.story_arcs(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  parent_id UUID REFERENCES public.discussions(id),
  upvotes INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── ROW LEVEL SECURITY ──
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_arcs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tracked_stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discussions ENABLE ROW LEVEL SECURITY;

-- Profiles: anyone can read, only owner can write
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Story arcs: public read, authenticated write
CREATE POLICY "Story arcs are viewable by everyone" ON public.story_arcs FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create story arcs" ON public.story_arcs FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Creators can update own arcs" ON public.story_arcs FOR UPDATE USING (auth.uid() = created_by);

-- Tracked stories: user-specific
CREATE POLICY "Users can view own tracked stories" ON public.user_tracked_stories FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can track stories" ON public.user_tracked_stories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can untrack stories" ON public.user_tracked_stories FOR DELETE USING (auth.uid() = user_id);

-- Discussions: public read, authenticated write
CREATE POLICY "Discussions are public" ON public.discussions FOR SELECT USING (true);
CREATE POLICY "Authenticated users can post" ON public.discussions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users can edit own posts" ON public.discussions FOR UPDATE USING (auth.uid() = user_id);

-- ── REALTIME ──
-- Enable realtime for these tables in Supabase Dashboard:
-- Database → Replication → select: profiles, story_arcs, discussions

ALTER PUBLICATION supabase_realtime ADD TABLE public.story_arcs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.discussions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

-- ── HELPER FUNCTIONS ──
CREATE OR REPLACE FUNCTION increment_tracking(story_id UUID)
RETURNS void AS $$
  UPDATE public.story_arcs
  SET tracking_count = tracking_count + 1
  WHERE id = story_id;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_upvotes(disc_id UUID)
RETURNS void AS $$
  UPDATE public.discussions
  SET upvotes = upvotes + 1
  WHERE id = disc_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- Update last_active on profile update
CREATE OR REPLACE FUNCTION update_last_active()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_active = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_profile_update
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_last_active();

-- ── SEED DATA (Optional demo arcs) ──
-- Uncomment to pre-populate with demo stories:
/*
INSERT INTO public.story_arcs (title, category, summary, tracking_count, sentiment_pos, timeline_events, key_players, contrarian_views, watch_next) VALUES
(
  'AI Chip Wars: Nvidia vs AMD vs Intel',
  'Technology',
  'Three-way battle for AI accelerator dominance as hyperscalers diversify away from Nvidia monopoly.',
  4231, 62,
  '[{"date":"Mar 2026","headline":"Nvidia H300 announced — 4× inference speed","detail":"Market reacts with Nvidia shares hitting new ATH at $1,420.","impact":"high"},{"date":"Jan 2026","headline":"AMD MI400 delayed 6 months","detail":"Supply chain issues and TSMC capacity constraints cited.","impact":"high"},{"date":"Oct 2025","headline":"Intel Gaudi 3 wins Azure contract","detail":"First major hyperscaler win for Intel in AI accelerators.","impact":"medium"}]',
  '[{"name":"Nvidia","role":"Market leader","stance":"bullish","desc":"Dominant position with CUDA ecosystem moat."},{"name":"AMD","role":"Challenger","stance":"neutral","desc":"MI400 delay hurts but long-term competitive."},{"name":"Intel","role":"Underdog","stance":"neutral","desc":"Gaudi 3 Azure win signals rebound potential."},{"name":"Hyperscalers","role":"Customers","stance":"bullish","desc":"Diversifying chip sourcing to reduce Nvidia dependence."}]',
  '[{"view":"Nvidia moat is real but narrowing. Custom silicon from Google TPUs and AWS Trainium is the existential threat not priced in.","source":"Semiconductor analyst","credibility":88}]',
  '[{"event":"Nvidia Q1 FY2027 Earnings","date":"Apr 23 2026","significance":"high","desc":"H300 revenue recognition will validate current $4T market cap thesis."},{"event":"EU AI Chip Antitrust Probe","date":"May 15 2026","significance":"high","desc":"DG COMP ruling on CUDA software bundling could reshape competitive dynamics."}]'
);
*/
