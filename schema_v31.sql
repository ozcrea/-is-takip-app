-- ============================================================
-- Atölye İş Takip — v31: records_delete_recent'i sütun tipinden
-- bağımsız, sağlam hale getir
--
-- KRİTİK HATA DÜZELTMESİ: schema_v30.sql'deki
-- "(created_at at time zone 'Europe/Berlin')::date" ifadesi, SADECE
-- created_at sütunu gerçekten timestamptz (zaman dilimi farkında)
-- tipindeyse doğru sonuç verir. Eğer sütun timestamp (zaman
-- dilimsiz) ise, AT TIME ZONE ifadesi TERSİ yönde bir dönüşüm yapar
-- (değeri "zaten Berlin saati" varsayıp UTC'ye çevirir) — bu da
-- normal çalışanların BUGÜNKÜ kendi kayıtlarını bile silememesine yol
-- açtı (admin'in ayrı bypass koşulu olduğu için admin etkilenmedi).
--
-- Bu SQL, "created_at::timestamptz" ile açıkça cast ekliyor:
--   - created_at zaten timestamptz ise bu cast hiçbir şeyi değiştirmez
--     (no-op).
--   - created_at aslında timestamp ise, Postgres veritabanının
--     (Supabase'de varsayılan UTC olan) oturum saat dilimini kullanarak
--     doğru şekilde timestamptz'ye çevirir.
-- Böylece ifade, sütunun gerçek tipinden bağımsız olarak doğru çalışır.
-- ============================================================

drop policy if exists "records_delete_recent" on records;
create policy "records_delete_recent" on records for delete
  using (
    auth.role() = 'authenticated' and (
      (created_at::timestamptz at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date
      or exists (select 1 from employees e where e.auth_user_id = auth.uid() and e.is_admin = true)
    )
  );

-- ============================================================
-- Kontrol 1 — records.created_at'in GERÇEK sütun tipini görmek için:
-- select column_name, data_type from information_schema.columns
-- where table_name = 'records' and column_name = 'created_at';
-- (Beklenen: "timestamp with time zone". Eğer "timestamp without time
-- zone" çıkarsa, yukarıdaki teşhis doğrulanmış olur — bu SQL yine de
-- düzeltir, sütunu ayrıca değiştirmenize gerek yok.)
--
-- Kontrol 2 — bugünkü bir kaydın artık doğru "bugün" sayıldığını
-- görmek için (kendi hesabınızla, normal bir çalışan olarak):
-- select id, created_at,
--   (created_at::timestamptz at time zone 'Europe/Berlin')::date as berlin_date,
--   (now() at time zone 'Europe/Berlin')::date as today_berlin
-- from records order by created_at desc limit 5;
-- ============================================================
