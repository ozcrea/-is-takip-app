-- ============================================================
-- Atölye İş Takip — v34: Gün sonu bildirim saatini 17:30 → 17:45'e kaydır
--
-- schema_v9.sql'deki iki pg_cron görevi (CEST/CET için 15:30 ve 16:30 UTC)
-- 15 dakika ileri alınıyor: 15:45 ve 16:45 UTC. Eski işler önce
-- unschedule ediliyor (aksi halde İKİSİ DE aktif kalır ve hem eski hem
-- yeni saatte bildirim gider) — sonra YENİ isimlerle (saatlerini
-- yansıtacak şekilde) yeniden oluşturuluyor.
--
-- Edge Function'ın kendi iç saat penceresi (17:25–17:39 → 17:40–17:54)
-- AYRICA index.ts'de güncellenmeli — bu SQL SADECE cron tarafını
-- değiştirir, ikisi birlikte deploy edilmezse bildirim hiç gitmez
-- (cron yeni saatte tetikler ama fonksiyon hâlâ eski pencereyi
-- bekleyip "skipped" döner).
-- ============================================================

select cron.unschedule('daily-report-1530-utc');
select cron.unschedule('daily-report-1630-utc');

select cron.schedule(
  'daily-report-1545-utc',
  '45 15 * * *',
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
  'daily-report-1645-utc',
  '45 16 * * *',
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
-- Kontrol — sadece iki YENİ işin (1545/1645) listelendiğini, eski
-- 1530/1630 işlerinin artık görünmediğini doğrulamak için:
-- select jobid, jobname, schedule, active from cron.job
-- where jobname like 'daily-report%';
-- ============================================================
