-- History: stage changes are written by the database and only by it, entries
-- stay with their owner, and deleting a person takes their history along.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- As A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage, prospect_status) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect', 'interested');

-- As postgres, to set a past start the trigger must overwrite.
reset role;
update public.person set stage_since = '2020-01-01'
  where id = '00000000-0000-0000-0000-0000000000a1';
set local role authenticated;

update public.person set name = 'Sarah Martin'
  where id = '00000000-0000-0000-0000-0000000000a1';

select is(
  (select count(*)::int from public.activity), 0,
  'changing only the name writes no entry'
);
select is(
  (select stage_since from public.person), '2020-01-01'::timestamptz,
  'changing only the name leaves stage_since alone'
);

update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';

select is(
  (select count(*)::int from public.activity
    where kind = 'stage' and stage = 'customer'), 1,
  'changing the stage writes one stage entry'
);
select is(
  (select stage_since from public.person), now(),
  'changing the stage sets stage_since'
);
select is(
  (select prospect_status::text from public.person), null,
  'leaving prospects clears the status'
);
select is(
  (select owner_id from public.activity),
  '00000000-0000-0000-0000-00000000000a'::uuid,
  'the stage entry belongs to the owner'
);

insert into public.activity (id, person_id, kind, text) values
  ('00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', 'call', 'Asked about the cream');

select is(
  (select happened_on from public.activity where kind = 'call'), current_date,
  'happened_on defaults to today'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, stage)
     values ('00000000-0000-0000-0000-0000000000a1', 'stage', 'team') $$,
  '42501', null,
  'the owner cannot write a stage entry'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text)
     values ('00000000-0000-0000-0000-0000000000a1', 'note', '   ') $$,
  '23514', null,
  'a blank note is refused'
);

delete from public.activity where kind = 'stage';

select is(
  (select count(*)::int from public.activity where kind = 'stage'), 1,
  'the owner cannot delete a stage entry'
);

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  (select count(*)::int from public.activity), 0,
  'another user sees none of the entries'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text)
     values ('00000000-0000-0000-0000-0000000000a1', 'note', 'Mine now') $$,
  '23503', null,
  'another user cannot add an entry on the owner''s person'
);
delete from public.activity;

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select is(
  (select count(*)::int from public.activity), 2,
  'another user cannot delete the entries'
);

delete from public.activity where id = '00000000-0000-0000-0000-0000000000c1';

select is(
  (select count(*)::int from public.activity where kind = 'call'), 0,
  'the owner deletes their own entry'
);

delete from public.person where id = '00000000-0000-0000-0000-0000000000a1';

select is(
  (select count(*)::int from public.activity), 0,
  'deleting the person deletes their history, stage entries included'
);

-- As anon.
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select throws_ok(
  'select * from public.activity', '42501', null,
  'anon cannot read the table'
);

reset role;

select table_privs_are(
  'public', 'activity', 'authenticated',
  ARRAY['SELECT', 'INSERT', 'DELETE'],
  'authenticated has only SELECT, INSERT, DELETE on activity'
);

select * from finish();
rollback;
