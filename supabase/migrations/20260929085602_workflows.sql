-- Workflows (#57): each user's own lists of steps, a person's place in one,
-- and pausing. Rules live in Dart (lib/features/workflows/domain/progress.dart);
-- the database keeps them consistent and does the two multi-row writes.

alter type public.activity_kind add value 'step';

create table public.workflow (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  stage public.person_stage not null,
  name text not null check (length(trim(name)) > 0),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Target of the composite foreign keys below.
  unique (id, owner_id)
);

-- One default per stage.
create unique index workflow_default_idx
  on public.workflow (owner_id, stage) where is_default;

create table public.workflow_step (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  workflow_id uuid not null,
  -- Sparse: an inserted step takes the midpoint, so no other position moves.
  position numeric not null,
  label text not null check (length(trim(label)) > 0),
  days int not null check (days >= 0),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete cascade,
  unique (workflow_id, position)
);

create index workflow_step_workflow_id_owner_id_idx
  on public.workflow_step (workflow_id, owner_id);

alter table public.person
  add column workflow_id uuid,
  add column at_position numeric,
  add column last_tick date,
  add column paused_at timestamptz,
  add foreign key (workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (workflow_id);

create index person_workflow_id_idx on public.person (workflow_id);

create trigger workflow_set_updated_at before update on public.workflow
  for each row execute function public.set_updated_at();
create trigger workflow_step_set_updated_at before update on public.workflow_step
  for each row execute function public.set_updated_at();

alter table public.workflow enable row level security;
alter table public.workflow_step enable row level security;

create policy workflow_select_own on public.workflow
  for select to authenticated using (owner_id = (select auth.uid()));
create policy workflow_insert_own on public.workflow
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy workflow_update_own on public.workflow
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy workflow_delete_own on public.workflow
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy workflow_step_select_own on public.workflow_step
  for select to authenticated using (owner_id = (select auth.uid()));
create policy workflow_step_insert_own on public.workflow_step
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy workflow_step_update_own on public.workflow_step
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy workflow_step_delete_own on public.workflow_step
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.workflow, public.workflow_step from anon, authenticated;
grant select, insert, update, delete
  on public.workflow, public.workflow_step to authenticated;

-- A stage change also ends a pause. Same function as #56, one line more.
create or replace function public.person_stage_changed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.stage_since = now();
  new.paused_at = null;
  if new.stage <> 'prospect' then
    new.prospect_status = null;
  end if;
  insert into public.activity (owner_id, person_id, kind, stage)
    values (new.owner_id, new.id, 'stage', new.stage);
  return new;
end $$;

-- The default workflows (spec §2.1), once per user, in English or French;
-- then everyone without a workflow starts their stage's default. plpgsql so
-- the new 'step' value is not resolved while this migration's transaction
-- is still open.
create function public.seed_workflows(p_lang text, p_today date) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  fr constant boolean := p_lang = 'fr';
  w record;
  new_id uuid;
begin
  -- Two devices seeding at once: the second waits, then finds the first's.
  perform pg_advisory_xact_lock(hashtext((select auth.uid())::text));
  if exists (select 1 from public.workflow) then
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
end $$;

-- Ticks a step: the history entry, with the label as it reads today, and the
-- person's new place, in one transaction. Dart computes p_next_position.
create function public.complete_step(
  p_person uuid, p_step uuid, p_next_position numeric, p_on date
) returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  step_label text;
  moved public.person;
begin
  select s.label into step_label
    from public.workflow_step s
    join public.person p on p.workflow_id = s.workflow_id
    where s.id = p_step and p.id = p_person;
  if step_label is null then
    raise exception 'step % is not on the workflow of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  insert into public.activity (person_id, kind, text, happened_on)
    values (p_person, 'step', step_label, p_on);
  update public.person
    set at_position = p_next_position, last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.seed_workflows(text, date) from public, anon;
revoke execute on function public.complete_step(uuid, uuid, numeric, date)
  from public, anon;
grant execute on function public.seed_workflows(text, date) to authenticated;
grant execute on function public.complete_step(uuid, uuid, numeric, date)
  to authenticated;
