-- Orders: an amount only on an order, an order needs text or an amount, and
-- an own order (no person) needs an amount and stays with its owner.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Marlène', 'customer');

select lives_ok(
  $$ insert into public.activity (id, person_id, kind, amount) values
     ('00000000-0000-0000-0000-0000000000c1',
      '00000000-0000-0000-0000-0000000000a1', 'order', 100.50) $$,
  'an order with an amount and no text saves'
);
select is(
  (select amount from public.activity
    where id = '00000000-0000-0000-0000-0000000000c1'), 100.50::numeric,
  'the amount is stored as given'
);
select lives_ok(
  $$ insert into public.activity (person_id, kind, text) values
     ('00000000-0000-0000-0000-0000000000a1', 'order', 'Two creams') $$,
  'an order with text and no amount still saves'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind) values
     ('00000000-0000-0000-0000-0000000000a1', 'order') $$,
  '23514', null,
  'an order with neither text nor amount is refused'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text, amount) values
     ('00000000-0000-0000-0000-0000000000a1', 'order', '  ', 100) $$,
  '23514', null,
  'blank text is refused, even with an amount'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, amount) values
     ('00000000-0000-0000-0000-0000000000a1', 'order', 0) $$,
  '23514', null,
  'a zero amount is refused'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text, amount) values
     ('00000000-0000-0000-0000-0000000000a1', 'call', 'Called', 100) $$,
  '23514', null,
  'only an order has an amount'
);
select lives_ok(
  $$ insert into public.activity (id, kind, amount) values
     ('00000000-0000-0000-0000-0000000000c2', 'order', 80) $$,
  'an own order (no person) with an amount saves'
);
select throws_ok(
  $$ insert into public.activity (kind, text) values ('order', 'For me') $$,
  '23514', null,
  'an own order needs an amount'
);
select throws_ok(
  $$ insert into public.activity (kind, text) values ('call', 'Nobody') $$,
  '23514', null,
  'only an order can have no person'
);

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  (select count(*)::int from public.activity where person_id is null), 0,
  'another user does not see the own order'
);
select throws_ok(
  $$ insert into public.activity (owner_id, kind, amount) values
     ('00000000-0000-0000-0000-00000000000a', 'order', 10) $$,
  '42501', null,
  'another user cannot write an own order for the owner'
);

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

delete from public.activity where id = '00000000-0000-0000-0000-0000000000c2';
select is(
  (select count(*)::int from public.activity where person_id is null), 0,
  'the owner deletes their own order'
);

select * from finish();
rollback;
