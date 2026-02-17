-- 1. LIMPIEZA: El orden importa (borramos de lo más específico a lo más general)
DROP VIEW IF EXISTS vista_bola_de_nieve;
DROP TABLE IF EXISTS transacciones;
DROP TABLE IF EXISTS deudas;
DROP TABLE IF EXISTS cuentas;
DROP TABLE IF EXISTS categorias;
DROP TABLE IF EXISTS cat_tipo_cuenta; -- Agregado para limpieza total
DROP TABLE IF EXISTS cat_monedas;      -- Agregado para limpieza total

-- 1. Categorías
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(20) CHECK (tipo IN ('PERSONAL', 'NEGOCIO', 'DEUDA', 'AHORRO')),
    descripcion TEXT
);

-- 2. Catálogo de tipos de cuenta (DEBE crearse antes que 'cuentas')
CREATE TABLE IF NOT EXISTS cat_tipo_cuenta (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL UNIQUE
);

INSERT INTO cat_tipo_cuenta (nombre) VALUES 
('DEBITO'), ('CREDITO'), ('PRESTAMO'), ('EFECTIVO');

-- 3. Catálogo de monedas (DEBE crearse antes que 'cuentas')
CREATE TABLE IF NOT EXISTS cat_monedas (
    codigo VARCHAR(3) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    simbolo VARCHAR(5) NOT NULL
);

INSERT INTO cat_monedas (codigo, nombre, simbolo) VALUES 
('MXN', 'Peso Mexicano', '$'),
('EUR', 'Euro', '€'),
('USD', 'Dólar Estadounidense', '$');

-- 4. Cuentas
CREATE TABLE IF NOT EXISTS cuentas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo_id INT REFERENCES cat_tipo_cuenta(id),
    moneda_codigo VARCHAR(3) REFERENCES cat_monedas(codigo) DEFAULT 'MXN',
    saldo_actual DECIMAL(12, 2) DEFAULT 0.00
);

-- 5. Deudas
CREATE TABLE IF NOT EXISTS deudas (
    id SERIAL PRIMARY KEY,
    nombre_acreedor VARCHAR(100) NOT NULL,
    monto_total DECIMAL(12, 2) NOT NULL,
    saldo_pendiente DECIMAL(12, 2) NOT NULL,
    tasa_interes DECIMAL(5, 2),
    pago_minimo DECIMAL(10, 2),
    dia_vencimiento INT,
    estado VARCHAR(20) DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'PAGADA'))
);

-- 6. Transacciones
CREATE TABLE IF NOT EXISTS transacciones (
    id SERIAL PRIMARY KEY,
    monto DECIMAL(10, 2) NOT NULL CHECK (monto > 0),
    tipo_movimiento VARCHAR(10) NOT NULL CHECK (tipo_movimiento IN ('INGRESO', 'EGRESO', 'TRANSFERENCIA')),
    fecha_transaccion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    descripcion TEXT,
    categoria_id INT REFERENCES categorias(id) ON DELETE SET NULL,
    cuenta_id INT REFERENCES cuentas(id) ON DELETE CASCADE,
    deuda_id INT REFERENCES deudas(id) ON DELETE SET NULL,
    es_deducible BOOLEAN DEFAULT FALSE
);

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