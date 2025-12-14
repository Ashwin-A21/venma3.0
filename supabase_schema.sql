-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Users Table
create table if not exists public.users (
  id uuid references auth.users not null primary key,
  username text unique,
  display_name text,
  phone text unique,
  avatar_url text,
  fluttermoji text,
  atman_balance int default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Friendships Table (Version 1 Logic)
create table if not exists public.friendships (
  id uuid default uuid_generate_v4() primary key,
  user_id_1 uuid references public.users(id) not null,
  user_id_2 uuid references public.users(id) not null,
  status text check (status in ('pending', 'active', 'blocked')) default 'pending',
  version_id int default 1,
  start_date timestamp with time zone default timezone('utc'::text, now()),
  streak_score int default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id_1, user_id_2)
);

-- Messages Table (with support for video, files, one-time view, disappearing)
create table if not exists public.messages (
  id uuid default uuid_generate_v4() primary key,
  friendship_id uuid references public.friendships(id) not null,
  sender_id uuid references public.users(id) not null,
  content text,
  type text check (type in ('text', 'image', 'video', 'file', 'sticker', 'nudge')) default 'text',
  file_name text, -- original filename for file/document uploads
  file_size bigint, -- file size in bytes
  is_read boolean default false,
  is_one_time boolean default false, -- disappears after viewing
  one_time_viewed boolean default false, -- has been viewed (for one-time messages)
  expires_at timestamp with time zone, -- for disappearing messages
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Add columns if table already exists (for migrations)
do $$
begin
  if not exists (select 1 from information_schema.columns where table_name = 'messages' and column_name = 'is_one_time') then
    alter table public.messages add column is_one_time boolean default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_name = 'messages' and column_name = 'one_time_viewed') then
    alter table public.messages add column one_time_viewed boolean default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_name = 'messages' and column_name = 'expires_at') then
    alter table public.messages add column expires_at timestamp with time zone;
  end if;
  if not exists (select 1 from information_schema.columns where table_name = 'messages' and column_name = 'file_name') then
    alter table public.messages add column file_name text;
  end if;
  if not exists (select 1 from information_schema.columns where table_name = 'messages' and column_name = 'file_size') then
    alter table public.messages add column file_size bigint;
  end if;
  -- Update type constraint to include video and file
  alter table public.messages drop constraint if exists messages_type_check;
  alter table public.messages add constraint messages_type_check check (type in ('text', 'image', 'video', 'file', 'sticker', 'nudge'));
end $$;

-- Chat Settings Table (for disappearing messages per friendship)
create table if not exists public.chat_settings (
  id uuid default uuid_generate_v4() primary key,
  friendship_id uuid references public.friendships(id) unique not null,
  disappearing_mode text check (disappearing_mode in ('off', 'after_read', '1_week', 'custom')) default 'off',
  custom_duration_hours int, -- for custom duration
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS for chat_settings
alter table public.chat_settings enable row level security;
drop policy if exists "Users can view their chat settings." on public.chat_settings;
create policy "Users can view their chat settings." on public.chat_settings for select using (
  exists (
    select 1 from public.friendships f
    where f.id = friendship_id
    and (f.user_id_1 = auth.uid() or f.user_id_2 = auth.uid())
  )
);
drop policy if exists "Users can update their chat settings." on public.chat_settings;
create policy "Users can update their chat settings." on public.chat_settings for all using (
  exists (
    select 1 from public.friendships f
    where f.id = friendship_id
    and (f.user_id_1 = auth.uid() or f.user_id_2 = auth.uid())
  )
);

-- Storage Buckets (must be public for getPublicUrl to work)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do update set public = true;
insert into storage.buckets (id, name, public) values ('chat_media', 'chat_media', true) on conflict (id) do update set public = true;
insert into storage.buckets (id, name, public) values ('status', 'status', true) on conflict (id) do update set public = true;

-- Storage Policies (drop first to allow re-running)
drop policy if exists "Users can upload chat media." on storage.objects;
create policy "Users can upload chat media." on storage.objects for insert with check (
  bucket_id = 'chat_media' and auth.uid() = (storage.foldername(name))[1]::uuid
);
drop policy if exists "Public can view chat media." on storage.objects;
create policy "Public can view chat media." on storage.objects for select using (bucket_id = 'chat_media');
drop policy if exists "Users can upload avatars." on storage.objects;
create policy "Users can upload avatars." on storage.objects for insert with check (
  bucket_id = 'avatars' and auth.uid() = (storage.foldername(name))[1]::uuid
);
drop policy if exists "Public can view avatars." on storage.objects;
create policy "Public can view avatars." on storage.objects for select using (bucket_id = 'avatars');
drop policy if exists "Users can upload status." on storage.objects;
create policy "Users can upload status." on storage.objects for insert with check (
  bucket_id = 'status' and auth.uid() = (storage.foldername(name))[1]::uuid
);
drop policy if exists "Public can view status." on storage.objects;
create policy "Public can view status." on storage.objects for select using (bucket_id = 'status');

-- RLS Policies (Basic for now)
alter table public.users enable row level security;
drop policy if exists "Public profiles are viewable by everyone." on public.users;
create policy "Public profiles are viewable by everyone." on public.users for select using (true);
drop policy if exists "Users can insert their own profile." on public.users;
create policy "Users can insert their own profile." on public.users for insert with check (auth.uid() = id);
drop policy if exists "Users can update own profile." on public.users;
create policy "Users can update own profile." on public.users for update using (auth.uid() = id);

alter table public.friendships enable row level security;
drop policy if exists "Users can view their own friendships." on public.friendships;
create policy "Users can view their own friendships." on public.friendships for select using (auth.uid() = user_id_1 or auth.uid() = user_id_2);
drop policy if exists "Users can insert friendships." on public.friendships;
create policy "Users can insert friendships." on public.friendships for insert with check (auth.uid() = user_id_1);

drop policy if exists "Users can update their own friendships." on public.friendships;
create policy "Users can update their own friendships." on public.friendships for update using (auth.uid() = user_id_1 or auth.uid() = user_id_2);
drop policy if exists "Users can delete their own friendships." on public.friendships;
create policy "Users can delete their own friendships." on public.friendships for delete using (auth.uid() = user_id_1 or auth.uid() = user_id_2);

alter table public.messages enable row level security;
drop policy if exists "Users can view messages in their friendships." on public.messages;
create policy "Users can view messages in their friendships." on public.messages for select using (
  exists (
    select 1 from public.friendships f
    where f.id = friendship_id
    and (f.user_id_1 = auth.uid() or f.user_id_2 = auth.uid())
  )
);
drop policy if exists "Users can insert messages in their friendships." on public.messages;
create policy "Users can insert messages in their friendships." on public.messages for insert with check (
  exists (
    select 1 from public.friendships f
    where f.id = friendship_id
    and (f.user_id_1 = auth.uid() or f.user_id_2 = auth.uid())
  )
);

-- Statuses Table
create table if not exists public.statuses (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.users(id) not null,
  content_url text,
  content_text text,
  type text check (type in ('image', 'text', 'video')) default 'image',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  expires_at timestamp with time zone default timezone('utc'::text, now() + interval '24 hours')
);

alter table public.statuses enable row level security;
drop policy if exists "Users can view friends statuses." on public.statuses;
create policy "Users can view friends statuses." on public.statuses for select using (
  exists (
    select 1 from public.friendships f
    where (f.user_id_1 = auth.uid() and f.user_id_2 = statuses.user_id)
       or (f.user_id_2 = auth.uid() and f.user_id_1 = statuses.user_id)
       and f.status = 'active'
  ) or auth.uid() = user_id
);
drop policy if exists "Users can insert own statuses." on public.statuses;
create policy "Users can insert own statuses." on public.statuses for insert with check (auth.uid() = user_id);

-- Calls Table
create table if not exists public.calls (
  id uuid default uuid_generate_v4() primary key,
  caller_id uuid references public.users(id) not null,
  receiver_id uuid references public.users(id) not null,
  status text check (status in ('offering', 'answering', 'connected', 'ended', 'rejected')) default 'offering',
  is_video boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Call Signals Table
create table if not exists public.call_signals (
  id uuid default uuid_generate_v4() primary key,
  call_id uuid references public.calls(id) not null,
  sender_id uuid references public.users(id) not null,
  payload jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS for Calls
alter table public.calls enable row level security;
drop policy if exists "Users can view calls they are part of." on public.calls;
create policy "Users can view calls they are part of." on public.calls for select using (auth.uid() = caller_id or auth.uid() = receiver_id);
drop policy if exists "Users can insert calls." on public.calls;
create policy "Users can insert calls." on public.calls for insert with check (auth.uid() = caller_id);
drop policy if exists "Users can update calls they are part of." on public.calls;
create policy "Users can update calls they are part of." on public.calls for update using (auth.uid() = caller_id or auth.uid() = receiver_id);

-- RLS for Signals
alter table public.call_signals enable row level security;
drop policy if exists "Users can view signals for their calls." on public.call_signals;
create policy "Users can view signals for their calls." on public.call_signals for select using (
  exists (select 1 from public.calls c where c.id = call_id and (c.caller_id = auth.uid() or c.receiver_id = auth.uid()))
);
drop policy if exists "Users can insert signals for their calls." on public.call_signals;
create policy "Users can insert signals for their calls." on public.call_signals for insert with check (
  exists (select 1 from public.calls c where c.id = call_id and (c.caller_id = auth.uid() or c.receiver_id = auth.uid()))
);

