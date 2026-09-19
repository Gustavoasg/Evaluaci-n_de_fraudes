-- =====================================================================
-- 04. QUERIES DE EXPORTACION PARA POWER BI
-- Estas mismas queries las ejecuta scripts/02_exportar_powerbi.py y guarda
-- el resultado como CSV en data/processed/. Se documentan aquí como texto
-- SQL plano para que puedan leerse/ejecutarse independientemente del script.
-- =====================================================================

-- 4.1 kpi_resumen.csv
SELECT
    COUNT(*)                                            AS total_transacciones,
    ROUND(SUM(monto), 2)                                AS volumen_total,
    SUM(es_fraude)                                      AS total_fraudes,
    ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4)         AS tasa_fraude_pct,
    ROUND(SUM(CASE WHEN es_fraude = 1 THEN monto ELSE 0 END), 2) AS monto_total_fraude,
    SUM(fue_marcada)                                    AS total_marcadas_por_regla
FROM transacciones;

-- 4.2 agregado_por_tipo.csv
SELECT
    tipo,
    COUNT(*)                                    AS total_transacciones,
    ROUND(SUM(monto), 2)                        AS volumen,
    ROUND(AVG(monto), 2)                        AS monto_promedio,
    SUM(es_fraude)                              AS fraudes,
    ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4) AS tasa_fraude_pct
FROM transacciones
GROUP BY tipo;

-- 4.3 agregado_diario.csv
SELECT
    CAST((step - 1) / 24 AS INTEGER) + 1  AS dia,
    COUNT(*)                              AS total_transacciones,
    ROUND(SUM(monto), 2)                  AS volumen,
    SUM(es_fraude)                        AS fraudes,
    ROUND(SUM(CASE WHEN es_fraude = 1 THEN monto ELSE 0 END), 2) AS monto_fraude
FROM transacciones
GROUP BY dia
ORDER BY dia;

-- 4.4 agregado_por_hora.csv
SELECT
    step % 24                                   AS hora_del_dia,
    COUNT(*)                                    AS total_transacciones,
    SUM(es_fraude)                              AS fraudes,
    ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4) AS tasa_fraude_pct
FROM transacciones
WHERE tipo IN ('TRANSFER', 'CASH_OUT')
GROUP BY hora_del_dia
ORDER BY hora_del_dia;

-- 4.5 comparacion_reglas.csv (ver 03_auditoria_regla_flagged.sql, seccion 3.5)

-- 4.6 muestra_transacciones.csv: todas las transacciones fraudulentas (8,213)
--     + una muestra aleatoria de 50,000 transacciones legítimas, para poder
--     explorar a nivel de transacción individual en Power BI sin cargar las
--     6.36M filas completas. Importante: la muestra aleatoria se toma SOLO
--     de las legítimas (subquery propia) y luego se une con TODO el fraude;
--     si se mezclara todo en un solo ORDER BY RANDOM() LIMIT, se perderían
--     la mayoría de los fraudes por ser tan pocos frente al total.
SELECT
    step, tipo, monto, cuenta_origen, saldo_ini_origen, saldo_fin_origen,
    cuenta_destino, saldo_ini_destino, saldo_fin_destino, es_fraude, fue_marcada
FROM transacciones
WHERE es_fraude = 1
UNION ALL
SELECT
    step, tipo, monto, cuenta_origen, saldo_ini_origen, saldo_fin_origen,
    cuenta_destino, saldo_ini_destino, saldo_fin_destino, es_fraude, fue_marcada
FROM (
    SELECT * FROM transacciones
    WHERE es_fraude = 0
    ORDER BY RANDOM()
    LIMIT 50000
);
