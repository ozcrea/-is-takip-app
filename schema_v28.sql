-- ============================================================
-- Atölye İş Takip — v28: Admin için records DÜZENLEME (update) yetkisi
--
-- records tablosunda şimdiye kadar HİÇ bir UPDATE politikası yoktu
-- (sadece insert/select/delete politikaları vardı) — yani kimse,
-- admin dahil, mevcut bir Auftrag kaydını düzenleyemiyordu.
--
-- Admin'in "Geçmişe Kayıt Ekle" panelinde artık bir çalışanın o güne
-- ait iş kayıtlarını (AKT-Nummer, varsa manuel fiyat, varsa Regiestunde
-- saati) düzenleyebilmesi için bu kural gerekiyor.
--
-- ÖNEMLİ NOT: RLS satır bazlı çalışır, HANGİ SÜTUNLARIN değiştirilebi-
-- leceğini kısıtlamaz. Yani teknik olarak bu kural, admin hesabının bir
-- kaydın herhangi bir alanını değiştirmesine izin verir — arayüz
-- sadece AKT/fiyat/saat alanlarını göstererek bunu pratikte sınırlar.
-- Normal çalışanlar için hiçbir şey değişmiyor (records için hâlâ
-- update yetkisi yok).
-- ============================================================

drop policy if exists "records_update_admin" on records;
create policy "records_update_admin" on records for update
  using (
    auth.role() = 'authenticated' and
    exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
  )
  with check (
    auth.role() = 'authenticated' and
    exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
  );

-- ============================================================
-- GERİ ALMAK İSTERSENİZ:
-- drop policy if exists "records_update_admin" on records;
-- ============================================================
