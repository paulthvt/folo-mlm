-- Row-level security on person: an owner sees and changes only their own rows,
-- anon sees nothing, and the table's checks hold. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- As A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (name, stage) values ('Marie', 'prospect');

select is(
  (select count(*)::int from public.person), 1,
  'the owner sees their row'
);
select is(
  (select owner_id from public.person),
  '00000000-0000-0000-0000-00000000000a'::uuid,
  'owner_id defaults to the caller'
);

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  (select count(*)::int from public.person), 0,
  'another user sees nothing'
);
select throws_ok(
  $$ insert into public.person (owner_id, name, stage)
     values ('00000000-0000-0000-0000-00000000000a', 'Lucas', 'customer') $$,
  '42501', null,
  'another user cannot insert a row for the owner'
);
update public.person set name = 'Taken';
delete from public.person;

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select is(
  (select name from public.person), 'Marie',
  'another user can neither update nor delete the row'
);

-- As anon.
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select throws_ok(
  'select * from public.person', '42501', null,
  'anon cannot read the table'
);

-- As postgres, past RLS, for the table checks.
reset role;

select throws_ok(
  $$ insert into public.person (owner_id, name, stage, prospect_status)
     values ('00000000-0000-0000-0000-00000000000a', 'Karim', 'customer', 'thinking') $$,
  '23514', null,
  'a prospect status only goes with the prospect stage'
);
select throws_ok(
  $$ insert into public.person (owner_id, name, stage)
     values ('00000000-0000-0000-0000-00000000000a', '   ', 'prospect') $$,
  '23514', null,
  'a blank name is refused'
);

select * from finish();
rollback;
