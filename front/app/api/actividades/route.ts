import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';
export const GET = () =>
  json(() =>
    run(`SELECT a.id_actividad, a.descripcion, a.tipo, aa.costo
         FROM actividad a LEFT JOIN actividad_arancelada aa USING (id_actividad)
         ORDER BY a.id_actividad`),
  );
