-- ============================================================================
-- Emerge Livelihoods — Organisation Dashboard
-- Supabase schema: users (auth), profiles, workbooks, workbook_sheets
-- Run this whole file once in: Supabase Dashboard -> SQL Editor -> New query
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. PROFILES  (one row per authenticated user, mirrors auth.users)
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  full_name   text,
  role        text not null default 'member' check (role in ('admin','member')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Auto-create a profile row every time someone signs up via Supabase Auth
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 2. WORKBOOKS  (one row per imported Excel/CSV file = metadata only)
-- ----------------------------------------------------------------------------
create table if not exists public.workbooks (
  id           text primary key,               -- client-generated id, e.g. "wb1"
  owner_id     uuid not null references auth.users(id) on delete cascade,
  label        text not null,
  file_name    text not null,
  sheet_order  jsonb not null default '[]'::jsonb,
  active_sheet text,
  header_row   boolean not null default true,
  sort_state   jsonb not null default '{"col":null,"dir":0}'::jsonb,
  filters      jsonb not null default '{}'::jsonb,
  col_widths   jsonb not null default '{}'::jsonb,
  row_heights  jsonb not null default '{}'::jsonb,
  saved_at     timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_workbooks_owner on public.workbooks(owner_id);

-- ----------------------------------------------------------------------------
-- 3. WORKBOOK_SHEETS  (one row per sheet inside a workbook = the actual grid data)
-- ----------------------------------------------------------------------------
create table if not exists public.workbook_sheets (
  id           uuid primary key default gen_random_uuid(),
  workbook_id  text not null references public.workbooks(id) on delete cascade,
  sheet_name   text not null,
  sheet_index  int not null default 0,
  data         jsonb not null default '[]'::jsonb,   -- array-of-arrays: raw rows x cols
  updated_at   timestamptz not null default now(),
  unique (workbook_id, sheet_name)
);

create index if not exists idx_workbook_sheets_workbook on public.workbook_sheets(workbook_id);

-- ----------------------------------------------------------------------------
-- 4. updated_at bookkeeping
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_workbooks_updated on public.workbooks;
create trigger trg_workbooks_updated
  before update on public.workbooks
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_sheets_updated on public.workbook_sheets;
create trigger trg_sheets_updated
  before update on public.workbook_sheets
  for each row execute procedure public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY — every user can only see/edit their own data
-- ----------------------------------------------------------------------------
alter table public.profiles        enable row level security;
alter table public.workbooks       enable row level security;
alter table public.workbook_sheets enable row level security;

drop policy if exists "Profiles: read own"   on public.profiles;
drop policy if exists "Profiles: update own" on public.profiles;
create policy "Profiles: read own"
  on public.profiles for select
  using (auth.uid() = id);
create policy "Profiles: update own"
  on public.profiles for update
  using (auth.uid() = id);

drop policy if exists "Workbooks: owner full access" on public.workbooks;
create policy "Workbooks: owner full access"
  on public.workbooks for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "Sheets: owner full access" on public.workbook_sheets;
create policy "Sheets: owner full access"
  on public.workbook_sheets for all
  using (
    exists (
      select 1 from public.workbooks w
      where w.id = workbook_sheets.workbook_id and w.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workbooks w
      where w.id = workbook_sheets.workbook_id and w.owner_id = auth.uid()
    )
  );

-- ============================================================================
-- Done. Verify in Table Editor: profiles, workbooks, workbook_sheets should
-- all exist, each with "RLS enabled" shown next to the table name.
-- ============================================================================
