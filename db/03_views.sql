-- 03_views.sql
USE club;

CREATE OR REPLACE VIEW vista_socios_resumen AS
SELECT 
    id,
    CONCAT(nombre, ' ', apellido) AS nombre_completo,
    email,
    fecha_alta
FROM socios;
