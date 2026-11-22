-- =====================================================
-- TP Base de Datos - GRUPO 2
-- 03_views.sql : vistas
-- Ejecutar DESPUÉS de 01_ddl.sql
-- =====================================================
SET NAMES utf8mb4;
USE tp_bd_grupo2;

-- =====================================================
-- VISTA (RA 9): deuda de cada cuota, derivada
-- =====================================================
CREATE OR REPLACE VIEW v_cuota_deuda AS
SELECT id_cuota,
       nro_base,
       nro_orden, 
       (monto_a_pagar - monto_abonado) AS deuda,     
       CASE
           WHEN monto_abonado >= monto_a_pagar THEN 'PAGADO'
           WHEN monto_abonado > 0              THEN 'PARCIAL'
           ELSE 'IMPAGA'
       END AS estado,
       IF(fecha_vencimiento < CURDATE() AND monto_abonado < monto_a_pagar, 'VENCIDA', NULL) AS esta_vencida
FROM cuota_social
WHERE monto_abonado < monto_a_pagar;

CREATE OR REPLACE VIEW v_cuota_deuda_extended AS
SELECT id_cuota,
       nro_base,
       nro_orden,
       fecha_vencimiento,
       monto_a_pagar,
       monto_abonado,
       (monto_a_pagar - monto_abonado) AS deuda,
       CASE
           WHEN monto_abonado >= monto_a_pagar THEN 'PAGADO'
           WHEN monto_abonado > 0              THEN 'PARCIAL'
           ELSE 'IMPAGA'
       END AS estado,
       IF(fecha_vencimiento < CURDATE() AND monto_abonado < monto_a_pagar, 'VENCIDA', NULL) AS esta_vencida
FROM cuota_social
WHERE monto_abonado < monto_a_pagar;


-- =====================================================
-- VISTA: estado de cuenta por grupo familiar
-- Cuotas sociales (deuda del titular) separada de la deuda de actividades (informativa)
-- Se usan subconsultas agregadas para evitar duplicar filas entre JOINs.
-- =====================================================
CREATE OR REPLACE VIEW v_estado_cuenta_grupo_familiar AS
SELECT g.nro_base,
       g.domicilio,
       g.num_telefono,
       t.nro_orden                  AS nro_orden_titular,
       t.nombre                     AS titular,
       t.correo_electronico         AS correo_titular,
       st.nro_celular               AS celular_titular,
       t.fecha_nacimiento          AS fecha_nacimiento,
       COUNT(*)                     AS cantidad_integrantes,
       g.deuda_total                AS deuda_total_registrada,
       SUM(s.deuda_actividad)       AS total_deuda_actividad_informativa

FROM grupo_familiar g,
     socio s,--Para contar los socios en el grupo familiar
     socio t, --Para obtener los socios titulares
     socio_titular st -- Para obtener los deatos de los titulares

WHERE s.nro_base = g.nro_base
  AND t.nro_base = g.nro_base
  AND t.is_titular = TRUE
  AND st.nro_base = t.nro_base
  AND st.nro_orden = t.nro_orden
GROUP BY g.nro_base, g.domicilio, g.num_telefono, g.deuda_total,
         t.nro_orden, t.nombre, t.correo_electronico, t.fecha_nacimiento, st.nro_celular;


-- =====================================================
-- VISTA: cronograma de actividades (cartelera para recepcion/socios)
-- No expone el DNI del profesional.
-- =====================================================
CREATE OR REPLACE VIEW v_cronograma_actividades AS
SELECT a.id_actividad,
       a.descripcion                         AS actividad,
       a.tipo,
       aa.costo,
       aa.frecuencia_pago,
       p.nombre                              AS profesional,
       ar.ubicacion_predio                   AS area,
       ar.estado_mantenimiento               AS estado_area,
       te.dias,
       te.horario,
       te.periodo,
       GROUP_CONCAT(ag.tipo_categoria ORDER BY ag.tipo_categoria SEPARATOR ', ') AS categorias_habilitadas
FROM trabaja_en te,
     actividad a,
     profesional p,
     area ar,
     agrupa ag
     LEFT JOIN actividad_arancelada aa ON aa.id_actividad = ag.id_actividad
WHERE te.id_actividad    = a.id_actividad
  AND te.id_profesional  = p.id_profesional
  AND te.id_area         = ar.id_area
  AND ag.id_actividad    = a.id_actividad
GROUP BY a.id_actividad, a.descripcion, a.tipo, aa.costo, aa.frecuencia_pago,
         p.id_profesional, p.nombre, ar.id_area, ar.ubicacion_predio,
         ar.estado_mantenimiento, te.dias, te.horario, te.periodo;


-- =====================================================
-- VISTA: nomina de inscriptos por actividad (para el rol profesor)
-- Seguridad logica / minimo privilegio: el profesor solo necesita SELECT
-- sobre esta vista. No expone deuda_actividad, correo_electronico,
-- domicilio ni num_telefono.
-- Ej: GRANT SELECT ON tp_bd_grupo2.v_nomina_inscriptos_profesor TO 'profesor'@'%';
-- =====================================================
CREATE OR REPLACE VIEW v_nomina_inscriptos_profesor AS
SELECT a.id_actividad,
       a.descripcion      AS actividad,
       s.nro_base,
       s.nro_orden,
       s.nombre,
       s.tipo_categoria,
       i.fecha_inscripcion
FROM se_inscribe_en i,
     actividad a,
     socio s
WHERE i.id_actividad = a.id_actividad
  AND i.nro_base     = s.nro_base
  AND i.nro_orden    = s.nro_orden;
