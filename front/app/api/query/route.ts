import { json, pool } from '../../../lib/db';

// Query libre (uso local/académico únicamente)
export const POST = (req: Request) =>
  json(async () => {
    const { sql } = await req.json();
    if (!String(sql || '').trim()) throw new Error('Query vacío');
    const [rows] = await pool.query(String(sql));
    return Array.isArray(rows) ? rows : [rows];
  });
