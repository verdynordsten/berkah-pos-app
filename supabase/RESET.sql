-- ============================================================
-- Berkah POS — RESET TOTAL (bersih total, hapus semua data + tabel)
-- Jalankan di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Efek: SEMUA data toko/produk/transaksi HILANG. User auth TIDAK
-- ikut terhapus (hapus manual di Dashboard > Authentication > Users).
-- Setelah ini, jalankan FULL_SCHEMA.sql untuk bangun ulang.
-- ============================================================

-- Hapus function dulu (biar drop table tidak ditolak dependensi)
drop function if exists public.create_store_with_owner(uuid, text, text);
drop function if exists public.create_store_with_owner(text, text);
drop function if exists public.verify_staff_pin(uuid, text, text);

-- Hapus tabel child dulu (ada FK), baru parent
drop table if exists public.stock_moves cascade;
drop table if exists public.transaction_items cascade;
drop table if exists public.transactions cascade;
drop table if exists public.shifts cascade;
drop table if exists public.staff cascade;
drop table if exists public.memberships cascade;
drop table if exists public.customers cascade;
drop table if exists public.products cascade;
drop table if exists public.categories cascade;
drop table if exists public.stores cascade;
