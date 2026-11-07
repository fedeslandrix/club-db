-- 04_routines.sql
SET NAMES utf8mb4;
USE tp_bd_grupo2;

DELIMITER //

-- Inscripción transaccional: valida, inscribe y (si es arancelada) suma la deuda.
-- El trigger trg_inscribe_bi valida la categoría; cualquier error hace ROLLBACK y se re-lanza.
CREATE PROCEDURE sp_inscribir(IN p_nro_base INT, IN p_nro_orden INT, IN p_id_actividad INT, IN p_simular_error BOOLEAN)
BEGIN
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_costo DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM socio WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El socio no existe';
    END IF;

    SELECT a.tipo, aa.costo INTO v_tipo, v_costo
    FROM actividad a
    LEFT JOIN actividad_arancelada aa USING (id_actividad)
    WHERE a.id_actividad = p_id_actividad;

    IF v_tipo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La actividad no existe';
    END IF;

    INSERT INTO se_inscribe_en (nro_base, nro_orden, id_actividad, fecha_inscripcion)
    VALUES (p_nro_base, p_nro_orden, p_id_actividad, CURDATE());

    IF v_tipo = 'ARANCELADA' THEN
        UPDATE socio SET deuda_actividad = deuda_actividad + v_costo
        WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden;
    END IF;

    -- Demo de ROLLBACK: falla después de haber modificado datos, para ver que se deshacen
    IF p_simular_error THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error simulado después del INSERT y el UPDATE';
    END IF;

    COMMIT;
END //

DELIMITER ;
