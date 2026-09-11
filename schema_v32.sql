-- ============================================================
-- Atölye İş Takip — v32: "Text Aufbereitung" yeni hizmet tipi
--
-- Yeni bir serbest-metin, manuel-fiyat, manuel-süre iş tipi ekleniyor.
-- Çalışan bu işi seçtiğinde: ne yaptığını yazar (açıklama), fiyatı
-- kendisi girer, süreyi (dakika) kendisi girer. Üçü de zorunlu, AKT/
-- Fahrgestellnummer de (diğer işler gibi) zorunlu kalıyor.
--
-- YENİ SÜTUN: sadece "custom_description" gerekiyor — fiyat ve süre
-- için zaten var olan sütunlar (custom_price, custom_duration_minutes)
-- yeniden kullanılıyor; bunlar SR-Lack/SR-Delle/MTS-SR (fiyat) ve
-- Showroom Pflege (süre) için de aynı şekilde kullanılıyor, bu yüzden
-- yeni sütun eklemeye gerek yok.
-- ============================================================

alter table records add column if not exists custom_description text;

insert into job_types (
  code, name, price_eur, duration_minutes, is_mts, is_variable_price,
  is_quantity, is_aufbereitung, is_internal, requires_ref,
  allows_extra_arbeit, category, active, sort_order
)
values (
  'Text Aufbereitung',
  'Text Aufbereitung (manuell)',
  null,
  null,
  false,
  true,
  false,
  false,
  false,
  true,
  false,
  'Sonstiges',
  true,
  (select coalesce(max(sort_order), 0) + 1 from job_types)
);

-- ============================================================
-- Kontrol — yeni iş tipinin doğru eklendiğini görmek için:
-- select code, name, price_eur, duration_minutes, is_variable_price,
--   requires_ref, category from job_types where code = 'Text Aufbereitung';
-- ============================================================
