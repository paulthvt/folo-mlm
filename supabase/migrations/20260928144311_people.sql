-- The first product table, and the conventions every later one follows
-- (docs/architecture.md → Backend): RLS on owner_id, uuid ids, owner_id
-- defaulting to the caller, created_at / updated_at, hard delete, grants to
-- authenticated only.

-- Shared by every table with an updated_at column.
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

create type public.person_stage as enum ('prospect', 'customer', 'team');
create type public.prospect_status as enum
  ('interested', 'thinking', 'not_now', 'no_reply');

create table public.person (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  name text not null check (length(trim(name)) > 0),
  stage public.person_stage not null,
  prospect_status public.prospect_status,
  phone text,
  email text,
  instagram text,
  needs text,
  products text,
  profession text,
  address text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint status_only_for_prospects
    check (prospect_status is null or stage = 'prospect')
);

create index person_owner_id_idx on public.person (owner_id);

create trigger person_set_updated_at before update on public.person
  for each row execute function public.set_updated_at();

alter table public.person enable row level security;

-- `(select auth.uid())` is evaluated once per query, not once per row.
create policy person_select_own on public.person
  for select to authenticated
  using (owner_id = (select auth.uid()));

create policy person_insert_own on public.person
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy person_update_own on public.person
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy person_delete_own on public.person
  for delete to authenticated
  using (owner_id = (select auth.uid()));

revoke all on public.person from anon;
grant select, insert, update, delete on public.person to authenticated;
