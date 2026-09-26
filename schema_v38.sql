-- ============================================================
-- schema_v38.sql — Standort/Vorarbeiter vorbereiten + "wer hat eingetragen"
-- ============================================================
-- NUR ERGÄNZUNGEN — kein bestehendes Verhalten ändert sich:
--   * keine Regel (Policy) wird gelöscht oder geändert
--   * keine bestehenden Daten werden verändert (außer lead_branch für
--     genau 3 Konten: A3A, W1S, H1A)
--   * die App funktioniert vorher und nachher identisch
--
-- Inhalt:
--   1) Hilfsfunktionen (werden ab v39 von den neuen Regeln benutzt)
--   2) employees.lead_branch  → Vorarbeiter einer Filiale (Standort-Login)
--   3) records.entered_by / daily_hours.entered_by → wer hat eingetragen
--      (wird AUTOMATISCH vom Server gesetzt, kann nicht gefälscht werden)
--   4) A3A = Ausschläger Weg, W1S = Wiesendamm, H1A = Horn
--
-- Kann mehrfach ausgeführt werden. Rückgängig machen: siehe Ende der Datei.
-- ============================================================

-- 1) Hilfsfunktionen -----------------------------------------------------

-- Heutiges Datum in Europe/Berlin (nie UTC — siehe CLAUDE.md §5)
create or replace function public.app_berlin_today()
returns date
language sql
stable
set search_path = public
as $$
  select (now() at time zone 'Europe/Berlin')::date
$$;

-- Aktiver Mitarbeiter des angemeldeten Benutzers (null wenn nicht angemeldet
-- oder deaktiviert). security definer: liest employees unabhängig von RLS,
-- gibt aber NUR die eigene id zurück.
create or replace function public.app_current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from employees
  where auth_user_id = auth.uid() and active = true
  limit 1
$$;

revoke all on function public.app_current_employee_id() from public;
grant execute on function public.app_current_employee_id() to anon, authenticated, service_role;
grant execute on function public.app_berlin_today() to anon, authenticated, service_role;

-- 2) Vorarbeiter-Zuordnung ----------------------------------------------

alter table employees add column if not exists lead_branch text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'employees_lead_branch_check') then
    alter table employees
      add constraint employees_lead_branch_check
      check (lead_branch is null or lead_branch in ('Ausschläger Weg', 'Wiesendamm', 'Horn'));
  end if;
end $$;

-- 3) "Wer hat eingetragen" ----------------------------------------------

alter table records     add column if not exists entered_by uuid references employees(id) on delete set null;
alter table daily_hours add column if not exists entered_by uuid references employees(id) on delete set null;

-- Setzt entered_by IMMER serverseitig auf den angemeldeten Benutzer —
-- ein vom Browser mitgeschickter Wert wird überschrieben (nicht fälschbar).
-- Bei Server-Funktionen (Service Role, kein Benutzer) bleibt es null.
create or replace function public.app_set_entered_by()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.entered_by := public.app_current_employee_id();
  return new;
end
$$;

drop trigger if exists records_set_entered_by on records;
create trigger records_set_entered_by
  before insert on records
  for each row execute function public.app_set_entered_by();

drop trigger if exists daily_hours_set_entered_by on daily_hours;
create trigger daily_hours_set_entered_by
  before insert or update on daily_hours
  for each row execute function public.app_set_entered_by();

-- 4) Vorarbeiter festlegen ----------------------------------------------

update employees set lead_branch = 'Ausschläger Weg' where akt_no = 'A3A';
update employees set lead_branch = 'Wiesendamm'      where akt_no = 'W1S';
update employees set lead_branch = 'Horn'            where akt_no = 'H1A';

-- ============================================================
-- Kontrolle (danach ausführen) — erwartet: 3 Zeilen A3A/H1A/W1S
--   select akt_no, lead_branch from employees where lead_branch is not null order by akt_no;
--
-- Rückgängig machen (nur falls nötig):
--   drop trigger if exists records_set_entered_by on records;
--   drop trigger if exists daily_hours_set_entered_by on daily_hours;
--   drop function if exists public.app_set_entered_by();
--   alter table records drop column if exists entered_by;
--   alter table daily_hours drop column if exists entered_by;
--   alter table employees drop constraint if exists employees_lead_branch_check;
--   alter table employees drop column if exists lead_branch;
--   drop function if exists public.app_current_employee_id();
--   drop function if exists public.app_berlin_today();
-- ============================================================
