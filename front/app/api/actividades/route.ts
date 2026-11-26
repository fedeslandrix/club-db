import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';
export const GET = () =>
  json(() =>
    run(`SELECT *
         FROM v_cronograma_actividades
         ORDER BY id_actividad`),
  );
