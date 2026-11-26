-- =====================================================
-- TP Base de Datos - GRUPO 2
-- 05_triggers.sql : restricciones adicionales (RA) e invariantes con triggers
-- Ejecutar DESPUÉS de 01_schema.sql (el cliente tiene que soportar DELIMITER)
-- =====================================================
SET NAMES utf8mb4;
USE tp_bd_grupo2;

-- =====================================================
-- TRIGGERS (restricciones adicionales e invariantes)
-- =====================================================
DELIMITER $$

-- Valida que el socio titular tenga nro_orden = 0 y categoría Mayores o Vitalicios
DROP TRIGGER IF EXISTS trg_socio_titular_bi$$
CREATE TRIGGER trg_socio_titular_bi
BEFORE INSERT ON socio_titular
FOR EACH ROW
BEGIN
    DECLARE v_cat VARCHAR(30);

    IF NEW.nro_orden <> 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el socio titular debe tener NroOrden = 0';
    END IF;

    SELECT tipo_categoria
      INTO v_cat
      FROM socio
     WHERE nro_base = NEW.nro_base AND nro_orden = NEW.nro_orden;

    IF v_cat NOT IN ('Mayores', 'Vitalicios') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el socio titular debe ser de categoria Mayores o Vitalicios';
    END IF;
END$$

-- Mantiene coherencia de socio titular y bloquea cambios de categoría incompatibles con sus inscripciones
DROP TRIGGER IF EXISTS trg_socio_bu$$
CREATE TRIGGER trg_socio_bu
BEFORE UPDATE ON socio
FOR EACH ROW
BEGIN
    -- Coherencia si el socio es titular
    IF EXISTS (SELECT 1 FROM socio_titular
                WHERE nro_base = OLD.nro_base AND nro_orden = OLD.nro_orden) THEN
        IF NEW.is_titular = FALSE THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RA: un socio presente en SOCIO TITULAR debe tener is_titular = TRUE';
        END IF;
        IF NEW.tipo_categoria NOT IN ('Mayores', 'Vitalicios') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RA: el socio titular debe ser de categoria Mayores o Vitalicios';
        END IF;
    END IF;

    -- Si cambia la categoría, verificar que no queden inscripciones incompatibles en AGRUPA
    IF NEW.tipo_categoria <> OLD.tipo_categoria THEN
        IF EXISTS (
            SELECT 1
              FROM se_inscribe_en i
             WHERE i.nro_base  = OLD.nro_base
               AND i.nro_orden = OLD.nro_orden
               AND i.id_actividad NOT IN (
                   SELECT a.id_actividad
                     FROM agrupa a
                    WHERE a.tipo_categoria = NEW.tipo_categoria
               )
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RA: no se puede cambiar la categoria del socio porque tiene inscripciones incompatibles en AGRUPA';
        END IF;
    END IF;
END$$

-- Verifica al inscribir que la categoría del socio esté habilitada para la actividad en AGRUPA
DROP TRIGGER IF EXISTS trg_inscribe_bi$$
CREATE TRIGGER trg_inscribe_bi
BEFORE INSERT ON se_inscribe_en
FOR EACH ROW
BEGIN
    DECLARE v_cat VARCHAR(30);

    SELECT tipo_categoria INTO v_cat
      FROM socio
     WHERE nro_base = NEW.nro_base AND nro_orden = NEW.nro_orden;

    IF NOT EXISTS (SELECT 1 FROM agrupa
                    WHERE id_actividad   = NEW.id_actividad
                      AND tipo_categoria = v_cat) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la categoria del socio no esta asociada a la actividad';
    END IF;
END$$

-- Verifica al modificar una inscripción que la categoría del socio siga habilitada en AGRUPA
DROP TRIGGER IF EXISTS trg_inscribe_bu$$
CREATE TRIGGER trg_inscribe_bu
BEFORE UPDATE ON se_inscribe_en
FOR EACH ROW
BEGIN
    DECLARE v_cat VARCHAR(30);

    SELECT tipo_categoria INTO v_cat
      FROM socio
     WHERE nro_base = NEW.nro_base AND nro_orden = NEW.nro_orden;

    IF NOT EXISTS (SELECT 1 FROM agrupa
                    WHERE id_actividad   = NEW.id_actividad
                      AND tipo_categoria = v_cat) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la categoria del socio no esta asociada a la actividad';
    END IF;
END$$

-- Impide quitar una categoría de AGRUPA si hay socios de esa categoría inscriptos en la actividad
DROP TRIGGER IF EXISTS trg_agrupa_bd$$
CREATE TRIGGER trg_agrupa_bd
BEFORE DELETE ON agrupa
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
          FROM se_inscribe_en i
          JOIN socio s
            ON s.nro_base  = i.nro_base
           AND s.nro_orden = i.nro_orden
         WHERE i.id_actividad   = OLD.id_actividad
           AND s.tipo_categoria = OLD.tipo_categoria
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: no se puede quitar la categoria de la actividad porque existen socios de esa categoria inscriptos';
    END IF;
END$$

-- RA 5: impide registrar un pago de arancel si el socio no está inscripto en la actividad
DROP TRIGGER IF EXISTS trg_abona_bi$$
CREATE TRIGGER trg_abona_bi
BEFORE INSERT ON abona
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM se_inscribe_en
                    WHERE nro_base     = NEW.nro_base
                      AND nro_orden    = NEW.nro_orden
                      AND id_actividad = NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el socio debe estar inscripto en la actividad para poder abonarla';
    END IF;
END$$

-- RA 5: mantiene la exigencia de inscripción si se modifica socio o actividad en un pago
DROP TRIGGER IF EXISTS trg_abona_bu$$
CREATE TRIGGER trg_abona_bu
BEFORE UPDATE ON abona
FOR EACH ROW
BEGIN
    IF NEW.nro_base <> OLD.nro_base
       OR NEW.nro_orden <> OLD.nro_orden
       OR NEW.id_actividad <> OLD.id_actividad THEN
        IF NOT EXISTS (SELECT 1 FROM se_inscribe_en
                        WHERE nro_base     = NEW.nro_base
                          AND nro_orden    = NEW.nro_orden
                          AND id_actividad = NEW.id_actividad) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RA: el socio debe estar inscripto en la actividad para poder abonarla';
        END IF;
    END IF;
END$$

-- Garantiza disjunción con NO ARANCELADA y coherencia con ACTIVIDAD.tipo = 'ARANCELADA'
DROP TRIGGER IF EXISTS trg_arancelada_bi$$
CREATE TRIGGER trg_arancelada_bi
BEFORE INSERT ON actividad_arancelada
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM actividad_no_arancelada WHERE id_actividad = NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la actividad ya es NO ARANCELADA (las subclases son disjuntas)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM actividad
                    WHERE id_actividad = NEW.id_actividad AND tipo = 'ARANCELADA') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: ACTIVIDAD.tipo debe ser ARANCELADA';
    END IF;
END$$

-- Hipótesis 5: hace inmutable frecuencia_pago una vez creada la actividad arancelada
DROP TRIGGER IF EXISTS trg_arancelada_bu$$
CREATE TRIGGER trg_arancelada_bu
BEFORE UPDATE ON actividad_arancelada
FOR EACH ROW
BEGIN
    IF NEW.frecuencia_pago <> OLD.frecuencia_pago THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la frecuencia de pago de una actividad arancelada es inmutable';
    END IF;
END$$

-- Garantiza disjunción con ARANCELADA y coherencia con ACTIVIDAD.tipo = 'NO_ARANCELADA'
DROP TRIGGER IF EXISTS trg_no_arancelada_bi$$
CREATE TRIGGER trg_no_arancelada_bi
BEFORE INSERT ON actividad_no_arancelada
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM actividad_arancelada WHERE id_actividad = NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la actividad ya es ARANCELADA (las subclases son disjuntas)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM actividad
                    WHERE id_actividad = NEW.id_actividad AND tipo = 'NO_ARANCELADA') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: ACTIVIDAD.tipo debe ser NO_ARANCELADA';
    END IF;
END$$

-- Impide cambiar ACTIVIDAD.tipo si la actividad ya existe en el subtipo contrario
DROP TRIGGER IF EXISTS trg_actividad_bu$$
CREATE TRIGGER trg_actividad_bu
BEFORE UPDATE ON actividad
FOR EACH ROW
BEGIN
    IF NEW.tipo <> 'ARANCELADA'
       AND EXISTS (SELECT 1 FROM actividad_arancelada WHERE id_actividad = OLD.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la actividad esta en ACTIVIDAD ARANCELADA, tipo debe ser ARANCELADA';
    END IF;
    IF NEW.tipo <> 'NO_ARANCELADA'
       AND EXISTS (SELECT 1 FROM actividad_no_arancelada WHERE id_actividad = OLD.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la actividad esta en ACTIVIDAD NO ARANCELADA, tipo debe ser NO_ARANCELADA';
    END IF;
END$$

-- Impide insertar un MONTO BASE cuyo período de vigencia se solape con otro existente
DROP TRIGGER IF EXISTS trg_monto_base_bi$$
CREATE TRIGGER trg_monto_base_bi
BEFORE INSERT ON monto_base
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM monto_base
                WHERE fecha_inicio <= NEW.fecha_fin
                  AND fecha_fin    >= NEW.fecha_inicio) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el periodo de vigencia se solapa con otro MONTO BASE';
    END IF;
END$$

-- Impide actualizar un MONTO BASE generando solapamiento con otro período vigente
DROP TRIGGER IF EXISTS trg_monto_base_bu$$
CREATE TRIGGER trg_monto_base_bu
BEFORE UPDATE ON monto_base
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM monto_base
                WHERE id_monto_base <> OLD.id_monto_base
                  AND fecha_inicio  <= NEW.fecha_fin
                  AND fecha_fin     >= NEW.fecha_inicio) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el periodo de vigencia se solapa con otro MONTO BASE';
    END IF;
END$$

-- Valida monto base no futuro y calcula monto_a_pagar sumando el aporte de todo el grupo familiar
DROP TRIGGER IF EXISTS trg_cuota_bi$$
CREATE TRIGGER trg_cuota_bi
BEFORE INSERT ON cuota_social
FOR EACH ROW
BEGIN
    DECLARE v_valor DECIMAL(12,2);
    DECLARE v_total DECIMAL(12,2);

    SELECT valor
      INTO v_valor
      FROM monto_base
     WHERE id_monto_base = NEW.id_monto_base
       AND fecha_inicio  <= NEW.fecha_vencimiento;

    IF v_valor IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el MONTO BASE no existe o su vigencia inicia despues de la fecha de vencimiento';
    END IF;

    SELECT ROUND(SUM(v_valor * (1 - c.descuento / 100)), 2)
      INTO v_total
      FROM socio s
      JOIN categoria c ON c.tipo_categoria = s.tipo_categoria
     WHERE s.nro_base = NEW.nro_base;

    IF v_total IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el grupo familiar no tiene socios registrados para calcular la cuota';
    END IF;

    SET NEW.monto_a_pagar = v_total;
END$$

-- Hace inmutable la cuota emitida, permitiendo modificar únicamente monto_abonado
DROP TRIGGER IF EXISTS trg_cuota_bu$$
CREATE TRIGGER trg_cuota_bu
BEFORE UPDATE ON cuota_social
FOR EACH ROW
BEGIN
    IF NEW.id_cuota <> OLD.id_cuota
       OR NEW.fecha_vencimiento <> OLD.fecha_vencimiento
       OR NEW.monto_a_pagar <> OLD.monto_a_pagar
       OR NEW.nro_base <> OLD.nro_base
       OR NEW.nro_orden <> OLD.nro_orden
       OR NEW.id_monto_base <> OLD.id_monto_base THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: una cuota emitida es inmutable; solo se permite actualizar monto_abonado';
    END IF;
END$$

-- Impide asignar dos actividades distintas en la misma área, período, días y horario al insertar
DROP TRIGGER IF EXISTS trg_trabaja_en_bi$$
CREATE TRIGGER trg_trabaja_en_bi
BEFORE INSERT ON trabaja_en
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM trabaja_en
                WHERE id_area      = NEW.id_area
                  AND periodo      = NEW.periodo
                  AND dias         = NEW.dias
                  AND horario      = NEW.horario
                  AND id_actividad <> NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el area ya tiene asignada otra actividad en ese periodo, dia y horario';
    END IF;
END$$

-- Impide asignar dos actividades distintas en la misma área, período, días y horario al actualizar
DROP TRIGGER IF EXISTS trg_trabaja_en_bu$$
CREATE TRIGGER trg_trabaja_en_bu
BEFORE UPDATE ON trabaja_en
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM trabaja_en
                WHERE id_area      = NEW.id_area
                  AND periodo      = NEW.periodo
                  AND dias         = NEW.dias
                  AND horario      = NEW.horario
                  AND id_actividad <> NEW.id_actividad
                  AND (id_profesional, id_actividad, id_area, dias, horario)
                      <> (OLD.id_profesional, OLD.id_actividad, OLD.id_area, OLD.dias, OLD.horario)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el area ya tiene asignada otra actividad en ese periodo, dia y horario';
    END IF;
END$$

DELIMITER ;
