-- ============================================================
-- Atölye İş Takip — v8 Şema Eklentisi
-- Bu dosyayı Supabase Dashboard > SQL Editor'e yapıştırıp "Run" tuşuna basın.
-- Var olan verileri SİLMEZ, sadece "Audi" filyal adını "Ausschläger Weg"
-- olarak günceller (job_types içindeki "Neuwagen Flatrate (Audi)" gibi
-- Audi marka isimlerine dokunmaz, sadece daily_hours.branch alanını düzeltir).
-- ============================================================

update daily_hours set branch = 'Ausschläger Weg' where branch = 'Audi';

-- ============================================================
-- Bitti. Kontrol için:
-- select distinct branch from daily_hours;
-- ============================================================
