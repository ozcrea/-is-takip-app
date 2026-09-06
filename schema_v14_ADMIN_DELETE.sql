-- ============================================================
-- Atölye İş Takip — v14b: Admin için 48 saatlik silme sınırını kaldırma
-- (İSTEĞE BAĞLI — lütfen çalıştırmadan önce okuyun)
--
-- NEDEN GEREKLİ: Admin, "Geçmişe Kayıt Ekle" ile GEÇMİŞ bir tarihe kayıt
-- eklediğinde, o kaydın created_at değeri geçmişte olacak. Mevcut silme
-- kuralı (schema_v12_LOCK.sql) sadece "created_at son 48 saat içinde"
-- olan kayıtların silinmesine izin veriyor. Yani admin, geriye dönük
-- eklediği bir kaydı YANLIŞ girdiyse (örn. yanlış tarih/tutar), bu kaydı
-- normal şekilde SİLEMEZ — çünkü created_at zaten 48 saatten eski.
--
-- BU DOSYA NE YAPAR: Sadece employees.is_admin = true olan hesabın
-- (yani sizin gizli admin hesabınızın) created_at'a bakmaksızın HER
-- KAYDI silebilmesini sağlar. Normal çalışanlar için hiçbir şey
-- değişmez — onlar hâlâ sadece son 48 saatteki kendi kayıtlarını
-- silebilir (mevcut davranış aynen korunuyor).
--
-- RİSK: Bu, admin hesabına (sizin hesabınıza) sınırsız silme yetkisi
-- verir — yanlışlıkla eski/başka bir çalışanın kaydını silme riski,
-- admin hesabının şifresi/erişimi başka biriyle paylaşılırsa kötüye
-- kullanılma riski. Sadece SİZ (admin hesabına erişimi olan) bu riski
-- kabul ediyorsanız çalıştırın.
-- ============================================================

drop policy if exists "records_delete_recent" on records;
create policy "records_delete_recent" on records for delete
  using (
    auth.role() = 'authenticated' and (
      created_at > now() - interval '48 hours'
      or exists (
        select 1 from employees e
        where e.auth_user_id = auth.uid() and e.is_admin = true
      )
    )
  );

-- ============================================================
-- GERİ ALMAK İSTERSENİZ (eski, sadece-48-saat davranışına dönmek için):
--
-- drop policy if exists "records_delete_recent" on records;
-- create policy "records_delete_recent" on records for delete
--   using (auth.role() = 'authenticated' and created_at > now() - interval '48 hours');
-- ============================================================
