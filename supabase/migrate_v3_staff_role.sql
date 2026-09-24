-- ============================================================
-- Berkah POS — Migrasi v3: peran staff (kasir / admin)
-- Jalankan di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Idempotent: aman di-Run ulang.
-- Efek:
--  1. staff.role ('kasir' default, atau 'admin')
--  2. Admin boleh kelola menu (app-side), kasir tidak.
--  3. Tiap staff tetap punya PIN sendiri (pin_hash unik per nama).
-- ============================================================

alter table public.staff
  add column if not exists role text not null default 'kasir';

-- Batasi nilai peran yang valid.
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
