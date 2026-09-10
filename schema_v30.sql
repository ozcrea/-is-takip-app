-- ============================================================
-- Atölye İş Takip — v30: records silme kuralı, '48 saat' yerine
-- 'aynı takvim günü' (Europe/Berlin)
--
-- Önceki kural (records_delete_recent), bir çalışanın kendi kaydını
-- created_at'tan itibaren SON 48 SAAT içinde silebilmesine izin
-- veriyordu (rolling window). Karar değişikliği: artık kayıt sadece
-- OLUŞTURULDUĞU TAKVİM GÜNÜ (Europe/Berlin saatiyle) içinde silinebilir
-- — gece yarısını (Berlin saatiyle) geçtiği anda, o kayıt normal
-- çalışan için artık silinemez/düzenlenemez.
--
-- AT TIME ZONE 'Europe/Berlin' kullanımı, Postgres'in IANA saat dilimi
-- veritabanı üzerinden CET/CEST (kış/yaz saati) geçişini otomatik ve
-- doğru şekilde hesaplar — sabit bir +1/+2 ofset yazmaktan daha
-- güvenilir.
--
-- Admin yetkisi DEĞİŞMİYOR: is_admin=true olan hesap hâlâ herhangi bir
-- tarihe ait kaydı, gün sınırı olmaksızın silebilir.
-- ============================================================

drop policy if exists "records_delete_recent" on records;
create policy "records_delete_recent" on records for delete
  using (
    auth.role() = 'authenticated' and (
      (created_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date
      or exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
    )
  );

-- ============================================================
-- GERİ ALMAK İSTERSENİZ (eski, 48 saatlik rolling window davranışına
-- dönmek için):
--
-- drop policy if exists "records_delete_recent" on records;
-- create policy "records_delete_recent" on records for delete
--   using (
--     auth.role() = 'authenticated' and (
--       created_at > now() - interval '48 hours'
--       or exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
--     )
--   );
--
-- Kontrol (bugün ve dün oluşturulmuş birer test kaydıyla):
-- select id, created_at, (created_at at time zone 'Europe/Berlin')::date as berlin_date
-- from records order by created_at desc limit 5;
-- ============================================================
