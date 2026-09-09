-- ============================================================
-- Atölye İş Takip — v22: Fotoservice'i genel listeye ve
-- Extra Arbeit seçeneklerine ekle (Item 5)
--
-- Şu ana kadar FOTOSERVICE bir "iç" (is_internal=true) iş tipiydi —
-- sadece GW-A/GW-B/GW-FR/VFW-W1/VFW-W2 işlerindeki "Fotoservice: Ja"
-- seçeneği tetiklendiğinde arka planda otomatik oluşturuluyordu.
--
-- Bu güncelleme ile FOTOSERVICE artık:
--   1) "Neuen Auftrag hinzufügen" genel listesinde DOĞRUDAN seçilebilir
--      bir hizmet olarak görünecek (is_internal=false),
--   2) AKT/Fahrgestellnummer girilmesi ZORUNLU olmayacak — Showroom
--      Pflege/EUROMOBIL ile aynı mantık (requires_ref=false).
--
-- Fiyatı hâlâ şubeye göre değişken (is_variable_price=true, zaten
-- schema_v15.sql'de ayarlanmıştı) ve ödeme her zaman index.html'deki
-- BRANCH_FOTOSERVICE_OWNER üzerinden o günkü şubenin sabit sorumlusuna
-- (A3A/W1S/H1A) yazılıyor — hangi yoldan seçilirse seçilsin (doğrudan
-- genel listeden, bir işin "Fotoservice: Ja" toggle'ından, ya da bir
-- işin Extra Arbeit seçeneği olarak), asla girenin kendi kaydına değil.
-- Bu mantık koddadır (insertJobRecord), bu dosya sadece görünürlük ve
-- AKT zorunluluğu bayraklarını günceller.
-- ============================================================

update job_types set is_internal = false, requires_ref = false where code = 'FOTOSERVICE';

-- Kontrol:
-- select code, is_internal, requires_ref, is_variable_price, allows_extra_arbeit
-- from job_types where code = 'FOTOSERVICE';
