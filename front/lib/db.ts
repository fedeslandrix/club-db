import mysql from 'mysql2/promise';

const g = globalThis as unknown as { pool?: mysql.Pool };

export const pool =
  g.pool ??
  (g.pool = mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: +(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'doctorado',
    database: process.env.DB_NAME || 'tp_bd_grupo2',
    dateStrings: true,
  }));

export async function json(fn: () => Promise<unknown>) {
  try {
    return Response.json(await fn());
  } catch (e: any) {
    return Response.json({ error: e.sqlMessage || e.message }, { status: 400 });
  }
}

export const run = async (sql: string) => (await pool.query(sql))[0];
