-- ============================================================
-- Atölye İş Takip — v15: Büyük hizmet kataloğu güncellemesi
-- (47 yeni hizmet, isim/kod değişikliği, 2 yeni VW seçeneği,
--  Showroom Pflege, EUROMOBIL, Extra Arbeit, Fotoservice şube fiyatı)
--
-- Bu dosyayı Supabase SQL Editor'de, TEK SEFERDE, baştan sona
-- çalıştırın. SADECE BİR KEZ çalıştırın (multi-row insert'lerde
-- "on conflict" yok — ikinci kez çalıştırırsanız aynı hizmetler
-- tekrar eklenir).
--
-- Program şu an CANLI kullanımda — bu dosya hiçbir mevcut satırı
-- SİLMEZ, sadece yeni kolon/satır ekler ve 2 spesifik satırı
-- (Unfall-W adı, FOTOSERVICE fiyat tipi) günceller.
-- ============================================================


-- ============================================================
-- 0) HAZIRLIK: kolonları genişlet (uzun hizmet isimleri için)
--    ve bu güncelleme için gereken yeni kolonları ekle.
--    Hepsi güvenli/geriye dönük uyumlu, mevcut veriyi etkilemez.
-- ============================================================

alter table job_types alter column code type text using code::text;
alter table job_types alter column name type text using name::text;

-- requires_ref: false olan hizmetlerde AKT/Fahrgestellnummer alanı
-- ZORUNLU DEĞİL (Showroom Pflege, EUROMOBIL için kullanılacak).
alter table job_types add column if not exists requires_ref boolean not null default true;

-- allows_extra_arbeit: true olan hizmetlerde (GW/NW kategorisi),
-- Regiestunde ve Fotoservice'in yanına 2'ye kadar "Extra Arbeit"
-- eklenebilir (bkz. madde 7 aşağıda).
alter table job_types add column if not exists allows_extra_arbeit boolean not null default false;

-- Showroom Pflege için: sabit duration_minutes yerine, her kayıtta
-- seçilen 1-5 saatlik süreyi (dakika olarak) tutan kolon. Fiyatı
-- ETKİLEMEZ, sadece kapasite/performans hesabına (workedMinutes)
-- dahil edilir.
alter table records add column if not exists custom_duration_minutes integer;

-- Extra Arbeit (madde 7): seçilen 1-2 ek hizmetin toplam fiyatı/süresi
-- ana kayda AYNEN Regiestunde gibi eklenir (ayrı kayıt oluşturulmaz).
-- *_code kolonları sadece görüntüleme/rapor amaçlıdır.
alter table records add column if not exists extra_arbeit_price numeric;
alter table records add column if not exists extra_arbeit_minutes integer;
alter table records add column if not exists extra_arbeit_1_code text;
alter table records add column if not exists extra_arbeit_2_code text;


-- ============================================================
-- 1) 47 YENİ HİZMET — mevcut listenin en altına, sırasıyla.
--    Not: "Beseitigung von Lackverunreinigungen..." satırı "pro Std."
--    olduğu için Regiestunde mantığıyla (is_aufbereitung=true, temel
--    fiyat 0) kuruldu — çalışan bu hizmeti seçtiğinde saat başına
--    Regiestunde alanından ekleme yapacak, tıpkı diğer "Aufbereitung"
--    hizmetlerinde olduğu gibi. Lütfen bu kararı gözden geçirin.
-- ============================================================

with base as (select coalesce(max(sort_order), 0) as start from job_types)
insert into job_types (code, name, price_eur, duration_minutes, is_aufbereitung, active, sort_order)
select v.code, v.code, v.price, v.duration, v.aufb, true, base.start + row_number() over ()
from base, (values
  ('Aufbringen von Insektenreiniger', 0.52, 1, false),
  ('Ausbesserung Kratzer, Steinschlag pro Bauteil', 8.84, 8, false),
  ('Auslieferungsfinish GW 1', 10.40, 10, false),
  ('Auslieferungsfinish GW 2', 19.76, 18, false),
  ('Baumharz entfernen', 21.84, 20, false),
  ('Beseitigung von Lackverunreinigungen, Teerentfernung, Aufklebern pro Std.', 0.00, null, true),
  ('Desinfektions-Paket DF', 15.60, 14, false),
  ('Desinfektions-Paket DO', 36.40, 33, false),
  ('Fahrzeug Schneebefreiung', 1.56, 2, false),
  ('Fahrzeug komplett abledern', 1.56, 2, false),
  ('Fahrzeug zu Stellplatz verbringen / vorfahren', 1.56, 2, false),
  ('Fahrzeugpolitur kompl. FZG', 36.40, 33, false),
  ('Fahrzeugpolitur pro Bauteil (Dach)', 10.40, 10, false),
  ('Fahrzeugpolitur pro Bauteil (Heckklappe/Motorhaube)', 9.36, 9, false),
  ('Fahrzeugpolitur pro Bauteil (Kotflügel/Seitenteil/Tür)', 8.32, 8, false),
  ('Fahrzeugpolitur pro Bauteil (Spiegelgehäuse)', 5.20, 5, false),
  ('Fahrzeugpolitur pro Bauteil (Stoßfänger)', 8.32, 8, false),
  ('Felgenreinigung (1 demontiertes Rad)', 4.16, 4, false),
  ('Felgenreinigung (Satz demontiert)', 16.64, 15, false),
  ('Felgenreinigung (Satz montiert am Fahrzeug)', 14.56, 13, false),
  ('Flugrost entfernen', 19.76, 18, false),
  ('HD Vorreinigung', 2.08, 2, false),
  ('Handwäsche', 10.40, 10, false),
  ('Handwäsche inkl. Innenreinigung', 26.00, 24, false),
  ('Handwäsche inkl. Innenreinigung und Hochglanzpolitur', 64.48, 58, false),
  ('Innenraum saugen (inkl. Kofferraum)', 14.56, 13, false),
  ('Innenraumreinigung', 16.64, 15, false),
  ('Insektenentfernung (ohne Politur)', 2.60, 3, false),
  ('Kennzeichenhaltermontage', 3.12, 3, false),
  ('Lederreinigung mit Lederpflege', 31.20, 28, false),
  ('Motorwäsche', 14.56, 13, false),
  ('Nanoversiegelung / Lackversiegelung', 26.00, 24, false),
  ('Oberwäsche manuell (für Mitarbeiter/Mobilitätsdienstleister)', 10.40, 10, false),
  ('Ozonbehandlung bei Geruchsverschmutzung (Raucher/Tiere)', 40.56, null, false),
  ('Pedale feucht reinigen', 1.56, 2, false),
  ('Reinigung der Aschenbecher, ggf. feucht', 1.04, 1, false),
  ('Reinigung und Aufwertung der Kunststoffteile innen und außen', 5.72, 5, false),
  ('Scheiben und Spiegelreinigung innen', 4.68, 4, false),
  ('Scheiben- und Spiegelreinigung außen', 3.12, 3, false),
  ('Schriftzüge und Folien entfernen', 0.00, null, false),
  ('Sitze reinigen (einzeln)', 9.36, 9, false),
  ('Sitze reinigen (komplett)', 31.20, 28, false),
  ('Standardprogramm', 28.08, 26, false),
  ('Stoff-/Teppich-/Himmelkorrektur', 61.36, 56, false),
  ('TAXI Kundenprogramm', 46.80, 42, false),
  ('Tierhaare entfernen je Std', 33.28, 30, false),
  ('pro Steinschlag', 2.08, 2, false)
) as v(code, price, duration, aufb);


-- ============================================================
-- 2) İSİM/ETİKET DEĞİŞİKLİĞİ: 'Unfall-W' → 'Unfall-W Reinigung
--    nach Instandsetzung'. Fiyat/süre AYNEN kalıyor.
--
--    ÖNEMLİ NOT: Çalışan ekranındaki butonda görünen metin, job_types
--    tablosunun "name" değil "code" kolonudur — bu yüzden hem code
--    hem name güncelleniyor (aksi halde görünen etiket değişmezdi).
--    "code" hiçbir özel JS mantığında (FOTOSERVICE_JOB_CODES, SR-Delle
--    vb.) kullanılmadığı için bu değişiklik güvenlidir.
-- ============================================================

update job_types
set code = 'Unfall-W Reinigung nach Instandsetzung',
    name = 'Unfall-W Reinigung nach Instandsetzung'
where code = 'Unfall-W';


-- ============================================================
-- 3) YENİ VW SEÇENEKLERİ — mevcut Audi seçeneklerine dokunulmuyor,
--    ayrı yeni satırlar. Süreleri, aşağıdaki alt sorgularla mevcut
--    Audi versiyonlarından OTOMATİK kopyalanıyor.
--
--    ⚠️ LÜTFEN ÇALIŞTIRDIKTAN SONRA KONTROL EDİN (aşağıdaki select ile):
--    Eğer duration_minutes NULL geldiyse, "code ilike" deseni mevcut
--    Audi satırınızın gerçek adıyla eşleşmemiş demektir — bu durumda
--    aşağıdaki iki update satırını, doğru mevcut hizmet adını yazarak
--    elle çalıştırın.
-- ============================================================

insert into job_types (code, name, price_eur, duration_minutes, active, sort_order)
select 'Neuwagen Flatrate 2 (VW)', 'Neuwagen Flatrate 2 (VW)', 70.72,
  (select duration_minutes from job_types
   where code ilike '%Neuwagen Flatrate%' and code not ilike '%VW%'
   order by sort_order limit 1),
  true, (select coalesce(max(sort_order), 0) + 1 from job_types);

insert into job_types (code, name, price_eur, duration_minutes, active, sort_order)
select 'NW Systempflege (VW)', 'NW Systempflege (VW)', 41.60,
  (select duration_minutes from job_types
   where code ilike '%NW Systempflege%' and code not ilike '%VW%'
   order by sort_order limit 1),
  true, (select coalesce(max(sort_order), 0) + 2 from job_types);

-- Kontrol (duration_minutes NULL ise elle düzeltin):
-- select code, price_eur, duration_minutes from job_types where code in ('Neuwagen Flatrate 2 (VW)', 'NW Systempflege (VW)');
--
-- Elle düzeltme şablonu (gerekirse):
-- update job_types set duration_minutes = <DEĞER> where code = 'Neuwagen Flatrate 2 (VW)';
-- update job_types set duration_minutes = <DEĞER> where code = 'NW Systempflege (VW)';


-- ============================================================
-- 5) SHOWROOM PFLEGE — yeni iş tipi. AKT/Şasi no gerekmez
--    (requires_ref=false), ücretsiz (0 €), süresi kayıt anında
--    1-5 saat arası seçilir (index.html tarafında dropdown ile,
--    records.custom_duration_minutes kolonuna yazılır ve kapasite
--    hesabına dahil edilir). 3 şubede de otomatik kullanılabilir
--    (iş tipleri şubeye göre kısıtlanmıyor).
-- ============================================================

insert into job_types (code, name, price_eur, duration_minutes, requires_ref, active, sort_order)
values (
  'Showroom Pflege', 'Showroom Pflege', 0, null, false, true,
  (select coalesce(max(sort_order), 0) + 1 from job_types)
);


-- ============================================================
-- 6) EUROMOBIL — 4 alt seçenek, sayaç bazlı (mevcut "adet girilen"
--    hizmetlerle AYNI is_quantity mekanizması), AKT/Şasi no gerekmez,
--    3 şubede kullanılabilir (kısıtlama yok).
-- ============================================================

with base as (select coalesce(max(sort_order), 0) as start from job_types)
insert into job_types (code, name, price_eur, duration_minutes, is_quantity, requires_ref, active, sort_order)
select v.code, v.code, v.price, v.duration, true, false, true, base.start + row_number() over ()
from base, (values
  ('EUROMOBIL - SB Oberwäsche maschinell', 4.41, null),
  ('EUROMOBIL - Oberwäsche 1', 6.09, 12),
  ('EUROMOBIL - Oberwäsche 2 / Kl. Reinigung', 8.09, 12),
  ('EUROMOBIL - Oberwäsche 3', 44.10, 30)
) as v(code, price, duration);


-- ============================================================
-- 7) EXTRA ARBEIT — GW ve NW kategorisi hizmetlerde, Regiestunde ve
--    Fotoservice'in yanına 2'ye kadar ek hizmet eklenebilmesi için
--    bu hizmetler allows_extra_arbeit=true olarak işaretleniyor.
--
--    ⚠️ DESEN EŞLEŞTİRME KULLANILDI (GW-%, NW Systempflege%,
--    %Neuwagen%, VFW-%). LÜTFEN AŞAĞIDAKİ KONTROL SORGUSUNU
--    ÇALIŞTIRIP LİSTENİN DOĞRU OLDUĞUNU ONAYLAYIN — eksik/fazla
--    bir hizmet varsa bana söyleyin, düzeltirim.
--
--    (Ek hizmet olarak SEÇİLEBİLECEK havuz — SR-Lack/SR-Delle/
--    MTS-SR dahil tüm "manuel fiyat girilen", sayaç bazlı ve iç
--    kullanım hizmetleri hariç tutulacak — bu, index.html
--    tarafında otomatik yapılıyor, ayrı bir SQL gerektirmiyor.)
-- ============================================================

update job_types set allows_extra_arbeit = true
where (
  code ilike 'GW-%'
  or code ilike 'VFW-%'
  or code ilike '%Neuwagen%'
  or code ilike '%NW Systempflege%'
)
and is_variable_price = false;

-- Kontrol (bu listeyi mutlaka gözden geçirin):
-- select code, price_eur, is_variable_price from job_types where allows_extra_arbeit = true order by code;


-- ============================================================
-- 8) FOTOSERVICE ŞUBE BAZLI FİYAT — sabit fiyat yerine değişken
--    fiyata çevriliyor (custom_price), index.html artık şubeye göre
--    (Ausschläger Weg → 9,88 €, Horn/Wiesendamm → 12,48 €) doğru
--    değeri otomatik yazacak. Süre (duration_minutes) BU SATIRLA
--    değiştirilmiyor — zaten elle 12 dakikaya güncellediğinizi
--    belirttiniz, aynen kalıyor.
-- ============================================================

update job_types set is_variable_price = true where code = 'FOTOSERVICE';


-- ============================================================
-- GENEL KONTROL (hepsini çalıştırdıktan sonra):
-- select count(*) from job_types; -- öncekinden +53 civarı olmalı (47+2+1+4-... rename hariç)
-- select code, price_eur, duration_minutes, is_aufbereitung, is_quantity, requires_ref, allows_extra_arbeit
-- from job_types order by sort_order desc limit 60;
-- ============================================================
