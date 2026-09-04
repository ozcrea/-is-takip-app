-- ============================================================
-- Atölye İş Takip — v5 Şema Güncellemesi
-- Bu dosyayı Supabase Dashboard > SQL Editor'e yapıştırıp "Run" tuşuna basın.
-- Var olan verileri SİLMEZ, sadece eksik kolonları ve iş tiplerini ekler/günceller.
-- ============================================================

-- 1) employees: şifre kolonu (v5 giriş sistemi için)
alter table employees add column if not exists password text;
update employees set password = akt_no where password is null;

-- 2) job_types: sayaç bazlı (+1) iş tipi bayrağı
alter table job_types add column if not exists is_quantity boolean default false;

-- 3) Tüm iş tiplerini ekle / güncelle (kod üzerinden eşleştirilir, ikinci kez
--    çalıştırmak güvenlidir).

-- Aufbereitung grubu (Regiestunde çıkar, AKT gerekir, 33,28 €/saat ek)
insert into job_types (code, name, duration_minutes, price_eur, is_aufbereitung, is_mts, is_variable_price, is_quantity, active, sort_order) values
  ('GW-A',        'Gebrauchtwagenaufbereitung Paket A',                150, 88.40,  true,  false, false, false, true, 10),
  ('GW-B',        'Gebrauchtwagenaufbereitung Paket B',                150, 99.84,  true,  false, false, false, true, 11),
  ('GW-FR',       'Gebrauchtwagen Flatrate',                           150, 138.32, true,  false, false, false, true, 12),
  ('Komfort',     'Komfortprogramm',                                  150, 53.04,  true,  false, false, false, true, 13),
  ('KP-Komfort',  'Kundenpaket Komfort – Innenraumreinigung',         150, 85.49,  true,  false, false, false, true, 14),
  ('KP-KomfortPlus','Kundenpaket Komfort Plus',                       150, 116.84, true,  false, false, false, true, 15),
  ('KP-Luxus',    'Kundenpaket Luxus – Außenreinigung',               150, 97.45,  true,  false, false, false, true, 16),
  ('Luxus',       'Luxusprogramm',                                    150, 109.20, true,  false, false, false, true, 17),
  ('NW-FR',       'Neuwagen Flatrate (Audi)',                         60,  75.92,  true,  false, false, false, true, 18),
  ('NW-FR-Aus',   'Neuwagen Flatrate für Ausstellungsfahrzeuge',      60,  85.28,  true,  false, false, false, true, 19),
  -- MTS grubu (ayrı ciro, Regiestunde çıkar, AKT gerekir)
  ('MTS-NW',      'MTS Neuwagen',                                     60,  66.00,  true,  true,  false, false, true, 20),
  ('MTS-GW',      'MTS Gebrauchtwagen',                               150, 126.50, true,  true,  false, false, true, 21),
  -- Diğer işler (Regiestunde yok, AKT gerekir)
  ('GW-Ausl',     'Gebraucht Auslieferung',                           30,  0,      false, false, false, false, true, 30),
  ('Unfall-W',    'Unfall Wäsche',                                    25,  28.08,  false, false, false, false, true, 31),
  ('Unfall-W2',   'Unfallwäsche 2',                                   25,  42.64,  false, false, false, false, true, 32),
  ('VFW-W1',      'VFW Wäsche W1',                                    25,  10.40,  false, false, false, false, true, 33),
  ('VFW-W2',      'VFW Wäsche W2',                                    25,  16.64,  false, false, false, false, true, 34),
  ('Ausl-NW1',    'Auslieferungsfinish NW1',                          25,  10.40,  false, false, false, false, true, 35),
  ('Ausl-NW2',    'Auslieferungsfinish NW2',                          25,  19.76,  false, false, false, false, true, 36),
  ('NW-Sys',      'NW Systempflege',                                  25,  43.68,  false, false, false, false, true, 37),
  -- Sayaç bazlı işler (AKT GEREKMEZ, +1 ile eklenir)
  ('SW1',         'Service Wäsche 1',                                 10,   3.74,  false, false, false, true,  true, 40),
  ('SW2',         'Service Wäsche 2',                                 10,   6.76,  false, false, false, true,  true, 41),
  ('NW-Annahme',  'Annahme vom Spediteur je KFZ',                     10,   7.80,  false, false, false, true,  true, 42),
  -- Değişken fiyatlı işler (fiyat elle girilir, AKT gerekir)
  -- Smart Repair'de standart süre yok (kullanıcı onayı) -> duration_minutes = null,
  -- bu işler şef panelindeki kapasite (Kapazität) hesabına dahil edilmez.
  ('Privat',      'Privat Kunde',                                     150,  null,  false, false, true,  false, true, 50),
  ('SR-Lack',     'Smart Repair - Lack',                              null, null,  false, false, true,  false, true, 51),
  ('SR-Delle',    'Smart Repair - Delle',                             null, null,  false, false, true,  false, true, 52)
on conflict (code) do update set
  name = excluded.name,
  duration_minutes = excluded.duration_minutes,
  price_eur = excluded.price_eur,
  is_aufbereitung = excluded.is_aufbereitung,
  is_mts = excluded.is_mts,
  is_variable_price = excluded.is_variable_price,
  is_quantity = excluded.is_quantity,
  active = excluded.active,
  sort_order = excluded.sort_order;

-- 4) SmartRepair ortak kullanıcı hesabı (yoksa oluştur)
insert into employees (name, akt_no, password, active)
values ('SmartRepair', 'SmartRepair', 'Repair2026', true)
on conflict (akt_no) do nothing;

-- ============================================================
-- Bitti. Kontrol için:
-- select code, name, price_eur, is_quantity, is_variable_price from job_types order by sort_order;
-- select name, akt_no, password from employees;
-- ============================================================
