-- Orders (#138): an order can say how much it was worth, in the business
-- model's unit (PV for dōTERRA, a plain number otherwise). An own order is
-- the user's, with no person: an order with an amount. Goals logs those.
-- A null person_id skips the (person_id, owner_id) foreign key (MATCH SIMPLE);
-- RLS still pins the row to its owner.

alter table public.activity
  add column amount numeric(12,2) check (amount > 0),
  alter column person_id drop not null;

-- Text is optional on an order with an amount, never blank when present.
alter table public.activity drop constraint stage_entry_shape;
alter table public.activity add constraint entry_shape check (
  (kind = 'stage' and stage is not null and text is null)
  or (kind <> 'stage' and stage is null
      and (text is null or length(trim(text)) > 0)
      and (text is not null or (kind = 'order' and amount is not null)))
);

alter table public.activity add constraint amount_only_on_orders
  check (amount is null or kind = 'order');

alter table public.activity add constraint person_or_own_order
  check (person_id is not null or (kind = 'order' and amount is not null));
