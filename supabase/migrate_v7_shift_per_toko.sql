-- ============================================================
-- Berkah POS — MIGRASI v7 (shift per-toko + modal dinamis)
-- Jalankan SEKALI di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Idempotent: aman di-Run ulang.
-- ------------------------------------------------------------
-- Masalah yang dibenerin:
--  - Daftar shift (Pagi/Siang/Malam + jam) tadinya HARDCODE di kode,
--    sama buat semua toko. Sekarang per-toko di shift_templates,
--    bisa diatur owner dari Setup Toko.
--  - Modal awal kas tadinya default global 500rb. Sekarang:
--    prioritas = closing_cash shift terakhir toko itu
--    (fallback = stores.default_opening_cash, fallback akhir = 0).
-- ============================================================

-- 1. Template shift per toko (nama + jam mulai/selesai).
create table if not exists public.shift_templates (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,                        -- cth: Pagi
  start_hour int not null default 7,         -- 0-23
  end_hour int not null default 15,          -- 0-23 (boleh < start = lewat tengah malam)
  sort int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);
create index if not exists shift_templates_store_idx
  on public.shift_templates(store_id);

-- 2. Modal default per toko (fallback kalau belum ada shift terakhir).
alter table public.stores
  add column if not exists default_opening_cash numeric not null default 0;

-- 3. Seed default 3 shift buat toko yang sudah ada tapi belum punya template.
--    (Toko baru dapat seed dari kode app saat dibuat.)
insert into public.shift_templates (store_id, name, start_hour, end_hour, sort)
select s.id, t.name, t.sh, t.eh, t.so
from public.stores s
cross join (values
  ('Pagi', 7, 15, 0),
  ('Siang', 15, 23, 1),
  ('Malam', 23, 7, 2)
) as t(name, sh, eh, so)
where not exists (
  select 1 from public.shift_templates st where st.store_id = s.id
);

-- 4. RLS allow-all (MVP, konsisten dgn tabel lama).
alter table public.shift_templates enable row level security;
drop policy if exists "mvp_all" on public.shift_templates;
create policy "mvp_all" on public.shift_templates
  for all using (true) with check (true);

-- 5. RPC register ikut seed 3 shift default (DB lama: timpa versi lama).
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
