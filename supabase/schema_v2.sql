-- ============================================================
-- Berkah POS — Supabase schema v2 (multi-tenant + roles)
-- Jalankan di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Aman dijalankan ulang (idempotent). v1 tetap kompatibel.
-- ============================================================

-- ============ 0. WAJIB: schema v1 dulu ============
-- Kalau project Supabase masih kosong, jalankan supabase/schema.sql (v1)
-- DULU, baru file ini. File ini hanya MENAMBAH tabel v2.

-- ============ 1. MEMBERSHIPS (user <-> toko + peran) ============
-- owner = pendaftar pertama (super admin), staff = kasir/admin toko
create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'staff', -- owner / admin / staff
  display_name text not null default 'Kasir',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, user_id)
);
create index if not exists memberships_user_idx on public.memberships(user_id);
create index if not exists memberships_store_idx on public.memberships(store_id);

-- ============ 2. STAFF (kasir PIN, TANPA login email) ============
-- Kasir gantian shift di HP yang sama: cukup nama + PIN 6 digit.
-- Dibuat & dikelola oleh owner. PIN disimpan sebagai hash (SHA-256 + salt toko).
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

-- ============ 3. SHIFTS: catat SIAPA yang buka (user / staff) ============
alter table public.shifts
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists staff_id uuid references public.staff(id) on delete set null;

-- ============ 4. RLS untuk tabel baru ============
alter table public.memberships enable row level security;
alter table public.staff enable row level security;

-- NOTE MVP: allow-all untuk anon (sama seperti v1) agar HP kasir TANPA
-- login Supabase Auth tetap bisa baca/tulis via anon key.
-- Kencangkan ke auth.uid()-based setelah semua flow stabil.
drop policy if exists "mvp_all" on public.memberships;
drop policy if exists "mvp_all" on public.staff;
create policy "mvp_all" on public.memberships for all using (true) with check (true);
create policy "mvp_all" on public.staff for all using (true) with check (true);

-- ============ 5. RPC: register toko baru dalam 1 transaksi ============
-- Dipanggil app setelah signUp: bikin store + membership owner sekaligus.
create or replace function public.create_store_with_owner(
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
  values (sid, auth.uid(), 'owner', nullif(trim(p_display_name), 'Owner'))
  on conflict (store_id, user_id) do update
    set role = 'owner', display_name = excluded.display_name;

  return sid;
end;
$$;

-- ============ 6. RPC: verifikasi PIN kasir (tanpa bocorkan hash) ============
-- App kirim store_id + name + pin_hash (SHA-256 dari "store_id:pin"),
-- DB cocokkan dengan pin_hash tersimpan. Return id staff kalau cocok.
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
