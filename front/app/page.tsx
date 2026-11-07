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
  const [r1, setR1] = useState<Result>();
  const [r2, setR2] = useState<Result>();
  const [r3, setR3] = useState<Result>();
  const [rIns, setRIns] = useState<Result>();
  const [r4, setR4] = useState<Result>();
  const [socios, setSocios] = useState<any[]>([]);
  const [acts, setActs] = useState<any[]>([]);
  const [socio, setSocio] = useState('');
  const [act, setAct] = useState('');
  const [simular, setSimular] = useState(false);
  const [sql, setSql] = useState('SELECT * FROM socio;');

  useEffect(() => {
    fetch('/api/socios').then((r) => r.json()).then((s) => { if (Array.isArray(s)) { setSocios(s); if (s[0]) setSocio(`${s[0].nro_base}/${s[0].nro_orden}`); } });
    fetch('/api/actividades').then((r) => r.json()).then((a) => { if (Array.isArray(a)) { setActs(a); if (a[0]) setAct(String(a[0].id_actividad)); } });
  }, []);

  const inscribir = async () => {
    const [nro_base, nro_orden] = socio.split('/').map(Number);
    setR3(undefined);
    setR3(await post('/api/inscribir', { nro_base, nro_orden, id_actividad: +act, simular_error: simular }));
  };

  return (
    <>
      <header>
        <h1>Club Deportivo Doctores</h1>
        <p className="subtitle">Consultas, inscripciones y SQL libre sobre la base del Club Deportivo Doctores.</p>
      </header>

      <Section title="Titulares con cuotas adeudadas (año en curso)">
        <ActionButton onClick={async () => { setR1(undefined); setR1(await (await fetch('/api/deudores')).json()); }}>Ejecutar</ActionButton>
        <Out d={r1} />
      </Section>

      <Section title="Socios por categoría inscriptos en todas las actividades gratuitas (año pasado)">
        <ActionButton onClick={async () => { setR2(undefined); setR2(await (await fetch('/api/gratuitas')).json()); }}>Ejecutar</ActionButton>
        <Out d={r2} />
      </Section>

      <Section title="Inscribir socio a actividad (transacción)">
        <div className="row">
        <select value={socio} onChange={(e) => setSocio(e.target.value)}>
          {socios.map((s) => (
            <option key={`${s.nro_base}/${s.nro_orden}`} value={`${s.nro_base}/${s.nro_orden}`}>
              {s.nro_base}/{String(s.nro_orden).padStart(2, '0')} {s.nombre} ({s.tipo_categoria})
            </option>
          ))}
        </select>
        <select value={act} onChange={(e) => setAct(e.target.value)}>
          {acts.map((a) => (
            <option key={a.id_actividad} value={a.id_actividad}>{a.id_actividad} {a.descripcion} [{a.tipo}]</option>
          ))}
        </select>
        <ActionButton onClick={inscribir}>Inscribir</ActionButton>
        </div>
        <label className="check">
          <input type="checkbox" checked={simular} onChange={(e) => setSimular(e.target.checked)} />
          Forzar error al final de la transacción (para ver el ROLLBACK)
        </label>
        <Out d={r3} />
        {r3?.antes && (
          <div className="table-wrap">
            <table>
              <thead><tr><th>Estado del socio</th><th>Deuda actividades</th><th>Inscripciones</th><th>En esta actividad</th></tr></thead>
              <tbody>
                <tr><td>Antes</td><td>{r3.antes.deuda}</td><td>{r3.antes.inscripciones}</td><td>{r3.antes.en_esta_actividad}</td></tr>
                <tr><td>Después</td><td>{r3.despues.deuda}</td><td>{r3.despues.inscripciones}</td><td>{r3.despues.en_esta_actividad}</td></tr>
              </tbody>
            </table>
          </div>
        )}
      </Section>

      <Section title="Socios inscriptos en actividades">
        <p className="hint">Consultalo antes y después de inscribir: con COMMIT aparece una fila nueva, con ROLLBACK la lista no cambia.</p>
        <ActionButton onClick={async () => { setRIns(undefined); setRIns(await (await fetch('/api/inscriptos')).json()); }}>Ver inscriptos</ActionButton>
        {Array.isArray(rIns) && <p className="hint">{rIns.length} inscripciones</p>}
        <Out d={rIns} />
      </Section>

      <Section title="SQL libre">
        <textarea value={sql} onChange={(e) => setSql(e.target.value)} />
        <ActionButton onClick={async () => { setR4(undefined); setR4(await post('/api/query', { sql })); }}>Ejecutar</ActionButton>
        <Out d={r4} />
      </Section>
    </>
  );
}
