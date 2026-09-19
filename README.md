# Auditoría de fraude en transacciones financieras (PaySim)

Proyecto de portafolio a nivel **analista de datos jr.**: SQL para limpiar,
validar y agregar datos de fraude financiero, y Power BI para el dashboard
final. A propósito sin machine learning — el objetivo es demostrar dominio de
SQL, calidad de datos, KPIs de negocio y comunicación de hallazgos, que es lo
que se evalúa en ese rol.

## Dataset

[PaySim — Synthetic Financial Datasets For Fraud Detection](https://www.kaggle.com/datasets/ealaxi/paysim1)
(Kaggle). 6,362,620 transacciones simuladas de un servicio de dinero móvil a
lo largo de ~31 días, con 8,213 marcadas como fraude real (0.13%).

## Estructura del proyecto

```
fraude_transacciones_paysim/
├── data/
│   ├── raw/                Synthetic_Financial_datasets_log.csv (fuente original)
│   └── processed/          CSVs agregados, listos para Power BI
├── db/
│   └── fraude.db            Base SQLite con la tabla `transacciones`
├── sql/
│   ├── 01_validacion_calidad_datos.sql
│   ├── 02_kpis_negocio.sql
│   ├── 03_auditoria_regla_flagged.sql
│   └── 04_exportar_powerbi.sql
├── scripts/
│   ├── 01_cargar_sqlite.py       Carga el CSV a SQLite (único paso en Python)
│   └── 02_exportar_powerbi.py    Ejecuta las queries de exportación y genera los CSV
├── powerbi/
│   └── guia_construccion_dashboard.md   Guía paso a paso para armar el .pbix
└── docs/
    └── hallazgos_resumen.md      Resumen ejecutivo de hallazgos
```

## Cómo reproducirlo

```bash
python scripts/01_cargar_sqlite.py      # crea db/fraude.db desde el CSV
python scripts/02_exportar_powerbi.py   # genera data/processed/*.csv
```

Después, sigue `powerbi/guia_construccion_dashboard.md` para construir el
dashboard en Power BI Desktop importando los CSV de `data/processed/`.

## Hallazgos principales

1. La regla de control del sistema (`isFlaggedFraud`) detecta **16 de 8,213**
   fraudes reales — 0.19% de recall. Es prácticamente inútil como defensa.
2. El fraude solo ocurre en transacciones `TRANSFER` y `CASH_OUT`; nunca en
   `PAYMENT`, `DEBIT` o `CASH_IN`.
3. Una regla simple ("vaciado exacto de la cuenta origen") sube el recall a
   97.5% con 0 falsos positivos — pero se documenta como probable artefacto
   del dataset sintético, no como solución lista para producción.
4. Las tasas de fraude por hora del día pueden ser engañosas cuando el
   volumen de referencia es muy bajo (madrugada) — ejemplo real de por qué
   una tasa necesita reportarse junto a su volumen base.

Detalle completo, con números y la explicación de cada hallazgo, en
[`docs/hallazgos_resumen.md`](docs/hallazgos_resumen.md).
