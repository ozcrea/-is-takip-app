-- ============================================================
-- Atölye İş Takip — v19: 'NW-Sys' kod uyuşmazlığını düzelt
--
-- Gerçek kod adı 'NW Systempflege (Audi)' değil 'NW-Sys' imiş —
-- bu yüzden schema_v17/v18'deki '%NW Systempflege%' deseni bunu
-- kaçırmış. Kesin (exact match) düzeltme:
-- ============================================================

update job_types set allows_extra_arbeit = true, is_aufbereitung = true
where code = 'NW-Sys';

-- Kontrol:
-- select code, allows_extra_arbeit, is_aufbereitung from job_types where code = 'NW-Sys';
