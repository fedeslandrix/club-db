-- =====================================================
-- TP Base de Datos - GRUPO 2
-- 04_datos.sql : datos de prueba
-- Ejecutar DESPUÉS de 01_ddl.sql y 02_triggers.sql (no depende de las vistas)
-- Se puede correr TODAS las veces que se quiera: al principio borra los datos
-- de todas las tablas (y reinicia los AUTO_INCREMENT) y los vuelve a cargar.
-- Las tablas, triggers y vistas NO se tocan, solo se vacían los datos.
-- El orden de los INSERT importa: respeta las FK y los triggers.
-- =====================================================
SET NAMES utf8mb4;
USE tp_bd_grupo2;

-- -----------------------------------------------------
-- REINICIO: vaciar todas las tablas
-- Se desactivan las FK solo para poder truncar; se reactivan antes de cargar,
-- así que los INSERT de abajo sí validan FK, CHECK y triggers.
-- -----------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE abona;
TRUNCATE TABLE se_inscribe_en;
TRUNCATE TABLE trabaja_en;
TRUNCATE TABLE permite;
TRUNCATE TABLE puede_dictar;
TRUNCATE TABLE agrupa;
TRUNCATE TABLE actividad_no_arancelada;
TRUNCATE TABLE actividad_arancelada;
TRUNCATE TABLE actividad;
TRUNCATE TABLE area;
TRUNCATE TABLE profesional;
TRUNCATE TABLE cuota_social;
TRUNCATE TABLE monto_base;
TRUNCATE TABLE socio_titular;
TRUNCATE TABLE socio;
TRUNCATE TABLE categoria;
TRUNCATE TABLE grupo_familiar;

SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------
-- CATEGORIA
-- (los nombres 'Mayores' y 'Vitalicios' tienen que coincidir con los de los triggers)
-- descuento: porcentaje. Negativo = incremento.
-- -----------------------------------------------------
INSERT INTO categoria (tipo_categoria, descuento) VALUES
    ('Infantiles', 20.00),
    ('Mayores',     0.00),
    ('Vitalicios', 30.00);

-- -----------------------------------------------------
-- GRUPO FAMILIAR  (deuda_total se recalcula al final)
-- -----------------------------------------------------
INSERT INTO grupo_familiar (nro_base, num_telefono, domicilio, deuda_total) VALUES
    (504, '223-4551001', 'Av. Independencia 2450',  0),
    (505, '223-4552002', 'Calle 14 N° 330',         0),
    (506, '223-4553003', 'San Lorenzo 1875',        0),
    (507, '223-4554004', 'Rivadavia 920',           0),
    (508, '223-4555005', 'Alberti 3100',            0);

-- -----------------------------------------------------
-- SOCIO
-- titular = nro_orden 0 e is_titular = TRUE (titulares: Mayores o Vitalicios)
-- deuda_actividad se recalcula al final
-- -----------------------------------------------------
INSERT INTO socio
    (nro_base, nro_orden, nombre, correo_electronico, fecha_nacimiento, deuda_actividad, is_titular, tipo_categoria)
VALUES
    -- Grupo 504: titular, cónyuge y dos hijos
    (504, 0, 'Carlos Gómez',      'carlos.gomez@mail.com',   '1980-03-15', 0, TRUE,  'Mayores'),
    (504, 1, 'Laura Benítez',     'laura.benitez@mail.com',  '1982-07-22', 0, FALSE, 'Mayores'),
    (504, 2, 'Tomás Gómez',       NULL,                      '2012-11-02', 0, FALSE, 'Infantiles'),
    (504, 3, 'Sofía Gómez',       NULL,                      '2015-05-30', 0, FALSE, 'Infantiles'),
    -- Grupo 505: titular sin familiares
    (505, 0, 'Marta Rodríguez',   'marta.rodriguez@mail.com','1950-01-09', 0, TRUE,  'Vitalicios'),
    -- Grupo 506: titular e hija
    (506, 0, 'Jorge Pérez',       'jorge.perez@mail.com',    '1975-09-12', 0, TRUE,  'Mayores'),
    (506, 1, 'Lucía Pérez',       NULL,                      '2014-02-18', 0, FALSE, 'Infantiles'),
    -- Grupo 507: titular sin familiares
    (507, 0, 'Ana Fernández',     'ana.fernandez@mail.com',  '1990-12-05', 0, TRUE,  'Mayores'),
    -- Grupo 508: titular y cónyuge, ambos vitalicios
    (508, 0, 'Roberto Silva',     'roberto.silva@mail.com',  '1948-06-27', 0, TRUE,  'Vitalicios'),
    (508, 1, 'Elena Díaz',        'elena.diaz@mail.com',     '1951-10-14', 0, FALSE, 'Vitalicios');

-- -----------------------------------------------------
-- SOCIO TITULAR  (el trigger valida nro_orden = 0, is_titular y categoría)
-- -----------------------------------------------------
INSERT INTO socio_titular (nro_base, nro_orden, nro_celular) VALUES
    (504, 0, '223-155110011'),
    (505, 0, '223-155220022'),
    (506, 0, '223-155330033'),
    (507, 0, '223-155440044'),
    (508, 0, '223-155550055');

-- -----------------------------------------------------
-- MONTO BASE  (vigencias sin solaparse)
-- -----------------------------------------------------
INSERT INTO monto_base (id_monto_base, valor, fecha_inicio, fecha_fin) VALUES
    (1, 20000.00, '2026-01-01', '2026-06-30'),
    (2, 25000.00, '2026-07-01', '2026-12-31');

-- -----------------------------------------------------
-- CUOTA SOCIAL
-- monto_a_pagar = valor del monto base * (1 - descuento de la categoría del titular):
--   Mayores    -> 20000.00 (monto base 1) / 25000.00 (monto base 2)
--   Vitalicios -> 17500.00 (monto base 2)
-- Se carga explícito para que el CHECK (monto_abonado <= monto_a_pagar) pase
-- aunque MySQL lo evalúe antes que el trigger. El trigger lo vuelve a calcular
-- y tiene que dar exactamente el mismo valor.
-- fecha_vencimiento tiene que caer dentro de la vigencia del monto base elegido.
-- Columnas: fecha_vencimiento, monto_abonado, monto_a_pagar, nro_base, nro_orden, id_monto_base
-- -----------------------------------------------------
INSERT INTO cuota_social
    (fecha_vencimiento, monto_abonado, monto_a_pagar, nro_base, nro_orden, id_monto_base)
VALUES
    -- Primer semestre (monto base 1)
    ('2026-06-10', 20000.00, 20000.00, 504, 0, 1),
    -- Octubre 2026
    ('2026-10-10', 25000.00, 25000.00, 504, 0, 2),
    ('2026-10-10', 17500.00, 17500.00, 505, 0, 2),
    ('2026-10-10', 25000.00, 25000.00, 506, 0, 2),
    ('2026-10-10',     0.00, 25000.00, 507, 0, 2),   -- impaga
    ('2026-10-10', 17500.00, 17500.00, 508, 0, 2),
    -- Noviembre 2026
    ('2026-11-10',     0.00, 25000.00, 504, 0, 2),   -- impaga
    ('2026-11-10',     0.00, 17500.00, 505, 0, 2),   -- impaga
    ('2026-11-10', 12500.00, 25000.00, 506, 0, 2),   -- pago parcial
    ('2026-11-10',     0.00, 25000.00, 507, 0, 2),   -- impaga
    ('2026-11-10', 17500.00, 17500.00, 508, 0, 2);

-- -----------------------------------------------------
-- PROFESIONAL
-- -----------------------------------------------------
INSERT INTO profesional (id_profesional, dni, nombre) VALUES
    (1, '28111222', 'Martín Acosta'),
    (2, '30222333', 'Valeria Núñez'),
    (3, '31333444', 'Diego Ferrari'),
    (4, '32444555', 'Julieta Ramos'),
    (5, '27555666', 'Hernán Molina'),
    (6, '33666777', 'Camila Torres');

-- -----------------------------------------------------
-- AREA
-- -----------------------------------------------------
INSERT INTO area (id_area, capacidad, ubicacion_predio, estado_mantenimiento) VALUES
    (1,   4, 'Sector norte - Cancha de tenis 1',  'Bueno'),
    (2,   4, 'Sector norte - Cancha de tenis 2',  'Bueno'),
    (3,   4, 'Sector norte - Cancha de tenis 3',  'En reparación'),
    (4,   4, 'Sector este - Cancha de tenis 9',   'Bueno'),
    (5,  40, 'Edificio central - Pileta climatizada', 'Bueno'),
    (6,  60, 'Edificio central - Salón de usos múltiples', 'Bueno'),
    (7,  20, 'Sector sur - Cancha de fútbol 5',   'Regular');

-- -----------------------------------------------------
-- ACTIVIDAD  (primero el supertipo, después los subtipos)
-- tipo: 'ARANCELADA' / 'NO_ARANCELADA'
-- -----------------------------------------------------
INSERT INTO actividad (id_actividad, descripcion, tipo) VALUES
    (1, 'Natación',                       'ARANCELADA'),
    (2, 'Tenis',                          'ARANCELADA'),
    (3, 'Eventos recreativos infantiles', 'NO_ARANCELADA'),
    (4, 'Yoga',                           'ARANCELADA'),
    (5, 'Ajedrez',                        'NO_ARANCELADA'),
    (6, 'Gimnasia suave',                 'NO_ARANCELADA'),
    (7, 'Fútbol infantil',                'ARANCELADA');

INSERT INTO actividad_arancelada (id_actividad, costo, frecuencia_pago) VALUES
    (1, 12000.00, 'Mensual'),
    (2, 18000.00, 'Mensual'),
    (4,  9000.00, 'Bimestral'),
    (7,  8000.00, 'Mensual');

INSERT INTO actividad_no_arancelada (id_actividad) VALUES
    (3),
    (5),
    (6);

-- -----------------------------------------------------
-- AGRUPA  (categorías habilitadas para cada actividad)
-- -----------------------------------------------------
INSERT INTO agrupa (id_actividad, tipo_categoria) VALUES
    (1, 'Infantiles'), (1, 'Mayores'), (1, 'Vitalicios'),   -- Natación
    (2, 'Infantiles'), (2, 'Mayores'),                      -- Tenis
    (3, 'Infantiles'),                                      -- Eventos recreativos infantiles
    (4, 'Mayores'),    (4, 'Vitalicios'),                   -- Yoga
    (5, 'Infantiles'), (5, 'Mayores'), (5, 'Vitalicios'),   -- Ajedrez
    (6, 'Vitalicios'),                                      -- Gimnasia suave
    (7, 'Infantiles');                                      -- Fútbol infantil

-- -----------------------------------------------------
-- PUEDE DICTAR  (profesional habilitado para la actividad)
-- -----------------------------------------------------
INSERT INTO puede_dictar (id_profesional, id_actividad) VALUES
    (1, 1), (1, 6),            -- Martín: Natación, Gimnasia suave
    (2, 1), (2, 4),            -- Valeria: Natación, Yoga
    (3, 2), (3, 7),            -- Diego: Tenis, Fútbol infantil
    (4, 2),                    -- Julieta: Tenis
    (5, 2), (5, 5),            -- Hernán: Tenis, Ajedrez
    (6, 2), (6, 3);            -- Camila: Tenis, Eventos recreativos

-- -----------------------------------------------------
-- PERMITE  (actividades que se pueden desarrollar en cada área)
-- -----------------------------------------------------
INSERT INTO permite (id_area, id_actividad) VALUES
    (1, 2), (2, 2), (3, 2), (4, 2),     -- canchas de tenis
    (5, 1),                             -- pileta
    (6, 3), (6, 4), (6, 5), (6, 6),     -- salón: eventos, yoga, ajedrez, gimnasia suave
    (7, 7);                             -- cancha de fútbol 5

-- -----------------------------------------------------
-- TRABAJA EN  (cronograma: un día por fila)
-- El trigger valida que el profesional pueda dictar la actividad
-- y que el área la permita.
-- -----------------------------------------------------
INSERT INTO trabaja_en (id_profesional, id_actividad, id_area, dias, horario, periodo) VALUES
    -- Tenis: lunes y miércoles de 9 a 11, cuatro profesores en las canchas 1, 2, 3 y 9
    (3, 2, 1, 'Lunes',     '09:00-11:00', '2do semestre 2026'),
    (3, 2, 1, 'Miércoles', '09:00-11:00', '2do semestre 2026'),
    (4, 2, 2, 'Lunes',     '09:00-11:00', '2do semestre 2026'),
    (4, 2, 2, 'Miércoles', '09:00-11:00', '2do semestre 2026'),
    (5, 2, 3, 'Lunes',     '09:00-11:00', '2do semestre 2026'),
    (5, 2, 3, 'Miércoles', '09:00-11:00', '2do semestre 2026'),
    (6, 2, 4, 'Lunes',     '09:00-11:00', '2do semestre 2026'),
    (6, 2, 4, 'Miércoles', '09:00-11:00', '2do semestre 2026'),
    -- Natación
    (1, 1, 5, 'Martes',    '18:00-19:00', '2do semestre 2026'),
    (1, 1, 5, 'Jueves',    '18:00-19:00', '2do semestre 2026'),
    (2, 1, 5, 'Lunes',     '19:00-20:00', '2do semestre 2026'),
    -- Yoga
    (2, 4, 6, 'Viernes',   '10:00-11:00', '2do semestre 2026'),
    -- Gimnasia suave
    (1, 6, 6, 'Martes',    '10:00-11:00', '2do semestre 2026'),
    -- Ajedrez
    (5, 5, 6, 'Jueves',    '17:00-18:30', '2do semestre 2026'),
    -- Eventos recreativos infantiles
    (6, 3, 6, 'Sábado',    '15:00-17:00', '2do semestre 2026'),
    -- Fútbol infantil
    (3, 7, 7, 'Sábado',    '10:00-12:00', '2do semestre 2026');

-- -----------------------------------------------------
-- SE INSCRIBE EN
-- El trigger valida que la categoría del socio esté asociada a la actividad (AGRUPA).
-- La actividad 6 (Gimnasia suave) y la 3 tienen inscriptos solo de su categoría.
-- -----------------------------------------------------
INSERT INTO se_inscribe_en (nro_base, nro_orden, id_actividad, fecha_inscripcion) VALUES
    (504, 0, 2, '2026-07-05'),   -- Carlos: Tenis
    (504, 0, 1, '2026-07-05'),   -- Carlos: Natación
    (504, 1, 4, '2026-07-10'),   -- Laura: Yoga
    (504, 2, 1, '2026-07-12'),   -- Tomás: Natación
    (504, 2, 3, '2026-07-12'),   -- Tomás: Eventos recreativos
    (504, 3, 2, '2026-07-15'),   -- Sofía: Tenis
    (504, 3, 7, '2026-07-15'),   -- Sofía: Fútbol infantil
    (505, 0, 6, '2026-07-03'),   -- Marta: Gimnasia suave
    (505, 0, 4, '2026-07-03'),   -- Marta: Yoga
    (506, 0, 1, '2026-07-20'),   -- Jorge: Natación
    (506, 0, 5, '2026-07-20'),   -- Jorge: Ajedrez
    (506, 1, 3, '2026-07-22'),   -- Lucía: Eventos recreativos
    (506, 1, 7, '2026-07-22'),   -- Lucía: Fútbol infantil
    (507, 0, 2, '2026-08-01'),   -- Ana: Tenis
    (508, 0, 1, '2026-07-08'),   -- Roberto: Natación
    (508, 0, 5, '2026-07-08'),   -- Roberto: Ajedrez
    (508, 1, 6, '2026-07-08'),   -- Elena: Gimnasia suave
    (508, 1, 4, '2026-07-08');   -- Elena: Yoga

-- -----------------------------------------------------
-- ABONA  (solo actividades aranceladas, y solo de socios inscriptos)
-- Los que están inscriptos en una arancelada y NO figuran acá, tienen deuda.
-- -----------------------------------------------------
INSERT INTO abona (id_actividad, nro_orden, nro_base, fecha) VALUES
    (2, 0, 504, '2026-07-20'),   -- Carlos pagó Tenis
    (4, 1, 504, '2026-07-25'),   -- Laura pagó Yoga
    (1, 2, 504, '2026-07-25'),   -- Tomás pagó Natación
    (7, 3, 504, '2026-07-28'),   -- Sofía pagó Fútbol infantil
    (1, 0, 506, '2026-08-05'),   -- Jorge pagó Natación
    (2, 0, 507, '2026-08-10'),   -- Ana pagó Tenis
    (4, 1, 508, '2026-07-30');   -- Elena pagó Yoga

-- -----------------------------------------------------
-- ATRIBUTOS DERIVADOS (RA 9)
-- deuda_actividad (socio) = suma del costo de las actividades aranceladas
--                           en las que está inscripto y todavía no pagó
-- deuda_total (grupo)     = deuda de las cuotas sociales + deuda_actividad de sus socios
-- -----------------------------------------------------
UPDATE socio s
SET s.deuda_actividad = COALESCE((
        SELECT SUM(aa.costo)
        FROM se_inscribe_en i
        JOIN actividad_arancelada aa ON aa.id_actividad = i.id_actividad
        LEFT JOIN abona ab ON ab.nro_base    = i.nro_base
                          AND ab.nro_orden   = i.nro_orden
                          AND ab.id_actividad = i.id_actividad
        WHERE i.nro_base  = s.nro_base
          AND i.nro_orden = s.nro_orden
          AND ab.id_actividad IS NULL
    ), 0)
WHERE s.nro_base > 0;

UPDATE grupo_familiar g
SET g.deuda_total =
      COALESCE((SELECT SUM(c.monto_a_pagar - c.monto_abonado) FROM cuota_social c WHERE c.nro_base = g.nro_base), 0)
    + COALESCE((SELECT SUM(s.deuda_actividad) FROM socio s WHERE s.nro_base = g.nro_base), 0)
WHERE g.nro_base > 0;

-- =====================================================
-- CONSULTAS PARA VERIFICAR QUE CARGÓ BIEN
-- =====================================================
-- SELECT * FROM grupo_familiar;
-- SELECT * FROM socio ORDER BY nro_base, nro_orden;
-- SELECT * FROM cuota_social;            -- monto_a_pagar lo calculó el trigger
-- SELECT * FROM v_cuota_deuda;

-- =====================================================
-- PRUEBAS DE LAS RA: cada una de estas sentencias tiene que FALLAR
-- (descomentar de a una y ejecutar)
-- =====================================================
-- RA 4: Tomás (Infantiles) no puede inscribirse en Yoga (solo Mayores y Vitalicios)
-- INSERT INTO se_inscribe_en VALUES (504, 2, 4, '2026-11-01');

-- RA 1: un socio Infantiles no puede ser titular
-- INSERT INTO socio VALUES (509, 0, 'Test', NULL, '2015-01-01', 0, TRUE, 'Infantiles');
-- (antes hay que crear el grupo: INSERT INTO grupo_familiar VALUES (509, '000', 'x', 0);)
-- INSERT INTO socio_titular VALUES (509, 0, '000');

-- RA 5: pagar una actividad en la que el socio no está inscripto
-- INSERT INTO abona VALUES (1, 0, 505, '2026-11-01');

-- RA 6: una actividad no puede ser arancelada y no arancelada a la vez
-- INSERT INTO actividad_no_arancelada VALUES (1);

-- RA 7: monto base con vigencia que se solapa con otra
-- INSERT INTO monto_base (valor, fecha_inicio, fecha_fin) VALUES (30000, '2026-12-01', '2027-05-31');

-- RA 8: Hernán (Tenis/Ajedrez) no puede dictar Natación
-- INSERT INTO trabaja_en VALUES (5, 1, 5, 'Viernes', '18:00-19:00', '2do semestre 2026');