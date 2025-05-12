USE car_prices_db;

-- Eliminar objetos si ya existen para evitar errores al recrearlos
DROP VIEW IF EXISTS ventas_por_estado;
DROP VIEW IF EXISTS resumen_modelos_vendidos;
DROP FUNCTION IF EXISTS calcular_margen;
DROP FUNCTION IF EXISTS evaluar_condicion;
DROP PROCEDURE IF EXISTS insertar_venta;
DROP TABLE IF EXISTS auditoria;
DROP TRIGGER IF EXISTS auditoria_venta_insert;

-- Vista 1: Ventas por estado:  Muestra el total de ventas y el precio promedio de venta por estado
CREATE VIEW ventas_por_estado AS
SELECT 
    s.state_name,
    COUNT(sale.sale_id) AS total_ventas,
    AVG(sale.selling_price) AS precio_promedio
FROM state s
LEFT JOIN sale ON s.state_id = sale.state_id
GROUP BY s.state_name;

-- Vista 2: Resumen de modelos vendidos: Muestra la cantidad de autos vendidos por marca y modelo, junto con el ingreso total
CREATE VIEW resumen_modelos_vendidos AS
SELECT 
    cm.make,
    cm.model,
    COUNT(c.vin) AS cantidad_vendida,
    SUM(sale.selling_price) AS ingreso_total
FROM car_model cm
JOIN car c ON cm.model_id = c.car_model_id
JOIN sale ON c.vin = sale.vin
GROUP BY cm.make, cm.model;

-- Función 1: Calcular el margen de ganancia: Calcula el margen de ganancia como (selling_price - mmr) / mmr * 100
DELIMITER //

CREATE FUNCTION calcular_margen(mmr DECIMAL(10,2), selling_price DECIMAL(10,2))
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE margen DECIMAL(5,2);
    IF mmr = 0 THEN
        SET margen = 0;
    ELSE
        SET margen = ((selling_price - mmr) / mmr) * 100;
    END IF;
    RETURN margen;
END //

-- Función 2: Evaluar la condición del auto: Devuelve una descripción textual basada en el valor de condition (0-50)
CREATE FUNCTION evaluar_condicion(condition INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE estado VARCHAR(20);
    IF condition IS NULL THEN
        SET estado = 'Desconocido';
    ELSEIF condition >= 40 THEN
        SET estado = 'Excelente';
    ELSEIF condition >= 30 THEN
        SET estado = 'Bueno';
    ELSEIF condition >= 20 THEN
        SET estado = 'Regular';
    ELSE
        SET estado = 'Malo';
    END IF;
    RETURN estado;
END //

DELIMITER ;

-- Stored Procedure: Insertar una nueva venta
-- Inserta un registro en la tabla sale y verifica que el VIN exista en car
DELIMITER //

CREATE PROCEDURE insertar_venta(
    IN p_vin VARCHAR(20),
    IN p_mmr DECIMAL(10,2),
    IN p_selling_price DECIMAL(10,2),
    IN p_sale_date DATETIME,
    IN p_state_id INT
)
BEGIN
    DECLARE vin_exists INT;

    -- Verificar si el VIN existe en la tabla car
    SELECT COUNT(*) INTO vin_exists
    FROM car
    WHERE vin = p_vin;

    IF vin_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El VIN especificado no existe en la tabla car.';
    ELSE
        -- Insertar la venta
        INSERT INTO sale (vin, mmr, selling_price, sale_date, state_id)
        VALUES (p_vin, p_mmr, p_selling_price, p_sale_date, p_state_id);
    END IF;
END //

DELIMITER ;

-- Tabla de auditoría para registrar inserciones en sale
CREATE TABLE auditoria (
    auditoria_id INT AUTO_INCREMENT PRIMARY KEY,
    accion VARCHAR(50) NOT NULL,
    vin VARCHAR(20) NOT NULL,
    usuario VARCHAR(50) NOT NULL,
    fecha_accion DATETIME NOT NULL
);

-- Trigger 1: Registrar inserciones en la tabla sale
DELIMITER //

CREATE TRIGGER auditoria_venta_insert
AFTER INSERT ON sale
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (accion, vin, usuario, fecha_accion)
    VALUES ('INSERT', NEW.vin, USER(), NOW());
END //

DELIMITER ;

-- Trigger 2: Registrar actualizaciones en la tabla sale
CREATE TRIGGER auditoria_venta_update
AFTER UPDATE ON sale
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (accion, vin, usuario, fecha_accion, detalle)
    VALUES ('UPDATE', NEW.vin, USER(), NOW(), 
            CONCAT('Venta actualizada - MMR Anterior: ', OLD.mmr, ', MMR Nuevo: ', NEW.mmr, 
                   ', Selling Price Anterior: ', OLD.selling_price, ', Selling Price Nuevo: ', NEW.selling_price));
END //

DELIMITER ;