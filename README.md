# Narratiq — AI-Native Business Intelligence Platform

> Business news that thinks with you. Story arcs, not static articles.

---

### Step 1: Supabase Setup

1. Go to [supabase.com](https://supabase.com) → New Project
2. Name it `narratiq`, choose your region, set a strong DB password
3. Go to **SQL Editor** → paste entire contents of `supabase-schema.sql` → Run
4. Go to **Authentication** → Settings → enable Email confirmations (optional for hackathon: disable for faster testing)
5. Go to **Project Settings** → API → copy:
   - `Project URL` → your `SUPABASE_URL`
   - `anon public` key → your `SUPABASE_ANON_KEY`

### Step 2: Configure Credentials

Open `js/config.js` and replace:
```js
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_PUBLIC_KEY';
```

Also set your creator email in `pages/dashboard.html`:
```js
const CREATOR_EMAIL = 'your@email.com';
```

### Step 3: Deploy to Vercel

```bash
# Install Vercel CLI
npm i -g vercel

# From the narratiq/ folder:
vercel

# Follow prompts → link to your Vercel account
# Choose: No existing project → narratiq
# Vercel auto-detects static site from vercel.json
```

Or use **Vercel Dashboard**:
1. Push this folder to GitHub
2. Go to [vercel.com](https://vercel.com) → New Project → Import from GitHub
3. Select your repo → Deploy (zero config needed)

---

## 📁 Project Structure

```
narratiq/
├── index.html              # Landing page with auth modal
├── vercel.json             # Vercel deployment config
├── supabase-schema.sql     # Full DB schema + RLS policies
├── css/
│   ├── global.css          # Design system (tokens, nav, buttons, etc.)
│   ├── home.css            # Landing page styles
│   ├── arc.css             # Story Arc page styles
│   ├── dashboard.css       # User dashboard styles
│   └── explore.css         # Explore page styles
├── js/
│   └── config.js           # Supabase client + all helpers
└── pages/
    ├── arc.html            # ⭐ Story Arc Tracker (core feature)
    ├── dashboard.html      # User dashboard + creator analytics
    └── explore.html        # Browse all story arcs
```

---

## ✨ Features

### Story Arc Tracker (`pages/arc.html`)
- Type any business story → AI generates complete narrative
- Interactive timeline with impact levels
- Key players with stance (bullish/bearish/neutral)
- Sentiment bar (bullish/neutral/bearish %)
- Contrarian Radar — minority perspectives surfaced
- What to Watch Next — forward intelligence
- Ask AI — Q&A about the story
- Save arcs to Supabase, track them on dashboard

### User Dashboard (`pages/dashboard.html`)
- Depth score, streak, stories tracked, discussions count
- Topic expertise bars
- Tracked stories list
- My discussions history
- **Creator Analytics** (restricted to your email):
  - Total users, stories, discussions
  - Active users in last 24h
  - Top story arcs by tracking
  - Real-time event log (Supabase Realtime)

### Explore (`pages/explore.html`)
- All story arcs with search + category filter
- Sort by: most tracked, recent, bullish, bearish
- Click any arc → go to Story Arc Tracker

### Auth
- Email/password signup + signin via Supabase Auth
- Profile auto-created on signup
- Auth state persists across pages

---

## 🗄️ Supabase Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles, scores, streaks |
| `story_arcs` | AI-generated story arcs with JSONB data |
| `user_tracked_stories` | Junction: user ↔ story |
| `discussions` | Threaded story-anchored discussions |

**Realtime enabled on:** `story_arcs`, `discussions`, `profiles`

---

## 🔒 Row Level Security

- Profiles: Public read, owner write
- Story arcs: Public read, authenticated create
- Discussions: Public read, authenticated post
- Tracked stories: User-only access

---

## 🧠 AI Integration

Story Arc generation uses a local fallback (no API key needed for demo).

For full AI power, create a Supabase Edge Function:
```
supabase/functions/generate-story-arc/index.ts
```

Call Claude API from there using `ANTHROPIC_API_KEY` environment variable set in Supabase Dashboard → Settings → Edge Functions.

---

## 📊 Creator Analytics

Set `CREATOR_EMAIL` in `dashboard.html` to your email.
When you log in with that email, you'll see the "Creator Analytics" tab with:
- Real-time Supabase counters
- Top story arcs leaderboard  
- Live event log (new users, stories, discussions)
- Full schema reference

---

## 🎨 Design

- **Fonts:** Playfair Display (serif) + Syne (sans) + JetBrains Mono
- **Palette:** Dark editorial — ember red accent on paper white
- **Aesthetic:** WSJ meets terminal intelligence
- **Animations:** Subtle floating hero card, fade-up reveals, pulse indicators

---
