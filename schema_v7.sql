-- ============================================================
-- Atölye İş Takip — v7 Şema Eklentisi
-- Bu dosyayı Supabase Dashboard > SQL Editor'e yapıştırıp "Run" tuşuna basın.
-- Var olan verileri SİLMEZ.
-- ============================================================

-- 1) ref_no sütunundaki NOT NULL kısıtını kesin olarak kaldırır.
-- Daha önce elle/manuel bir düzeltme denenmiş olabilir ama hata devam
-- ediyorsa kısıt hâlâ aktif demektir — bu satır garantiye alır.
alter table records alter column ref_no drop not null;

-- 2) Sayaç bazlı (+1 / adet) işlerin standart sürelerini günceller.
-- Bu süre çalışana gösterilmez, sadece şef panelindeki kapasite
-- hesabına girer. Birim fiyatlar değişmedi.
update job_types set duration_minutes = 13 where code = 'SW1';
update job_types set duration_minutes = 20 where code = 'SW2';
update job_types set duration_minutes = 8  where code = 'NW-Annahme';

-- ============================================================
-- Bitti. Kontrol için:
-- select code, duration_minutes, price_eur from job_types
-- where code in ('SW1','SW2','NW-Annahme');
-- ============================================================
