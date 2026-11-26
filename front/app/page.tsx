'use client';
import { useEffect, useState } from 'react';

type Result = any;

function Out({ d }: { d: Result }) {
  if (!d) return null;
  if (d.error) return <p className="msg err">{d.error}</p>;
  if (d.mensaje) return <p className="msg ok">{d.mensaje}</p>;
  if (!d.length) return <p className="empty">Sin resultados</p>;
  const keys = Object.keys(d[0]);
  return (
    <div className="table-wrap"><table>
      <thead><tr>{keys.map((k) => <th key={k}>{k}</th>)}</tr></thead>
      <tbody>
        {d.map((r: any, i: number) => (
          <tr key={i}>{keys.map((k) => <td key={k}>{String(r[k] ?? '')}</td>)}</tr>
        ))}
      </tbody>
    </table></div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2>{title}</h2>
      <div className="body">{children}</div>
    </section>
  );
}

function ActionButton({ onClick, children }: { onClick: () => Promise<void>; children: React.ReactNode }) {
  const [busy, setBusy] = useState(false);
  const click = async () => {
    if (busy) return;
    setBusy(true);
    // Duración mínima para que la animación se perciba aunque la consulta sea instantánea
    const min = new Promise((r) => setTimeout(r, 450));
    try { await Promise.all([onClick(), min]); } finally { setBusy(false); }
  };
  return (
    <button onClick={click} disabled={busy} aria-busy={busy} className={busy ? 'busy' : undefined}>
      {busy && <span className="spinner" aria-hidden="true" />}
      {busy ? 'Consultando…' : children}
    </button>
  );
}

const post = (url: string, body: unknown) =>
  fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then((r) => r.json());

export default function Page() {
  const [rDeudores, setRDeudores] = useState<Result>();
  const [rGratuitas, setRGratuitas] = useState<Result>();
  const [rCronograma, setRCronograma] = useState<Result>();
  const [rInscriptos, setRInscriptos] = useState<Result>();
  const [rQuery, setRQuery] = useState<Result>();
  const [acts, setActs] = useState<any[]>([]);
  const [actFiltro, setActFiltro] = useState('');
  const [sql, setSql] = useState('SELECT * FROM socio;');

  useEffect(() => {
    fetch('/api/actividades').then((r) => r.json()).then((a) => {
      if (Array.isArray(a)) {
        const unique = Array.from(new Map(a.map((x: any) => [x.id_actividad, x])).values());
        setActs(unique);
      }
    });
  }, []);

  return (
    <>
      <header>
        <h1>Club Deportivo Doctores</h1>
        <p className="subtitle">Consultas, vistas y SQL libre sobre la base del Club Deportivo Doctores.</p>
      </header>

      <Section title="Titulares con cuotas adeudadas (año en curso)">
        <ActionButton onClick={async () => { setRDeudores(undefined); setRDeudores(await (await fetch('/api/deudores')).json()); }}>Ejecutar</ActionButton>
        <Out d={rDeudores} />
      </Section>

      <Section title="Socios por categoría inscriptos en todas las actividades gratuitas (año pasado)">
        <ActionButton onClick={async () => { setRGratuitas(undefined); setRGratuitas(await (await fetch('/api/gratuitas')).json()); }}>Ejecutar</ActionButton>
        <Out d={rGratuitas} />
      </Section>

      <Section title="Cronograma de actividades">
        <ActionButton onClick={async () => { setRCronograma(undefined); setRCronograma(await (await fetch('/api/actividades')).json()); }}>Ver cronograma</ActionButton>
        <Out d={rCronograma} />
      </Section>

      <Section title="Nómina de inscriptos por actividad">
        <div className="row">
          <select value={actFiltro} onChange={(e) => setActFiltro(e.target.value)}>
            <option value="">Todas las actividades</option>
            {acts.map((a) => (
              <option key={a.id_actividad} value={a.id_actividad}>{a.id_actividad} {a.actividad ?? a.descripcion} [{a.tipo}]</option>
            ))}
          </select>
          <ActionButton onClick={async () => {
            setRInscriptos(undefined);
            const url = actFiltro ? `/api/inscriptos?id_actividad=${encodeURIComponent(actFiltro)}` : '/api/inscriptos';
            setRInscriptos(await (await fetch(url)).json());
          }}>Ver inscriptos</ActionButton>
        </div>
        {Array.isArray(rInscriptos) && (
          <p className="hint" style={{ marginTop: '.75rem', marginBottom: 0 }}>{rInscriptos.length} inscripciones</p>
        )}
        <Out d={rInscriptos} />
      </Section>

      <Section title="SQL libre">
        <textarea value={sql} onChange={(e) => setSql(e.target.value)} />
        <ActionButton onClick={async () => { setRQuery(undefined); setRQuery(await post('/api/query', { sql })); }}>Ejecutar</ActionButton>
        <Out d={rQuery} />
      </Section>
    </>
  );
}
