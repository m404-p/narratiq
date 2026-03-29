// ============================================================
// NARRATIQ — Supabase Configuration
// Replace with your actual Supabase project credentials
// ============================================================
const SUPABASE_URL = 'https://pfzxgkfynxnhipimgshi.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmenhna2Z5bnhuaGlwaW1nc2hpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NTk0ODEsImV4cCI6MjA5MDMzNTQ4MX0.-YxGiFB7iIoawMqCmjukGTJNiO4AEEXqZEMEujUdFWw';
const ANTHROPIC_PROXY = 'https://api.anthropic.com/v1/messages'; // Use your proxy/edge function

// Initialize Supabase client
const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============================================================
// AUTH HELPERS
// ============================================================
const Auth = {
  async signUp(email, password, username) {
    const { data, error } = await sb.auth.signUp({
      email,
      password,
      options: { data: { username, avatar_initials: username.slice(0, 2).toUpperCase() } }
    });
    if (error) throw error;
    if (data.user) {
      await sb.from('profiles').upsert({
        id: data.user.id,
        username,
        email,
        avatar_initials: username.slice(0, 2).toUpperCase(),
        depth_score: 0,
        streak: 0,
        stories_tracked: 0,
        topics_mastered: [],
        created_at: new Date().toISOString()
      });
    }
    return data;
  },

  async signIn(email, password) {
    const { data, error } = await sb.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  },

  async signOut() {
    await sb.auth.signOut();
    window.location.href = '/index.html';
  },

  async getUser() {
    const { data: { user } } = await sb.auth.getUser();
    return user;
  },

  async getProfile(userId) {
    const { data } = await sb.from('profiles').select('*').eq('id', userId).single();
    return data;
  },

  onAuthChange(callback) {
    return sb.auth.onAuthStateChange(callback);
  }
};

// ============================================================
// STORY ARC HELPERS
// ============================================================
const Stories = {
  async getAll() {
    const { data } = await sb.from('story_arcs')
      .select('*, profiles(username, avatar_initials)')
      .order('created_at', { ascending: false });
    return data || [];
  },

  async getTrending() {
    const { data } = await sb.from('story_arcs')
      .select('*')
      .order('tracking_count', { ascending: false })
      .limit(6);
    return data || [];
  },

  async getById(id) {
    const { data } = await sb.from('story_arcs')
      .select('*, profiles(username, avatar_initials)')
      .eq('id', id)
      .single();
    return data;
  },

  async create(story) {
    const user = await Auth.getUser();
    if (!user) throw new Error('Not authenticated');
    const { data, error } = await sb.from('story_arcs').insert({
      ...story,
      created_by: user.id,
      tracking_count: 1,
      created_at: new Date().toISOString()
    }).select().single();
    if (error) throw error;
    return data;
  },

  async track(storyId) {
    const user = await Auth.getUser();
    if (!user) return;
    await sb.from('user_tracked_stories').upsert({ user_id: user.id, story_id: storyId });
    await sb.rpc('increment_tracking', { story_id: storyId });
    await sb.from('profiles').update({ stories_tracked: sb.raw('stories_tracked + 1') }).eq('id', user.id);
  },

  async getTrackedByUser(userId) {
    const { data } = await sb.from('user_tracked_stories')
      .select('story_id, story_arcs(*)')
      .eq('user_id', userId);
    return data || [];
  }
};

// ============================================================
// DISCUSSIONS HELPERS
// ============================================================
const Discussions = {
  async getByStory(storyId) {
    const { data } = await sb.from('discussions')
      .select('*, profiles(username, avatar_initials, depth_score)')
      .eq('story_id', storyId)
      .order('created_at', { ascending: true });
    return data || [];
  },

  async post(storyId, content, parentId = null) {
    const user = await Auth.getUser();
    if (!user) throw new Error('Not authenticated');
    const { data, error } = await sb.from('discussions').insert({
      story_id: storyId,
      user_id: user.id,
      content,
      parent_id: parentId,
      upvotes: 0,
      created_at: new Date().toISOString()
    }).select('*, profiles(username, avatar_initials, depth_score)').single();
    if (error) throw error;
    return data;
  },

  async upvote(discussionId) {
    await sb.rpc('increment_upvotes', { disc_id: discussionId });
  },

  subscribeToStory(storyId, callback) {
    return sb.channel(`discussions:${storyId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'discussions',
        filter: `story_id=eq.${storyId}`
      }, callback)
      .subscribe();
  }
};

// ============================================================
// AI — STORY ARC GENERATOR
// Uses Anthropic API via Supabase Edge Function
// ============================================================
const AI = {
  async generateStoryArc(topic) {
    const { data, error } = await sb.functions.invoke('generate-story-arc', {
      body: { topic }
    });
    if (error) throw error;
    return data;
  },

  async generateInsight(storyContext, question) {
    const { data, error } = await sb.functions.invoke('ai-insight', {
      body: { storyContext, question }
    });
    if (error) throw error;
    return data;
  }
};

// ============================================================
// ANALYTICS — Creator Dashboard
// ============================================================
const Analytics = {
  async getPlatformStats() {
    const [users, stories, discussions] = await Promise.all([
      sb.from('profiles').select('id', { count: 'exact' }),
      sb.from('story_arcs').select('id', { count: 'exact' }),
      sb.from('discussions').select('id', { count: 'exact' })
    ]);
    return {
      totalUsers: users.count || 0,
      totalStories: stories.count || 0,
      totalDiscussions: discussions.count || 0
    };
  },

  async getActiveUsers() {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { count } = await sb.from('profiles')
      .select('id', { count: 'exact' })
      .gte('last_active', since);
    return count || 0;
  },

  subscribeToRealtime(table, callback) {
    return sb.channel(`realtime:${table}`)
      .on('postgres_changes', { event: '*', schema: 'public', table }, callback)
      .subscribe();
  }
};

// Utility: format relative time
function timeAgo(dateStr) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

// Utility: show toast notification
function showToast(msg, type = 'info') {
  const t = document.createElement('div');
  t.className = `toast toast-${type}`;
  t.textContent = msg;
  document.body.appendChild(t);
  requestAnimationFrame(() => t.classList.add('show'));
  setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 300); }, 3000);
}
