-- ============================================================
-- Atölye İş Takip — v26: daily_hours silme yetkisini çalışana da aç (Madde 4)
--
-- schema_v23.sql'de daily_hours için SADECE admin'e silme izni veren
-- "daily_hours_delete_admin" politikası eklenmişti. Bu, normal bir
-- çalışanın (örn. W3) kendi BUGÜNKÜ yanlış saat/şube kaydını kendisinin
-- silmesini hâlâ engelliyordu — çünkü daily_hours için hiçbir zaman
-- "kendi kaydını sil" politikası olmamıştı (records tablosundaki 48
-- saatlik kendi-kaydını-silme kuralının bir eşdeğeri hiç yoktu).
--
-- BU DOSYA NE YAPAR: "daily_hours_delete_admin" politikasını kaldırıp
-- yerine, mevcut "kendi saatini son 2 gün içinde düzenleyebilme" kuralıyla
-- (daily_hours_update_recent) TUTARLI yeni bir "daily_hours_delete"
-- politikası koyar:
--   - Bir çalışan, KENDİ daily_hours kaydını, work_date bugünden en
--     fazla 2 gün öncesiyse silebilir (Ändern ile düzenleyebildiği aynı
--     pencere).
--   - Admin hesabı, work_date sınırı olmadan HERHANGİ BİR çalışanın
--     kaydını silebilir (schema_v23'teki gibi).
-- ============================================================

drop policy if exists "daily_hours_delete_admin" on daily_hours;
drop policy if exists "daily_hours_delete" on daily_hours;
create policy "daily_hours_delete" on daily_hours for delete
  using (
    auth.role() = 'authenticated' and (
      (
        work_date >= current_date - 2
        and employee_id in (select id from employees where auth_user_id = auth.uid())
      )
      or exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
    )
  );

-- ============================================================
-- GERİ ALMAK İSTERSENİZ (sadece admin silebilsin, kendi kaydını
-- kimse silemesin davranışına dönmek için):
--
-- drop policy if exists "daily_hours_delete" on daily_hours;
-- create policy "daily_hours_delete_admin" on daily_hours for delete
--   using (
--     auth.role() = 'authenticated' and
--     exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
--   );
-- ============================================================
