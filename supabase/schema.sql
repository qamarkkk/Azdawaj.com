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

-- Profiles: private columns are visible only to their owner.
-- Discovery is exposed separately through a limited-field RPC below.
create policy "Profile owner reads own private profile"
on public.profiles for select to authenticated
using (id = (select auth.uid()));

create policy "Users create own profile"
on public.profiles for insert to authenticated
with check (id = (select auth.uid()) and birth_date <= (current_date - interval '18 years')::date);

create policy "Users update own profile"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()) and birth_date <= (current_date - interval '18 years')::date);

-- Likes: only the sender and recipient can inspect a like; sender controls it.
create policy "Users read likes involving themselves"
on public.likes for select to authenticated
using (from_user = (select auth.uid()) or to_user = (select auth.uid()));

create policy "Users send own likes"
on public.likes for insert to authenticated
with check (from_user = (select auth.uid()));

create policy "Users remove own likes"
on public.likes for delete to authenticated
using (from_user = (select auth.uid()));

-- Matches: only participants can see them.
create policy "Participants view matches"
on public.matches for select to authenticated
using (user_one = (select auth.uid()) or user_two = (select auth.uid()));

-- Blocks: users can manage only blocks they created.
create policy "Users view blocks they created"
on public.blocks for select to authenticated
using (blocker_id = (select auth.uid()));

create policy "Users create own blocks"
on public.blocks for insert to authenticated
with check (blocker_id = (select auth.uid()));

create policy "Users remove own blocks"
on public.blocks for delete to authenticated
using (blocker_id = (select auth.uid()));

-- Reports: reporters may submit and view their own reports. No client update/delete.
create policy "Users submit own reports"
on public.reports for insert to authenticated
with check (reporter_id = (select auth.uid()));

create policy "Users view own reports"
on public.reports for select to authenticated
using (reporter_id = (select auth.uid()));

-- Messages: only participants in a match may read; sender must be a participant.
create policy "Match participants read messages"
on public.messages for select to authenticated
using (
  exists (
    select 1 from public.matches m
    where m.id = match_id
      and (m.user_one = (select auth.uid()) or m.user_two = (select auth.uid()))
  )
);

create policy "Match participants send messages"
on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.matches m
    where m.id = match_id
      and (m.user_one = (select auth.uid()) or m.user_two = (select auth.uid()))
  )
);

-- Match creation should be performed by a trusted server-side function after
-- verifying reciprocal likes, not by an unrestricted client insert.
revoke insert, update, delete on public.matches from anon, authenticated;


-- Limited public discovery surface. SECURITY DEFINER is intentional here:
-- base profiles RLS keeps birth_date and other private columns owner-only.
create or replace function public.discover_profiles()
returns table (id uuid, display_name text, city text, bio text, photo_path text)
language sql
stable
security definer
set search_path = ''
as $function$
  select p.id, p.display_name, p.city, p.bio, p.photo_path
  from public.profiles p
  where (select auth.uid()) is not null
    and p.id <> (select auth.uid())
    and p.is_active = true
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = (select auth.uid()))
    )
    and not exists (
      select 1 from public.likes l
      where l.from_user = (select auth.uid()) and l.to_user = p.id
    )
  order by p.created_at desc
  limit 50;
$function$;

revoke all on function public.discover_profiles() from public, anon;
grant execute on function public.discover_profiles() to authenticated;

-- Mutual likes are created only through the authenticated server-side RPC.
create or replace function public.send_like(p_target_user uuid)
returns table (is_match boolean, match_id uuid)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_match_id uuid;
  v_user_one uuid;
  v_user_two uuid;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_target_user is null or p_target_user = v_actor then
    raise exception 'Invalid target profile' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = v_actor and p.is_active = true
  ) then
    raise exception 'An active profile is required before liking'
      using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_target_user and p.is_active = true
  ) then
    return query select false, null::uuid;
    return;
  end if;

  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = v_actor and b.blocked_id = p_target_user)
       or (b.blocker_id = p_target_user and b.blocked_id = v_actor)
  ) then
    return query select false, null::uuid;
    return;
  end if;

  insert into public.likes (from_user, to_user)
  values (v_actor, p_target_user)
  on conflict (from_user, to_user) do nothing;

  if exists (
    select 1 from public.likes l
    where l.from_user = p_target_user and l.to_user = v_actor
  ) then
    v_user_one := least(v_actor, p_target_user);
    v_user_two := greatest(v_actor, p_target_user);

    insert into public.matches (user_one, user_two)
    values (v_user_one, v_user_two)
    on conflict (user_one, user_two) do nothing;

    select m.id into v_match_id
    from public.matches m
    where m.user_one = v_user_one and m.user_two = v_user_two;

    return query select true, v_match_id;
  else
    return query select false, null::uuid;
  end if;
end;
$function$;

revoke insert on table public.likes from public, anon, authenticated;
revoke all on function public.send_like(uuid) from public, anon;
grant execute on function public.send_like(uuid) to authenticated;

-- Private photo storage. Each account can access only its own original uploads.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 5242880,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Users upload their own profile photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users read their own profile photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users update their own profile photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users delete their own profile photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Important: chat policies must also enforce block relationships before chat
-- is enabled in the mobile app. Reports still require an admin moderation path.
