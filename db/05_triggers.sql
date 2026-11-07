-- =====================================================
-- TP Base de Datos - GRUPO 2
-- 02_triggers.sql : restricciones adicionales (RA) implementadas con triggers
-- Ejecutar DESPUÉS de 01_ddl.sql (el cliente tiene que soportar DELIMITER)
-- =====================================================
SET NAMES utf8mb4;
USE tp_bd_grupo2;

-- =====================================================
-- TRIGGERS (restricciones adicionales)
-- =====================================================
DELIMITER $$

-- -----------------------------------------------------
-- RA 1, 2 y 3: SOCIO TITULAR
--   - NroOrden = 0
--   - el socio debe estar marcado is_titular = TRUE
--   - su categoría debe ser Mayores o Vitalicios
--   (ajustar los nombres si en la tabla categoria están escritos distinto)
-- -----------------------------------------------------
CREATE TRIGGER trg_socio_titular_bi
BEFORE INSERT ON socio_titular
FOR EACH ROW
BEGIN
    DECLARE v_es_titular BOOLEAN;
    DECLARE v_cat VARCHAR(30);

    IF NEW.nro_orden <> 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el socio titular debe tener NroOrden = 0';
    END IF;

    SELECT is_titular, tipo_categoria
      INTO v_es_titular, v_cat
      FROM socio
     WHERE nro_base = NEW.nro_base AND nro_orden = NEW.nro_orden;

    IF v_es_titular IS NULL OR v_es_titular = FALSE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el socio debe tener is_titular = TRUE para ser socio titular';
    END IF;

    IF v_cat NOT IN ('Mayores', 'Vitalicios') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el socio titular debe ser de categoria Mayores o Vitalicios';
    END IF;
END$$

-- Que no se pueda cambiar is_titular / categoría de un socio que ya es titular
CREATE TRIGGER trg_socio_bu
BEFORE UPDATE ON socio
FOR EACH ROW
BEGIN
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
END$$

-- -----------------------------------------------------
-- RA 4: la categoría del socio debe estar asociada a la actividad (AGRUPA)
-- -----------------------------------------------------
CREATE TRIGGER trg_inscribe_bi
BEFORE INSERT ON se_inscribe_en
FOR EACH ROW
BEGIN
    DECLARE v_cat VARCHAR(30);

    SELECT tipo_categoria INTO v_cat
      FROM socio
     WHERE nro_base = NEW.nro_base AND nro_orden = NEW.nro_orden;

    IF NOT EXISTS (SELECT 1 FROM agrupa
                    WHERE id_actividad = NEW.id_actividad
                      AND tipo_categoria = v_cat) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la categoria del socio no esta asociada a la actividad';
    END IF;
END$$

CREATE TRIGGER trg_inscribe_bu
BEFORE UPDATE ON se_inscribe_en
FOR EACH ROW
BEGIN
    DECLARE v_cat VARCHAR(30);

    SELECT tipo_categoria INTO v_cat
      FROM socio
     WHERE nro_base = NEW.nro_base AND nro_orden = NEW.nro_orden;

    IF NOT EXISTS (SELECT 1 FROM agrupa
                    WHERE id_actividad = NEW.id_actividad
                      AND tipo_categoria = v_cat) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: la categoria del socio no esta asociada a la actividad';
    END IF;
END$$

-- -----------------------------------------------------
-- RA 6: disjunción ARANCELADA / NO ARANCELADA y coherencia con ACTIVIDAD.tipo
-- -----------------------------------------------------
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

-- No dejar cambiar ACTIVIDAD.tipo si ya existe en el subtipo contrario
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

-- -----------------------------------------------------
-- RA 7: vigencias de MONTO BASE sin solapamiento
-- -----------------------------------------------------
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

CREATE TRIGGER trg_monto_base_bu
BEFORE UPDATE ON monto_base
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM monto_base
                WHERE id_monto_base <> OLD.id_monto_base
                  AND fecha_inicio <= NEW.fecha_fin
                  AND fecha_fin    >= NEW.fecha_inicio) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el periodo de vigencia se solapa con otro MONTO BASE';
    END IF;
END$$

-- -----------------------------------------------------
-- RA 7 y 9: CUOTA SOCIAL
--   - el monto base debe estar vigente en la fecha de vencimiento
--   - monto_a_pagar es derivado: valor del monto base ajustado por el
--     descuento de la categoría del titular. Se calcula siempre acá.
-- -----------------------------------------------------
CREATE TRIGGER trg_cuota_bi
BEFORE INSERT ON cuota_social
FOR EACH ROW
BEGIN
    DECLARE v_valor DECIMAL(12,2);
    DECLARE v_desc  DECIMAL(6,2);

    IF NOT EXISTS (SELECT 1 FROM monto_base
                    WHERE id_monto_base = NEW.id_monto_base
                      AND NEW.fecha_vencimiento BETWEEN fecha_inicio AND fecha_fin) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el MONTO BASE no esta vigente en la fecha de vencimiento';
    END IF;

    SELECT mb.valor, c.descuento
      INTO v_valor, v_desc
      FROM monto_base mb, socio s
      JOIN categoria c ON c.tipo_categoria = s.tipo_categoria
     WHERE mb.id_monto_base = NEW.id_monto_base
       AND s.nro_base  = NEW.nro_base
       AND s.nro_orden = NEW.nro_orden;

    SET NEW.monto_a_pagar = ROUND(v_valor * (1 - v_desc / 100), 2);
END$$

CREATE TRIGGER trg_cuota_bu
BEFORE UPDATE ON cuota_social
FOR EACH ROW
BEGIN
    DECLARE v_valor DECIMAL(12,2);
    DECLARE v_desc  DECIMAL(6,2);

    IF NOT EXISTS (SELECT 1 FROM monto_base
                    WHERE id_monto_base = NEW.id_monto_base
                      AND NEW.fecha_vencimiento BETWEEN fecha_inicio AND fecha_fin) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el MONTO BASE no esta vigente en la fecha de vencimiento';
    END IF;

    SELECT mb.valor, c.descuento
      INTO v_valor, v_desc
      FROM monto_base mb, socio s
      JOIN categoria c ON c.tipo_categoria = s.tipo_categoria
     WHERE mb.id_monto_base = NEW.id_monto_base
       AND s.nro_base  = NEW.nro_base
       AND s.nro_orden = NEW.nro_orden;

    SET NEW.monto_a_pagar = ROUND(v_valor * (1 - v_desc / 100), 2);
END$$

-- -----------------------------------------------------
-- RA 8: cronograma válido (TRABAJA EN)
--   - el profesional debe estar habilitado para la actividad
--   - el área debe permitir la actividad
-- -----------------------------------------------------
CREATE TRIGGER trg_trabaja_en_bi
BEFORE INSERT ON trabaja_en
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM puede_dictar
                    WHERE id_profesional = NEW.id_profesional
                      AND id_actividad   = NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el profesional no esta habilitado para dictar la actividad';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM permite
                    WHERE id_area      = NEW.id_area
                      AND id_actividad = NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el area no permite desarrollar la actividad';
    END IF;
END$$

CREATE TRIGGER trg_trabaja_en_bu
BEFORE UPDATE ON trabaja_en
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM puede_dictar
                    WHERE id_profesional = NEW.id_profesional
                      AND id_actividad   = NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el profesional no esta habilitado para dictar la actividad';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM permite
                    WHERE id_area      = NEW.id_area
                      AND id_actividad = NEW.id_actividad) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RA: el area no permite desarrollar la actividad';
    END IF;
END$$

DELIMITER ;