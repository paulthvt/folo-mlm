-- Today (#58): the workflow rule lives here and only here. A person's current
-- step and its due day are computed fields every reader selects (Today, the
-- contact's NEXT STEP, later a push job), and complete_step finds the next
-- position itself. The device compares due_on with its own today, nothing
-- more. Supersedes "Rules live in Dart" in 20260929085602_workflows.sql.

-- The first step at or after the person's position; null with no workflow or
-- once past the last step. Found by position, not id, so an edit applies at
-- once: a removed step hands over to the next, an inserted one before is
-- skipped.
create function public.current_step_id(p public.person) returns uuid
language sql stable security invoker set search_path = '' as $$
  select s.id from public.workflow_step s
  where s.workflow_id = p.workflow_id and s.position >= p.at_position
  order by s.position limit 1
$$;

-- When that step is due: its days after the last tick. Null while paused,
-- with no workflow, or done.
create function public.due_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select p.last_tick + s.days from public.workflow_step s
  where p.paused_at is null and s.id = public.current_step_id(p)
$$;

drop function public.complete_step(uuid, uuid, numeric, date);

-- Ticks the person's current step: the history entry, with the label as it
-- reads today, and the move to the next step (or one past the last), in one
-- transaction. Any other step is refused, so a stale tick from a second
-- device adds nothing.
create function public.complete_step(p_person uuid, p_step uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  next_position numeric;
  moved public.person;
begin
  select * into target from public.person where id = p_person;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  select * into step from public.workflow_step where id = p_step;
  select coalesce(min(s.position), step.position + 1) into next_position
    from public.workflow_step s
    where s.workflow_id = step.workflow_id and s.position > step.position;

  insert into public.activity (person_id, kind, text, happened_on)
    values (p_person, 'step', step.label, p_on);
  update public.person
    set at_position = next_position, last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.current_step_id(public.person) from public, anon;
revoke execute on function public.due_on(public.person) from public, anon;
revoke execute on function public.complete_step(uuid, uuid, date) from public, anon;
grant execute on function public.current_step_id(public.person) to authenticated;
grant execute on function public.due_on(public.person) to authenticated;
grant execute on function public.complete_step(uuid, uuid, date) to authenticated;
