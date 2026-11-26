-- =====================================================
-- TP Base de Datos - GRUPO 2
-- 09_test_routines.sql : Suite completa de pruebas unitarias automatizadas (14 tests)
-- Cada uno de los 7 Stored Procedures cuenta con:
--   1) Un test de Caso Exitoso (Happy Path / COMMIT)
--   2) Un test de Caso de Error Controlado (Negative / ROLLBACK)
-- Rango de prueba aislado: grupos 600..609 (no interfiere con 504..508 ni con 901..950).
-- =====================================================
SET NAMES utf8mb4;
USE tp_bd_grupo2;

-- 1. Limpieza de pruebas anteriores
DELETE FROM abona          WHERE nro_base BETWEEN 600 AND 609;
DELETE FROM se_inscribe_en WHERE nro_base BETWEEN 600 AND 609;
DELETE FROM cuota_social   WHERE nro_base BETWEEN 600 AND 609;
DELETE FROM socio_titular  WHERE nro_base BETWEEN 600 AND 609;
DELETE FROM socio          WHERE nro_base BETWEEN 600 AND 609;
DELETE FROM grupo_familiar WHERE nro_base BETWEEN 600 AND 609;

DELETE FROM agrupa WHERE id_actividad IN (SELECT id_actividad FROM actividad WHERE descripcion IN ('Test Paddle 99', 'Test Invalida'));
DELETE FROM actividad_arancelada WHERE id_actividad IN (SELECT id_actividad FROM actividad WHERE descripcion IN ('Test Paddle 99', 'Test Invalida'));
DELETE FROM actividad WHERE descripcion IN ('Test Paddle 99', 'Test Invalida');

-- 2. Tabla temporal para almacenar resultados
-- ENGINE=MEMORY es NO transaccional: los ROLLBACK de los SPs no revierten los INSERTs de resultados
DROP TEMPORARY TABLE IF EXISTS _test_results;
CREATE TEMPORARY TABLE _test_results (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sp_name VARCHAR(40) NOT NULL,
    test_tipo VARCHAR(15) NOT NULL,
    resultado VARCHAR(10) NOT NULL,
    detalle VARCHAR(255) NOT NULL
) ENGINE=MEMORY;

-- 3. Procedimiento ejecutor de la suite de 14 pruebas
DROP PROCEDURE IF EXISTS sp_run_tests;
DELIMITER //

CREATE PROCEDURE sp_run_tests()
BEGIN
    DECLARE v_id_act_test INT;
    DECLARE v_id_cuota_test INT;

    -- =================================================
    -- SP 1: sp_alta_grupo_familiar
    -- =================================================
    -- Test 1 (Éxito): Alta atómica de familia y titular Mayores
    BEGIN
        DECLARE v_error BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = TRUE;

        CALL sp_alta_grupo_familiar(600, '223-4556000', 'Av. Colón 2000', 'Esteban Quito', 'esteban@mail.com', '1982-04-10', 'Mayores', '223-155600000');

        IF NOT v_error 
           AND EXISTS (SELECT 1 FROM grupo_familiar WHERE nro_base = 600 AND deuda_total = 0.00)
           AND EXISTS (SELECT 1 FROM socio WHERE nro_base = 600 AND nro_orden = 0 AND is_titular = TRUE AND tipo_categoria = 'Mayores')
           AND EXISTS (SELECT 1 FROM socio_titular WHERE nro_base = 600 AND nro_orden = 0 AND nro_celular = '223-155600000') THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_grupo_familiar', 'Éxito (COMMIT)', 'PASSED', 'Filas creadas en grupo_familiar, socio y socio_titular con orden 0');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_grupo_familiar', 'Éxito (COMMIT)', 'FAILED', 'No se crearon todas las entidades relacionadas o hubo error');
        END IF;
    END;

    -- Test 2 (Rollback): Rechazo de titular Infantil por trigger
    BEGIN
        DECLARE v_error_esperado BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_esperado = TRUE;

        CALL sp_alta_grupo_familiar(601, '223-0000000', 'Calle Falsa 123', 'Nene', 'nene@mail.com', '2019-01-01', 'Infantiles', '223-1111111');

        IF v_error_esperado AND NOT EXISTS (SELECT 1 FROM grupo_familiar WHERE nro_base = 601) THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_grupo_familiar', 'Error (ROLLBACK)', 'PASSED', 'Trigger rechazó titular Infantil y ROLLBACK eliminó fila de grupo_familiar');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_grupo_familiar', 'Error (ROLLBACK)', 'FAILED', 'Se permitió titular Infantil o quedaron datos huérfanos');
        END IF;
    END;


    -- =================================================
    -- SP 2: sp_alta_integrante_familiar
    -- =================================================
    -- Test 3 (Éxito): Cálculo automático de nro_orden = 1
    BEGIN
        DECLARE v_error BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = TRUE;

        CALL sp_alta_integrante_familiar(600, 'Pepito Quito', 'pepito@mail.com', '2015-06-12', 'Infantiles');

        IF NOT v_error 
           AND EXISTS (SELECT 1 FROM socio WHERE nro_base = 600 AND nro_orden = 1 AND is_titular = FALSE AND tipo_categoria = 'Infantiles') THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_integrante_familiar', 'Éxito (COMMIT)', 'PASSED', 'Asignó nro_orden = 1 atómicamente con is_titular = FALSE');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_integrante_familiar', 'Éxito (COMMIT)', 'FAILED', 'Fallo al calcular nro_orden o al insertar integrante');
        END IF;
    END;

    -- Test 4 (Rollback): Rechazo ante grupo familiar inexistente
    BEGIN
        DECLARE v_error_esperado BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_esperado = TRUE;

        CALL sp_alta_integrante_familiar(9999, 'Hijo Fantasma', 'fantasma@mail.com', '2015-01-01', 'Infantiles');

        IF v_error_esperado AND NOT EXISTS (SELECT 1 FROM socio WHERE nro_base = 9999) THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_integrante_familiar', 'Error (ROLLBACK)', 'PASSED', 'Validación rechazó grupo inexistente y abortó la transacción');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_integrante_familiar', 'Error (ROLLBACK)', 'FAILED', 'No se validó existencia de grupo o se insertó socio huérfano');
        END IF;
    END;


    -- =================================================
    -- SP 3: sp_alta_actividad
    -- =================================================
    -- Test 5 (Éxito): Especialización total y categoría inicial en agrupa
    BEGIN
        DECLARE v_error BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = TRUE;

        CALL sp_alta_actividad('Test Paddle 99', 'ARANCELADA', 15000.00, 'Mensual', 'Mayores');

        SELECT id_actividad INTO v_id_act_test
        FROM actividad
        WHERE descripcion = 'Test Paddle 99'
        LIMIT 1;

        IF NOT v_error 
           AND v_id_act_test IS NOT NULL
           AND EXISTS (SELECT 1 FROM actividad_arancelada WHERE id_actividad = v_id_act_test AND costo = 15000.00)
           AND EXISTS (SELECT 1 FROM agrupa WHERE id_actividad = v_id_act_test AND tipo_categoria = 'Mayores') THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_actividad', 'Éxito (COMMIT)', 'PASSED', 'Especialización total y categoría inicial en agrupa vinculadas');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_actividad', 'Éxito (COMMIT)', 'FAILED', 'No se insertó en subtipo o agrupa');
        END IF;
    END;

    -- Test 6 (Rollback): Tipo de actividad inválido
    BEGIN
        DECLARE v_error_esperado BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_esperado = TRUE;

        CALL sp_alta_actividad('Test Invalida', 'TIPO_INEXISTENTE', 1000.00, 'Mensual', 'Mayores');

        IF v_error_esperado AND NOT EXISTS (SELECT 1 FROM actividad WHERE descripcion = 'Test Invalida') THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_actividad', 'Error (ROLLBACK)', 'PASSED', 'Rechazó tipo inválido y ROLLBACK eliminó fila padre de actividad');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_alta_actividad', 'Error (ROLLBACK)', 'FAILED', 'No rechazó o dejó fila huérfana en tabla actividad');
        END IF;
    END;


    -- =================================================
    -- SP 4: sp_inscribir
    -- =================================================
    -- Test 7 (Éxito): Inscripción arancelada suma a deuda_actividad
    BEGIN
        DECLARE v_error BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = TRUE;

        -- Inscribimos a Pepito (600/1, Infantil) en Natación (id 1, arancelada, $12000)
        CALL sp_inscribir(600, 1, 1, FALSE);

        IF NOT v_error 
           AND EXISTS (SELECT 1 FROM se_inscribe_en WHERE nro_base = 600 AND nro_orden = 1 AND id_actividad = 1)
           AND EXISTS (SELECT 1 FROM socio WHERE nro_base = 600 AND nro_orden = 1 AND deuda_actividad = 12000.00) THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_inscribir', 'Éxito (COMMIT)', 'PASSED', 'Inscripción registrada y deuda_actividad incrementada en $12.000');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_inscribir', 'Éxito (COMMIT)', 'FAILED', 'Fallo al inscribir o no se actualizó deuda_actividad');
        END IF;
    END;

    -- Test 8 (Rollback): Simulación de error revierte inscripción y deuda
    BEGIN
        DECLARE v_error_esperado BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_esperado = TRUE;

        -- Intentar inscribir a Esteban (600/0) con simular_error = TRUE en Tenis (id 2)
        CALL sp_inscribir(600, 0, 2, TRUE);

        IF v_error_esperado 
           AND NOT EXISTS (SELECT 1 FROM se_inscribe_en WHERE nro_base = 600 AND nro_orden = 0 AND id_actividad = 2)
           AND (SELECT deuda_actividad FROM socio WHERE nro_base = 600 AND nro_orden = 0) = 0.00 THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_inscribir', 'Error (ROLLBACK)', 'PASSED', 'Simulación de error disparó ROLLBACK: ni inscripción ni deuda persistieron');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_inscribir', 'Error (ROLLBACK)', 'FAILED', 'No se revirtieron los cambios tras simulación de error');
        END IF;
    END;


    -- =================================================
    -- SP 5: sp_registrar_pago_arancel
    -- =================================================
    -- Test 9 (Éxito): Pago registrado y deuda_actividad saldada en 0
    BEGIN
        DECLARE v_error BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = TRUE;

        -- Pepito paga su arancel de Natación
        CALL sp_registrar_pago_arancel(600, 1, 1, CURDATE());

        IF NOT v_error 
           AND EXISTS (SELECT 1 FROM abona WHERE nro_base = 600 AND nro_orden = 1 AND id_actividad = 1)
           AND (SELECT deuda_actividad FROM socio WHERE nro_base = 600 AND nro_orden = 1) = 0.00 THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_arancel', 'Éxito (COMMIT)', 'PASSED', 'Pago registrado en abona y deuda_actividad saldada en 0');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_arancel', 'Éxito (COMMIT)', 'FAILED', 'Fallo al asentar pago o al descontar deuda');
        END IF;
    END;

    -- Test 10 (Rollback): Rechazo ante pago duplicado de arancel
    BEGIN
        DECLARE v_error_esperado BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_esperado = TRUE;

        -- Intentar volver a pagar la misma actividad ya abonada
        CALL sp_registrar_pago_arancel(600, 1, 1, CURDATE());

        IF v_error_esperado THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_arancel', 'Error (ROLLBACK)', 'PASSED', 'Rechazó doble pago de un mismo arancel (Hipótesis 2)');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_arancel', 'Error (ROLLBACK)', 'FAILED', 'Permitió pagar dos veces la misma actividad');
        END IF;
    END;


    -- =================================================
    -- SP 6: sp_liquidar_cuotas_mes
    -- =================================================
    -- Test 11 (Éxito): Emisión masiva de cuotas familiares y deuda_total
    BEGIN
        DECLARE v_error BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = TRUE;

        -- Liquidar cuotas de fin de año 2026
        CALL sp_liquidar_cuotas_mes('2026-11-01', '2026-11-28');

        -- Buscamos la cuota recién generada para el grupo 600
        SELECT id_cuota INTO v_id_cuota_test
        FROM cuota_social
        WHERE nro_base = 600 AND fecha_vencimiento = '2026-11-28'
        LIMIT 1;

        -- En el grupo 600: Esteban (Mayores = 25000) + Pepito (Infantiles = 25000 * 0.8 = 20000) = 45000
        IF NOT v_error 
           AND v_id_cuota_test IS NOT NULL
           AND (SELECT monto_a_pagar FROM cuota_social WHERE id_cuota = v_id_cuota_test) = 45000.00
           AND (SELECT deuda_total FROM grupo_familiar WHERE nro_base = 600) = 45000.00 THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_liquidar_cuotas_mes', 'Éxito (COMMIT)', 'PASSED', 'Cuota familiar sumó integrantes ($45.000) y actualizó deuda_total');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_liquidar_cuotas_mes', 'Éxito (COMMIT)', 'FAILED', 'No se emitió cuota o el cálculo familiar no coincidió');
        END IF;
    END;

    -- Test 12 (Rollback): Rechazo de vencimiento anterior al inicio del monto base
    BEGIN
        DECLARE v_error_esperado BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_esperado = TRUE;

        -- Período segundo semestre 2026 (inicia 2026-07-01). Pasamos vencimiento 2026-06-01 (inválido por RA 2)
        CALL sp_liquidar_cuotas_mes('2026-08-01', '2026-06-01');

        IF v_error_esperado AND NOT EXISTS (SELECT 1 FROM cuota_social WHERE fecha_vencimiento = '2026-06-01') THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_liquidar_cuotas_mes', 'Error (ROLLBACK)', 'PASSED', 'Rechazó vencimiento anterior al inicio de vigencia (RA 2)');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_liquidar_cuotas_mes', 'Error (ROLLBACK)', 'FAILED', 'Permitió liquidar con fecha de vencimiento anterior al período');
        END IF;
    END;


    -- =================================================
    -- SP 7: sp_registrar_pago_cuota
    -- =================================================
    -- Test 13 (Éxito): Pago parcial actualiza monto_abonado y reduce deuda_total
    BEGIN
        DECLARE v_error BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = TRUE;

        -- Pagamos $15.000 de la cuota de $45.000
        CALL sp_registrar_pago_cuota(v_id_cuota_test, 15000.00);

        IF NOT v_error 
           AND (SELECT monto_abonado FROM cuota_social WHERE id_cuota = v_id_cuota_test) = 15000.00
           AND (SELECT deuda_total FROM grupo_familiar WHERE nro_base = 600) = 30000.00 THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_cuota', 'Éxito (COMMIT)', 'PASSED', 'Abonó $15.000 y redujo deuda_total del grupo a $30.000');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_cuota', 'Éxito (COMMIT)', 'FAILED', 'Fallo al abonar o al descontar deuda del grupo');
        END IF;
    END;

    -- Test 14 (Rollback): Rechazo de sobrepago mantiene saldos intactos
    BEGIN
        DECLARE v_error_esperado BOOLEAN DEFAULT FALSE;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_esperado = TRUE;

        -- Quedan $30.000 de saldo. Intentamos pagar $999.999
        CALL sp_registrar_pago_cuota(v_id_cuota_test, 999999.00);

        IF v_error_esperado 
           AND (SELECT monto_abonado FROM cuota_social WHERE id_cuota = v_id_cuota_test) = 15000.00
           AND (SELECT deuda_total FROM grupo_familiar WHERE nro_base = 600) = 30000.00 THEN
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_cuota', 'Error (ROLLBACK)', 'PASSED', 'Rechazó pago superior al saldo y mantuvo valores intactos');
        ELSE
            INSERT INTO _test_results (sp_name, test_tipo, resultado, detalle)
            VALUES ('sp_registrar_pago_cuota', 'Error (ROLLBACK)', 'FAILED', 'Permitió sobrepago o corrompió los importes');
        END IF;
    END;

END //
DELIMITER ;

-- 4. Ejecutar la suite completa
CALL sp_run_tests();

-- 5. Mostrar la tabla de resultados final
SELECT id AS '#',
       sp_name AS 'Stored Procedure',
       test_tipo AS 'Tipo de Caso',
       resultado AS 'Estado',
       detalle AS 'Detalle de Verificación'
FROM _test_results
ORDER BY id;

-- 6. Limpiar procedimiento temporal
DROP PROCEDURE IF EXISTS sp_run_tests;
