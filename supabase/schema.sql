-- AZDAWAJ.COM initial schema
-- Apply to a new Supabase project only after reviewing this migration.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 60),
  birth_date date not null,
  city text not null check (char_length(city) between 2 and 80),
  bio text not null default '' check (char_length(bio) <= 500),
  gender text check (gender in ('woman','man','non_binary','prefer_not_to_say')),
  interested_in text[] not null default '{}',
  photo_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_adult_only check (birth_date <= (current_date - interval '18 years')::date)
);

create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references public.profiles(id) on delete cascade,
  to_user uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(from_user, to_user),
  check (from_user <> to_user)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  user_one uuid not null references public.profiles(id) on delete cascade,
  user_two uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_one < user_two),
  unique(user_one, user_two)
);

create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (blocker_id <> blocked_id),
  unique(blocker_id, blocked_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 80),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'pending' check (status in ('pending','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists profiles_city_active_idx on public.profiles(city) where is_active = true;
create index if not exists likes_to_user_idx on public.likes(to_user);
create index if not exists messages_match_created_idx on public.messages(match_id, created_at);
create index if not exists reports_status_created_idx on public.reports(status, created_at);

alter table public.profiles enable row level security;
alter table public.likes enable row level security;
alter table public.matches enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.messages enable row level security;

-- Profiles: authenticated users can see active profiles, edit only their own.
create policy "Authenticated users view active profiles"
on public.profiles for select to authenticated
using (is_active = true or id = auth.uid());

create policy "Users create own profile"
on public.profiles for insert to authenticated
with check (id = auth.uid() and birth_date <= (current_date - interval '18 years')::date);

create policy "Users update own profile"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid() and birth_date <= (current_date - interval '18 years')::date);

-- Likes: only the sender and recipient can inspect a like; sender controls it.
create policy "Users read likes involving themselves"
on public.likes for select to authenticated
using (from_user = auth.uid() or to_user = auth.uid());

create policy "Users send own likes"
on public.likes for insert to authenticated
with check (from_user = auth.uid());

create policy "Users remove own likes"
on public.likes for delete to authenticated
using (from_user = auth.uid());

-- Matches: only participants can see them.
create policy "Participants view matches"
on public.matches for select to authenticated
using (user_one = auth.uid() or user_two = auth.uid());

-- Blocks: users can manage only blocks they created.
create policy "Users view blocks they created"
on public.blocks for select to authenticated
using (blocker_id = auth.uid());

create policy "Users create own blocks"
on public.blocks for insert to authenticated
with check (blocker_id = auth.uid());

create policy "Users remove own blocks"
on public.blocks for delete to authenticated
using (blocker_id = auth.uid());

-- Reports: reporters may submit and view their own reports. No client update/delete.
create policy "Users submit own reports"
on public.reports for insert to authenticated
with check (reporter_id = auth.uid());

create policy "Users view own reports"
on public.reports for select to authenticated
using (reporter_id = auth.uid());

-- Messages: only participants in a match may read; sender must be a participant.
create policy "Match participants read messages"
on public.messages for select to authenticated
using (
  exists (
    select 1 from public.matches m
    where m.id = match_id
      and (m.user_one = auth.uid() or m.user_two = auth.uid())
  )
);

create policy "Match participants send messages"
on public.messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.matches m
    where m.id = match_id
      and (m.user_one = auth.uid() or m.user_two = auth.uid())
  )
);

-- Match creation should be performed by a trusted server-side function after
-- verifying reciprocal likes, not by an unrestricted client insert.
revoke insert, update, delete on public.matches from anon, authenticated;
