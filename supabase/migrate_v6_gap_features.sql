-- ============================================================
-- Berkah POS — MIGRASI v6 (Gap 1-5: laporan, promo, stok, order, kas)
-- Jalankan SEKALI di Supabase Dashboard > SQL Editor (copy-paste, Run).
-- Idempotent: aman di-Run ulang.
-- Payment agregator SKIP (nanti). PPOB SKIP (nanti).
-- ============================================================

-- ---------- A. PROMO DISKON DINAMIS (Gap 2) ----------
create table if not exists public.promos (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,                       -- cth: HEMAT10
  kind text not null default 'percent',     -- percent | nominal
  value numeric not null default 10,        -- 10 = 10% | 5000 = Rp5000
  min_total numeric not null default 0,     -- min. belanja biar promo nyala
  starts_at timestamptz,                    -- null = langsung aktif
  ends_at timestamptz,                      -- null = selamanya
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);
create index if not exists promos_store_idx on public.promos(store_id);

-- Pajak dinamis sudah ada: stores.tax_percent (dipakai checkout, bukan hardcode).

-- ---------- B. POIN MEMBER (Gap 2) ----------
alter table public.customers
  add column if not exists points int not null default 0;

-- Jejak poin masuk/keluar per transaksi
create table if not exists public.point_moves (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete set null,
  transaction_id uuid references public.transactions(id) on delete set null,
  points int not null,                       -- +dapat / -tukar
  reason text not null default 'earn',
  created_at timestamptz not null default now()
);
create index if not exists point_moves_cust_idx on public.point_moves(customer_id);

-- Aturan poin per toko (1 poin tiap kelipatan spend_step, nilai tukar per poin)
alter table public.stores
  add column if not exists point_step numeric not null default 10000,
  add column if not exists point_value numeric not null default 100;

-- ---------- C. STOK: ambang + pembelian supplier (Gap 3) ----------
alter table public.products
  add column if not exists low_stock_at int not null default 5;

alter table public.stock_moves
  add column if not exists note text;

-- Pembelian / stok masuk dari supplier
create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  supplier text not null default '-',
  note text,
  total numeric not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists purchases_store_idx on public.purchases(store_id);

create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name text not null,
  qty int not null default 1,
  cost numeric not null default 0,
  line_total numeric not null default 0
);

-- ---------- D. TIPE ORDER + MEJA (Gap 5a) ----------
alter table public.transactions
  add column if not exists order_type text not null default 'takeaway',
  add column if not exists table_no text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'trx_order_type_chk') then
    alter table public.transactions
      add constraint trx_order_type_chk
      check (order_type in ('dinein', 'takeaway', 'delivery'));
  end if;
end
$$;

-- ---------- E. KAS / KEUANGAN SEDERHANA tanpa PPOB (Gap 6) ----------
create table if not exists public.cash_moves (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  kind text not null default 'out',          -- in (masuk) | out (keluar)
  category text not null default 'Lainnya',  -- Belanja bahan, Gaji, Sewa, ...
  amount numeric not null default 0,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists cash_moves_store_idx on public.cash_moves(store_id);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'cash_kind_chk') then
    alter table public.cash_moves
      add constraint cash_kind_chk check (kind in ('in', 'out'));
  end if;
end
$$;

-- ---------- F. KOMISI KASIR (Gap 4) ----------
alter table public.staff
  add column if not exists commission_pct numeric not null default 0;

alter table public.memberships
  add column if not exists commission_pct numeric not null default 0;

-- ---------- G. RLS allow-all (MVP, konsisten dgn tabel lama) ----------
alter table public.promos enable row level security;
alter table public.point_moves enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.cash_moves enable row level security;

drop policy if exists "mvp_all" on public.promos;
drop policy if exists "mvp_all" on public.point_moves;
drop policy if exists "mvp_all" on public.purchases;
drop policy if exists "mvp_all" on public.purchase_items;
drop policy if exists "mvp_all" on public.cash_moves;

create policy "mvp_all" on public.promos for all using (true) with check (true);
create policy "mvp_all" on public.point_moves for all using (true) with check (true);
create policy "mvp_all" on public.purchases for all using (true) with check (true);
create policy "mvp_all" on public.purchase_items for all using (true) with check (true);
create policy "mvp_all" on public.cash_moves for all using (true) with check (true);
