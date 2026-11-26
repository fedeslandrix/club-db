-- 02_indexes.sql
-- 02_indexes.sql
USE tp_bd_grupo2;

CREATE UNIQUE INDEX uq_trabaja_en_prof_turno
    ON trabaja_en (id_profesional, periodo, dias, horario);

CREATE INDEX idx_trabaja_en_area_turno
    ON trabaja_en (id_area, periodo, dias, horario);

CREATE INDEX idx_cuota_vencimiento_cobro
    ON cuota_social (
        fecha_vencimiento, nro_base, nro_orden,
        monto_a_pagar, monto_abonado
    );

CREATE INDEX idx_abona_fecha
    ON abona (fecha);

-- (Placeholder) El índice anterior referenciaba una tabla "socios" y una columna "apellido"
-- que no existen en el esquema, y abortaba la inicialización de la base.
-- Agregar acá los índices reales sobre las tablas de 01_schema.sql.
