"""
Carga el CSV crudo de PaySim a una base SQLite local.
No hay driver de PaySim/CSV nativo en Power BI para 6.3M filas sin pasar antes
por SQL, asi que este script es el unico paso en Python del proyecto: todo el
analisis posterior vive en archivos .sql puros.
"""
import csv
import sqlite3
import time
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CSV_PATH = BASE_DIR / "data" / "raw" / "Synthetic_Financial_datasets_log.csv"
DB_PATH = BASE_DIR / "db" / "fraude.db"

SCHEMA = """
DROP TABLE IF EXISTS transacciones;
CREATE TABLE transacciones (
    id              INTEGER PRIMARY KEY,
    step            INTEGER NOT NULL,
    tipo            TEXT NOT NULL,
    monto           REAL NOT NULL,
    cuenta_origen   TEXT NOT NULL,
    saldo_ini_origen  REAL NOT NULL,
    saldo_fin_origen  REAL NOT NULL,
    cuenta_destino  TEXT NOT NULL,
    saldo_ini_destino REAL NOT NULL,
    saldo_fin_destino REAL NOT NULL,
    es_fraude       INTEGER NOT NULL,
    fue_marcada     INTEGER NOT NULL
);
"""

BATCH_SIZE = 50_000


def main():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.executescript(SCHEMA)
    conn.commit()

    insert_sql = """
        INSERT INTO transacciones (
            step, tipo, monto, cuenta_origen, saldo_ini_origen, saldo_fin_origen,
            cuenta_destino, saldo_ini_destino, saldo_fin_destino, es_fraude, fue_marcada
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """

    start = time.time()
    total = 0
    batch = []
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        assert header == [
            "step", "type", "amount", "nameOrig", "oldbalanceOrg", "newbalanceOrig",
            "nameDest", "oldbalanceDest", "newbalanceDest", "isFraud", "isFlaggedFraud",
        ], f"Encabezado inesperado: {header}"

        for row in reader:
            step, tipo, amount, name_orig, old_orig, new_orig, name_dest, old_dest, new_dest, is_fraud, is_flagged = row
            batch.append((
                int(step), tipo, float(amount), name_orig, float(old_orig), float(new_orig),
                name_dest, float(old_dest), float(new_dest), int(is_fraud), int(is_flagged),
            ))
            if len(batch) >= BATCH_SIZE:
                cur.executemany(insert_sql, batch)
                conn.commit()
                total += len(batch)
                batch = []
                print(f"  {total:,} filas cargadas...", end="\r")

        if batch:
            cur.executemany(insert_sql, batch)
            conn.commit()
            total += len(batch)

    print(f"\nCarga terminada: {total:,} filas en {time.time() - start:.1f}s")

    print("Creando indices...")
    cur.executescript("""
        CREATE INDEX idx_tipo ON transacciones(tipo);
        CREATE INDEX idx_es_fraude ON transacciones(es_fraude);
        CREATE INDEX idx_step ON transacciones(step);
        CREATE INDEX idx_cuenta_origen ON transacciones(cuenta_origen);
        CREATE INDEX idx_cuenta_destino ON transacciones(cuenta_destino);
    """)
    conn.commit()
    conn.close()
    print(f"Base de datos lista en: {DB_PATH}")


if __name__ == "__main__":
    main()
