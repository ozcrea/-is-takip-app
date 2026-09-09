-- ============================================================
-- Atölye İş Takip — v21: VFW-W1/VFW-W2 Extra Arbeit kontrolü
--
-- Bu ikisi FOTOSERVICE_JOB_CODES listesinde zaten var olduğu ve
-- schema_v17.sql'deki "code ilike 'VFW-%'" deseni tam bu kodlarla
-- eşleştiği için muhtemelen zaten allows_extra_arbeit=true idi.
-- Bu SQL kesin (exact match) ve idempotent — zaten true ise hiçbir
-- şey değişmez, değilse düzeltir.
-- ============================================================

update job_types set allows_extra_arbeit = true where code in ('VFW-W1', 'VFW-W2');

-- Kontrol:
-- select code, allows_extra_arbeit, is_aufbereitung from job_types where code in ('VFW-W1', 'VFW-W2');
