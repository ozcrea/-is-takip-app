-- ============================================================
-- Atölye İş Takip — v14: MTS Smart Rep + Fotoservice sahiplik yeniden atama
-- Bu dosyayı Supabase SQL Editor'de çalıştırın. SADECE BİR KEZ çalıştırın
-- (aşağıdaki insert'lerde "on conflict" yok — ikinci kez çalıştırırsanız
-- job_types'a aynı satırlar tekrar eklenir).
-- ============================================================

-- 1) records tablosuna, "MTS Smart Rep" için Lack/Delle alt tipini
--    tutacak yeni bir kolon (mevcut verileri SİLMEZ, varsayılan NULL).
alter table records add column if not exists mts_subtype text;

-- 2) job_types tablosuna "iç kullanım" bayrağı: true olan satırlar
--    çalışan/admin'in seçebileceği iş listesinde GÖSTERİLMEZ — sadece
--    sistem tarafından (Fotoservice yeniden atama için) otomatik
--    kullanılır. Mevcut hiçbir satırı etkilemez (varsayılan false).
alter table job_types add column if not exists is_internal boolean not null default false;

-- 3) YENİ "MTS Smart Rep" iş tipi — SR-Lack ve SR-Delle'ye HİÇ DOKUNULMUYOR,
--    bu tamamen ayrı, yeni bir satır. is_mts=true olduğu için mevcut %25
--    komisyon kuralına göre otomatik olarak MUAF olacak (bkz. index.html'de
--    "if(r.job_types.is_mts) mtsRevenue += price" mantığı).
--
--    ⚠️ duration_minutes: aşağıya SR-Lack (veya SR-Delle) ile AYNI değeri
--    yazın — bu değer, kapasite/performans hesaplamasında (bir çalışanın
--    beyan ettiği saatlere göre ne kadar doldurduğu) kullanılıyor. Örnek
--    olarak kontrol etmek için önce şunu çalıştırabilirsiniz:
--      select code, duration_minutes from job_types where code in ('SR-Lack','SR-Delle');
insert into job_types (code, name, is_mts, is_variable_price, duration_minutes, active, sort_order)
values (
  'MTS-SR',
  'MTS Smart Rep',
  true,
  true,
  60, -- ⚠️ BURAYA SR-Lack/SR-Delle İLE AYNI duration_minutes DEĞERİNİ YAZIN
  true,
  (select coalesce(max(sort_order), 0) + 1 from job_types)
);

-- 4) YENİ "FOTOSERVICE" iç (internal) iş tipi — is_internal=true olduğu
--    için hiçbir çalışanın/admin'in "Neuen Auftrag hinzufügen" listesinde
--    GÖRÜNMEYECEK. Sadece index.html'deki insertJobRecord() fonksiyonu
--    tarafından, "Fotoservice = Ja" seçildiğinde, o günkü şubenin sabit
--    sorumlusuna (A3A / W1S / H1A) otomatik olarak kayıt açmak için
--    kullanılır. Süresi (8 dk) ve fiyatı (9,88 €) SABİTTİR.
insert into job_types (code, name, price_eur, duration_minutes, is_variable_price, is_mts, is_internal, active, sort_order)
values (
  'FOTOSERVICE',
  'Fotoservice (otomatik atanmış)',
  9.88,
  8,
  false,
  false,
  true,
  true,
  (select coalesce(max(sort_order), 0) + 1 from job_types)
);

-- ============================================================
-- Bitti. Kontrol için:
-- select code, name, is_mts, is_variable_price, is_internal, duration_minutes, price_eur
-- from job_types where code in ('MTS-SR', 'FOTOSERVICE');
--
-- ÖNEMLİ: A3A, W1S, H1A akt_no'larına sahip çalışanların employees
-- tablosunda GERÇEKTEN var olduğundan emin olun — Fotoservice yeniden
-- atama bu üç akt_no'yu şubeye göre sabit olarak kullanıyor
-- (bkz. index.html BRANCH_FOTOSERVICE_OWNER):
--   Ausschläger Weg → A3A
--   Wiesendamm      → W1S
--   Horn            → H1A
-- select akt_no, name, active from employees where akt_no in ('A3A','W1S','H1A');
-- ============================================================
