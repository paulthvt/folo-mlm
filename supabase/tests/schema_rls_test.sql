-- The publishable key is public, so RLS is the only boundary
-- (docs/architecture.md → Backend). Holds for every table in public, including
-- ones added after this test was written. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select is_empty(
  $$ select c.relname::text from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p')
       and not c.relrowsecurity $$,
  'every public table has RLS enabled'
);

select is_empty(
  $$ select c.relname::text from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p')
       and not exists (select 1 from pg_policy p where p.polrelid = c.oid) $$,
  'every public table has at least one policy'
);

-- Supabase grants anon everything on new tables by default; each migration
-- revokes it. Views count too: one would bypass RLS unless security_invoker.
select is_empty(
  $$ select distinct table_name::text from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'anon' $$,
  'anon has no privilege on any public table or view'
);

select * from finish();
rollback;
