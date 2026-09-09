-- ============================================================
-- Atölye İş Takip — v24: job_types.category (Madde 2 için)
--
-- Bu SQL, "Mitarbeiter Raporu" (2A) ve "Şube başına Kategori Raporu" (2B)
-- için gerekli olan kategori bazlı gruplamayı sağlıyor. job_types.code
-- alanı tutarlı bir önek kullanmadığı için (bkz. önceki NW-Sys uyuşmazlığı),
-- otomatik/pattern-matching bir kural yerine, gönderdiğiniz TAM job_types
-- listesine göre HER SATIRI TEK TEK elle kategorilendirdim.
--
-- ⚠️ LÜTFEN ÇALIŞTIRMADAN ÖNCE ŞU BELİRSİZ/YORUMSAL KARARLARI KONTROL EDİN:
--
--   1) "SR" — YENİ bir kategori. SR-Lack ve SR-Delle (is_mts=false,
--      MTS-SR'den FARKLI) için ekledim, çünkü bunlar MTS değil ama GW/NW/SW
--      de değil. Eğer bunları GW veya SW altında saymanızı istiyorsanız,
--      aşağıdaki ilgili UPDATE satırını değiştirin.
--
--   2) "Sonstiges" — şu hizmetleri buraya koydum çünkü GW/NW/SW/Foto/MTS/
--      Privat'a net şekilde oturmuyorlar:
--        - Unfall-W Reinigung nach Instandsetzung, Unfall-W2 (kaza sonrası
--          temizlik — GW/NW hattının bir parçası değil, ayrı bir süreç)
--        - TAXI Kundenprogramm (özel müşteri programı, Privat'tan farklı)
--        - Showroom Pflege (araç değil, showroom bakımı)
--        - EUROMOBIL - * (4 kalem — sabit bir filo/sözleşme müşterisi,
--          adet bazlı, GW/NW/SW hattına dahil değil)
--      Bunlardan herhangi birini başka bir kategoriye taşımak isterseniz
--      ilgili UPDATE satırını düzenleyin.
--
--   3) "SW" içine Komfort/Luxus/Standardprogramm/KP-Komfort/KP-KomfortPlus/
--      KP-Luxus (paket/program seviyeleri) VE tüm tekil detaylandırma
--      hizmetlerini (Felgenreinigung, Handwäsche, Fahrzeugpolitur, vb.)
--      dahil ettim — hepsi "Service Wäsche" şemsiyesi altında görünüyor.
--      Bunları ayrı bir kategoride görmek isterseniz belirtin.
--
-- 2B raporunda (Normal = MTS ve Privat HARİÇ) yukarıdaki tüm diğer
-- kategoriler (GW, NW, SW, Foto, SR, Sonstiges) "Normal" sayılır —
-- örneğinizdeki "Foto: 40 adet" satırı da bu yüzden dahil.
-- ============================================================

alter table job_types add column if not exists category text;

-- GW (Gebrauchtwagen)
update job_types set category = 'GW' where code in (
  'GW-A', 'GW-B', 'GW-FR', 'GW-Ausl',
  'Auslieferungsfinish GW 1', 'Auslieferungsfinish GW 2',
  'VFW-W1', 'VFW-W2'
);

-- NW (Neuwagen)
update job_types set category = 'NW' where code in (
  'NW-FR', 'NW-FR-Aus', 'NW-Sys', 'NW Systempflege (VW)',
  'Neuwagen Flatrate 2 (VW)', 'NW-Annahme', 'Ausl-NW1', 'Ausl-NW2'
);

-- MTS (Mobiler Teknik Servis türleri)
update job_types set category = 'MTS' where code in ('MTS-NW', 'MTS-GW', 'MTS-SR');

-- SR (Smart Repair — MTS olmayan) — bkz. yukarıdaki not (1)
update job_types set category = 'SR' where code in ('SR-Lack', 'SR-Delle');

-- Privat
update job_types set category = 'Privat' where code = 'Privat';

-- Foto
update job_types set category = 'Foto' where code = 'FOTOSERVICE';

-- SW (Service Wäsche — paket/program seviyeleri + tekil detaylandırma
-- hizmetlerinin tamamı) — bkz. yukarıdaki not (3)
update job_types set category = 'SW' where code in (
  'SW1', 'SW2', 'Komfort', 'Luxus', 'Standardprogramm',
  'KP-Komfort', 'KP-KomfortPlus', 'KP-Luxus',
  'Aufbringen von Insektenreiniger',
  'Ausbesserung Kratzer, Steinschlag pro Bauteil',
  'Baumharz entfernen',
  'Beseitigung von Lackverunreinigungen, Teerentfernung, Aufklebern pro Std.',
  'Desinfektions-Paket DF', 'Desinfektions-Paket DO',
  'Fahrzeug Schneebefreiung', 'Fahrzeug komplett abledern',
  'Fahrzeug zu Stellplatz verbringen / vorfahren',
  'Fahrzeugpolitur kompl. FZG',
  'Fahrzeugpolitur pro Bauteil (Dach)',
  'Fahrzeugpolitur pro Bauteil (Heckklappe/Motorhaube)',
  'Fahrzeugpolitur pro Bauteil (Kotflügel/Seitenteil/Tür)',
  'Fahrzeugpolitur pro Bauteil (Spiegelgehäuse)',
  'Fahrzeugpolitur pro Bauteil (Stoßfänger)',
  'Felgenreinigung (1 demontiertes Rad)',
  'Felgenreinigung (Satz demontiert)',
  'Felgenreinigung (Satz montiert am Fahrzeug)',
  'Flugrost entfernen', 'HD Vorreinigung',
  'Handwäsche', 'Handwäsche inkl. Innenreinigung',
  'Handwäsche inkl. Innenreinigung und Hochglanzpolitur',
  'Innenraum saugen (inkl. Kofferraum)', 'Innenraumreinigung',
  'Insektenentfernung (ohne Politur)', 'Kennzeichenhaltermontage',
  'Lederreinigung mit Lederpflege', 'Motorwäsche',
  'Nanoversiegelung / Lackversiegelung',
  'Oberwäsche manuell (für Mitarbeiter/Mobilitätsdienstleister)',
  'Ozonbehandlung bei Geruchsverschmutzung (Raucher/Tiere)',
  'Pedale feucht reinigen', 'Reinigung der Aschenbecher, ggf. feucht',
  'Reinigung und Aufwertung der Kunststoffteile innen und außen',
  'Scheiben und Spiegelreinigung innen',
  'Scheiben- und Spiegelreinigung außen',
  'Schriftzüge und Folien entfernen',
  'Sitze reinigen (einzeln)', 'Sitze reinigen (komplett)',
  'Stoff-/Teppich-/Himmelkorrektur', 'Tierhaare entfernen je Std',
  'pro Steinschlag'
);

-- Sonstiges — bkz. yukarıdaki not (2)
update job_types set category = 'Sonstiges' where code in (
  'Unfall-W Reinigung nach Instandsetzung', 'Unfall-W2',
  'TAXI Kundenprogramm', 'Showroom Pflege',
  'EUROMOBIL - SB Oberwäsche maschinell',
  'EUROMOBIL - Oberwäsche 1',
  'EUROMOBIL - Oberwäsche 2 / Kl. Reinigung',
  'EUROMOBIL - Oberwäsche 3'
);

-- ============================================================
-- Kontrol — kategorisiz kalan (unutulmuş) bir hizmet olmamalı,
-- bu sorgu BOŞ dönmeli:
-- select code, name from job_types where category is null;
--
-- Kategori dağılımını görmek için:
-- select category, count(*) from job_types group by category order by category;
-- ============================================================
