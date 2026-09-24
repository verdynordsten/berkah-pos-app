-- ============================================================
-- Berkah POS — Migrasi v4: PIN owner (memberships.pin_hash)
-- Jalankan di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Idempotent: aman di-Run ulang.
-- Efek:
--  1. memberships.pin_hash (nullable; NULL = owner belum pasang PIN)
--  2. RPC verify_owner_pin(p_user_id, p_store_id, p_pin_hash) -> boolean
--  3. Masuk mode owner/admin WAJIB PIN — kasir tidak bisa naik ke owner
--     tanpa tahu PIN owner. Login email saja TIDAK cukup.
-- Catatan: kalau policy RLS dikencangkan nanti, kedua fungsi di bawah
-- SECURITY DEFINER sehingga tetap bisa verifikasi tanpa baca hash.
-- ============================================================

alter table public.memberships
  add column if not exists pin_hash text;

-- ============ RPC: verifikasi PIN owner/admin ============
-- App kirim user_id + store_id + pin_hash (SHA-256 "storeId:userId:pin").
-- Return true kalau cocok + membership aktif. Tidak pernah bocorkan hash.
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
