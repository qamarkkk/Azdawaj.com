-- The blocks table is intentionally private to the person who created a block.
-- A policy subquery against public.blocks is therefore subject to blocks RLS and
-- cannot reliably see a block created by the other match participant.
-- This private SECURITY DEFINER helper checks only pairs that include auth.uid().
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

create or replace function private.is_blocked_between(
  p_user_one uuid,
  p_user_two uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select case
    when (select auth.uid()) is null then false
    when (select auth.uid()) <> p_user_one
      and (select auth.uid()) <> p_user_two then false
    else exists (
      select 1
      from public.blocks b
      where (b.blocker_id = p_user_one and b.blocked_id = p_user_two)
         or (b.blocker_id = p_user_two and b.blocked_id = p_user_one)
    )
  end;
$function$;

revoke all on function private.is_blocked_between(uuid, uuid) from public, anon;
grant execute on function private.is_blocked_between(uuid, uuid) to authenticated, service_role;

drop policy if exists "unblocked match participants read matches" on public.matches;
create policy "unblocked match participants read matches"
on public.matches
for select
to authenticated
using (
  (user_one = (select auth.uid()) or user_two = (select auth.uid()))
  and not private.is_blocked_between(user_one, user_two)
);

drop policy if exists "unblocked match participants read messages" on public.messages;
create policy "unblocked match participants read messages"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.matches m
    where m.id = messages.match_id
      and (m.user_one = (select auth.uid()) or m.user_two = (select auth.uid()))
      and not private.is_blocked_between(m.user_one, m.user_two)
  )
);

drop policy if exists "unblocked match participants send messages" on public.messages;
create policy "unblocked match participants send messages"
on public.messages
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1
    from public.matches m
    where m.id = messages.match_id
      and (m.user_one = (select auth.uid()) or m.user_two = (select auth.uid()))
      and not private.is_blocked_between(m.user_one, m.user_two)
  )
);
