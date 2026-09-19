# Ficha del proyecto

## 1. Información general

- **Nombre del proyecto:** Auditoría de Fraude en Transacciones Financieras (PaySim)
- **Especialidad:** DA (Analista de Datos)
- **Fuente del proyecto:** Dataset (Kaggle)
- **Link a la fuente original:** https://www.kaggle.com/datasets/ealaxi/paysim1
- **Link al proyecto publicado:** _Pendiente._ Aún no se sube a un repositorio público ni se publica el dashboard (ver sección 8).

## 2. Objetivo

Evaluar si el control automático de fraude de una plataforma de dinero móvil
(`isFlaggedFraud`) realmente protege el negocio, y entregar a un equipo de
riesgo/fraude un panorama claro de dónde se concentran las pérdidas y qué
tan confiable es la regla vigente. La decisión de negocio que apoya: si vale
la pena seguir confiando en el control actual o hay que reemplazarlo/reforzarlo,
y en qué tipos de transacción enfocar la revisión manual.

## 3. Plan de trabajo

1. **Exploración inicial** — Antes de decidir el enfoque, se inspeccionó el
   CSV crudo (6,362,620 filas) directo desde el zip para confirmar esquema,
   volumen, tipos de transacción y tasa de fraude, sin descomprimir el
   archivo completo primero.
2. **Preparación** — Diseño de esquema y carga del CSV a una base SQLite
   (`db/fraude.db`, `scripts/01_cargar_sqlite.py`), con índices sobre tipo,
   fraude, step y cuentas. Validación de calidad de datos: duplicados,
   nulos, valores negativos, cuadre de saldos origen/destino
   (`sql/01_validacion_calidad_datos.sql`).
3. **Construcción** — KPIs de negocio y series de tiempo en SQL
   (`sql/02_kpis_negocio.sql`), auditoría de la regla `isFlaggedFraud` contra
   una regla alternativa propia (`sql/03_auditoria_regla_flagged.sql`),
   exportación de tablas curadas para Power BI
   (`sql/04_exportar_powerbi.sql`, `scripts/02_exportar_powerbi.py`), y guía
   de construcción del dashboard (`powerbi/guia_construccion_dashboard.md`).
4. **Evaluación** — Métricas de recall/precisión (vía matriz de confusión en
   SQL) para la regla actual vs. la regla alternativa propuesta.
5. **Conclusiones y próximos pasos** — Resumen ejecutivo de hallazgos y
   recomendaciones en `docs/hallazgos_resumen.md`.

_(No se incluyó una etapa de modelado/ML a propósito: el proyecto se acotó a
nivel analista jr., con foco en SQL + BI en vez de machine learning.)_

## 4. Preguntas clave

1. **¿De dónde vienen los datos y qué tan vigentes son?** Es un dataset
   sintético (paper de 2016, simulación de un servicio de dinero móvil), no
   son transacciones reales. Cualquier conclusión de este proyecto es una
   demostración de método, no un hallazgo trasladable directo a un sistema
   de producción real.
2. **¿La regla alternativa que propuse (97.5% recall) generalizaría a datos
   reales, o solo funciona porque exploté un artefacto de cómo se generó
   este dataset?** Se documentó explícitamente esta duda en vez de vender el
   resultado como una solución lista para producción — es la pregunta que
   más me haría un líder de equipo antes de aprobar este hallazgo.
3. **¿Qué pasa si esto escala a un volumen real de producción (cientos de
   millones de transacciones diarias)?** Por eso se decidió no cargar las
   6.3M filas completas a Power BI, sino agregarlas en SQL y usar solo una
   muestra estratificada para el detalle transaccional — una decisión de
   diseño pensando en escalabilidad, no una limitación técnica de la
   herramienta.

## 5. Qué se hizo y cómo

- **Manejo de datos:** carga de 6,362,620 filas a SQLite vía Python
  (`sqlite3` + `executemany` en lotes de 50,000), único paso en Python del
  proyecto — todo el análisis vive en archivos `.sql` puros.
- **Validación:** se revisaron duplicados exactos, valores negativos,
  campos vacíos, y cuadre de saldos (`saldo_inicial - monto = saldo_final`)
  por tipo de transacción y por fraude vs. no fraude. Este último cruce
  reveló que el saldo destino cuadra mucho menos en transacciones
  fraudulentas (43.5%) que en legítimas (77.4%) — pista de un artefacto de
  generación sintética, documentada como advertencia y no explotada
  silenciosamente en la regla propuesta.
- **KPIs y series de tiempo:** agregaciones por tipo de transacción, por día
  (31 días) y por hora del día, todas calculadas en SQL puro con `GROUP BY`
  y funciones de ventana simples (`CAST`, `%`).
- **Auditoría de reglas:** matrices de confusión calculadas directamente en
  SQL (sin librerías de ML) para comparar la regla original
  (`isFlaggedFraud`) contra una regla propia basada en "vaciado exacto de
  cuenta origen".
- **Diseño del export para BI:** en vez de importar las 6.3M filas a Power
  BI, se generaron tablas agregadas (por tipo, por día, por hora, tabla
  comparativa de reglas) más una muestra estratificada de 58,213 filas
  (8,213 fraudes + 50,000 legítimas aleatorias) para exploración a nivel
  transacción — decisión explícita de diseño, documentada en la guía de
  Power BI.

## 6. Resultados

- **Métrica principal:** recall de la regla de control vigente = **0.19%**
  (16 de 8,213 fraudes detectados). Una regla alternativa simple de "vaciado
  exacto de cuenta" logra **97.5% de recall con 100% de precisión** sobre
  este dataset (con la reserva de generalización ya señalada).
- El fraude ocurre exclusivamente en transacciones `TRANSFER` y `CASH_OUT`
  (0 casos en `PAYMENT`, `DEBIT`, `CASH_IN`).
- El fraude nunca tiene como destino una cuenta de comercio, siempre otra
  cuenta de cliente — 44 cuentas destino recibieron más de un fraude
  (candidatas a "cuenta mula").
- Las tasas de fraude por hora de madrugada (40-58%) resultaron ser
  estadísticamente engañosas por bajo volumen base, hallazgo que se
  documentó explícitamente como advertencia de lectura del dashboard.

## 7. Conclusiones

Lo que más destacaría en una entrevista es la auditoría del artefacto de
datos sintéticos: en vez de reportar "encontré una regla con 97.5% de
recall" como un éxito sin más, documenté por qué probablemente no
generalizaría — es el mismo tipo de rigor que ya había aplicado en otros
proyectos del portafolio (ver `project_ufc_fight_prediction` y
`project_ai_ds_salaries_2026` en las notas de proyectos anteriores), ahora
trasladado a un formato SQL + BI en vez de notebook.

Con más tiempo/recursos mejoraría: (1) construir el `.pbix` real en Power BI
Desktop y publicarlo (pendiente, ver checklist); (2) si hubiera datos reales
disponibles, validar si el patrón de "vaciado de cuenta" se sostiene fuera
de la simulación; (3) agregar una vista de costo de negocio (falso negativo
vs. falso positivo) con supuestos de monto perdido/bloqueado, para dar el
salto de "esta regla detecta mejor" a "esta regla ahorra X".

## 8. Checklist antes de publicar

- [x] README explica el proyecto sin necesidad de revisar todo el detalle
- [x] Archivos organizados, sin pruebas sueltas o versiones viejas
- [x] Sin credenciales ni datos sensibles en el repositorio (dataset público, sin PII real)
- [x] Link a la fuente original incluido y funcionando (ver sección 1 y `README.md`)
- [ ] Proyecto publicado y accesible — **pendiente:** falta construir el `.pbix` en Power BI Desktop (guía en `powerbi/guia_construccion_dashboard.md`) y subir el repositorio/publicar el dashboard
- [ ] Link compartido con tu coach — pendiente hasta completar el punto anterior
