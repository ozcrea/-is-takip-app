-- ============================================================
-- Atölye İş Takip — v6 Şema Eklentisi
-- Bu dosyayı Supabase Dashboard > SQL Editor'e yapıştırıp "Run" tuşuna basın.
-- Var olan verileri SİLMEZ, sadece yeni bir kolon ekler.
-- ============================================================

-- Smart Repair (Delle) kayıtlarında işi kimin yaptığını tutan kolon.
-- Diğer iş tiplerinde her zaman null kalır.
alter table records add column if not exists performed_by text;

-- ============================================================
-- Bitti. Kontrol için:
-- select r.created_at, jt.code, r.performed_by
-- from records r join job_types jt on jt.id = r.job_type_id
-- where jt.code = 'SR-Delle' order by r.created_at desc limit 20;
-- ============================================================
