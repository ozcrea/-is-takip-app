-- ============================================================
-- Atölye İş Takip — v33: Ayrı, SADECE GÖRÜNTÜLEME yetkili "Chef" hesabı
--
-- Chef-Panel'e giriş, bir önceki düzeltmede (schema_v32 sonrası) yanlışlıkla
-- ADMIN hesabıyla birleştirilmişti. Bu YANLIŞ — admin'in kendi ayrı, gerçek
-- giriş yolu zaten /admin sayfasında var ve dokunulmuyor. Chef-Panel artık
-- TAMAMEN AYRI, sadece görüntüleme yetkili yeni bir hesapla çalışacak:
--   - is_admin = false  → admin'e özel gün-içi kayıt ekleme/düzenleme/silme
--     paneli (index.html'deki isHiddenAdmin kontrolü) bu hesaba ASLA
--     görünmez — mevcut kod zaten bunu is_admin=true şartına bağlıyor,
--     bu yüzden Chef için ek bir kısıtlama yazmaya gerek yok.
--   - is_chef_viewer = true → sadece Chef panosuna (raporlar, "Alle
--     Einträge" salt-okunur tablo, PDF indirme) yönlendirilmesini sağlayan
--     yeni bir bayrak.
--
-- ŞİFRE NOTU: Aşağıdaki 'ChefRapor2026!' değeri SADECE bir kereliğine,
-- migrate-employees Edge Function'ının gerçek bir Supabase Auth hesabı
-- oluşturmak için kullandığı GEÇİCİ düz metin değerdir. Fonksiyon
-- çalıştıktan sonra employees.auth_user_id doldurulur ve girişler ARTIK
-- SADECE gerçek Supabase Auth üzerinden doğrulanır (authenticateEmployee
-- fonksiyonu auth_user_id doluysa employees.password'a hiç bakmaz).
-- ============================================================

alter table employees add column if not exists is_chef_viewer boolean not null default false;

insert into employees (name, akt_no, password, is_admin, is_chef_viewer, hidden_from_login, active)
values ('Chef', 'Chef', 'ChefRapor2026!', false, true, true, true);

-- ============================================================
-- SONRAKİ ADIM (bu SQL'i çalıştırdıktan hemen sonra):
-- Supabase Dashboard → Edge Functions → migrate-employees → "Invoke"
-- (aynı, daha önce diğer çalışanlar için bir kez çalıştırdığınız buton).
-- Bu fonksiyon auth_user_id'si boş olan HER satırı işler — sadece yeni
-- 'Chef' satırını bulup gerçek bir Auth hesabı oluşturacak, diğer
-- çalışanlara dokunmayacak (onlarınki zaten dolu).
--
-- Kontrol — migrate-employees çalıştıktan sonra doğrulamak için:
-- select name, akt_no, is_admin, is_chef_viewer, auth_user_id
-- from employees where akt_no = 'Chef';
-- (auth_user_id artık NULL olmamalı.)
-- ============================================================
