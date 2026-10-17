-- Notes on Books — Supabase schema
-- Fresh install: paste this whole file into Supabase: SQL Editor → New query → Run.
--
-- Migrations for existing installs (run once, in order, only the ones you haven't run yet):
--   v1.6: alter table notes add column scripture_refs jsonb default '[]';
--   v2.6: alter table people add column if not exists first_name text default '',
--                            add column if not exists middle_name text default '',
--                            add column if not exists last_name text default '';
--
-- NOTE (Sept 2026): from 30 Oct 2026 Supabase stops auto-exposing new public-schema
-- tables to the Data API. Existing tables keep their grants, so a running project is
-- unaffected — but a FRESH install needs the explicit grants at the bottom of this file.
-- They are included below, so this file remains a complete restore path.

create extension if not exists pgcrypto;

create table people (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,                  -- "First Middle Last", derived from the parts below (v2.6)
  sort_name text default '',            -- "Last, First Middle", derived likewise
  first_name text default '',
  middle_name text default '',
  last_name text default '',
  dates text default '',
  notes text default '',
  urls jsonb default '[]',
  tags text[] default '{}',
  created_at timestamptz default now()
);

create table works (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  pub jsonb default '{}',              -- {type: book|article|web, place, publisher, year, imprint, edition,
                                       --  journal, volume, issue, pages, doi, site, accessed}
  source_status text default 'published',  -- published | eebo | surrogate
  original_work_id uuid references works(id) on delete set null,
  review_flag text default '',
  urls jsonb default '[]',
  tags text[] default '{}',
  notes text default '',
  created_at timestamptz default now()
);

create table work_contributors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  work_id uuid not null references works(id) on delete cascade,
  person_id uuid not null references people(id) on delete cascade,
  role text not null default 'author', -- author | editor | translator | chapter_author
  position int default 0
);

create table notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  work_id uuid references works(id) on delete set null,
  quote_html text default '',
  note_html text default '',
  locators jsonb default '[]',         -- [{type, value}] type: page|eebo|chapter|kindle|folio|other
  scripture_refs jsonb default '[]',   -- [{book, chStart, vStart, chEnd, vEnd, verses?}]
  tags text[] default '{}',
  purposes text[] default '{}',
  purpose_values jsonb default '{}',
  chapter_title text default '',
  chapter_author text default '',
  date_added timestamptz default now(),
  updated_at timestamptz default now()
);

create table purposes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  position int default 0,
  fields jsonb default '[]'            -- [{key, label, type: text|select|multiselect, options: []}]
);

create table settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb default '{}'
);

-- Search helper indexes
create index notes_search_idx on notes using gin (
  to_tsvector('english', coalesce(quote_html,'') || ' ' || coalesce(note_html,''))
);
create index notes_tags_idx on notes using gin (tags);
create index notes_work_idx on notes (work_id);
create index wc_work_idx on work_contributors (work_id);
create index wc_person_idx on work_contributors (person_id);

-- Row-level security: each user sees only their own rows
alter table people enable row level security;
alter table works enable row level security;
alter table work_contributors enable row level security;
alter table notes enable row level security;
alter table purposes enable row level security;
alter table settings enable row level security;

create policy "own people" on people for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own works" on works for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own wc" on work_contributors for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own notes" on notes for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own purposes" on purposes for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own settings" on settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- GRANTS -------------------------------------------------------
-- Until Oct 2026 Supabase granted these automatically to every table in `public`,
-- so this file never needed them. That default is going away: after 30 Oct 2026 a
-- table created without an explicit grant is invisible to the Data API (PostgREST,
-- which is what supabase-js talks to) and the app would fail with
--   42501  permission denied for table people
-- Existing projects are NOT retroactively stripped — this matters for fresh installs,
-- i.e. the "JSON backup + new project + schema.sql = full restore" path.
--
-- Grants and RLS are separate layers: a grant decides whether a role may touch the
-- table at all; the policies above still decide which rows it sees. `anon` is
-- deliberately not granted — the app requires sign-in, and RLS would return nothing
-- to an anonymous caller anyway.

grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

-- keeps any table added later in this schema reachable without repeating the grant
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated, service_role;
alter default privileges in schema public
  grant usage, select on sequences to authenticated, service_role;
