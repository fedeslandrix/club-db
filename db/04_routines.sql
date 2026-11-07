-- 04_routines.sql
USE club;

DELIMITER //

CREATE PROCEDURE sp_obtener_socios()
BEGIN
    SELECT * FROM socios ORDER BY id DESC;
END //

DELIMITER ;
