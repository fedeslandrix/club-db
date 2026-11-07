import { json, run } from '../../../lib/db';
export const dynamic = 'force-dynamic';

// Consigna 2: socios inscriptos en TODAS las actividades gratuitas el año pasado, por categoría
const Q = `
SELECT s.tipo_categoria, COUNT(*) AS cantidad_socios
FROM socio s
WHERE (SELECT COUNT(DISTINCT i.id_actividad)
         FROM se_inscribe_en i
         JOIN actividad_no_arancelada na ON na.id_actividad = i.id_actividad
        WHERE i.nro_base = s.nro_base AND i.nro_orden = s.nro_orden
          AND YEAR(i.fecha_inscripcion) = YEAR(CURDATE()) - 1)
      = (SELECT COUNT(*) FROM actividad_no_arancelada)
  AND (SELECT COUNT(*) FROM actividad_no_arancelada) > 0
GROUP BY s.tipo_categoria`;

export const GET = () => json(() => run(Q));
