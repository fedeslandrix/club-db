-- =====================================================
-- 08_test_gratuitas.sql : datos de prueba SOLO para la consulta:
--   "Cantidad de socios por categoria que se hayan inscripto en todas las
--    actividades gratuitas (de su categoria, segun agrupa) durante el anio pasado."
-- Gratuitas = actividad_no_arancelada. Anio pasado = 2025 (hoy es 2026).
-- Gratuitas por categoria segun 06_data.sql (agrupa):
--   Infantiles -> 3, 5   |   Mayores -> 5   |   Vitalicios -> 5, 6
-- Usa el grupo 950 y la categoria 'Honorarios'. Se puede correr varias veces.
-- =====================================================
SET NAMES utf8mb4;
USE tp_bd_grupo2;

-- ---------- limpieza ----------
DELETE FROM se_inscribe_en WHERE nro_base = 950;
DELETE FROM socio_titular  WHERE nro_base = 950;
DELETE FROM socio          WHERE nro_base = 950;
DELETE FROM grupo_familiar WHERE nro_base = 950;
DELETE FROM categoria      WHERE tipo_categoria = 'Honorarios';
-- (por si corriste la version anterior de este script, que agregaba estas filas)
DELETE FROM agrupa WHERE (id_actividad, tipo_categoria) IN
    ((3, 'Mayores'), (3, 'Vitalicios'), (6, 'Infantiles'), (6, 'Mayores'));

-- ---------- categoria sin ninguna actividad gratuita (caso borde) ----------
--INSERT INTO categoria (tipo_categoria, descuento) VALUES ('Honorarios', 0.00);

-- ---------- grupo y socios ----------
INSERT INTO grupo_familiar (nro_base, num_telefono, domicilio, deuda_total) VALUES
    (950, '223-9500000', 'Test 950 - gratuitas', 0);

INSERT INTO socio
    (nro_base, nro_orden, nombre, correo_electronico, fecha_nacimiento, deuda_actividad, is_titular, tipo_categoria)
VALUES
    (950,  0, 'S0  Mayores - gratuita 5 en 2025',            NULL, '1980-01-01', 0, TRUE,  'Mayores'),
    (950,  1, 'S1  Mayores - gratuita 5 en 2026',            NULL, '1981-01-01', 0, FALSE, 'Mayores'),
    (950,  2, 'S2  Mayores - gratuita 5 en 2024',            NULL, '1982-01-01', 0, FALSE, 'Mayores'),
    (950,  3, 'S3  Mayores - sin inscripciones',             NULL, '1983-01-01', 0, FALSE, 'Mayores'),
    (950,  4, 'S4  Mayores - gratuita 5 el 01/01/2025 + aranceladas', NULL, '1984-01-01', 0, FALSE, 'Mayores'),
    (950,  5, 'S5  Infantiles - gratuitas 3 y 5 en 2025',    NULL, '2010-01-01', 0, FALSE, 'Infantiles'),
    (950,  6, 'S6  Infantiles - solo gratuita 3',            NULL, '2011-01-01', 0, FALSE, 'Infantiles'),
    (950,  7, 'S7  Infantiles - bordes 31/12 y 01/01',       NULL, '2012-01-01', 0, FALSE, 'Infantiles'),
    (950,  8, 'S8  Infantiles - 3 en 2025 y 5 en 2026',      NULL, '2013-01-01', 0, FALSE, 'Infantiles'),
    (950,  9, 'S9  Infantiles - solo arancelada',            NULL, '2014-01-01', 0, FALSE, 'Infantiles'),
    (950, 10, 'S10 Vitalicios - gratuitas 5 y 6 en 2025',    NULL, '1950-01-01', 0, FALSE, 'Vitalicios'),
    (950, 11, 'S11 Vitalicios - solo gratuita 5',            NULL, '1951-01-01', 0, FALSE, 'Vitalicios'),
    (950, 12, 'S12 Vitalicios - solo gratuita 6',            NULL, '1952-01-01', 0, FALSE, 'Vitalicios'),
    (950, 13, 'S13 Vitalicios - 5 y 6 en 2025 + arancelada', NULL, '1953-01-01', 0, FALSE, 'Vitalicios');
    --(950, 14, 'S14 Honorarios - categoria sin gratuitas',    NULL, '1960-01-01', 0, FALSE, 'Honorarios');

INSERT INTO socio_titular (nro_base, nro_orden, nro_celular) VALUES (950, 0, '223-155-950');

-- ---------- inscripciones ----------
-- Gratuitas: 3 (eventos infantiles), 5 (ajedrez), 6 (gimnasia suave)
-- Aranceladas: 1 (natacion), 2 (tenis), 4 (yoga), 7 (futbol infantil)
INSERT INTO se_inscribe_en (nro_base, nro_orden, id_actividad, fecha_inscripcion) VALUES
    -- Mayores (necesitan la 5)
    (950,  0, 5, '2025-03-10'),                                   -- CUENTA
    (950,  1, 5, '2026-02-10'),                                   -- no: es de 2026
    (950,  2, 5, '2024-05-10'),                                   -- no: es de 2024
    -- S3 sin inscripciones                                       -- no
    (950,  4, 5, '2025-01-01'), (950, 4, 1, '2025-02-02'), (950, 4, 4, '2025-02-02'),  -- CUENTA (borde; aranceladas no influyen)
    -- Infantiles (necesitan la 3 y la 5)
    (950,  5, 3, '2025-04-11'), (950,  5, 5, '2025-04-11'),       -- CUENTA
    (950,  6, 3, '2025-05-12'),                                   -- no: falta la 5
    (950,  7, 3, '2025-12-31'), (950,  7, 5, '2025-01-01'),       -- CUENTA (bordes)
    (950,  8, 3, '2025-06-13'), (950,  8, 5, '2026-01-13'),       -- no: la 5 es de 2026
    (950,  9, 7, '2025-07-14'),                                   -- no: solo arancelada
    -- Vitalicios (necesitan la 5 y la 6)
    (950, 10, 5, '2025-08-15'), (950, 10, 6, '2025-08-15'),       -- CUENTA
    (950, 11, 5, '2025-09-16'),                                   -- no: falta la 6
    (950, 12, 6, '2025-10-17'),                                   -- no: falta la 5
    (950, 13, 5, '2025-11-18'), (950, 13, 6, '2025-11-18'), (950, 13, 1, '2025-11-18');  -- CUENTA
    -- S14 Honorarios sin inscripciones: no tiene gratuitas que cumplir -> CUENTA (verdad vacia)
