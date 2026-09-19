-- =====================================================================
-- 01. VALIDACION DE CALIDAD DE DATOS
-- Objetivo: antes de confiar en cualquier KPI, confirmar que los datos
-- son consistentes. Un analista jr. debe poder mostrar que revisó esto
-- antes de construir el dashboard.
-- =====================================================================

-- 1.1 Conteo general y nulos (la tabla se creó con NOT NULL, esto confirma
--     que la carga no dejó campos vacíos "silenciosos" como cadena vacía)
SELECT
    COUNT(*)                                            AS total_filas,
    SUM(CASE WHEN tipo = '' THEN 1 ELSE 0 END)          AS tipo_vacio,
    SUM(CASE WHEN cuenta_origen = '' THEN 1 ELSE 0 END) AS cuenta_origen_vacia,
    SUM(CASE WHEN cuenta_destino = '' THEN 1 ELSE 0 END) AS cuenta_destino_vacia
FROM transacciones;

-- 1.2 Duplicados exactos (misma combinación de todos los campos)
SELECT COUNT(*) AS filas_en_grupos_duplicados
FROM (
    SELECT step, tipo, monto, cuenta_origen, saldo_ini_origen, saldo_fin_origen,
           cuenta_destino, saldo_ini_destino, saldo_fin_destino, COUNT(*) AS n
    FROM transacciones
    GROUP BY 1,2,3,4,5,6,7,8,9
    HAVING COUNT(*) > 1
);

-- 1.3 Montos y saldos negativos (no deberían existir en un sistema de pagos)
SELECT
    SUM(CASE WHEN monto < 0 THEN 1 ELSE 0 END)             AS montos_negativos,
    SUM(CASE WHEN saldo_ini_origen < 0 THEN 1 ELSE 0 END)  AS saldo_ini_origen_negativo,
    SUM(CASE WHEN saldo_fin_origen < 0 THEN 1 ELSE 0 END)  AS saldo_fin_origen_negativo,
    SUM(CASE WHEN saldo_ini_destino < 0 THEN 1 ELSE 0 END) AS saldo_ini_destino_negativo,
    SUM(CASE WHEN saldo_fin_destino < 0 THEN 1 ELSE 0 END) AS saldo_fin_destino_negativo
FROM transacciones;

-- 1.4 Cuadre de saldo en el origen: saldo_ini_origen - monto debería ser
--     igual a saldo_fin_origen. Cuánto se cumple por tipo de transacción.
SELECT
    tipo,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN ABS((saldo_ini_origen - monto) - saldo_fin_origen) < 0.01
             THEN 1 ELSE 0 END)                                           AS cuadra,
    ROUND(100.0 * SUM(CASE WHEN ABS((saldo_ini_origen - monto) - saldo_fin_origen) < 0.01
                          THEN 1 ELSE 0 END) / COUNT(*), 2)               AS pct_cuadra
FROM transacciones
GROUP BY tipo
ORDER BY total DESC;

-- 1.5 Lo mismo pero separando fraude vs no fraude: aquí es donde aparece
--     el hallazgo clave -> en las transacciones fraudulentas el saldo
--     destino casi nunca cuadra (saldo_ini_destino + monto != saldo_fin_destino),
--     lo cual es un artefacto de cómo se generó el dataset sintético y no
--     necesariamente una señal de fraude real. Ver docs/hallazgos_resumen.md.
SELECT
    es_fraude,
    COUNT(*)                                                                AS total,
    SUM(CASE WHEN ABS((saldo_ini_destino + monto) - saldo_fin_destino) < 0.01
             THEN 1 ELSE 0 END)                                             AS cuadra_destino,
    ROUND(100.0 * SUM(CASE WHEN ABS((saldo_ini_destino + monto) - saldo_fin_destino) < 0.01
                          THEN 1 ELSE 0 END) / COUNT(*), 2)                 AS pct_cuadra_destino
FROM transacciones
WHERE tipo IN ('TRANSFER', 'CASH_OUT')
GROUP BY es_fraude;

-- 1.6 Cuentas que aparecen como origen Y destino en la misma fila (autopago,
--     no debería pasar)
SELECT COUNT(*) AS filas_origen_igual_destino
FROM transacciones
WHERE cuenta_origen = cuenta_destino;

-- 1.7 Confirmar el prefijo de cuenta: 'C' = cliente, 'M' = comercio.
--     ¿Los comercios (M) reciben fraude alguna vez?
SELECT
    SUBSTR(cuenta_destino, 1, 1) AS prefijo_destino,
    es_fraude,
    COUNT(*) AS total
FROM transacciones
GROUP BY 1, 2
ORDER BY 1, 2;

-- 1.8 Rango de la columna step (para saber cuántos días/horas cubre el dataset)
SELECT
    MIN(step) AS step_min,
    MAX(step) AS step_max,
    MAX(step) / 24.0 AS dias_aprox
FROM transacciones;
