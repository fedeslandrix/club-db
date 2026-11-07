import { pool } from '../../../lib/db';

// La transacción vive en la base de datos (sp_inscribir); acá solo se invoca.
// Antes y después se lee el estado del socio para poder mostrar el efecto del COMMIT / ROLLBACK.
const estado = async (nro_base: number, nro_orden: number, id_actividad: number) => {
  const [r]: any = await pool.query(
    `SELECT s.deuda_actividad AS deuda,
            (SELECT COUNT(*) FROM se_inscribe_en WHERE nro_base=s.nro_base AND nro_orden=s.nro_orden) AS inscripciones,
            (SELECT COUNT(*) FROM se_inscribe_en WHERE nro_base=s.nro_base AND nro_orden=s.nro_orden AND id_actividad=?) AS en_esta_actividad
     FROM socio s WHERE s.nro_base=? AND s.nro_orden=?`,
    [id_actividad, nro_base, nro_orden]);
  return r[0];
};

export async function POST(req: Request) {
  const { nro_base, nro_orden, id_actividad, simular_error } = await req.json();
  const antes = await estado(nro_base, nro_orden, id_actividad);
  try {
    await pool.query('CALL sp_inscribir(?,?,?,?)', [nro_base, nro_orden, id_actividad, !!simular_error]);
    const despues = await estado(nro_base, nro_orden, id_actividad);
    return Response.json({ ok: true, mensaje: 'Inscripción realizada (COMMIT)', antes, despues });
  } catch (e: any) {
    const despues = await estado(nro_base, nro_orden, id_actividad);
    return Response.json({ error: (e.sqlMessage || e.message) + ' (ROLLBACK)', antes, despues }, { status: 400 });
  }
}
