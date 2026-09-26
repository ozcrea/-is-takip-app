-- ============================================================
-- schema_v37.sql — Push-Mitteilungen: Chef / Mitarbeiter trennen
-- ============================================================
-- Zweck:
--   push_subscriptions bekommt eine Zielgruppe (audience):
--     'boss' = Chef/Admin-Geräte  → bekommen weiterhin den 17:45 Tagesbericht
--     'emp'  = Mitarbeiter-Geräte → bekommen NUR Mitteilungen (z. B. Updates),
--                                   NIE den Tagesbericht mit Umsatz
--
-- Sicherheit / Auswirkungen:
--   * Es werden nur ZWEI Spalten hinzugefügt — keine Daten gelöscht/geändert.
--   * Alle bestehenden Geräte bekommen automatisch audience = 'boss'
--     → der tägliche 17:45-Bericht läuft für sie genau wie bisher weiter.
--   * RLS-Regeln bleiben unverändert (insert/update nur für angemeldete
--     Benutzer, select/delete nur über die Edge Function / Service Role).
--   * Kann mehrfach ausgeführt werden (if not exists).
--
-- Reihenfolge: ZUERST diese Datei ausführen, DANACH die Edge Functions
-- (daily-report, send-announcement) und die App aktualisieren.
-- ============================================================

alter table push_subscriptions
  add column if not exists audience text not null default 'boss';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'push_subscriptions_audience_check'
  ) then
    alter table push_subscriptions
      add constraint push_subscriptions_audience_check
      check (audience in ('boss', 'emp'));
  end if;
end $$;

alter table push_subscriptions
  add column if not exists employee_id uuid references employees(id) on delete set null;

-- ============================================================
-- Kontrolle (danach ausführen): alle bestehenden Geräte = 'boss'
--   select audience, count(*) from push_subscriptions group by audience;
--
-- Rückgängig machen (nur falls nötig, keine Datenverluste an anderen Tabellen):
--   alter table push_subscriptions drop column if exists employee_id;
--   alter table push_subscriptions drop constraint if exists push_subscriptions_audience_check;
--   alter table push_subscriptions drop column if exists audience;
-- ============================================================
