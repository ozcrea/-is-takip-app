-- schema_v35.sql
-- 1) Regiestunde artık AKT/Şasi no zorunlu (requires_ref=true).
--    Mevcut 2 kayıt ref_no=NULL olarak kalır (geriye dönük bozulma yok,
--    NOT NULL constraint EKLENMİYOR — sadece UI validasyonu bu bayrağı okur).
UPDATE job_types SET requires_ref = true WHERE code = 'Regiestunde';

-- 2) Extra Arbeit 3. ve 4. opsiyonel slot için yeni nullable kolonlar.
--    Mevcut extra_arbeit_1_code/2_code/price/minutes hiç dokunulmuyor.
ALTER TABLE records ADD COLUMN IF NOT EXISTS extra_arbeit_3_code text;
ALTER TABLE records ADD COLUMN IF NOT EXISTS extra_arbeit_4_code text;
