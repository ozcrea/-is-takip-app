-- ============================================================
-- Atölye İş Takip — v27: Admin için records silme yetkisini genişlet
--
-- Admin'in "Geçmişe Kayıt Ekle" formunda artık seçilen çalışan+tarih
-- için o güne ait Auftrag (records) kayıtlarını görüntüleme/silme ve
-- "Bu günü tamamen temizle" (o güne ait tüm records + daily_hours)
-- özelliği var. Ama mevcut records silme kuralı (records_delete_recent)
-- sadece created_at'ı SON 48 SAAT içinde olan kayıtların silinmesine
-- izin veriyor — admin'in haftalar/aylar önce geriye dönük eklenmiş
-- bir kaydı silmesi bu yüzden engelleniyordu.
--
-- Bu SQL, schema_v14_ADMIN_DELETE.sql ile TAMAMEN AYNI politikayı
-- (idempotent — daha önce çalıştırılmış olsa da tekrar çalıştırmak
-- güvenli, sonuç değişmez) yeniden uygular: employees.is_admin=true
-- olan hesap (gizli admin hesabınız) için 48 saatlik sınırı kaldırır.
-- Normal çalışanlar için davranış AYNI KALIR — hâlâ sadece kendi son
-- 48 saatteki kaydını silebilir.
-- ============================================================

drop policy if exists "records_delete_recent" on records;
create policy "records_delete_recent" on records for delete
  using (
    auth.role() = 'authenticated' and (
      created_at > now() - interval '48 hours'
      or exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
    )
  );

-- ============================================================
-- GERİ ALMAK İSTERSENİZ (sadece son-48-saat davranışına dönmek için):
--
-- drop policy if exists "records_delete_recent" on records;
-- create policy "records_delete_recent" on records for delete
--   using (auth.role() = 'authenticated' and created_at > now() - interval '48 hours');
-- ============================================================
