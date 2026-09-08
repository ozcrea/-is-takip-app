-- ============================================================
-- Atölye İş Takip — v17: Extra Arbeit'i tüm Neuwagen ve Auslieferung
-- hizmetlerine genişlet
--
-- schema_v15.sql'deki desen (GW-%, VFW-%, %Neuwagen%, %NW Systempflege%)
-- bazı hizmetleri (GW-Ausl, Ausl-NW1, Ausl-NW2, Auslieferungsfinish GW 1/2,
-- "Neuwagen Flatrate für Ausstellungsfahrzeuge" gibi farklı adlandırılmış
-- olabilecek satırları) kaçırmış olabilir. Bu dosya, istenen 10 hizmetin
-- HEPSİNİ daha geniş bir desenle kapsıyor. Zaten allows_extra_arbeit=true
-- olanları etkilemez (idempotent), sadece eksik olanları ekler.
--
-- Bu dosyayı Supabase SQL Editor'de çalıştırın.
-- ============================================================

update job_types set allows_extra_arbeit = true
where (
  code ilike '%Neuwagen%'                    -- Neuwagen Flatrate 1 (Audi), Neuwagen Flatrate 2 (VW),
                                              -- Neuwagen Flatrate für Ausstellungsfahrzeuge
  or code ilike '%NW Systempflege%'          -- NW Systempflege (Audi), NW Systempflege (VW)
  or code ilike '%GW-Ausl%'                  -- GW-Ausl (Gebraucht Auslieferung)
  or code ilike '%Ausl-NW1%'                 -- Ausl-NW1 (Auslieferungsfinish NW1)
  or code ilike '%Ausl-NW2%'                 -- Ausl-NW2 (Auslieferungsfinish NW2)
  or code ilike '%Auslieferungsfinish%'      -- Auslieferungsfinish GW 1, Auslieferungsfinish GW 2
)
and is_variable_price = false;

-- ============================================================
-- KONTROL — bu sorguyu çalıştırıp, istediğiniz 10 hizmetin HEPSİNİN
-- listede ve allows_extra_arbeit = true olduğunu doğrulayın. Listede
-- görünmeyen bir hizmet varsa, gerçek "code" değeri yukarıdaki
-- desenlerden farklı yazılmış demektir — bana tam adını söylerseniz
-- düzeltirim.
--
-- select code, price_eur, is_variable_price, allows_extra_arbeit
-- from job_types
-- where code ilike '%Neuwagen%' or code ilike '%NW Systempflege%'
--    or code ilike '%GW-Ausl%' or code ilike '%Ausl-NW1%' or code ilike '%Ausl-NW2%'
--    or code ilike '%Auslieferungsfinish%'
-- order by code;
--
-- Beklenen 10 satır:
--   Neuwagen Flatrate 1 (Audi)
--   Neuwagen Flatrate 2 (VW)
--   NW Systempflege (Audi)
--   NW Systempflege (VW)
--   Neuwagen Flatrate für Ausstellungsfahrzeuge
--   GW-Ausl (Gebraucht Auslieferung)
--   Ausl-NW1 (Auslieferungsfinish NW1)
--   Ausl-NW2 (Auslieferungsfinish NW2)
--   Auslieferungsfinish GW 1
--   Auslieferungsfinish GW 2
-- ============================================================
