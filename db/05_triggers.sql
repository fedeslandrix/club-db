-- 05_triggers.sql
USE club;

CREATE TABLE IF NOT EXISTS socios_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    socio_id INT NOT NULL,
    accion VARCHAR(50) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE TRIGGER trg_despues_insert_socio
AFTER INSERT ON socios
FOR EACH ROW
BEGIN
    INSERT INTO socios_log (socio_id, accion)
    VALUES (NEW.id, 'NUEVO_SOCIO');
END //

DELIMITER ;
