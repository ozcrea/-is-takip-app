-- schema_v36.sql
-- Yeni iş tipi: "Smart Repair" — Text Aufbereitung ile AYNI işlev (Preis +
-- Beschreibung + Dauer, serbest metin), ama MTS/Privat değil; geliri
-- Dashboard'da "Lack" kartına (SR-Lack ile aynı bucket) yazılır.
INSERT INTO job_types (code, name, category, is_mts, is_variable_price, requires_ref, is_aufbereitung, is_quantity, is_internal, allows_extra_arbeit, active, sort_order)
VALUES ('Smart Repair', 'Smart Repair', 'SR', false, true, true, false, false, false, false, true, 53);
