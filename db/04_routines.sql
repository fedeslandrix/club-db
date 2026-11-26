SET NAMES utf8mb4;
USE tp_bd_grupo2;

DELIMITER //

-- =====================================================
-- SP 1: sp_inscribir (existente - ajustado)
-- Bloquea socio, valida, inscribe y actualiza socio.deuda_actividad.
-- =====================================================
DROP PROCEDURE IF EXISTS sp_inscribir //
CREATE PROCEDURE sp_inscribir(
    IN p_nro_base INT, 
    IN p_nro_orden INT, 
    IN p_id_actividad INT, 
    IN p_simular_error BOOLEAN
)
BEGIN
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_costo DECIMAL(12,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Bloqueo pesimista del socio
    IF NOT EXISTS (SELECT 1 FROM socio WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El socio no existe';
    END IF;

    -- Evitar doble inscripción en la misma fecha
    IF EXISTS (SELECT 1 FROM se_inscribe_en WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden AND id_actividad = p_id_actividad AND fecha_inscripcion = CURDATE()) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El socio ya se encuentra inscripto en esta actividad en la fecha de hoy';
    END IF;

    -- Obtener tipo y costo
    SELECT a.tipo, COALESCE(aa.costo, 0.00) INTO v_tipo, v_costo
    FROM actividad a
    LEFT JOIN actividad_arancelada aa USING (id_actividad)
    WHERE a.id_actividad = p_id_actividad;

    IF v_tipo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La actividad no existe';
    END IF;

    -- Insertar inscripción (el trigger trg_inscribe_bi valida la categoría contra agrupa)
    INSERT INTO se_inscribe_en (nro_base, nro_orden, id_actividad, fecha_inscripcion)
    VALUES (p_nro_base, p_nro_orden, p_id_actividad, CURDATE());

    -- Si es arancelada, se suma a la deuda_actividad del socio
    IF v_tipo = 'ARANCELADA' THEN
        UPDATE socio 
           SET deuda_actividad = deuda_actividad + v_costo
         WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden;
    END IF;

    -- Simulación de error para probar ROLLBACK
    IF p_simular_error THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error simulado: Transacción abortada con ROLLBACK';
    END IF;

    COMMIT;
END //


-- =====================================================
-- SP 2: sp_alta_grupo_familiar (nuevo)
-- Participación total: GrupoFamiliar <-> Socio <-> SocioTitular
-- =====================================================
DROP PROCEDURE IF EXISTS sp_alta_grupo_familiar //
CREATE PROCEDURE sp_alta_grupo_familiar(
    IN p_nro_base INT,
    IN p_num_telefono VARCHAR(20),
    IN p_domicilio VARCHAR(150),
    IN p_nombre VARCHAR(100),
    IN p_correo VARCHAR(120),
    IN p_fecha_nac DATE,
    IN p_tipo_categoria VARCHAR(30),
    IN p_nro_celular VARCHAR(20)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Crear el grupo familiar
    INSERT INTO grupo_familiar (nro_base, num_telefono, domicilio, deuda_total)
    VALUES (p_nro_base, p_num_telefono, p_domicilio, 0.00);

    -- 2. Crear el socio titular (nro_orden = 0, is_titular = TRUE)
    INSERT INTO socio (nro_base, nro_orden, nombre, correo_electronico, fecha_nacimiento, deuda_actividad, is_titular, tipo_categoria)
    VALUES (p_nro_base, 0, p_nombre, p_correo, p_fecha_nac, 0.00, TRUE, p_tipo_categoria);

    -- 3. Crear el socio titular con su celular
    INSERT INTO socio_titular (nro_base, nro_orden, nro_celular)
    VALUES (p_nro_base, 0, p_nro_celular);

    COMMIT;
END //


-- =====================================================
-- SP 3: sp_alta_integrante_familiar (nuevo)
-- Calcula atómicamente el nro_orden sin condiciones de carrera.
-- =====================================================
DROP PROCEDURE IF EXISTS sp_alta_integrante_familiar //
CREATE PROCEDURE sp_alta_integrante_familiar(
    IN p_nro_base INT,
    IN p_nombre VARCHAR(100),
    IN p_correo VARCHAR(120),
    IN p_fecha_nac DATE,
    IN p_tipo_categoria VARCHAR(30)
)
BEGIN
    DECLARE v_sig_orden INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Bloqueo del grupo familiar
    IF NOT EXISTS (SELECT 1 FROM grupo_familiar WHERE nro_base = p_nro_base FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El grupo familiar no existe';
    END IF;

    -- Calcular el siguiente número de orden
    SELECT COALESCE(MAX(nro_orden), 0) + 1 INTO v_sig_orden
    FROM socio
    WHERE nro_base = p_nro_base;

    INSERT INTO socio (nro_base, nro_orden, nombre, correo_electronico, fecha_nacimiento, deuda_actividad, is_titular, tipo_categoria)
    VALUES (p_nro_base, v_sig_orden, p_nombre, p_correo, p_fecha_nac, 0.00, FALSE, p_tipo_categoria);

    COMMIT;
END //


-- =====================================================
-- SP 4: sp_alta_actividad (nuevo)
-- Especialización total y participación total en AGRUPA.
-- =====================================================
DROP PROCEDURE IF EXISTS sp_alta_actividad //
CREATE PROCEDURE sp_alta_actividad(
    IN p_descripcion VARCHAR(200),
    IN p_tipo VARCHAR(20),
    IN p_costo DECIMAL(12,2),
    IN p_frecuencia_pago VARCHAR(30),
    IN p_tipo_categoria_inicial VARCHAR(30)
)
BEGIN
    DECLARE v_id_actividad INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Validar tipo antes del INSERT (con ENUM un valor inválido lanza SQLSTATE 01000, no SQLEXCEPTION)
    IF p_tipo IS NULL OR p_tipo NOT IN ('ARANCELADA', 'NO_ARANCELADA') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Tipo de actividad inválido (use ARANCELADA o NO_ARANCELADA)';
    END IF;

    -- 1. Insertar en tabla padre
    INSERT INTO actividad (descripcion, tipo)
    VALUES (p_descripcion, p_tipo);

    SET v_id_actividad = LAST_INSERT_ID();

    -- 2. Insertar en subtipo
    IF p_tipo = 'ARANCELADA' THEN
        INSERT INTO actividad_arancelada (id_actividad, costo, frecuencia_pago)
        VALUES (v_id_actividad, p_costo, p_frecuencia_pago);
    ELSE
        INSERT INTO actividad_no_arancelada (id_actividad)
        VALUES (v_id_actividad);
    END IF;

    -- 3. Vincular categoría inicial en agrupa
    INSERT INTO agrupa (id_actividad, tipo_categoria)
    VALUES (v_id_actividad, p_tipo_categoria_inicial);

    COMMIT;
END //


-- =====================================================
-- SP 5: sp_liquidar_cuotas_mes (nuevo)
-- Emisión masiva de cuotas y actualización de grupo_familiar.deuda_total.
-- =====================================================
DROP PROCEDURE IF EXISTS sp_liquidar_cuotas_mes //
CREATE PROCEDURE sp_liquidar_cuotas_mes(
    IN p_fecha_periodo DATE,
    IN p_fecha_vencimiento DATE
)
BEGIN
    DECLARE v_id_monto INT;
    DECLARE v_fecha_inicio DATE;
    DECLARE v_ultimo_id INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Buscar el monto base vigente para la fecha del período
    SELECT id_monto_base, fecha_inicio INTO v_id_monto, v_fecha_inicio
    FROM monto_base
    WHERE p_fecha_periodo BETWEEN fecha_inicio AND fecha_fin
    LIMIT 1;

    IF v_id_monto IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: No existe un monto base vigente para el período indicado';
    END IF;

    -- RA 2: La cuota puede vencer luego del fin de vigencia, pero debe ser posterior a la fecha de inicio
    IF p_fecha_vencimiento < v_fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La fecha de vencimiento no puede ser anterior al inicio del monto base';
    END IF;

    -- Registrar el último id_cuota previo para identificar solo las cuotas nuevas
    SELECT COALESCE(MAX(id_cuota), 0) INTO v_ultimo_id
    FROM cuota_social;

    -- 1. Insertar cuota para cada titular activo que no la tenga ya
    INSERT INTO cuota_social (fecha_vencimiento, monto_abonado, monto_a_pagar, nro_base, nro_orden, id_monto_base)
    SELECT p_fecha_vencimiento, 0.00, 0.00, st.nro_base, st.nro_orden, v_id_monto
    FROM socio_titular st
    WHERE NOT EXISTS (
        SELECT 1 FROM cuota_social cs
        WHERE cs.nro_base = st.nro_base 
          AND cs.nro_orden = st.nro_orden 
          AND cs.fecha_vencimiento = p_fecha_vencimiento
          AND cs.id_monto_base = v_id_monto
    );

    -- 2. Actualizar deuda_total solo de los grupos con cuotas recién generadas
    UPDATE grupo_familiar gf
    JOIN cuota_social cs
      ON cs.nro_base = gf.nro_base
    SET gf.deuda_total = gf.deuda_total + cs.monto_a_pagar
    WHERE cs.id_cuota > v_ultimo_id
      AND cs.fecha_vencimiento = p_fecha_vencimiento
      AND cs.id_monto_base = v_id_monto;

    COMMIT;
END //


-- =====================================================
-- SP 6: sp_registrar_pago_cuota (nuevo)
-- Bloquea la cuota, valida saldo y descuenta de grupo_familiar.deuda_total.
-- =====================================================
DROP PROCEDURE IF EXISTS sp_registrar_pago_cuota //
CREATE PROCEDURE sp_registrar_pago_cuota(
    IN p_id_cuota INT,
    IN p_monto DECIMAL(12,2)
)
BEGIN
    DECLARE v_abonado DECIMAL(12,2);
    DECLARE v_a_pagar DECIMAL(12,2);
    DECLARE v_nro_base INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_monto <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El monto a abonar debe ser mayor a 0';
    END IF;

    -- Bloqueo pesimista de la cuota
    SELECT monto_abonado, monto_a_pagar, nro_base 
      INTO v_abonado, v_a_pagar, v_nro_base
    FROM cuota_social
    WHERE id_cuota = p_id_cuota
    FOR UPDATE;

    IF v_a_pagar IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La cuota social especificada no existe';
    END IF;

    IF (v_abonado + p_monto) > v_a_pagar THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El monto ingresado excede el saldo adeudado de la cuota';
    END IF;

    -- Registrar el pago
    UPDATE cuota_social
       SET monto_abonado = monto_abonado + p_monto
     WHERE id_cuota = p_id_cuota;

    -- Descontar de la deuda_total del grupo familiar
    UPDATE grupo_familiar
       SET deuda_total = GREATEST(0.00, deuda_total - p_monto)
     WHERE nro_base = v_nro_base;

    COMMIT;
END //


-- =====================================================
-- SP 7: sp_registrar_pago_arancel (nuevo)
-- Pago total de arancel (Hipótesis 2) y descuento de socio.deuda_actividad.
-- =====================================================
DROP PROCEDURE IF EXISTS sp_registrar_pago_arancel //
CREATE PROCEDURE sp_registrar_pago_arancel(
    IN p_nro_base INT,
    IN p_nro_orden INT,
    IN p_id_actividad INT,
    IN p_fecha DATE
)
BEGIN
    DECLARE v_costo DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Bloqueo del socio
    IF NOT EXISTS (SELECT 1 FROM socio WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El socio no existe';
    END IF;

    -- Validar inscripción
    IF NOT EXISTS (SELECT 1 FROM se_inscribe_en WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden AND id_actividad = p_id_actividad) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El socio no se encuentra inscripto en esta actividad';
    END IF;

    -- Obtener costo arancelado
    SELECT costo INTO v_costo
    FROM actividad_arancelada
    WHERE id_actividad = p_id_actividad;

    IF v_costo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La actividad no es arancelada';
    END IF;

    -- Hipótesis 2: pago único sin duplicados
    IF EXISTS (SELECT 1 FROM abona WHERE id_actividad = p_id_actividad AND nro_base = p_nro_base AND nro_orden = p_nro_orden) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El arancel de esta actividad ya fue abonado previamente';
    END IF;

    -- Insertar en abona
    INSERT INTO abona (id_actividad, nro_orden, nro_base, fecha)
    VALUES (p_id_actividad, p_nro_orden, p_nro_base, COALESCE(p_fecha, CURDATE()));

    -- Descontar únicamente de la deuda_actividad del socio
    UPDATE socio
       SET deuda_actividad = GREATEST(0.00, deuda_actividad - v_costo)
     WHERE nro_base = p_nro_base AND nro_orden = p_nro_orden;

    COMMIT;
END //

DELIMITER ;