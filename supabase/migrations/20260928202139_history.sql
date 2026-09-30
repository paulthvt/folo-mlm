-- History (#56): when the current stage began, a log of what happened with
-- each person, and stage changes recorded by the database. Entries are never
-- edited, so activity has no updated_at and no update grant.

alter table public.person add column stage_since timestamptz;
update public.person set stage_since = created_at;
alter table public.person
  alter column stage_since set not null,
  alter column stage_since set default now();

-- Target of activity's composite foreign key.
alter table public.person add constraint person_id_owner_key unique (id, owner_id);

create type public.activity_kind as enum
  ('note', 'call', 'message', 'order', 'meeting', 'stage');

create table public.activity (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  person_id uuid not null,
  kind public.activity_kind not null,
  happened_on date not null default current_date,
  text text,
  stage public.person_stage,
  created_at timestamptz not null default now(),
  -- An entry always belongs to the person's owner.
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade,
  constraint stage_entry_shape check (
    (kind = 'stage' and stage is not null and text is null)
    or (kind <> 'stage' and stage is null
        and text is not null and length(trim(text)) > 0)
  )
);

create index activity_person_id_owner_id_idx
  on public.activity (person_id, owner_id);

alter table public.activity enable row level security;

create policy activity_select_own on public.activity
  for select to authenticated
  using (owner_id = (select auth.uid()));

-- Stage entries come from the trigger below, never from the app.
create policy activity_insert_own on public.activity
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and kind <> 'stage');

create policy activity_delete_own on public.activity
  for delete to authenticated
  using (owner_id = (select auth.uid()) and kind <> 'stage');

revoke all on public.activity from anon, authenticated;
grant select, insert, delete on public.activity to authenticated;

-- security definer to insert past the kind <> 'stage' policy. It only writes
-- the owner and id of the row being updated, which RLS has already allowed.
create function public.person_stage_changed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.stage_since = now();
  if new.stage <> 'prospect' then
    new.prospect_status = null;
  end if;
  insert into public.activity (owner_id, person_id, kind, stage)
    values (new.owner_id, new.id, 'stage', new.stage);
  return new;
end $$;

create trigger person_stage_changed before update of stage on public.person
  for each row when (old.stage is distinct from new.stage)
  execute function public.person_stage_changed();
