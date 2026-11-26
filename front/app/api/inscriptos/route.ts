import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';

export const GET = (req: Request) =>
  json(() => {
    const raw = new URL(req.url).searchParams.get('id_actividad');
    if (raw !== null && raw !== '') {
      const idActividad = Number(raw);
      if (!Number.isInteger(idActividad) || idActividad <= 0) {
        throw new Error('id_actividad inválido');
      }
      return run(
        `SELECT nro_base, nro_orden, nombre, tipo_categoria,
                id_actividad, actividad, fecha_inscripcion
         FROM v_nomina_inscriptos_profesor
         WHERE id_actividad = ?
         ORDER BY nro_base, nro_orden`,
        [idActividad],
      );
    }
    return run(
      `SELECT nro_base, nro_orden, nombre, tipo_categoria,
              id_actividad, actividad, fecha_inscripcion
       FROM v_nomina_inscriptos_profesor
       ORDER BY nro_base, nro_orden, id_actividad`,
    );
  });

