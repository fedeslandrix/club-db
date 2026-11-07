import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';
export const GET = () =>
  json(() => run('SELECT nro_base, nro_orden, nombre, tipo_categoria FROM socio ORDER BY nro_base, nro_orden'));
