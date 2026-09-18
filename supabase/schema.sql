-- ==============================================================================
-- A-Chatz Complete Supabase PostgreSQL Schema & Security Policies
-- ==============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. PROFILES / USERS TABLE
-- Maps to auth.users and extends with application-specific profile data
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    username TEXT NOT NULL DEFAULT 'A-Chatz User',
    phone_number TEXT,
    avatar_url TEXT,
    bio TEXT DEFAULT '',
    status TEXT DEFAULT 'Available',
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMPTZ,
    blocked_user_ids TEXT[] DEFAULT '{}',
    account_type TEXT DEFAULT 'personal', -- 'personal', 'business'
    public_key TEXT,
    role TEXT DEFAULT 'user', -- 'user', 'admin', 'official'
    is_banned BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false,
    verification_tier TEXT, -- 'standard', 'official', 'vip'
    payment_integration JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for searching users by username / email / phone
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- ==============================================================================
-- 2. CONTACTS TABLE
-- Tracks mutual or saved contacts between users
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    nickname TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (user_id, contact_id)
);

CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON public.contacts(user_id);

-- ==============================================================================
-- 3. CHATS (CONVERSATIONS / THREADS) TABLE
-- Supports both 1-on-1 private chats and group chats
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.chats (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('private', 'group')),
    title TEXT NOT NULL DEFAULT 'Chat',
    photo_url TEXT,
    description TEXT,
    member_ids TEXT[] NOT NULL DEFAULT '{}',
    last_message TEXT,
    last_message_at TIMESTAMPTZ,
    last_message_sender_id TEXT,
    pinned_message_ids TEXT[] DEFAULT '{}',
    muted_by TEXT[] DEFAULT '{}',
    archived_by TEXT[] DEFAULT '{}',
    admins TEXT[] DEFAULT '{}',
    locked_by TEXT[] DEFAULT '{}',
    created_by TEXT,
    unread_count JSONB DEFAULT '{}',
    disappearing_duration INT, -- in seconds
    typing JSONB DEFAULT '{}',
    recording JSONB DEFAULT '{}',
    deleted_at JSONB DEFAULT '{}',
    is_ghost BOOLEAN DEFAULT false,
    crm_labels JSONB DEFAULT '{}',
    last_message_delivered_to JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chats_member_ids ON public.chats USING GIN(member_ids);
CREATE INDEX IF NOT EXISTS idx_chats_last_message_at ON public.chats(last_message_at DESC);

-- ==============================================================================
-- 4. MESSAGES TABLE
-- Encrypted and rich media messages within chats
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL,
    type TEXT NOT NULL, -- 'text', 'image', 'imageGroup', 'video', 'voice', 'document', 'location', 'system', 'sticker', 'poll'
    cipher_text TEXT NOT NULL,
    media_url TEXT,
    thumbnail_url TEXT,
    media_urls TEXT[] DEFAULT '{}',
    local_file_paths TEXT[] DEFAULT '{}',
    file_name TEXT,
    duration_ms INT,
    reply_to_message_id TEXT,
    edited_at TIMESTAMPTZ,
    latitude FLOAT8,
    longitude FLOAT8,
    is_live BOOLEAN DEFAULT false,
    live_until TIMESTAMPTZ,
    deleted_for TEXT[] DEFAULT '{}',
    deleted_for_everyone BOOLEAN DEFAULT false,
    deleted_by_admin BOOLEAN DEFAULT false,
    reactions JSONB DEFAULT '{}',
    read_by JSONB DEFAULT '{}',
    delivered_to JSONB DEFAULT '{}',
    starred_by TEXT[] DEFAULT '{}',
    is_encrypted BOOLEAN DEFAULT false,
    sender_public_key TEXT,
    recipient_public_key TEXT,
    is_view_once BOOLEAN DEFAULT false,
    opened_by TEXT[] DEFAULT '{}',
    self_destruct_duration INT,
    is_sos BOOLEAN DEFAULT false,
    is_forwarded BOOLEAN DEFAULT false,
    is_hd BOOLEAN DEFAULT false,
    poll_question TEXT,
    poll_options TEXT[] DEFAULT '{}',
    poll_votes JSONB DEFAULT '{}',
    image_reactions JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);

-- ==============================================================================
-- 5. STATUSES (STORIES) TABLE
-- 24-hour disappearing stories with music, text, media, reactions
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.statuses (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    owner_id TEXT NOT NULL,
    owner_name TEXT NOT NULL DEFAULT 'User',
    owner_photo_url TEXT,
    is_owner_verified BOOLEAN DEFAULT false,
    type TEXT NOT NULL DEFAULT 'text', -- 'text', 'image', 'video', 'voice'
    media_url TEXT,
    caption TEXT,
    text_bg_color BIGINT,
    text_font TEXT,
    music_title TEXT,
    music_artist TEXT,
    music_preview_url TEXT,
    seen_by JSONB DEFAULT '{}',
    reactions JSONB DEFAULT '{}',
    comments JSONB DEFAULT '[]',
    reshared_from_status_id TEXT,
    reshared_from_owner_name TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_statuses_owner_id ON public.statuses(owner_id);
CREATE INDEX IF NOT EXISTS idx_statuses_expires_at ON public.statuses(expires_at DESC);

-- ==============================================================================
-- 6. MUTED STATUSES TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.muted_statuses (
    user_id TEXT NOT NULL,
    muted_owner_id TEXT NOT NULL,
    muted_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, muted_owner_id)
);

-- ==============================================================================
-- 7. CHANNELS TABLE
-- Public broadcast channels
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.channels (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL,
    description TEXT,
    photo_url TEXT,
    owner_id TEXT NOT NULL,
    is_verified BOOLEAN DEFAULT false,
    followers_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_channels_owner_id ON public.channels(owner_id);

-- ==============================================================================
-- 8. CHANNEL FOLLOWERS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.channel_followers (
    channel_id TEXT NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    role TEXT DEFAULT 'follower', -- 'follower', 'admin'
    joined_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (channel_id, user_id)
);

-- ==============================================================================
-- 9. CHANNEL POSTS TABLE
-- Broadcast messages sent in channels
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.channel_posts (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    channel_id TEXT NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL,
    text TEXT,
    media_url TEXT,
    type TEXT DEFAULT 'text',
    reactions JSONB DEFAULT '{}',
    poll_question TEXT,
    poll_options TEXT[] DEFAULT '{}',
    poll_votes JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_channel_posts_channel_id ON public.channel_posts(channel_id);
CREATE INDEX IF NOT EXISTS idx_channel_posts_created_at ON public.channel_posts(created_at DESC);

-- ==============================================================================
-- 10. CALLS TABLE (VOIP & WEBRTC SIGNALING)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.calls (
    id TEXT PRIMARY KEY,
    caller_id TEXT NOT NULL,
    caller_name TEXT NOT NULL DEFAULT 'User',
    caller_photo_url TEXT,
    receiver_ids TEXT[] NOT NULL,
    chat_id TEXT NOT NULL,
    is_video BOOLEAN DEFAULT false,
    is_group BOOLEAN DEFAULT false,
    status TEXT NOT NULL DEFAULT 'calling', -- 'calling', 'accepted', 'declined', 'ended'
    offer JSONB,
    answer JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_calls_receiver_ids ON public.calls USING GIN(receiver_ids);
CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON public.calls(caller_id);

-- ==============================================================================
-- 11. CALL CANDIDATES TABLE (ICE CANDIDATES)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.call_candidates (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    call_id TEXT NOT NULL REFERENCES public.calls(id) ON DELETE CASCADE,
    candidate_type TEXT NOT NULL CHECK (candidate_type IN ('offerer', 'answerer')),
    candidate JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_call_candidates_call_id ON public.call_candidates(call_id);

-- ==============================================================================
-- 12. CALL HISTORY TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.call_history (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id TEXT NOT NULL,
    call_id TEXT,
    other_user_id TEXT,
    is_outgoing BOOLEAN DEFAULT false,
    is_video BOOLEAN DEFAULT false,
    status TEXT,
    timestamp TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_call_history_user_id ON public.call_history(user_id);

-- ==============================================================================
-- 13. LIVE SESSIONS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.live_sessions (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    host_id TEXT NOT NULL,
    host_name TEXT NOT NULL DEFAULT 'Host',
    host_photo_url TEXT,
    title TEXT NOT NULL,
    status TEXT DEFAULT 'live', -- 'live', 'ended'
    viewer_count INT DEFAULT 0,
    co_host_id TEXT,
    co_host_name TEXT,
    co_host_photo_url TEXT,
    co_host_status TEXT, -- 'requested', 'approved', 'declined'
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_live_sessions_host_id ON public.live_sessions(host_id);
CREATE INDEX IF NOT EXISTS idx_live_sessions_status ON public.live_sessions(status);

-- Subcollections for live sessions
CREATE TABLE IF NOT EXISTS public.live_comments (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    session_id TEXT NOT NULL REFERENCES public.live_sessions(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    user_photo_url TEXT,
    comment TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_live_comments_session_id ON public.live_comments(session_id);

CREATE TABLE IF NOT EXISTS public.live_join_requests (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    session_id TEXT NOT NULL REFERENCES public.live_sessions(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    photo_url TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_live_join_requests_session_id ON public.live_join_requests(session_id);

-- ==============================================================================
-- 14. COMMUNITIES TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.communities (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    owner_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    photo_url TEXT,
    group_ids TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_communities_owner_id ON public.communities(owner_id);

-- ==============================================================================
-- 15. SCHEDULED CALLS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.scheduled_calls (
    meeting_id TEXT PRIMARY KEY,
    organizer_id TEXT NOT NULL,
    chat_id TEXT NOT NULL,
    title TEXT NOT NULL,
    scheduled_time TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 16. GAMES TABLE (e.g. Tic Tac Toe)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.games (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    player_x TEXT NOT NULL,
    player_o TEXT,
    board JSONB,
    current_turn TEXT,
    status TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 17. CATALOG ITEMS TABLE (Business Catalog)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.catalog_items (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC,
    image_url TEXT,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_catalog_items_user_id ON public.catalog_items(user_id);

-- ==============================================================================
-- 18. REPORTS TABLE (Moderation)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    reporter_id TEXT NOT NULL,
    reported_user_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'resolved', 'dismissed'
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 19. VERIFICATION REQUESTS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.verification_requests (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id TEXT NOT NULL,
    full_name TEXT,
    document_urls TEXT[] DEFAULT '{}',
    status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    tier TEXT,
    submitted_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 20. BUSINESS ANALYTICS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.business_analytics (
    id TEXT PRIMARY KEY, -- owner user ID
    profile_clicks INT DEFAULT 0,
    catalog_views INT DEFAULT 0,
    messages_received INT DEFAULT 0,
    orders_placed INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 21. DEVICE LINKING & NOTIFICATIONS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.device_linking_requests (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    device_name TEXT,
    public_key TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    platform TEXT DEFAULT 'flutter',
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- AUTOMATIC PROFILE CREATION TRIGGER ON AUTH SIGNUP
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, username, avatar_url, role, is_verified, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
        CASE WHEN NEW.email = 'official@a-chatz.com' THEN 'official' ELSE 'user' END,
        CASE WHEN NEW.email = 'official@a-chatz.com' THEN true ELSE false END,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- ENABLE REALTIME ON KEY TABLES
-- ==============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.statuses;
ALTER PUBLICATION supabase_realtime ADD TABLE public.channels;
ALTER PUBLICATION supabase_realtime ADD TABLE public.channel_posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
ALTER PUBLICATION supabase_realtime ADD TABLE public.call_candidates;
ALTER PUBLICATION supabase_realtime ADD TABLE public.live_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.live_comments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.games;

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.muted_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_followers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_linking_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are readable by authenticated users"
    ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Chats policies
CREATE POLICY "Users can read chats they belong to"
    ON public.chats FOR SELECT TO authenticated
    USING (auth.uid()::text = ANY(member_ids));

CREATE POLICY "Users can create chats they belong to"
    ON public.chats FOR INSERT TO authenticated
    WITH CHECK (auth.uid()::text = ANY(member_ids));

CREATE POLICY "Users can update chats they belong to"
    ON public.chats FOR UPDATE TO authenticated
    USING (auth.uid()::text = ANY(member_ids));

-- Messages policies
CREATE POLICY "Users can read messages in their chats"
    ON public.messages FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.chats c
            WHERE c.id = messages.chat_id
            AND auth.uid()::text = ANY(c.member_ids)
        )
    );

CREATE POLICY "Users can send messages to their chats"
    ON public.messages FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid()::text = sender_id AND
        EXISTS (
            SELECT 1 FROM public.chats c
            WHERE c.id = messages.chat_id
            AND auth.uid()::text = ANY(c.member_ids)
        )
    );

CREATE POLICY "Users can update messages in their chats"
    ON public.messages FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.chats c
            WHERE c.id = messages.chat_id
            AND auth.uid()::text = ANY(c.member_ids)
        )
    );

-- Statuses policies
CREATE POLICY "Authenticated users can read all active statuses"
    ON public.statuses FOR SELECT TO authenticated
    USING (expires_at > now());

CREATE POLICY "Users can create their own statuses"
    ON public.statuses FOR INSERT TO authenticated
    WITH CHECK (auth.uid()::text = owner_id);

CREATE POLICY "Users can update or delete their own statuses"
    ON public.statuses FOR ALL TO authenticated
    USING (auth.uid()::text = owner_id);

-- Channels policies
CREATE POLICY "Authenticated users can read channels"
    ON public.channels FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can create channels"
    ON public.channels FOR INSERT TO authenticated
    WITH CHECK (auth.uid()::text = owner_id);

CREATE POLICY "Channel owners can manage their channels"
    ON public.channels FOR ALL TO authenticated
    USING (auth.uid()::text = owner_id);

-- Channel followers policies
CREATE POLICY "Followers can be viewed by all authenticated users"
    ON public.channel_followers FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can follow/unfollow channels"
    ON public.channel_followers FOR ALL TO authenticated
    USING (auth.uid()::text = user_id);

-- Channel posts policies
CREATE POLICY "Channel posts are viewable by all authenticated users"
    ON public.channel_posts FOR SELECT TO authenticated USING (true);

CREATE POLICY "Channel admins can create posts"
    ON public.channel_posts FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.channels c
            WHERE c.id = channel_posts.channel_id AND c.owner_id = auth.uid()::text
        ) OR
        EXISTS (
            SELECT 1 FROM public.channel_followers f
            WHERE f.channel_id = channel_posts.channel_id AND f.user_id = auth.uid()::text AND f.role = 'admin'
        )
    );

-- Calls policies
CREATE POLICY "Call participants can read call sessions"
    ON public.calls FOR SELECT TO authenticated
    USING (auth.uid()::text = caller_id OR auth.uid()::text = ANY(receiver_ids));

CREATE POLICY "Users can initiate calls"
    ON public.calls FOR INSERT TO authenticated
    WITH CHECK (auth.uid()::text = caller_id);

CREATE POLICY "Call participants can update call state"
    ON public.calls FOR UPDATE TO authenticated
    USING (auth.uid()::text = caller_id OR auth.uid()::text = ANY(receiver_ids));

CREATE POLICY "Call participants can manage ICE candidates"
    ON public.call_candidates FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.calls c
            WHERE c.id = call_candidates.call_id
            AND (auth.uid()::text = c.caller_id OR auth.uid()::text = ANY(c.receiver_ids))
        )
    );

-- Catalog items policies
CREATE POLICY "Catalog items are publicly readable"
    ON public.catalog_items FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage their own catalog items"
    ON public.catalog_items FOR ALL TO authenticated
    USING (auth.uid()::text = user_id);

-- Storage bucket configurations
INSERT INTO storage.buckets (id, name, public) VALUES
    ('avatars', 'avatars', true),
    ('chat_media', 'chat_media', true),
    ('status_stories', 'status_stories', true),
    ('verification_docs', 'verification_docs', false),
    ('catalog', 'catalog', true),
    ('channel_photos', 'channel_photos', true),
    ('official_broadcasts', 'official_broadcasts', true)
ON CONFLICT (id) DO NOTHING;
