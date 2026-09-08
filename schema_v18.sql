-- ============================================================
-- Atölye İş Takip — v18: Aynı 10 hizmete Regiestunde (Extra Stunde)
-- alanını da ekle (is_aufbereitung = true)
--
-- schema_v17.sql'deki AYNI desen kullanılıyor (tutarlılık için) —
-- Extra Arbeit'i işaretlediğimiz 10 hizmetin hepsine is_aufbereitung=true
-- ekleniyor. Bu, index.html'de zaten var olan "Regiestunde Aufbereitung"
-- dropdown'ını tetikliyor — kod tarafında hiçbir değişiklik gerekmiyor,
-- sadece bu bayrak true olan hizmetlerde otomatik çıkıyor.
--
-- Sonuç: bu 10 hizmette hem Extra Arbeit (2'ye kadar ek hizmet) hem de
-- Regiestunde (Extra Stunde, saat başına ek ücret) birlikte kullanılabilir.
-- ============================================================

update job_types set is_aufbereitung = true
where (
  code ilike '%Neuwagen%'
  or code ilike '%NW Systempflege%'
  or code ilike '%GW-Ausl%'
  or code ilike '%Ausl-NW1%'
  or code ilike '%Ausl-NW2%'
  or code ilike '%Auslieferungsfinish%'
)
and is_variable_price = false;

-- ============================================================
-- KONTROL — lütfen bunu YORUMSUZ, ayrıca çalıştırıp sonucu bana
-- gönderin (bir önceki schema_v17.sql'in de gerçekten eşleşip
-- eşleşmediğini bu sorgu netleştirecek):
--
-- select code, price_eur, is_variable_price, allows_extra_arbeit, is_aufbereitung
-- from job_types
-- where code ilike '%Neuwagen%' or code ilike '%NW Systempflege%'
--    or code ilike '%GW-Ausl%' or code ilike '%Ausl-NW1%' or code ilike '%Ausl-NW2%'
--    or code ilike '%Auslieferungsfinish%'
-- order by code;
--
-- Beklenen: 10 satır, hepsinde allows_extra_arbeit = true VE
-- is_aufbereitung = true olmalı.
-- ============================================================
