-- The workflow rule, which lives only here: a person's current step, when it
-- is due, and what ticking it does. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'prospect', 'Samples');
insert into public.workflow_step (id, workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1', 1, 'Send a first message', 0),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000f1', 2, 'Send the samples', 1),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000f1', 3, 'Samples arrived', 4);

insert into public.person (id, name, stage, workflow_id, at_position, last_tick, paused_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'On a step', 'prospect', '00000000-0000-0000-0000-0000000000f1', 2, '2026-09-28', null),
  ('00000000-0000-0000-0000-0000000000a2', 'Done', 'prospect', '00000000-0000-0000-0000-0000000000f1', 4, '2026-09-28', null),
  ('00000000-0000-0000-0000-0000000000a3', 'No workflow', 'prospect', null, null, null, null),
  ('00000000-0000-0000-0000-0000000000a4', 'Paused', 'prospect', '00000000-0000-0000-0000-0000000000f1', 2, '2026-09-28', now()),
  ('00000000-0000-0000-0000-0000000000a5', 'At the start', 'prospect', '00000000-0000-0000-0000-0000000000f1', 1, '2026-09-28', null);

select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('00000000-0000-0000-0000-0000000000c2'::uuid, '2026-09-29'::date) $$,
  'on a step: that step, due its days after the last tick'
);
select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a2' $$,
  $$ values (null::uuid, null::date) $$,
  'past the last step: no step, nothing due'
);
select is(
  (select p.due_on from public.person p where p.id = '00000000-0000-0000-0000-0000000000a3'),
  null,
  'no workflow: nothing due'
);
select is(
  (select p.due_on from public.person p where p.id = '00000000-0000-0000-0000-0000000000a4'),
  null,
  'paused: nothing due'
);

select lives_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a5',
       '00000000-0000-0000-0000-0000000000c1', '2026-09-30') $$,
  'complete_step ticks the current step'
);
select results_eq(
  $$ select p.at_position, p.last_tick, p.current_step_id, p.due_on
     from public.person p where p.id = '00000000-0000-0000-0000-0000000000a5' $$,
  $$ values (2::numeric, '2026-09-30'::date,
             '00000000-0000-0000-0000-0000000000c2'::uuid, '2026-10-01'::date) $$,
  'complete_step moves to the next step, counted from the tick'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a5' and kind = 'step'),
  1,
  'complete_step writes one history entry'
);
select throws_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a5',
       '00000000-0000-0000-0000-0000000000c1', '2026-09-30') $$,
  'P0002', null,
  'a step that is no longer current is refused (stale tick)'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a5' and kind = 'step'),
  1,
  'a refused tick adds no history entry'
);
select throws_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a3',
       '00000000-0000-0000-0000-0000000000c1', '2026-09-30') $$,
  'P0002', null,
  'a person with no workflow has no step to tick'
);

delete from public.workflow_step where id = '00000000-0000-0000-0000-0000000000c2';
select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('00000000-0000-0000-0000-0000000000c3'::uuid, '2026-10-02'::date) $$,
  'current step removed: the next one takes over, with its own days'
);

insert into public.workflow_step (workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-0000000000f1', 1.5, 'Inserted before', 2);
select is(
  (select p.current_step_id from public.person p where p.id = '00000000-0000-0000-0000-0000000000a1'),
  '00000000-0000-0000-0000-0000000000c3'::uuid,
  'a step inserted before the current one is skipped'
);

select results_eq(
  $$ select (m).at_position, (m).last_tick from (
       select public.complete_step(
         '00000000-0000-0000-0000-0000000000a1',
         '00000000-0000-0000-0000-0000000000c3', '2026-10-02') as m) t $$,
  $$ values (1e9::numeric, '2026-10-02'::date) $$,
  'the last step parks the person at 1e9 (#59), and returns the row'
);
select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (null::uuid, null::date) $$,
  'after the last step: done'
);
select is(
  has_function_privilege('anon', 'public.due_on(public.person)', 'execute'),
  false,
  'anon cannot call due_on'
);

select * from finish();
rollback;
