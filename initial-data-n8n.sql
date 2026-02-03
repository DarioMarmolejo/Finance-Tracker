-- 1. Crear la Categoría #1 (Para que n8n la encuentre)
INSERT INTO categorias (id, nombre, tipo, descripcion) 
VALUES (1, 'Alimentación', 'PERSONAL', 'Comida, despensa y restaurantes');
INSERT INTO categorias (id, nombre, tipo, descripcion) 
VALUES (2, 'Transporte', 'PERSONAL', 'Gasolina, mantenimiento y cuotas');

-- 2. Crear la Cuenta #1 (Para que n8n tenga de dónde descontar)
INSERT INTO cuentas (id, nombre, tipo, saldo_actual) 
VALUES (1, 'Cartera Efectivo', 'EFECTIVO', 1000.00);

-- (Opcional) Ajustar la secuencia para que los siguientes inserts sean 2, 3, etc.
SELECT setval('categorias_id_seq', (SELECT MAX(id) FROM categorias));
SELECT setval('cuentas_id_seq', (SELECT MAX(id) FROM cuentas));
