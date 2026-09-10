-- ============================================================
-- Atölye İş Takip — v25: "Regiestunde" genel listeye eklensin (Madde 1)
--
-- Regiestunde artık, FOTOSERVICE gibi, genel "Neuen Auftrag hinzufügen"
-- listesinde DOĞRUDAN seçilebilir bir hizmet. Seçildiğinde kaç saat
-- olduğu elle (manuel) girilir. Fiyat ve iş süresi, mevcut "Regiestunde
-- Aufbereitung" ek alanıyla TAM AYNI formülü kullanır (bkz. index.html
-- recordPrice() ve workedMinutes hesaplaması):
--   fiyat  = girilen_saat × 33.28 €  (REGIESTUNDE_RATE)
--   süre   = girilen_saat × 60 dakika
-- Bunu price_eur=0 ve duration_minutes=0 ile sağlıyoruz — asıl değer,
-- kayıttaki mevcut "regiestunde" sütununa (girilen saat) yazılıyor,
-- recordPrice() zaten bunu otomatik hesaba katıyor. Yeni bir sütun
-- GEREKMİYOR.
-- ============================================================

insert into job_types (code, name, price_eur, duration_minutes, is_mts, is_variable_price, is_quantity, is_aufbereitung, is_internal, requires_ref, allows_extra_arbeit, category, active, sort_order)
values (
  'Regiestunde',
  'Regiestunde (manuell)',
  0,
  0,
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  'Sonstiges',
  true,
  (select coalesce(max(sort_order), 0) + 1 from job_types)
);

-- Kontrol:
-- select code, price_eur, duration_minutes, requires_ref, category from job_types where code = 'Regiestunde';
