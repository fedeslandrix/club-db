-- =====================================================
-- 07_test_enunciado.sql : datos de prueba SOLO para probar la consulta:
--   "Datos del socio titular de grupos familiares que adeudan cuotas
--    sociales del anio en curso, junto con el importe total adeudado y
--    la cantidad de integrantes del grupo."
-- Usa grupos 901..909 (no toca los grupos 504..508 de 06_data.sql).
-- Se puede correr varias veces: primero borra lo suyo.
-- Anio en curso = 2026 (YEAR(CURDATE())).
-- =====================================================
SET NAMES utf8mb4;
USE tp_bd_grupo2;

-- ---------- limpieza (orden por FK) ----------
DELETE FROM cuota_social   WHERE nro_base >= 900;
DELETE FROM socio_titular  WHERE nro_base >= 900;
DELETE FROM socio          WHERE nro_base >= 900;
DELETE FROM grupo_familiar WHERE nro_base >= 900;
DELETE FROM monto_base     WHERE id_monto_base IN (3, 4);

-- ---------- montos base para otros anios (no se solapan con 2026) ----------
INSERT INTO monto_base (id_monto_base, valor, fecha_inicio, fecha_fin) VALUES
    (3, 18000.00, '2025-01-01', '2025-12-31'),
    (4, 30000.00, '2027-01-01', '2027-12-31');
-- Montos base disponibles: 1 = 2026 ene-jun (20000), 2 = 2026 jul-dic (25000),
--                          3 = 2025 (18000),         4 = 2027 (30000)
-- monto_a_pagar: Mayores = valor ; Vitalicios = valor * 0.70

-- ---------- grupos ----------
INSERT INTO grupo_familiar (nro_base, num_telefono, domicilio, deuda_total) VALUES
    (901, '223-9010001', 'Test 901 - varias cuotas impagas 2026', 0),
    (902, '223-9020002', 'Test 902 - solo cuota futura 2026',     0),
    (903, '223-9030003', 'Test 903 - todo pagado',                0),
    (904, '223-9040004', 'Test 904 - deuda solo en 2025 y 2027',  0),
    (905, '223-9050005', 'Test 905 - deuda 2026 y 2025',          0),
    (906, '223-9060006', 'Test 906 - bordes 01/01 y 31/12',       0),
    (907, '223-9070007', 'Test 907 - sin cuotas',                 0),
    (908, '223-9080008', 'Test 908 - deuda de 1 centavo',         0),
    (909, '223-9090009', 'Test 909 - deuda actividad, cuotas ok', 0);

-- ---------- socios (titular = nro_orden 0) ----------
-- Columnas: nro_base, nro_orden, nombre, correo, fecha_nac, deuda_actividad, is_titular, categoria
INSERT INTO socio
    (nro_base, nro_orden, nombre, correo_electronico, fecha_nacimiento, deuda_actividad, is_titular, tipo_categoria)
VALUES
    -- 901: 3 integrantes
    (901, 0, 'Titular 901',  't901@mail.com', '1980-01-10', 0,    TRUE,  'Mayores'),
    (901, 1, 'Hijo 901 A',   NULL,            '2010-05-05', 3000, FALSE, 'Infantiles'),
    (901, 2, 'Hijo 901 B',   NULL,            '2012-06-06', 0,    FALSE, 'Infantiles'),
    -- 902: 1 integrante
    (902, 0, 'Titular 902',  't902@mail.com', '1985-02-11', 0,    TRUE,  'Mayores'),
    -- 903: 2 integrantes
    (903, 0, 'Titular 903',  't903@mail.com', '1970-03-12', 0,    TRUE,  'Mayores'),
    (903, 1, 'Conyuge 903',  NULL,            '1972-04-13', 0,    FALSE, 'Mayores'),
    -- 904: 1 integrante
    (904, 0, 'Titular 904',  't904@mail.com', '1965-04-14', 0,    TRUE,  'Mayores'),
    -- 905: 2 integrantes, titular Vitalicio
    (905, 0, 'Titular 905',  't905@mail.com', '1949-05-15', 0,    TRUE,  'Vitalicios'),
    (905, 1, 'Conyuge 905',  NULL,            '1951-06-16', 0,    FALSE, 'Vitalicios'),
    -- 906: 1 integrante
    (906, 0, 'Titular 906',  't906@mail.com', '1990-07-17', 0,    TRUE,  'Mayores'),
    -- 907: 2 integrantes
    (907, 0, 'Titular 907',  't907@mail.com', '1975-08-18', 0,    TRUE,  'Mayores'),
    (907, 1, 'Hija 907',     NULL,            '2015-09-19', 0,    FALSE, 'Infantiles'),
    -- 908: 5 integrantes
    (908, 0, 'Titular 908',  't908@mail.com', '1978-09-20', 0,    TRUE,  'Mayores'),
    (908, 1, 'Conyuge 908',  NULL,            '1979-10-21', 0,    FALSE, 'Mayores'),
    (908, 2, 'Hijo 908 A',   NULL,            '2008-11-22', 0,    FALSE, 'Infantiles'),
    (908, 3, 'Hijo 908 B',   NULL,            '2011-12-23', 0,    FALSE, 'Infantiles'),
    (908, 4, 'Hijo 908 C',   NULL,            '2016-01-24', 0,    FALSE, 'Infantiles'),
    -- 909: 2 integrantes, con deuda de actividad
    (909, 0, 'Titular 909',  't909@mail.com', '1982-10-25', 5000, TRUE,  'Mayores'),
    (909, 1, 'Hija 909',     NULL,            '2013-11-26', 4000, FALSE, 'Infantiles');

INSERT INTO socio_titular (nro_base, nro_orden, nro_celular) VALUES
    (901, 0, '223-155-901'), (902, 0, '223-155-902'), (903, 0, '223-155-903'),
    (904, 0, '223-155-904'), (905, 0, '223-155-905'), (906, 0, '223-155-906'),
    (907, 0, '223-155-907'), (908, 0, '223-155-908'), (909, 0, '223-155-909');

-- ---------- cuotas ----------
-- Columnas: fecha_vencimiento, monto_abonado, monto_a_pagar, nro_base, nro_orden, id_monto_base
INSERT INTO cuota_social
    (fecha_vencimiento, monto_abonado, monto_a_pagar, nro_base, nro_orden, id_monto_base)
VALUES
    -- 901 (Mayores): 2026 -> 20000 + 15000 + 25000 = 60000 de deuda; una pagada que no suma
    ('2026-03-10',     0.00, 20000.00, 901, 0, 1),   -- deuda 20000 (vencida)
    ('2026-09-10', 10000.00, 25000.00, 901, 0, 2),   -- deuda 15000 (parcial)
    ('2026-12-10',     0.00, 25000.00, 901, 0, 2),   -- deuda 25000 (aun no vence)
    ('2026-02-10', 20000.00, 20000.00, 901, 0, 1),   -- pagada, no suma

    -- 902 (Mayores): solo una cuota futura impaga -> 25000
    ('2026-12-20',     0.00, 25000.00, 902, 0, 2),

    -- 903 (Mayores): todo pagado en 2026 -> NO aparece
    ('2026-04-10', 20000.00, 20000.00, 903, 0, 1),
    ('2026-10-10', 25000.00, 25000.00, 903, 0, 2),

    -- 904 (Mayores): impaga 2025 y 2027, 2026 pagada -> NO aparece
    ('2025-08-10',     0.00, 18000.00, 904, 0, 3),
    ('2027-03-10',     0.00, 30000.00, 904, 0, 4),
    ('2026-05-10', 20000.00, 20000.00, 904, 0, 1),

    -- 905 (Vitalicios): 2026 debe 14000; la de 2025 (12600) NO suma
    ('2026-05-10',     0.00, 14000.00, 905, 0, 1),   -- 20000 * 0.70
    ('2025-08-10',     0.00, 12600.00, 905, 0, 3),   -- 18000 * 0.70 (otro anio)

    -- 906 (Mayores): bordes del anio -> 20000 + 25000 = 45000
    ('2026-01-01',     0.00, 20000.00, 906, 0, 1),
    ('2026-12-31',     0.00, 25000.00, 906, 0, 2),

    -- 907: sin cuotas -> NO aparece

    -- 908 (Mayores): falta 1 centavo -> 0.01
    ('2026-02-10', 19999.99, 20000.00, 908, 0, 1),

    -- 909 (Mayores): cuotas pagadas (tiene deuda_actividad pero NO debe aparecer)
    ('2026-06-10', 20000.00, 20000.00, 909, 0, 1);

-- ---------- derivados: deuda_total = deuda de cuotas sociales (todas las cuotas del grupo) ----------
UPDATE grupo_familiar g
SET g.deuda_total = COALESCE((SELECT SUM(c.monto_a_pagar - c.monto_abonado)
                              FROM cuota_social c
                              WHERE c.nro_base = g.nro_base), 0)
WHERE g.nro_base >= 900;
