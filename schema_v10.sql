-- ============================================================
-- Atölye İş Takip — v10 Güvenlik Sıkılaştırma (RLS)
-- SADECE SİZ ONAYLADIKTAN SONRA Supabase SQL Editor'de çalıştırın.
-- Var olan verileri SİLMEZ, sadece kimin ne yapabileceğini kısıtlar.
--
-- ÖNEMLİ SINIRLAMA: Bu uygulamada gerçek bir Supabase Auth oturumu yok
-- (giriş tamamen tarayıcı tarafında kontrol ediliyor). Bu yüzden RLS,
-- "bu isteği gönderen hangi çalışan" ayrımını YAPAMAZ — SELECT tüm
-- tablolarda açık kalmak zorunda (hem çalışan günlük görünümü hem şef
-- paneli buna ihtiyaç duyuyor). Aşağıdaki değişiklikler riski şuna
-- indiriyor: "anon key'i ele geçiren biri en fazla son 48 saatteki
-- kayıtları silebilir/değiştirebilir, geçmişi toptan bozamaz, employees/
-- job_types tablolarına hiç yazamaz."
-- ============================================================

-- ---------- EMPLOYEES: sadece okuma ----------
alter table employees enable row level security;
drop policy if exists "employees_select" on employees;
create policy "employees_select" on employees for select using (true);
-- insert/update/delete için policy yok -> RLS açıkken varsayılan: tamamen kapalı

-- ---------- JOB_TYPES: sadece okuma ----------
alter table job_types enable row level security;
drop policy if exists "job_types_select" on job_types;
create policy "job_types_select" on job_types for select using (true);
-- insert/update/delete: kapalı

-- ---------- RECORDS: okuma + ekleme + son 48 saat silme ----------
alter table records enable row level security;

drop policy if exists "records_select" on records;
create policy "records_select" on records for select using (true);

drop policy if exists "records_insert" on records;
create policy "records_insert" on records for insert with check (true);

drop policy if exists "records_delete_recent" on records;
create policy "records_delete_recent" on records for delete
  using (created_at > now() - interval '48 hours');
-- update: kapalı (uygulama records'ta hiç update kullanmıyor)

-- ---------- DAILY_HOURS: okuma + ekleme + son 48 saat güncelleme ----------
alter table daily_hours enable row level security;

drop policy if exists "daily_hours_select" on daily_hours;
create policy "daily_hours_select" on daily_hours for select using (true);

drop policy if exists "daily_hours_insert" on daily_hours;
create policy "daily_hours_insert" on daily_hours for insert with check (true);

drop policy if exists "daily_hours_update_recent" on daily_hours;
create policy "daily_hours_update_recent" on daily_hours for update
  using (work_date >= current_date - 2)
  with check (work_date >= current_date - 2);
-- delete: kapalı (uygulama daily_hours'ta hiç delete kullanmıyor)

-- ---------- PUSH_SUBSCRIPTIONS: sadece ekleme/güncelleme ----------
alter table push_subscriptions enable row level security;

-- v9'da yazdığımız eski gevşek "for all" kuralını kaldırıyoruz
drop policy if exists "push_subscriptions_all" on push_subscriptions;

drop policy if exists "push_subscriptions_insert" on push_subscriptions;
create policy "push_subscriptions_insert" on push_subscriptions for insert with check (true);

drop policy if exists "push_subscriptions_update" on push_subscriptions;
create policy "push_subscriptions_update" on push_subscriptions for update using (true) with check (true);
-- select/delete: kapalı — istemci bunları hiç kullanmıyor; Edge Function zaten
-- service role key ile çalışıyor ve RLS'i otomatik bypass ediyor (etkilenmez).

-- ============================================================
-- Bitti. Kontrol için:
-- select tablename, rowsecurity from pg_tables where schemaname='public';
-- select tablename, policyname, cmd from pg_policies where schemaname='public' order by tablename;
-- ============================================================
