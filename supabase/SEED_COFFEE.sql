-- ============================================================
-- Berkah POS — SEED MENU COFFEE (toko yang sudah ada tapi kosong)
-- Cara: ganti 'Berkah Coffee' dengan nama toko lo, Run SEKALI.
-- Isi: 3 kategori + 9 menu coffee. Aman di-Run ulang (skip duplikat).
-- ============================================================

do $$
declare sid uuid;
declare c_minum uuid; declare c_makan uuid; declare c_snack uuid;
begin
  select id into sid from public.stores where name = 'Berkah Coffee' limit 1;
  if sid is null then
    raise exception 'Toko "Berkah Coffee" tidak ketemu. Ganti nama di bawah sesuai nama toko lo.';
  end if;

  insert into public.categories (store_id, name, sort)
  values (sid, 'Minuman', 1), (sid, 'Makanan', 2), (sid, 'Snack', 3)
  on conflict (store_id, name) do nothing;

  select id into c_minum from public.categories where store_id = sid and name = 'Minuman';
  select id into c_makan from public.categories where store_id = sid and name = 'Makanan';
  select id into c_snack from public.categories where store_id = sid and name = 'Snack';

  insert into public.products (store_id, category_id, name, price, stock) values
    (sid, c_minum, 'Kopi Susu Gula Aren', 18000, 50),
    (sid, c_minum, 'Americano Hot/Ice', 15000, 50),
    (sid, c_minum, 'Caffe Latte', 20000, 50),
    (sid, c_minum, 'Teh Manis Hot/Ice', 8000, 50),
    (sid, c_minum, 'Matcha Latte', 22000, 30),
    (sid, c_makan, 'Indomie Goreng + Telor', 15000, 40),
    (sid, c_makan, 'Nasi Goreng', 18000, 30),
    (sid, c_snack, 'Pisang Goreng Coklat Keju', 12000, 30),
    (sid, c_snack, 'Kentang Goreng', 10000, 30);
end $$;
