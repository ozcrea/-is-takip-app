-- ============================================================
-- Atölye İş Takip — v11: Gerçek Supabase Auth için hazırlık
-- Bu dosya SADECE EKLEME yapar — hiçbir mevcut satırı silmez/değiştirmez.
-- Supabase SQL Editor'de çalıştırabilirsiniz, geri dönüşü kolaydır
-- (istenirse "alter table employees drop column ..." ile geri alınabilir).
-- ============================================================

-- 1) employees tablosuna 3 yeni kolon:
--    auth_user_id: bu çalışanın gerçek Supabase Auth hesabına bağlantısı
--    is_admin: true ise Chef-Panel'e PIN'siz, direkt erişebilir
--    hidden_from_login: true ise bu satır giriş ekranındaki isim
--                        listesinde (dropdown'da) GÖRÜNMEZ — sahibin
--                        gizli /admin hesabı için kullanılacak
alter table employees add column if not exists auth_user_id uuid unique references auth.users(id);
alter table employees add column if not exists is_admin boolean not null default false;
alter table employees add column if not exists hidden_from_login boolean not null default false;

-- 2) ŞEF hesabını işaretleyin — hangi çalışanın "Şef" (is_admin) olacağını
--    SİZ belirlemelisiniz, ben tahmin etmiyorum. AKT_NO_BURAYA yerine
--    gerçek kullanıcı adını (örn. 'H1A') yazıp çalıştırın:
--
-- update employees set is_admin = true where akt_no = 'AKT_NO_BURAYA';

-- 3) Sahibin (sizin) gizli admin hesabınız — kullanıcı adı ve şifreyi
--    SİZ belirleyip aşağıdaki placeholder'ları değiştirdikten sonra
--    çalıştırın (gerçek şifrenizi bana yazmanıza gerek yok):
--
-- insert into employees (name, akt_no, password, active, is_admin, hidden_from_login)
-- values ('Inhaber', 'KULLANICI_ADINIZ', 'SIFRENIZ', true, true, true);

-- ============================================================
-- Bitti. Kontrol için:
-- select name, akt_no, is_admin, hidden_from_login, auth_user_id from employees;
-- ============================================================
