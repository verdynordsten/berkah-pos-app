-- Berkah POS — Supabase schema v1
-- Jalankan di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Urutan: tabel -> RLS -> policy -> seed demo.

-- ============ TABLES ============
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
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  shift_id uuid references public.shifts(id) on delete set null,
  customer_id uuid references public.customers(id) on delete set null,
  code text not null, -- misal #129
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  tax numeric not null default 0,
  total numeric not null default 0,
  pay_method text not null default 'Tunai', -- Tunai/QRIS/Debit/E-Wallet
  paid numeric not null default 0,
  change numeric not null default 0,
  status text not null default 'paid', -- paid/refunded
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
  qty int not null, -- +masuk / -keluar
  reason text not null default 'sale', -- sale/restock/opname/return
  created_at timestamptz not null default now()
);

-- ============ RLS (anonym akses via anon key, batasi per app) ============
-- NOTE MVP: RLS ON + policy allow-all untuk anon. Kencangkan setelah auth jadi
-- (ganti ke auth.uid()-based). Jangan expose service_role key di app.
alter table public.stores enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.shifts enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;
alter table public.stock_moves enable row level security;

drop policy if exists "mvp_all" on public.stores;
drop policy if exists "mvp_all" on public.categories;
drop policy if exists "mvp_all" on public.products;
drop policy if exists "mvp_all" on public.customers;
drop policy if exists "mvp_all" on public.shifts;
drop policy if exists "mvp_all" on public.transactions;
drop policy if exists "mvp_all" on public.transaction_items;
drop policy if exists "mvp_all" on public.stock_moves;

create policy "mvp_all" on public.stores for all using (true) with check (true);
create policy "mvp_all" on public.categories for all using (true) with check (true);
create policy "mvp_all" on public.products for all using (true) with check (true);
create policy "mvp_all" on public.customers for all using (true) with check (true);
create policy "mvp_all" on public.shifts for all using (true) with check (true);
create policy "mvp_all" on public.transactions for all using (true) with check (true);
create policy "mvp_all" on public.transaction_items for all using (true) with check (true);
create policy "mvp_all" on public.stock_moves for all using (true) with check (true);

-- ============ SEED DEMO (toko + kategori + 6 produk + pelanggan) ============
insert into public.stores (name, address, phone, tax_percent)
values ('Toko Berkah Jaya', 'Jl. Merdeka No.12', '0812-3456-7890', 10)
on conflict do nothing;

-- ambil store id untuk seed
do $$
declare sid uuid;
begin
  select id into sid from public.stores where name = 'Toko Berkah Jaya' limit 1;
  insert into public.categories (store_id, name, sort) values
    (sid, 'Semua', 0), (sid, 'Minuman', 1), (sid, 'Makanan', 2),
    (sid, 'Snack', 3), (sid, 'Sembako', 4)
  on conflict do nothing;
  insert into public.products (store_id, name, price, stock) values
    (sid, 'Kopi Tubruk 200g', 28000, 42),
    (sid, 'Teh Botol 450ml', 6000, 120),
    (sid, 'Indomie Goreng', 3500, 200),
    (sid, 'Roti Tawar Sari', 18000, 35),
    (sid, 'Susu UHT 1L', 22000, 60),
    (sid, 'Chitato 68g', 12000, 88)
  on conflict do nothing;
  insert into public.customers (store_id, name, phone) values
    (sid, 'Pelanggan Umum', null),
    (sid, 'Budi', '0812-111'),
    (sid, 'Sari', '0813-222'),
    (sid, 'Agung', '0819-333')
  on conflict do nothing;
end $$;
