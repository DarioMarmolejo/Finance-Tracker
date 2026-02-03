-- 1. LIMPIEZA: Borramos todo para empezar de cero
DROP TABLE IF EXISTS transacciones;
DROP TABLE IF EXISTS deudas;
DROP TABLE IF EXISTS cuentas;
DROP TABLE IF EXISTS categorias;

-- 2. CREACIÓN: Hay que volver a crear las tablas después del DROP
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(20) CHECK (tipo IN ('PERSONAL', 'NEGOCIO', 'DEUDA', 'AHORRO'))
);

CREATE TABLE cuentas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    saldo_actual DECIMAL(12, 2) DEFAULT 0.00
);

CREATE TABLE deudas (
    id SERIAL PRIMARY KEY,
    nombre_acreedor VARCHAR(100) NOT NULL,
    monto_total DECIMAL(12, 2) NOT NULL,
    saldo_pendiente DECIMAL(12, 2) NOT NULL,
    estado VARCHAR(20) DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'PAGADA'))
);

CREATE TABLE transacciones (
    id SERIAL PRIMARY KEY,
    monto DECIMAL(10, 2) NOT NULL,
    tipo_movimiento VARCHAR(10) CHECK (tipo_movimiento IN ('INGRESO', 'EGRESO')),
    cuenta_id INT REFERENCES cuentas(id),
    deuda_id INT REFERENCES deudas(id),
    descripcion TEXT
);

-- 3. FUNCIONES Y TRIGGERS (Cópialos del script anterior)
---
--- LÓGICA DE AUTOMATIZACIÓN (TRIGGERS)
---

-- Función para actualizar el saldo de la cuenta automáticamente
CREATE OR REPLACE FUNCTION actualizar_saldo_cuenta()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.tipo_movimiento = 'INGRESO') THEN
        UPDATE cuentas SET saldo_actual = saldo_actual + NEW.monto 
        WHERE id = NEW.cuenta_id;
    ELSIF (NEW.tipo_movimiento = 'EGRESO') THEN
        UPDATE cuentas SET saldo_actual = saldo_actual - NEW.monto 
        WHERE id = NEW.cuenta_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para cuentas
CREATE TRIGGER trg_actualizar_saldo_cuenta
AFTER INSERT ON transacciones
FOR EACH ROW EXECUTE FUNCTION actualizar_saldo_cuenta();

-- Función para reducir el saldo de la deuda cuando se registra un pago (egreso)
CREATE OR REPLACE FUNCTION actualizar_saldo_deuda()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Si la transacción está ligada a una deuda y es un EGRESO (pago)
    IF (NEW.deuda_id IS NOT NULL AND NEW.tipo_movimiento = 'EGRESO') THEN
        
        -- Restamos el pago del saldo pendiente
        UPDATE deudas 
        SET saldo_pendiente = saldo_pendiente - NEW.monto
        WHERE id = NEW.deuda_id;

        -- 2. Implementación de tu snippet: Verificamos si ya se liquidó
        -- Usamos el registro actualizado de la tabla deudas
        IF (SELECT saldo_pendiente FROM deudas WHERE id = NEW.deuda_id) <= 0 THEN
            UPDATE deudas 
            SET estado = 'PAGADA', 
                saldo_pendiente = 0 -- Forzamos a 0 por si hubo un pago mayor al saldo
            WHERE id = NEW.deuda_id;
        END IF;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para deudas
CREATE TRIGGER trg_actualizar_saldo_deuda
AFTER INSERT ON transacciones
FOR EACH ROW EXECUTE FUNCTION actualizar_saldo_deuda();

--La Vista de "Bola de Nieve"
--Esta te diría siempre qué deuda atacar primero:
CREATE OR REPLACE VIEW vista_bola_de_nieve AS
SELECT nombre_acreedor, saldo_pendiente, pago_minimo
FROM deudas
WHERE estado = 'ACTIVA'
ORDER BY saldo_pendiente ASC; -- La deuda más pequeña siempre arriba

-- 4. INSERTS DE PRUEBA
INSERT INTO cuentas (nombre, saldo_actual) VALUES ('Nómina Inbursa', 10000.00);
INSERT INTO deudas (nombre_acreedor, monto_total, saldo_pendiente) VALUES ('Préstamo Personal', 5000.00, 5000.00);

-- TEST: Pago con excedente
INSERT INTO transacciones (monto, tipo_movimiento, cuenta_id, deuda_id, descripcion) 
VALUES (5500.00, 'EGRESO', 1, 1, 'Pago mayor al saldo');

-- 5. VERIFICACIÓN
SELECT * FROM cuentas;
SELECT * FROM deudas;