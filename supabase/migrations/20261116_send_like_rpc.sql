-- AZDAWAJ.COM: server-authorized likes and mutual-match creation
-- Clients must call public.send_like(target_user) instead of inserting into likes.
-- The function derives the acting user from the verified Supabase JWT and
-- creates a match only after reciprocal likes exist.

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
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  if p_target_user is null or p_target_user = v_actor then
    raise exception 'Invalid target profile'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_actor
      and p.is_active = true
  ) then
    raise exception 'An active profile is required before liking'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_target_user
      and p.is_active = true
  ) then
    return query select false, null::uuid;
    return;
  end if;

  -- A block in either direction prevents new likes and matches.
  if exists (
    select 1
    from public.blocks b
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
    select 1
    from public.likes l
    where l.from_user = p_target_user
      and l.to_user = v_actor
  ) then
    v_user_one := least(v_actor, p_target_user);
    v_user_two := greatest(v_actor, p_target_user);

    insert into public.matches (user_one, user_two)
    values (v_user_one, v_user_two)
    on conflict (user_one, user_two) do nothing;

    select m.id
      into v_match_id
    from public.matches m
    where m.user_one = v_user_one
      and m.user_two = v_user_two;

    return query select true, v_match_id;
  else
    return query select false, null::uuid;
  end if;
end;
$function$;

-- Do not allow clients to bypass reciprocal-like and block checks with direct
-- table inserts. SECURITY DEFINER lets the narrowly scoped RPC perform inserts.
revoke insert on table public.likes from public, anon, authenticated;
revoke all on function public.send_like(uuid) from public, anon;
grant execute on function public.send_like(uuid) to authenticated;

comment on function public.send_like(uuid) is
  'Creates an authenticated user like and atomically creates a mutual match when the other user has already liked them. Blocks are checked in both directions.';
