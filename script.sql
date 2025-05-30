-- Eliminar la base de datos si existe para evitar conflictos
DROP DATABASE IF EXISTS car_prices_db;

-- Crear la base de datos
CREATE DATABASE car_prices_db;
USE car_prices_db;

-- Tabla State
CREATE TABLE State (
    state_id INT AUTO_INCREMENT PRIMARY KEY,
    state_name VARCHAR(2) NOT NULL UNIQUE
);

-- Tabla Seller
CREATE TABLE Seller (
    seller_id INT AUTO_INCREMENT PRIMARY KEY,
    seller_name VARCHAR(100) NOT NULL UNIQUE,
    state_id INT,
    FOREIGN KEY (state_id) REFERENCES State(state_id)
);

-- Tabla Car_Model
CREATE TABLE Car_Model (
    model_id INT AUTO_INCREMENT PRIMARY KEY,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    trim VARCHAR(50),
    UNIQUE (make, model, trim)
);

-- Tabla Car (con la columna renombrada a car_condition)
CREATE TABLE Car (
    vin VARCHAR(20) PRIMARY KEY,
    year INT NOT NULL,
    body VARCHAR(50) NOT NULL,
    transmission VARCHAR(20),
    odometer INT NOT NULL,
    color VARCHAR(50),
    interior VARCHAR(50),
    car_condition INT,
    car_model_id INT NOT NULL,
    seller_id INT NOT NULL,
    FOREIGN KEY (car_model_id) REFERENCES Car_Model(model_id),
    FOREIGN KEY (seller_id) REFERENCES Seller(seller_id),
    INDEX idx_car_model_id (car_model_id)
);

-- Tabla Sale
CREATE TABLE Sale (
    sale_id INT AUTO_INCREMENT PRIMARY KEY,
    vin VARCHAR(20) NOT NULL UNIQUE,
    mmr DECIMAL(10,2) NOT NULL,
    selling_price DECIMAL(10,2) NOT NULL,
    sale_date DATETIME NOT NULL,
    state_id INT NOT NULL,
    FOREIGN KEY (vin) REFERENCES Car(vin),
    FOREIGN KEY (state_id) REFERENCES State(state_id),
    INDEX idx_vin (vin)
);



-- Verificar que las tablas se crearon correctamente
SHOW TABLES;