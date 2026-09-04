-- ============================================================
-- Atölye İş Takip — v9 Şema Eklentisi: Otomatik Gün Sonu Bildirimi
-- Bu dosyayı Supabase Dashboard > SQL Editor'e yapıştırıp "Run" tuşuna basın.
-- Var olan verileri SİLMEZ.
-- ============================================================

-- 1) Şefin tarayıcı push aboneliklerini tutan tablo (birden fazla cihaz olabilir).
create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  endpoint text unique not null,
  p256dh text not null,
  auth text not null,
  created_at timestamptz default now()
);

alter table push_subscriptions enable row level security;

-- Uygulamanın geri kalanıyla tutarlı: RLS şu an gevşek (bkz. güvenlik
-- sıkılaştırma maddesi, ileride ele alınacak). Şimdilik anon key ile
-- ekleme/okuma/silme serbest.
drop policy if exists "push_subscriptions_all" on push_subscriptions;
create policy "push_subscriptions_all" on push_subscriptions
  for all using (true) with check (true);

-- 2) Zamanlanmış görev için gerekli eklentiler.
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 3) Her gün İKİ farklı UTC saatinde (15:30 ve 16:30 UTC) Edge Function'ı
-- tetikler. Bu, Almanya'nın yaz/kış saati değişimini (CEST/CET) elle takip
-- etmenize gerek kalmadan otomatik doğru çalışması için kasıtlı bir çözüm:
-- Edge Function içindeki kod, Berlin saatiyle gerçekten 17:30 civarı mı diye
-- kendi kontrolünü yapıyor, değilse sessizce hiçbir şey yapmadan çıkıyor.
-- Yani biri her zaman doğru saatte "gerçek" tetiklemeyi yapar, diğeri no-op olur.
--
-- ÖNEMLİ: Aşağıdaki URL'deki YOUR-ANON-KEY yerine gerçek anon key'inizi
-- (bu dosyanın başında da kullandığımız sb_publishable_... anahtarı) yazın.
select cron.schedule(
  'daily-report-1530-utc',
  '30 15 * * *',
  $$
  select net.http_post(
    url := 'https://mfgofccidwmrqlyjbsvz.supabase.co/functions/v1/daily-report',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_n5PXoej2lr_FQQVCjag0jw_EifWkYir'
    ),
    body := '{}'::jsonb
  );
  $$
);

select cron.schedule(
  'daily-report-1630-utc',
  '30 16 * * *',
  $$
  select net.http_post(
    url := 'https://mfgofccidwmrqlyjbsvz.supabase.co/functions/v1/daily-report',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_n5PXoej2lr_FQQVCjag0jw_EifWkYir'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- ============================================================
-- Bitti. Kontrol için:
-- select * from cron.job;
-- select * from push_subscriptions;
-- ============================================================
