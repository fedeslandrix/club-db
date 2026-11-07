-- =====================================================
-- TP Base de Datos - GRUPO 2
-- 03_views.sql : vistas
-- Ejecutar DESPUÉS de 01_ddl.sql
-- =====================================================
USE tp_bd_grupo2;

-- =====================================================
-- VISTA (RA 9): deuda de cada cuota, derivada
-- =====================================================
CREATE VIEW v_cuota_deuda AS
SELECT id_cuota,
       nro_base,
       nro_orden,
       fecha_vencimiento,
       monto_a_pagar,
       monto_abonado,
       (monto_a_pagar - monto_abonado) AS deuda
FROM cuota_social;