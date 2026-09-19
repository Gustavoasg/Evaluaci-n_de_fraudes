"""
Ejecuta las queries de sql/04_exportar_powerbi.sql y sql/03_auditoria_regla_flagged.sql
(seccion 3.5) y guarda cada resultado como CSV en data/processed/, listo para
importar en Power BI. Se hace en Python solo por la mecanica de escritura de
archivos; el contenido analitico vive en los .sql.
"""
import csv
import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "db" / "fraude.db"
OUT_DIR = BASE_DIR / "data" / "processed"

QUERIES = {
    "kpi_resumen.csv": """
        SELECT
            COUNT(*) AS total_transacciones,
            ROUND(SUM(monto), 2) AS volumen_total,
            SUM(es_fraude) AS total_fraudes,
            ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4) AS tasa_fraude_pct,
            ROUND(SUM(CASE WHEN es_fraude = 1 THEN monto ELSE 0 END), 2) AS monto_total_fraude,
            SUM(fue_marcada) AS total_marcadas_por_regla
        FROM transacciones
    """,
    "agregado_por_tipo.csv": """
        SELECT
            tipo,
            COUNT(*) AS total_transacciones,
            ROUND(SUM(monto), 2) AS volumen,
            ROUND(AVG(monto), 2) AS monto_promedio,
            SUM(es_fraude) AS fraudes,
            ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4) AS tasa_fraude_pct
        FROM transacciones
        GROUP BY tipo
    """,
    "agregado_diario.csv": """
        SELECT
            CAST((step - 1) / 24 AS INTEGER) + 1 AS dia,
            COUNT(*) AS total_transacciones,
            ROUND(SUM(monto), 2) AS volumen,
            SUM(es_fraude) AS fraudes,
            ROUND(SUM(CASE WHEN es_fraude = 1 THEN monto ELSE 0 END), 2) AS monto_fraude
        FROM transacciones
        GROUP BY dia
        ORDER BY dia
    """,
    "agregado_por_hora.csv": """
        SELECT
            step % 24 AS hora_del_dia,
            COUNT(*) AS total_transacciones,
            SUM(es_fraude) AS fraudes,
            ROUND(100.0 * SUM(es_fraude) / COUNT(*), 4) AS tasa_fraude_pct
        FROM transacciones
        WHERE tipo IN ('TRANSFER', 'CASH_OUT')
        GROUP BY hora_del_dia
        ORDER BY hora_del_dia
    """,
    "comparacion_reglas.csv": """
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
        SELECT 'Regla original (monto > 200k)' AS regla, vp AS verdaderos_positivos,
               fp AS falsos_positivos, fn AS falsos_negativos,
               ROUND(100.0 * vp / NULLIF(vp+fn,0), 2) AS recall_pct,
               ROUND(100.0 * vp / NULLIF(vp+fp,0), 2) AS precision_pct
        FROM regla_actual
        UNION ALL
        SELECT 'Regla nueva (vaciado de cuenta)', vp, fp, fn,
               ROUND(100.0 * vp / NULLIF(vp+fn,0), 2),
               ROUND(100.0 * vp / NULLIF(vp+fp,0), 2)
        FROM regla_nueva
    """,
    "muestra_transacciones.csv": """
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
        )
    """,
}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    for filename, query in QUERIES.items():
        cur.execute(query)
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        out_path = OUT_DIR / filename
        with open(out_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(cols)
            writer.writerows(rows)
        print(f"{filename}: {len(rows):,} filas -> {out_path}")

    conn.close()


if __name__ == "__main__":
    main()
