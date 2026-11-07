import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';
export const GET = () =>
  json(() =>
    run(`SELECT s.nro_base, s.nro_orden, s.nombre, s.tipo_categoria,
                a.id_actividad, a.descripcion AS actividad, a.tipo, i.fecha_inscripcion
         FROM se_inscribe_en i
         JOIN socio s USING (nro_base, nro_orden)
         JOIN actividad a USING (id_actividad)
         ORDER BY s.nro_base, s.nro_orden, a.id_actividad`));

