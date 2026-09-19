-- =====================================================================
-- 03. AUDITORIA DE LA REGLA DE NEGOCIO isFlaggedFraud
-- El dataset trae una regla simulada que marca como sospechosa toda
-- transferencia > 200,000. Esta sección mide qué tan bien funciona esa
-- regla contra el fraude real, y propone/evalúa una alternativa, todo
-- con SQL (sin machine learning).
-- =====================================================================

-- 3.1 Matriz de confusión de la regla actual (fue_marcada vs es_fraude)
SELECT
    SUM(CASE WHEN fue_marcada = 1 AND es_fraude = 1 THEN 1 ELSE 0 END) AS verdaderos_positivos,
    SUM(CASE WHEN fue_marcada = 1 AND es_fraude = 0 THEN 1 ELSE 0 END) AS falsos_positivos,
    SUM(CASE WHEN fue_marcada = 0 AND es_fraude = 1 THEN 1 ELSE 0 END) AS falsos_negativos,
    SUM(CASE WHEN fue_marcada = 0 AND es_fraude = 0 THEN 1 ELSE 0 END) AS verdaderos_negativos
FROM transacciones;

-- 3.2 Recall y precisión de la regla actual
--     Recall = de todo el fraude real, ¿qué % detectó la regla?
--     Precisión = de lo que la regla marcó, ¿qué % era fraude real?
WITH conf AS (
    SELECT
        SUM(CASE WHEN fue_marcada = 1 AND es_fraude = 1 THEN 1 ELSE 0 END) AS vp,
        SUM(CASE WHEN fue_marcada = 1 AND es_fraude = 0 THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN fue_marcada = 0 AND es_fraude = 1 THEN 1 ELSE 0 END) AS fn
    FROM transacciones
)
SELECT
    vp, fp, fn,
    ROUND(100.0 * vp / NULLIF(vp + fn, 0), 2) AS recall_pct,
    ROUND(100.0 * vp / NULLIF(vp + fp, 0), 2) AS precision_pct
FROM conf;

-- 3.3 ¿Por qué falla tanto? Revisar cuántos fraudes reales sí superan
--     el umbral de 200,000 que usa la regla.
SELECT
    SUM(CASE WHEN monto > 200000 THEN 1 ELSE 0 END)   AS fraudes_sobre_200k,
    SUM(CASE WHEN monto <= 200000 THEN 1 ELSE 0 END)  AS fraudes_bajo_200k,
    COUNT(*)                                          AS total_fraudes
FROM transacciones
WHERE es_fraude = 1;
-- Conclusión esperada: casi todo el fraude ocurre en montos por debajo del
-- umbral, por eso la regla de "solo mirar montos grandes" casi no detecta nada.

-- 3.4 Regla alternativa simple, basada en el patrón de "vaciado de cuenta"
--     encontrado en 02_kpis_negocio.sql (2.7): marcar como sospechosa toda
--     transacción TRANSFER o CASH_OUT donde la cuenta origen queda en 0
--     Y el monto es igual al saldo inicial (es decir, se vacía la cuenta).
WITH regla_nueva AS (
    SELECT
        es_fraude,
        CASE
            WHEN tipo IN ('TRANSFER', 'CASH_OUT')
                 AND saldo_fin_origen = 0
                 AND ABS(saldo_ini_origen - monto) < 0.01
                 AND saldo_ini_origen > 0
            THEN 1 ELSE 0
        END AS marcada_regla_nueva
    FROM transacciones
    WHERE tipo IN ('TRANSFER', 'CASH_OUT')
)
SELECT
    SUM(CASE WHEN marcada_regla_nueva = 1 AND es_fraude = 1 THEN 1 ELSE 0 END) AS verdaderos_positivos,
    SUM(CASE WHEN marcada_regla_nueva = 1 AND es_fraude = 0 THEN 1 ELSE 0 END) AS falsos_positivos,
    SUM(CASE WHEN marcada_regla_nueva = 0 AND es_fraude = 1 THEN 1 ELSE 0 END) AS falsos_negativos,
    ROUND(100.0 * SUM(CASE WHEN marcada_regla_nueva = 1 AND es_fraude = 1 THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN es_fraude = 1 THEN 1 ELSE 0 END), 0), 2)        AS recall_pct,
    ROUND(100.0 * SUM(CASE WHEN marcada_regla_nueva = 1 AND es_fraude = 1 THEN 1 ELSE 0 END)
          / NULLIF(SUM(marcada_regla_nueva), 0), 2)                             AS precision_pct
FROM regla_nueva;
-- Nota honesta para el reporte: esta regla nueva sube mucho el recall, pero
-- el "vaciado de cuenta" es en buena parte el mismo artefacto de generación
-- sintética que aparece en 01_validacion_calidad_datos.sql (1.5). Es decir:
-- funciona muy bien EN ESTE dataset, pero probablemente no generalizaría a
-- datos reales de producción. Esto se documenta explícitamente en
-- docs/hallazgos_resumen.md como limitación, no se oculta.

-- 3.5 Tabla comparativa final regla actual vs regla nueva (para exportar
--     a Power BI como tabla de comparación)
WITH regla_actual AS (
    SELECT
        SUM(CASE WHEN fue_marcada = 1 AND es_fraude = 1 THEN 1 ELSE 0 END) AS vp,
        SUM(CASE WHEN fue_marcada = 1 AND es_fraude = 0 THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN fue_marcada = 0 AND es_fraude = 1 THEN 1 ELSE 0 END) AS fn
    FROM transacciones
),
regla_nueva AS (
    SELECT
        SUM(CASE WHEN tipo IN ('TRANSFER','CASH_OUT') AND saldo_fin_origen = 0
                      AND ABS(saldo_ini_origen - monto) < 0.01 AND saldo_ini_origen > 0
                      AND es_fraude = 1 THEN 1 ELSE 0 END) AS vp,
        SUM(CASE WHEN tipo IN ('TRANSFER','CASH_OUT') AND saldo_fin_origen = 0
                      AND ABS(saldo_ini_origen - monto) < 0.01 AND saldo_ini_origen > 0
                      AND es_fraude = 0 THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN NOT(tipo IN ('TRANSFER','CASH_OUT') AND saldo_fin_origen = 0
                      AND ABS(saldo_ini_origen - monto) < 0.01 AND saldo_ini_origen > 0)
                      AND es_fraude = 1 THEN 1 ELSE 0 END) AS fn
    FROM transacciones
)
SELECT 'Regla original (monto > 200k)' AS regla, vp AS verdaderos_positivos, fp AS falsos_positivos,
       fn AS falsos_negativos,
       ROUND(100.0 * vp / NULLIF(vp+fn,0), 2) AS recall_pct,
       ROUND(100.0 * vp / NULLIF(vp+fp,0), 2) AS precision_pct
FROM regla_actual
UNION ALL
SELECT 'Regla nueva (vaciado de cuenta)', vp, fp, fn,
       ROUND(100.0 * vp / NULLIF(vp+fn,0), 2),
       ROUND(100.0 * vp / NULLIF(vp+fp,0), 2)
FROM regla_nueva;
