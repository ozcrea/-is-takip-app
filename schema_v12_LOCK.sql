-- ============================================================
-- Atölye İş Takip — v12: RLS'i GERÇEK AUTH'A KİLİTLEME (Adım 7)
--
-- ⚠️ BU DOSYAYI HENÜZ ÇALIŞTIRMAYIN ⚠️
-- Bu, planın en riskli adımı. Sadece inceleme/onay için hazırlandı.
--
-- ÖN KOŞUL (ZORUNLU) — bu SQL'i çalıştırmadan ÖNCE şunu SQL Editor'de
-- çalıştırıp SONUCU kontrol edin:
--
--   select akt_no, auth_user_id from employees;
--
-- Eğer TEK BİR SATIRDA BİLE auth_user_id boşsa (NULL), bu SQL'i ÇALIŞTIRMAYIN.
-- O çalışan, migrate-employees fonksiyonu ile Auth'a taşınmadan bu kilit
-- uygulanırsa, giriş ekranını geçebilir ama ardından hiçbir işlemi
-- (kayıt ekleme, saat kaydetme, iş listesini görme) YAPAMAZ hale gelir —
-- çünkü onun oturumu gerçek bir Supabase Auth oturumu değil, hâlâ eski
-- (anon key ile) geçici sistemdedir.
--
-- Tüm satırlarda auth_user_id doluysa, bu SQL güvenle çalıştırılabilir.
-- ============================================================

-- job_types: artık sadece giriş yapmış biri okuyabilir
-- (job listesi zaten sadece giriş ekranından sonra gösteriliyor)
drop policy if exists "job_types_select" on job_types;
create policy "job_types_select" on job_types for select
  using (auth.role() = 'authenticated');

-- records
drop policy if exists "records_select" on records;
create policy "records_select" on records for select
  using (auth.role() = 'authenticated');

drop policy if exists "records_insert" on records;
create policy "records_insert" on records for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "records_delete_recent" on records;
create policy "records_delete_recent" on records for delete
  using (auth.role() = 'authenticated' and created_at > now() - interval '48 hours');

-- daily_hours
drop policy if exists "daily_hours_select" on daily_hours;
create policy "daily_hours_select" on daily_hours for select
  using (auth.role() = 'authenticated');

drop policy if exists "daily_hours_insert" on daily_hours;
create policy "daily_hours_insert" on daily_hours for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "daily_hours_update_recent" on daily_hours;
create policy "daily_hours_update_recent" on daily_hours for update
  using (auth.role() = 'authenticated' and work_date >= current_date - 2)
  with check (auth.role() = 'authenticated' and work_date >= current_date - 2);

-- push_subscriptions
drop policy if exists "push_subscriptions_insert" on push_subscriptions;
create policy "push_subscriptions_insert" on push_subscriptions for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "push_subscriptions_update" on push_subscriptions;
create policy "push_subscriptions_update" on push_subscriptions for update
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- NOT: employees tablosunun SELECT politikası BİLEREK değiştirilmiyor
-- (using(true) olarak kalıyor) — çünkü giriş ekranındaki isim listesi
-- (dropdown), kullanıcı HENÜZ giriş yapmadan önce gösterilmek zorunda.
-- Bu listede sadece isim/kullanıcı adı var, şifre zaten ayrı bir
-- güvenlik konusu (bkz. önceki "employees şifre görünürlüğü" notu).

-- ============================================================
-- Uyguladıktan HEMEN SONRA test edin (bkz. ayrıca gönderdiğim test listesi):
-- 1. Yeni bir çalışanla (auth_user_id dolu) giriş yapıp kayıt ekleyin.
-- 2. Şef panelini açın, tüm veriler görünüyor mu kontrol edin.
-- 3. Bir sorun varsa HEMEN schema_v12_ROLLBACK.sql'i çalıştırın.
-- ============================================================
