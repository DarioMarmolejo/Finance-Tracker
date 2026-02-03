-- 1. Categorías: Clasificación (Personal, Negocios, Deudas, Ahorros)
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(20) CHECK (tipo IN ('PERSONAL', 'NEGOCIO', 'DEUDA', 'AHORRO')),
    descripcion TEXT
);

-- 2. Cuentas: Donde vive el dinero (Inbursa, Efectivo, etc.)
CREATE TABLE IF NOT EXISTS cuentas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(20) DEFAULT 'DEBITO',
    moneda VARCHAR(3) DEFAULT 'MXN',
    saldo_actual DECIMAL(12, 2) DEFAULT 0.00
);

-- 3. Deudas: Optimizada para el método Bola de Nieve
CREATE TABLE IF NOT EXISTS deudas (
    id SERIAL PRIMARY KEY,
    nombre_acreedor VARCHAR(100) NOT NULL,
    monto_total DECIMAL(12, 2) NOT NULL,      -- Monto inicial
    saldo_pendiente DECIMAL(12, 2) NOT NULL,  -- Lo que falta por pagar
    tasa_interes DECIMAL(5, 2),
    pago_minimo DECIMAL(10, 2),
    dia_vencimiento INT,
    estado VARCHAR(20) DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'PAGADA'))
);

-- 4. Transacciones: El registro de movimientos diario
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
    IF (NEW.deuda_id IS NOT NULL AND NEW.tipo_movimiento = 'EGRESO') THEN
        UPDATE deudas SET saldo_pendiente = saldo_pendiente - NEW.monto
        WHERE id = NEW.deuda_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para deudas
CREATE TRIGGER trg_actualizar_saldo_deuda
AFTER INSERT ON transacciones
FOR EACH ROW EXECUTE FUNCTION actualizar_saldo_deuda();