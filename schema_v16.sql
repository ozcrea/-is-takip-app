-- ============================================================
-- Atölye İş Takip — v16: Wiesendamm için yeni çalışan (W3)
-- Bu dosyayı Supabase SQL Editor'de çalıştırın. SADECE BİR KEZ çalıştırın.
-- ============================================================

insert into employees (name, akt_no, password, active, is_admin, hidden_from_login)
values ('W3', 'W3', 'W3', true, false, false);

-- ============================================================
-- Bitti. Kontrol için:
-- select name, akt_no, active, is_admin, hidden_from_login, auth_user_id
-- from employees where akt_no = 'W3';
-- ============================================================
