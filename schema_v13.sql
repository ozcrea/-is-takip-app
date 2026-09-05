-- ============================================================
-- Atölye İş Takip — v13: Fotoservice eklentisi
-- Bu dosyayı Supabase SQL Editor'de çalıştırın.
-- Var olan verileri SİLMEZ, sadece yeni bir kolon ekler (varsayılan: false).
-- ============================================================

alter table records add column if not exists fotoservice boolean not null default false;

-- ============================================================
-- Bitti. Kontrol için:
-- select column_name, data_type, column_default from information_schema.columns
-- where table_name = 'records' and column_name = 'fotoservice';
-- ============================================================
