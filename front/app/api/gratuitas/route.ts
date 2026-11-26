import { json, run } from "../../../lib/db";
export const dynamic = "force-dynamic";

// Consigna 2: socios inscriptos en TODAS las actividades gratuitas el año pasado, por categoría
const Q = `SELECT s.tipo_categoria,
       COUNT(*) AS cantidad_socios
FROM socio s
WHERE NOT EXISTS (
        SELECT 1
        FROM actividad_no_arancelada na, agrupa ag
        WHERE ag.id_actividad   = na.id_actividad
          AND ag.tipo_categoria = s.tipo_categoria
          AND NOT EXISTS (
                SELECT 1
                FROM se_inscribe_en i
                WHERE i.nro_base     = s.nro_base
                  AND i.nro_orden    = s.nro_orden
                  AND i.id_actividad = na.id_actividad
                  AND YEAR(i.fecha_inscripcion) = YEAR(CURDATE()) - 1))
GROUP BY s.tipo_categoria`;

export const GET = () => json(() => run(Q));