-- ============================================================
-- Atölye İş Takip — v23: Admin için daily_hours düzenleme/silme
-- yetkisi (Item 1)
--
-- NEDEN GEREKLİ: Admin'in "Geçmişe Kayıt Ekle" formunda artık seçilen
-- çalışan+tarih için daily_hours (saat+şube) görüntüleme/ekleme/
-- düzenleme/silme arayüzü var. Ama mevcut RLS kuralları buna izin
-- vermiyordu:
--   - daily_hours_update_recent: sadece work_date >= bugün-2 olan
--     kayıtların GÜNCELLENMESİNE izin veriyordu (geçmiş bir günün
--     saatini düzeltmek imkansızdı).
--   - daily_hours için hiçbir DELETE politikası YOKTU (silme her
--     zaman reddediliyordu).
--
-- BU DOSYA NE YAPAR (schema_v14_ADMIN_DELETE.sql ile AYNI DESEN):
--   1) daily_hours_update_recent: work_date sınırını, employees.is_admin
--      = true olan hesap (gizli admin hesabınız) için tamamen kaldırır.
--      Normal çalışanlar için davranış AYNI KALIR — hâlâ sadece son 2
--      günün saatini kendileri değiştirebilir.
--   2) YENİ bir daily_hours_delete_admin politikası ekler — SADECE
--      is_admin=true olan hesap daily_hours kaydı silebilir. Normal
--      çalışanlar hiçbir zaman kendi daily_hours kaydını silemez
--      (zaten öyleydi, bu davranış değişmiyor).
--
-- RİSK: schema_v14_ADMIN_DELETE.sql'deki ile aynı — admin hesabına
-- (sizin hesabınıza) sınırsız düzenleme/silme yetkisi verir. Sadece
-- admin hesabının erişimine güveniyorsanız çalıştırın.
-- ============================================================

drop policy if exists "daily_hours_update_recent" on daily_hours;
create policy "daily_hours_update_recent" on daily_hours for update
  using (
    auth.role() = 'authenticated' and (
      work_date >= current_date - 2
      or exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
    )
  )
  with check (
    auth.role() = 'authenticated' and (
      work_date >= current_date - 2
      or exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
    )
  );

drop policy if exists "daily_hours_delete_admin" on daily_hours;
create policy "daily_hours_delete_admin" on daily_hours for delete
  using (
    auth.role() = 'authenticated' and
    exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
  );

-- ============================================================
-- GERİ ALMAK İSTERSENİZ (eski, sadece-son-2-gün + hiç silme yok
-- davranışına dönmek için):
--
-- drop policy if exists "daily_hours_update_recent" on daily_hours;
-- create policy "daily_hours_update_recent" on daily_hours for update
--   using (auth.role() = 'authenticated' and work_date >= current_date - 2)
--   with check (auth.role() = 'authenticated' and work_date >= current_date - 2);
--
-- drop policy if exists "daily_hours_delete_admin" on daily_hours;
-- ============================================================
