# Guía para construir el dashboard en Power BI Desktop

Todos los datos ya están calculados y exportados en `data/processed/`. Aquí
solo se importa y se arma la parte visual — no hay que recalcular nada dentro
de Power BI salvo un par de medidas simples.

## 1. Cargar los datos

`Inicio > Obtener datos > Texto/CSV` y carga estos 6 archivos de
`data/processed/`:

| Archivo | Rol en el modelo |
|---|---|
| `kpi_resumen.csv` | Tabla de 1 fila, para las tarjetas KPI |
| `agregado_por_tipo.csv` | Barras por tipo de transacción |
| `agregado_diario.csv` | Serie de tiempo (31 días) |
| `agregado_por_hora.csv` | Patrón por hora del día |
| `comparacion_reglas.csv` | Tabla comparativa regla actual vs regla nueva |
| `muestra_transacciones.csv` | Detalle a nivel transacción (8,213 fraudes + 50,000 legítimas de muestra) |

No hace falta crear relaciones entre estas tablas — cada una alimenta
visuales distintos de forma independiente (son tablas de resumen, no un
modelo relacional). Déjalas como tablas sueltas.

## 2. Medidas DAX a crear

Sobre `kpi_resumen`, crea estas medidas (botón derecho en la tabla > Nueva medida):

```dax
Tasa de Fraude % = SUM(kpi_resumen[tasa_fraude_pct])

Recall de la Regla Actual % =
DIVIDE(16, SUM(kpi_resumen[total_fraudes])) * 100
```

Sobre `muestra_transacciones` (para poder filtrar por tipo/fraude en la tabla
de detalle):

```dax
Monto Promedio Muestra = AVERAGE(muestra_transacciones[monto])
```

No se necesitan más medidas complejas — el objetivo es mostrar los hallazgos
ya calculados en SQL, no reconstruir la lógica de negocio dentro de Power BI.

## 3. Páginas del reporte

### Página 1 — Panorama general

- **4 tarjetas (Card)** desde `kpi_resumen`: `total_transacciones`,
  `volumen_total`, `total_fraudes`, `tasa_fraude_pct`.
- **Gráfico de barras** (`agregado_por_tipo`): eje = `tipo`, valor =
  `volumen`; agrega una segunda barra o un gráfico combinado mostrando
  `fraudes` por tipo para que se vea que solo `TRANSFER`/`CASH_OUT` tienen
  barra de fraude.
- **Texto/tarjeta** con el dato "16 de 8,213 detectados por el sistema
  (0.19% recall)" — este es el hallazgo principal, debe ser lo primero que se
  vea.

### Página 2 — Cuándo ocurre el fraude

- **Gráfico de líneas** (`agregado_diario`): eje = `dia`, dos líneas —
  `total_transacciones` y `fraudes` (usa doble eje Y, porque las escalas son
  muy distintas). Esto muestra que el volumen normal fluctúa mucho día a día
  pero el conteo de fraude se mantiene estable.
- **Gráfico de barras o líneas** (`agregado_por_hora`): eje = `hora_del_dia`,
  valores = `total_transacciones` y `tasa_fraude_pct` en ejes separados.
  Agrega un cuadro de texto explicando por qué la tasa de madrugada es
  engañosa (bajo volumen, ver `docs/hallazgos_resumen.md` sección 3).

### Página 3 — La regla de control y la alternativa

- **Tabla** desde `comparacion_reglas`: columnas `regla`,
  `verdaderos_positivos`, `falsos_positivos`, `falsos_negativos`,
  `recall_pct`, `precision_pct`. Con formato condicional en `recall_pct`
  (rojo/verde) se ve de inmediato el contraste 0.19% vs 97.5%.
- **Cuadro de texto** con la advertencia honesta: la regla nueva funciona tan
  bien probablemente porque explota un patrón del dataset sintético, no
  porque sea garantía de que funcionaría igual en producción (copiar el
  párrafo correspondiente de `docs/hallazgos_resumen.md`, sección 4).

### Página 4 — Detalle de transacciones (exploración)

- **Tabla o matriz** desde `muestra_transacciones` con segmentadores
  (slicers) por `tipo` y `es_fraude`, columnas: `step`, `tipo`, `monto`,
  `cuenta_origen`, `cuenta_destino`, `saldo_ini_origen`, `saldo_fin_origen`,
  `fue_marcada`.
- Útil para que en una entrevista puedas mostrar ejemplos reales de
  transacciones fraudulentas y explicar el patrón de vaciado de cuenta.

## 4. Formato general

- Usa un color de alerta (rojo/naranja) reservado únicamente para `fraudes`
  y `es_fraude = 1` en todos los visuales, y un color neutro para el resto —
  consistencia visual entre páginas ayuda a que el dashboard se lea rápido.
- Título de cada página debe indicar la pregunta que responde ("¿Dónde se
  concentra el fraude?", no solo "Página 2").
- Agrega un botón o página de inicio con el resumen de 3 líneas del hallazgo
  principal (regla actual vs regla nueva) — es lo que un director de riesgo
  leería primero.

## 5. Qué NO incluir (y por qué)

No se importa la tabla completa de 6.36M filas a Power BI. Se decidió
agregar en SQL y traer solo un muestreo estratificado para el detalle
transaccional. Esto es una decisión de diseño real de analista (no una
limitación técnica de Power BI, que sí soportaría 6.3M filas): mantiene el
archivo `.pbix` ligero, las consultas rápidas, y dirige el análisis por las
preguntas de negocio en vez de la fuerza bruta. Vale la pena mencionarlo
explícitamente si te preguntan en una entrevista por qué no cargaste todo el
CSV.
