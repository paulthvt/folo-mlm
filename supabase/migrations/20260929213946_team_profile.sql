-- A team member's own profile (#60): what they are aiming for, in their words.
-- Free text like the other facts, blank stored as null. Shown only while
-- they are on the team, kept if they move. No rank, volume or comparison.
alter table public.person
  add column why text,
  add column own_goal text,
  add column time_available text,
  add column would_love_to text,
  add column strengths text,
  add column stuck_on text;
