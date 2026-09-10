-- ============================================================
-- Atölye İş Takip — v29: NW-FR / NW-FR-Aus'a Regiestunde + Extra Arbeit
--
-- Çalışan geri bildirimi: Neuwagen Flatrate işlerinde (NW-FR, NW-FR-Aus)
-- ne Regiestunde (Extra Stunde) ne de Extra Arbeit seçeneği görünüyor.
-- Bu iki hizmet Neuwagen kategorisinde olduğu için, daha önce TÜM
-- Neuwagen hizmetlerine bu iki özelliğin eklenmesi istenmişti
-- (schema_v17-v20) — ama bu ikisi o zamanki eşleştirmede kaçırılmış
-- olabilir (daha önce NW-Sys'te de aynı tür bir kaçırma yaşanmıştı).
--
-- Bu SQL, tam eşleşme (exact match, trim ile boşluk/görünmez karakter
-- sorunlarına karşı korumalı) kullanarak, idempotent şekilde düzeltir —
-- zaten doğruysa hiçbir şey değişmez.
-- ============================================================

update job_types
set allows_extra_arbeit = true, is_aufbereitung = true
where trim(code) in ('NW-FR', 'NW-FR-Aus');

-- Kontrol:
-- select code, allows_extra_arbeit, is_aufbereitung from job_types where trim(code) in ('NW-FR', 'NW-FR-Aus');
