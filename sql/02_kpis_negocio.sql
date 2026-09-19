-- =====================================================================
-- 02. KPIs DE NEGOCIO
-- Estas queries responden las preguntas que haría un equipo de riesgo/
-- fraude: cuánto se mueve, dónde se concentra el fraude, y cuándo ocurre.
-- Los resultados de aquí alimentan el dashboard de Power BI.
-- =====================================================================

-- 2.1 Resumen general (para las tarjetas KPI del dashboard)
SELECT
    COUNT(*)                                            AS total_transacciones,
    ROUND(SUM(monto), 2)                                AS volumen_total,
    SUM(es_fraude)                                      AS total_fraudes,
    ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4)         AS tasa_fraude_pct,
    ROUND(SUM(CASE WHEN es_fraude = 1 THEN monto ELSE 0 END), 2) AS monto_total_fraude,
    SUM(fue_marcada)                                    AS total_marcadas_por_regla
FROM transacciones;

-- 2.2 Volumen y fraude por tipo de transacción
SELECT
    tipo,
    COUNT(*)                                              AS total_transacciones,
    ROUND(SUM(monto), 2)                                  AS volumen,
    ROUND(AVG(monto), 2)                                  AS monto_promedio,
    SUM(es_fraude)                                        AS fraudes,
    ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4)           AS tasa_fraude_pct
FROM transacciones
GROUP BY tipo
ORDER BY volumen DESC;

-- 2.3 Monto promedio: fraude vs legítima (solo en los tipos donde existe fraude)
SELECT
    tipo,
    es_fraude,
    COUNT(*)              AS total,
    ROUND(AVG(monto), 2)  AS monto_promedio,
    ROUND(MIN(monto), 2)  AS monto_min,
    ROUND(MAX(monto), 2)  AS monto_max
FROM transacciones
WHERE tipo IN ('TRANSFER', 'CASH_OUT')
GROUP BY tipo, es_fraude
ORDER BY tipo, es_fraude;

-- 2.4 Serie de tiempo diaria (step / 24 = día). Para el gráfico de tendencia.
SELECT
    CAST((step - 1) / 24 AS INTEGER) + 1  AS dia,
    COUNT(*)                              AS total_transacciones,
    ROUND(SUM(monto), 2)                  AS volumen,
    SUM(es_fraude)                        AS fraudes,
    ROUND(SUM(CASE WHEN es_fraude = 1 THEN monto ELSE 0 END), 2) AS monto_fraude
FROM transacciones
GROUP BY dia
ORDER BY dia;

-- 2.5 Patrón por hora del día (step % 24). ¿El fraude se concentra en
--     ciertas horas, a diferencia del tráfico normal?
SELECT
    step % 24                                          AS hora_del_dia,
    COUNT(*)                                           AS total_transacciones,
    SUM(es_fraude)                                     AS fraudes,
    ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4)        AS tasa_fraude_pct
FROM transacciones
WHERE tipo IN ('TRANSFER', 'CASH_OUT')
GROUP BY hora_del_dia
ORDER BY hora_del_dia;

-- 2.6 Distribución de fraude por rango de monto (para ver si el fraude
--     se concentra en montos altos, medios o está distribuido)
SELECT
    CASE
        WHEN monto < 10000   THEN '01: < 10k'
        WHEN monto < 100000  THEN '02: 10k - 100k'
        WHEN monto < 500000  THEN '03: 100k - 500k'
        WHEN monto < 1000000 THEN '04: 500k - 1M'
        ELSE                      '05: >= 1M'
    END                                          AS rango_monto,
    COUNT(*)                                     AS total,
    SUM(es_fraude)                               AS fraudes,
    ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4)  AS tasa_fraude_pct
FROM transacciones
WHERE tipo IN ('TRANSFER', 'CASH_OUT')
GROUP BY rango_monto
ORDER BY rango_monto;

-- 2.7 ¿El fraude vacía por completo la cuenta origen? (saldo_fin_origen = 0)
SELECT
    es_fraude,
    COUNT(*)                                                          AS total,
    SUM(CASE WHEN saldo_fin_origen = 0 THEN 1 ELSE 0 END)             AS cuenta_vaciada,
    ROUND(100.0 * SUM(CASE WHEN saldo_fin_origen = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_cuenta_vaciada
FROM transacciones
WHERE tipo IN ('TRANSFER', 'CASH_OUT')
GROUP BY es_fraude;

-- 2.8 Cuentas destino que reciben más de una transacción de tipo TRANSFER
--     marcada como fraude (posibles "cuentas mula" reutilizadas)
SELECT
    cuenta_destino,
    COUNT(*)              AS veces_receptora_de_fraude,
    ROUND(SUM(monto), 2)  AS monto_total_recibido
FROM transacciones
WHERE es_fraude = 1
GROUP BY cuenta_destino
HAVING COUNT(*) > 1
ORDER BY veces_receptora_de_fraude DESC;
