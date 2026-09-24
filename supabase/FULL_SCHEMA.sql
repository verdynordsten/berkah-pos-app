-- ============================================================
-- Berkah POS — FULL SCHEMA (SATU FILE, FINAL)
-- Jalankan SEKALI di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Idempotent: aman di-Run ulang. Berisi v1 + v2 + fix p_user_id.
-- Kalau mau mulai dari NOL: Run RESET.sql dulu, baru file ini.
-- ============================================================

-- ============ 1. TABLES ============
create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Toko Berkah Jaya',
  address text default 'Jl. Merdeka No.12',
  phone text default '0812-3456-7890',
  tax_percent numeric not null default 10,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  sort int not null default 0,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  price numeric not null default 0,
  stock int not null default 0,
  photo_url text,
  barcode text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  cashier_name text not null default 'Andi',
  label text not null default 'Shift Pagi (07-15)',
  opening_cash numeric not null default 0,
  closing_cash numeric,
  opened_at timestamptz not null default now(),
  closed_at timestamptz
  -- NOTE: kolom user_id / staff_id ditambah di bawah (setelah tabel staff ada)
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  shift_id uuid references public.shifts(id) on delete set null,
  customer_id uuid references public.customers(id) on delete set null,
  code text not null,
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  tax numeric not null default 0,
  total numeric not null default 0,
  pay_method text not null default 'Tunai',
  paid numeric not null default 0,
  change numeric not null default 0,
  status text not null default 'paid',
  created_at timestamptz not null default now()
);

create table if not exists public.transaction_items (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name text not null,
  price numeric not null default 0,
  qty int not null default 1,
  line_total numeric not null default 0
);

create table if not exists public.stock_moves (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  qty int not null,
  reason text not null default 'sale',
  created_at timestamptz not null default now()
);

-- ============ 2. MEMBERSHIPS (user <-> toko + peran) ============
-- owner = pendaftar pertama (super admin); staff/admin = anggota toko
create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'staff',
  display_name text not null default 'Kasir',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, user_id)
);
create index if not exists memberships_user_idx on public.memberships(user_id);
create index if not exists memberships_store_idx on public.memberships(store_id);

-- ============ 3. STAFF (kasir PIN, TANPA login email) ============
create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  pin_hash text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);
create index if not exists staff_store_idx on public.staff(store_id);

-- kolom shifts.user_id / staff_id kalau tabel shifts sudah ada dari v1
alter table public.shifts
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists staff_id uuid references public.staff(id) on delete set null;

-- ============ 3b. STAFF: kolom peran (kasir / admin) ===========
alter table public.staff
  add column if not exists role text not null default 'kasir';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'staff_role_chk'
  ) then
    alter table public.staff
      add constraint staff_role_chk
      check (role in ('kasir', 'admin'));
  end if;
end
$$;

-- ============ 4. RLS + POLICY (MVP allow-all via anon key) ============
alter table public.stores enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.shifts enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;
alter table public.stock_moves enable row level security;
alter table public.memberships enable row level security;
alter table public.staff enable row level security;

drop policy if exists "mvp_all" on public.stores;
drop policy if exists "mvp_all" on public.categories;
drop policy if exists "mvp_all" on public.products;
drop policy if exists "mvp_all" on public.customers;
drop policy if exists "mvp_all" on public.shifts;
drop policy if exists "mvp_all" on public.transactions;
drop policy if exists "mvp_all" on public.transaction_items;
drop policy if exists "mvp_all" on public.stock_moves;
drop policy if exists "mvp_all" on public.memberships;
drop policy if exists "mvp_all" on public.staff;

create policy "mvp_all" on public.stores for all using (true) with check (true);
create policy "mvp_all" on public.categories for all using (true) with check (true);
create policy "mvp_all" on public.products for all using (true) with check (true);
create policy "mvp_all" on public.customers for all using (true) with check (true);
create policy "mvp_all" on public.shifts for all using (true) with check (true);
create policy "mvp_all" on public.transactions for all using (true) with check (true);
create policy "mvp_all" on public.transaction_items for all using (true) with check (true);
create policy "mvp_all" on public.stock_moves for all using (true) with check (true);
create policy "mvp_all" on public.memberships for all using (true) with check (true);
create policy "mvp_all" on public.staff for all using (true) with check (true);

-- ============ 5. RPC: register toko baru (FINAL — 3 parameter) ============
-- Hapus varian LAMA (2 parameter) dulu agar PostgREST tidak bingung.
drop function if exists public.create_store_with_owner(text, text);

create or replace function public.create_store_with_owner(
  p_user_id uuid,
  p_store_name text,
  p_display_name text default 'Owner'
) returns uuid
language plpgsql
security definer
as $$
declare
  sid uuid;
begin
  insert into public.stores (name) values (nullif(trim(p_store_name), ''))
  returning id into sid;

  insert into public.memberships (store_id, user_id, role, display_name)
  values (sid, p_user_id, 'owner', nullif(trim(p_display_name), 'Owner'))
  on conflict (store_id, user_id) do update
    set role = 'owner', display_name = excluded.display_name;

  return sid;
end;
$$;

-- ============ 6. RPC: verifikasi PIN kasir ============
create or replace function public.verify_staff_pin(
  p_store_id uuid,
  p_name text,
  p_pin_hash text
) returns uuid
language plpgsql
security definer
as $$
declare
  sid uuid;
begin
  select id into sid from public.staff
  where store_id = p_store_id
    and lower(name) = lower(trim(p_name))
    and pin_hash = p_pin_hash
    and is_active = true
  limit 1;
  return sid;
end;
$$;

-- ============ 7. PIN OWNER (memberships.pin_hash, v4) ============
alter table public.memberships
  add column if not exists pin_hash text;

-- Verifikasi PIN owner/admin: SHA-256 "storeId:userId:pin".
-- Masuk mode owner WAJIB PIN — login email saja tidak cukup.
create or replace function public.verify_owner_pin(
  p_user_id uuid,
  p_store_id uuid,
  p_pin_hash text
) returns boolean
language plpgsql
security definer
as $$
declare
  ok boolean;
begin
  select true into ok from public.memberships
  where user_id = p_user_id
    and store_id = p_store_id
    and pin_hash = p_pin_hash
    and is_active = true
  limit 1;
  return coalesce(ok, false);
end;
$$;

-- ============ 8. SHIFT PER-TOKO + MODAL DEFAULT (v7) ============
-- Daftar shift + jam per toko (diatur owner dari Setup Toko).
create table if not exists public.shift_templates (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  start_hour int not null default 7,
  end_hour int not null default 15,
  sort int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);
create index if not exists shift_templates_store_idx
  on public.shift_templates(store_id);

alter table public.stores
  add column if not exists default_opening_cash numeric not null default 0;

alter table public.shift_templates enable row level security;
drop policy if exists "mvp_all" on public.shift_templates;
create policy "mvp_all" on public.shift_templates
  for all using (true) with check (true);

-- RPC register ikut seed 3 shift default buat toko baru.
create or replace function public.create_store_with_owner(
  p_user_id uuid,
  p_store_name text,
  p_display_name text default 'Owner'
) returns uuid
language plpgsql
security definer
as $$
declare
  sid uuid;
begin
  insert into public.stores (name) values (nullif(trim(p_store_name), ''))
  returning id into sid;

  insert into public.memberships (store_id, user_id, role, display_name)
  values (sid, p_user_id, 'owner', nullif(trim(p_display_name), 'Owner'))
  on conflict (store_id, user_id) do update
    set role = 'owner', display_name = excluded.display_name;

  insert into public.shift_templates (store_id, name, start_hour, end_hour, sort)
  values (sid, 'Pagi', 7, 15, 0),
         (sid, 'Siang', 15, 23, 1),
         (sid, 'Malam', 23, 7, 2)
  on conflict (store_id, name) do nothing;

  return sid;
end;
$$;
