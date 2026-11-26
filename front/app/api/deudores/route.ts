import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';

// Consigna 1: titulares con cuotas del año en curso adeudadas
const Q = `SELECT v2.nro_base, v2.titular, v2.fecha_nacimiento, v2.correo_titular,
       v2.celular_titular, v2.domicilio, v2.num_telefono,
       v2.cantidad_integrantes,
       SUM(v1.deuda) AS total_adeudado
FROM v_cuota_deuda_extended v1,
     v_estado_cuenta_grupo_familiar v2
WHERE v1.nro_base = v2.nro_base
  AND v1.deuda > 0
  AND YEAR(v1.fecha_vencimiento) = YEAR(CURDATE())
GROUP BY v2.nro_base, v2.titular, v2.fecha_nacimiento, v2.correo_titular,
         v2.celular_titular, v2.domicilio, v2.num_telefono, v2.cantidad_integrantes`;

export const GET = () => json(() => run(Q));
