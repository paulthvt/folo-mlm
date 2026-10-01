-- Team check-ins (#103): when the user last talked with someone. A computed
-- field every reader selects, like due_on; never written. A stage change is
-- the database talking, not the user, so it does not count.
create function public.last_contact_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select max(a.happened_on) from public.activity a
  where a.person_id = p.id and a.kind <> 'stage'
$$;

revoke execute on function public.last_contact_on(public.person) from public, anon;
grant execute on function public.last_contact_on(public.person) to authenticated;
