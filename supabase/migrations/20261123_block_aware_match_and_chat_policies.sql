-- AZDAWAJ.COM: enforce blocks across matches and private chat.
-- If either participant blocks the other, both users lose access to the match
-- and its messages, and neither can send new messages.

drop policy if exists "match participants read matches" on public.matches;
create policy "unblocked match participants read matches"
on public.matches
for select
to authenticated
using (
  (user_one = (select auth.uid()) or user_two = (select auth.uid()))
  and not exists (
    select 1
    from public.blocks b
    where (b.blocker_id = matches.user_one and b.blocked_id = matches.user_two)
       or (b.blocker_id = matches.user_two and b.blocked_id = matches.user_one)
  )
);

drop policy if exists "match participants read messages" on public.messages;
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
      and not exists (
        select 1
        from public.blocks b
        where (b.blocker_id = m.user_one and b.blocked_id = m.user_two)
           or (b.blocker_id = m.user_two and b.blocked_id = m.user_one)
      )
  )
);

drop policy if exists "match participants send messages" on public.messages;
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
      and not exists (
        select 1
        from public.blocks b
        where (b.blocker_id = m.user_one and b.blocked_id = m.user_two)
           or (b.blocker_id = m.user_two and b.blocked_id = m.user_one)
      )
  )
);
