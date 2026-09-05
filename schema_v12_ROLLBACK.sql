-- ============================================================
-- ACİL DURUM: schema_v12_LOCK.sql'i geri alma
--
-- schema_v12_LOCK.sql'i uyguladıktan sonra bir şey bozulursa, bu dosyayı
-- çalıştırın — job_types/records/daily_hours/push_subscriptions'ı
-- schema_v10'daki bilinen-çalışan (anon key ile de erişilebilen) haline
-- ANINDA geri döndürür. Veri kaybı YOKTUR, sadece kim-ne-yapabilir
-- kuralları eski haline döner.
-- ============================================================

drop policy if exists "job_types_select" on job_types;
create policy "job_types_select" on job_types for select using (true);

drop policy if exists "records_select" on records;
create policy "records_select" on records for select using (true);

drop policy if exists "records_insert" on records;
create policy "records_insert" on records for insert with check (true);

drop policy if exists "records_delete_recent" on records;
create policy "records_delete_recent" on records for delete
  using (created_at > now() - interval '48 hours');

drop policy if exists "daily_hours_select" on daily_hours;
create policy "daily_hours_select" on daily_hours for select using (true);

drop policy if exists "daily_hours_insert" on daily_hours;
create policy "daily_hours_insert" on daily_hours for insert with check (true);

drop policy if exists "daily_hours_update_recent" on daily_hours;
create policy "daily_hours_update_recent" on daily_hours for update
  using (work_date >= current_date - 2)
  with check (work_date >= current_date - 2);

drop policy if exists "push_subscriptions_insert" on push_subscriptions;
create policy "push_subscriptions_insert" on push_subscriptions for insert with check (true);

drop policy if exists "push_subscriptions_update" on push_subscriptions;
create policy "push_subscriptions_update" on push_subscriptions for update using (true) with check (true);

-- ============================================================
-- Bitti — sistem schema_v10 seviyesindeki güvenliğe (herkes kendi
-- işini yapabilir ama sadece son 48 saat silme/güncelleme) döndü.
-- ============================================================
