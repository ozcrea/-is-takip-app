-- ============================================================
-- Atölye İş Takip — v20: NW-Sys düzeltmesi (sağlamlaştırılmış),
-- Neuwagen Flatrate 2 (VW) süresi, Kundenpaket/Luxus paketleri
-- ============================================================

-- ============================================================
-- 1) NW-Sys HÂLÂ EKSİK — schema_v19.sql'deki "=" (tam/case-sensitive
--    eşleşme) tutmamış olabilir (büyük/küçük harf ya da görünmeyen
--    boşluk farkı ihtimaline karşı). Bu sefer "ilike" + trim ile,
--    büyük/küçük harf ve baştaki/sondaki boşluklardan bağımsız olarak
--    eşleştiriyoruz:
update job_types set allows_extra_arbeit = true, is_aufbereitung = true
where trim(code) ilike 'NW-Sys';

-- Kontrol (LÜTFEN ÇALIŞTIRIP SONUCU PAYLAŞIN):
-- select code, allows_extra_arbeit, is_aufbereitung from job_types where trim(code) ilike 'NW-Sys';
--
-- Eğer bu da 0 satır dönerse, kodun gerçek yazılışını görmek için:
-- select code, length(code) from job_types where code ilike '%sys%' or code ilike '%NW%';


-- ============================================================
-- 2) 'Neuwagen Flatrate 2 (VW)' süresi NULL — 60 dakika olarak ayarla:
update job_types set duration_minutes = 60 where code = 'Neuwagen Flatrate 2 (VW)';

-- Kontrol:
-- select code, price_eur, duration_minutes from job_types where code = 'Neuwagen Flatrate 2 (VW)';


-- ============================================================
-- 3) Kundenpaket / Luxus paketlerine de Extra Arbeit + Extra Stunde ekle.
--    Gerçek kod adlarını bilmediğim için geniş bir desenle yakalıyorum
--    ("Komfort", "Luxus" geçen veya "KP-" ile başlayan her şey). Hem
--    allows_extra_arbeit hem is_aufbereitung true yapılıyor.
update job_types set allows_extra_arbeit = true, is_aufbereitung = true
where code ilike '%Komfort%' or code ilike '%Luxus%' or code ilike 'KP-%';

-- KONTROL — LÜTFEN ÇALIŞTIRIP SONUCU PAYLAŞIN (hangi paketlerin
-- gerçekten yakalandığını bu listeden göreceğiz):
-- select code, price_eur, is_variable_price, allows_extra_arbeit, is_aufbereitung
-- from job_types
-- where code ilike '%Komfort%' or code ilike '%Luxus%' or code ilike 'KP-%'
-- order by code;
-- ============================================================
