-- ============================================================
-- Berkah POS — Migrasi v5: kelola kategori per-toko + foto produk
-- Jalankan di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Idempotent: aman di-Run ulang.
-- Efek:
--  1. categories: kolom updated_at + index store_id (kategori bebas
--     per-toko: 1 email/1 toko bisa punya banyak kategori sendiri,
--     tidak campur dengan toko lain — scope selalu store_id).
--  2. Storage bucket 'product-photos' (public) + policy baca public,
--     tulis/hapus via anon (MVP; samakan dengan policy tabel mvp_all).
--     Tanpa bucket ini, upload foto produk gagal.
-- ============================================================

-- ---- 1. Kategori per-toko ----
alter table public.categories
  add column if not exists updated_at timestamptz not null default now();

create index if not exists categories_store_sort_idx
  on public.categories(store_id, sort);

-- unique(store_id, name) SUDAH ada dari FULL_SCHEMA (anti-duplikat
-- nama kategori dalam 1 toko, tapi beda toko boleh sama).

-- ---- 2. Bucket foto produk ----
insert into storage.buckets (id, name, public)
values ('product-photos', 'product-photos', true)
on conflict (id) do update set public = true;

-- Policy storage (MVP allow-all, konsisten dengan mvp_all tabel).
drop policy if exists "mvp_read" on storage.objects;
drop policy if exists "mvp_write" on storage.objects;
drop policy if exists "mvp_delete" on storage.objects;

create policy "mvp_read" on storage.objects
  for select using (bucket_id = 'product-photos');

create policy "mvp_write" on storage.objects
  for insert with check (bucket_id = 'product-photos');

create policy "mvp_delete" on storage.objects
  for delete using (bucket_id = 'product-photos');
