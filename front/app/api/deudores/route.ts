import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';

// Consigna 1: titulares con cuotas del año en curso adeudadas
const Q = `
SELECT s.nro_base, s.nro_orden, s.nombre, s.correo_electronico,
       gf.domicilio, gf.num_telefono,
       SUM(c.monto_a_pagar - c.monto_abonado) AS total_adeudado,
       (SELECT COUNT(*) FROM socio m WHERE m.nro_base = s.nro_base) AS cant_integrantes
FROM cuota_social c
JOIN socio s ON s.nro_base = c.nro_base AND s.nro_orden = c.nro_orden
JOIN grupo_familiar gf ON gf.nro_base = s.nro_base
WHERE YEAR(c.fecha_vencimiento) = YEAR(CURDATE())
  AND c.monto_a_pagar > c.monto_abonado
GROUP BY s.nro_base, s.nro_orden, s.nombre, s.correo_electronico, gf.domicilio, gf.num_telefono
ORDER BY total_adeudado DESC`;

export const GET = () => json(() => run(Q));
