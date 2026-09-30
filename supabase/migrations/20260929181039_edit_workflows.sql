-- Editing workflows (#59): the defaults are seeded once per account, ever,
-- and a stage's default is switched in one call. Plain edits go through the
-- RLS of #57; current_step_id and due_on (#58) carry them to people.

create table public.workflow_seeded (
  owner_id uuid primary key default auth.uid()
    references auth.users on delete cascade,
  seeded_at timestamptz not null default now()
);

alter table public.workflow_seeded enable row level security;

create policy workflow_seeded_select_own on public.workflow_seeded
  for select to authenticated using (owner_id = (select auth.uid()));
create policy workflow_seeded_insert_own on public.workflow_seeded
  for insert to authenticated with check (owner_id = (select auth.uid()));

-- Written once, never changed or removed while the account exists.
revoke all on public.workflow_seeded from anon, authenticated;
grant select, insert on public.workflow_seeded to authenticated;

-- Everyone seeded before this migration.
insert into public.workflow_seeded (owner_id)
  select distinct owner_id from public.workflow;

-- Same as #57, except that it asks the marker rather than "any workflow", so
-- an account that deleted everything is not given the defaults back.
create or replace function public.seed_workflows(p_lang text, p_today date)
returns void
language plpgsql security invoker set search_path = '' as $$
declare
  fr constant boolean := p_lang = 'fr';
  w record;
  new_id uuid;
begin
  -- Two devices seeding at once: the second waits, then finds the marker.
  perform pg_advisory_xact_lock(hashtext((select auth.uid())::text));
  if exists (
    select 1 from public.workflow_seeded
    where owner_id = (select auth.uid())
  ) then
    return;
  end if;

  for w in
    select * from (values
      ('prospect'::public.person_stage, true,
       case when fr then 'Échantillons' else 'Samples' end,
       case when fr then
         '[["Envoyer un premier message",0],["Envoyer les échantillons",1],["Échantillons reçus",4],["Demander comment ça s''est passé",3],["Relancer",7]]'
       else
         '[["Send a first message",0],["Send the samples",1],["Samples arrived",4],["Ask how the samples went",3],["Follow up",7]]'
       end::jsonb),
      ('prospect', false,
       case when fr then 'Professionnels de santé' else 'Health professionals' end,
       case when fr then
         '[["Se présenter",0],["Partager une fiche produit",2],["Proposer un kit d''échantillons",5],["Relancer",7]]'
       else
         '[["Introduce yourself",0],["Share a product sheet",2],["Offer a sample kit",5],["Follow up",7]]'
       end::jsonb),
      ('customer', true,
       case when fr then 'Nouveau client' else 'New customer' end,
       case when fr then
         '[["Remercier pour la commande",0],["Commande reçue",5],["Prendre des nouvelles des produits",14],["Proposer un réassort régulier",21]]'
       else
         '[["Thank them for the order",0],["Order arrived",5],["Check in on the products",14],["Suggest a refill routine",21]]'
       end::jsonb),
      ('customer', false,
       case when fr then 'Point réassort' else 'Refill check-in' end,
       case when fr then
         '[["Demander où en sont les réserves",25],["Aider pour la prochaine commande",3]]'
       else
         '[["Ask how supplies are going",25],["Help with the next order",3]]'
       end::jsonb),
      ('team', true,
       case when fr then 'Premiers pas' else 'Getting started' end,
       case when fr then
         '[["Appel de bienvenue",0],["Appel de déballage",5],["Première formation",3],["Premier objectif ensemble",7],["Point à deux semaines",14]]'
       else
         '[["Welcome call",0],["Unboxing call",5],["First training",3],["First goal together",7],["Two-week check-in",14]]'
       end::jsonb)
    ) as t(stage, is_default, name, steps)
  loop
    insert into public.workflow (stage, name, is_default)
      values (w.stage, w.name, w.is_default)
      returning id into new_id;
    insert into public.workflow_step (workflow_id, position, label, days)
      select new_id, s.ord, s.value ->> 0, (s.value ->> 1)::int
      from jsonb_array_elements(w.steps) with ordinality as s(value, ord);
  end loop;

  update public.person p
    set workflow_id = wf.id, at_position = 1, last_tick = p_today
    from public.workflow wf
    where wf.stage = p.stage and wf.is_default and p.workflow_id is null;

  insert into public.workflow_seeded default values;
end $$;

-- On: the stage's default, instead of any other (the other is cleared first,
-- so workflow_default_idx never sees two). Off: the stage has none.
create function public.set_default(p_workflow uuid, p_on boolean) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person_stage;
begin
  select stage into target from public.workflow where id = p_workflow;
  if target is null then
    raise exception 'workflow % not found', p_workflow using errcode = 'P0002';
  end if;
  if p_on then
    update public.workflow set is_default = false
      where stage = target and is_default and id <> p_workflow;
  end if;
  update public.workflow set is_default = p_on where id = p_workflow;
end $$;

revoke execute on function public.set_default(uuid, boolean) from public, anon;
grant execute on function public.set_default(uuid, boolean) to authenticated;

-- Same as #58, except that past the last step parks the person at 1e9, not
-- one past the last: a step moved or added at the end then never brings back
-- someone who finished.
-- ponytail: a finite sentinel; a workflow reaching position 1e9 would collide.
create or replace function public.complete_step(p_person uuid, p_step uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  next_position numeric;
  moved public.person;
begin
  select * into target from public.person where id = p_person for update;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  select * into step from public.workflow_step where id = p_step;
  select coalesce(min(s.position), 1e9) into next_position
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

revoke execute on function public.complete_step(uuid, uuid, date) from public, anon;
grant execute on function public.complete_step(uuid, uuid, date) to authenticated;

-- Everyone who finished before this migration moves to the same place.
update public.person p set at_position = 1e9
  where p.workflow_id is not null and p.at_position is not null
    and not exists (
      select 1 from public.workflow_step s
      where s.workflow_id = p.workflow_id and s.position >= p.at_position
    );
