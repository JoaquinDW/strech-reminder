# Revisión independiente de costes Higgsfield (Claude)

Fecha: 2026-11-02. Autor: Claude Code, a partir de `docs/handoffs/claude-code-exercise-media-and-costs.md`.

**Qué se hizo y qué no.** Leí el handoff, los materiales de `docs/prototypes/illustrated-instructor/` y el código (`DemoRoutines.swift`, `BreakFlowView.swift`, rig de Kip). Revisé precios con fuentes oficiales de Higgsfield. **No** compré planes, no subí medios, no consulté saldo ni consumí créditos, no generé videos, no modifiqué la app y no ejecuté tests.

**Limitaciones de esta revisión.**
- No tengo el conector MCP de Higgsfield en esta sesión: **no repetí ninguna cotización** (`estimate_video_cost`) ni el saldo. Las cifras por intento son las siete cotizaciones históricas de `higgsfield-budget.json` (mismo día). Las uso como precios unitarios, no como cotizaciones mías.
- La página `higgsfield.ai/pricing` no se pudo renderizar desde mi entorno (contenido dinámico y red bloqueada). Verifiqué los planes con el artículo oficial de precios, la ayuda oficial y la ayuda de MCP (enlaces al final). La oferta del checkout de tu cuenta y país sigue sin confirmar.

---

## 1. Recomendación

| Decisión | Recomendación |
|---|---|
| Plan para el piloto | **Starter, mensual** (15 USD + impuestos, 200 créditos). Sin Auto-Refill ni packs. |
| Canal | **MCP (créditos del plan)** o la web: para Seedance 2.0 en Starter cuestan lo mismo. Nada de Unlimited aplica vía MCP. |
| Modelo | **Primera ronda comparativa Mini vs Fast** (8 s, 720p, 1:1, sin audio) en los dos pilotos. Quedarse con el más barato que pase la rúbrica. |
| Límite por intento | ≤ 20 créditos (Fast 8 s). Cualquier cotización mayor = parar y recalcular. |
| Techo del piloto | **160 créditos** (se mantiene el anterior), con reparto distinto (ver §5). |
| Señal de parada | 2 fallos parecidos del mismo movimiento con el mismo modelo, o ningún modelo aprobado tras la ronda 2. |
| Pasar a Plus | Solo si: piloto aprobado **y** inventario fijado **y** la proyección (clips × 3 × cotización) supera lo que Starter cubre en el plazo deseado, o si el piloto demuestra que hace falta Start & End Frame o Kling. |

Diferencias con la recomendación anterior: coincido en Starter mensual para el piloto y en el techo de 160, pero **cambio el modelo de "Fast por defecto" a "comparar Mini y Fast en la primera ronda"**. Mini cuesta 8 créditos frente a 20 por intento; si sirve, la biblioteca completa cabe en 1–2 meses de Starter y Plus deja de ser necesario. Esa comparación cuesta 16 créditos más que hacer solo Fast y es la información que más cambia el presupuesto. También propongo **reflejar en espejo** los movimientos bilaterales frontales para no generar cada lado (§3).

---

## 2. Precios y acceso verificados

### Planes individuales (USD/mes, sin impuestos)

| Plan | Mensual | Créditos/mes | USD/crédito si se gasta todo | Fuente |
|---|---:|---:|---:|---|
| Starter | 15 | 200 | 0,075 | Blog oficial de precios (24-oct-2026) + oferta renderizada vista en el handoff |
| Plus | 49 | 1.000 | 0,049 | ídem |
| Ultra | 129 | 3.000 | 0,043 | Blog oficial |

- **Coincide** con lo que observó el handoff (15/200 y 49/1.000). El blog oficial está fechado el 24-oct-2026.
- **Discrepancia que sigue viva:** un artículo de Krea (competidor, actualizado el 23-oct-2026) lista Starter 19/270 y Plus 59/1.200 (47 anual). Lo trato como oferta antigua o regional. **Si el checkout muestra otra cifra, rehacer §4–§5.**
- Anual: el blog oficial no da tarifas anuales. El handoff vio Plus anual ≈39 USD/mes facturado por año; no lo verifiqué. No es relevante para un piloto de un mes.

### Acceso por plan (lo relevante para nosotros)

| Función | Starter | Plus | Fuente / estado |
|---|---|---|---|
| Seedance 2.0 Fast y Mini | Sí | Sí | Handoff (oferta renderizada + catálogo MCP). No reverificado. |
| Kling 3.0 std/pro | Probablemente no ("selected models") | Sí ("every model") | Catálogo MCP del handoff marcaba std desde Plus. No reverificado. |
| Start & End Frame | No | Sí | Blog oficial (Plus/Ultra lo incluyen). |
| Videos simultáneos | 2 | 6 | Blog oficial. Irrelevante: generaremos de uno en uno. |
| Unlimited de video Seedance/Kling | No | Plus mensual: no (solo imagen); Kling 3.0 720p 5 s en Plus **anual** | Blog oficial. Las promos cambian (p. ej. "14-Day Unlimited Seedance" de julio). |
| Unlimited de imagen (Seedream 5.0 Lite, FLUX.2 Pro 1K) | Sí, 365 días, solo web | Set completo | Blog oficial. Útil para una referencia "de pie" si hace falta. |

### Web vs MCP vs API

| Canal | Cómo se cobra | Unlimited/gratis | Nota |
|---|---|---|---|
| Web (higgsfield.ai) | Créditos del plan | **Sí** aplica | Único canal donde una promo Unlimited ahorra créditos. |
| MCP / CLI / Canvas / Supercomputer | Créditos del plan, a tarifa estándar | **No**, nunca | Ayuda oficial de MCP (1-ago-2026) y de créditos. |
| API (console.higgsfield.ai) | **Saldo prepago en USD, separado**; el plan no cuenta | No | Blog oficial de la API (16-sep-2026). Tarifas "desde": Seedance 2.0 0,9332 USD/s; Kling 3.0 0,112 USD/s. El saldo caduca al año. |

Consecuencias:
- No sumar créditos del plan con saldo API: son sistemas distintos.
- Seedance 2.0 por API (≈7,47 USD por intento de 8 s) es ~5× más caro que por Starter (20 créditos ≈ 1,50 USD). Descartado.
- Kling 3.0 por API (≈0,90 USD por 8 s, tarifa "desde", sin confirmar modo/resolución) es una **alternativa real sin suscripción** si Kling resultara ser el mejor modelo. Requiere configurar la API y prepagar; queda como opción a verificar, no como plan inicial.

### Reglas de créditos (ayuda oficial)

- Los créditos de suscripción **caducan en cada renovación**; no se acumulan. Packs/Auto-Refill caducan a los 90 días.
- Se gastan primero los de suscripción.
- Fallos: "normalmente" reembolso automático en minutos; **algunos modelos no reembolsan**. Contar el reembolso solo cuando aparezca en Usage.
- Un re-roll se cobra como un intento nuevo.

---

## 3. Inventario real de clips

Código: `DemoRoutines.swift` define 10 movimientos. Las rutinas usan 4/6/8 movimientos y asignan **30 s por movimiento** (2 y 3 min) o **37 s** (5 min). Un clip de 8 s se repetirá ~4 veces; la duración de la rutina no exige clips largos.

| Movimiento | Postura | Lados / partes | Clips a generar | Nota |
|---|---|---|---:|---|
| Shoulder rolls (piloto A) | Sentado | Simétrico | 1 | Ping-pong no sirve: invierte el sentido del giro. |
| Seated twist (piloto B) | Sentado, ¾ | Bilateral | 1 + espejo | Validar que el espejo del ¾ se ve coherente. |
| Ear to shoulder | Sentado | Bilateral | 1 + espejo | Frontal, buen candidato a espejo. |
| Slow yes, slow no | Sentado | Dos movimientos | 2 | Hoy el rig solo inclina la cabeza; separar "sí" y "no". |
| Shrug and drop | Sentado | Simétrico | 1 | Corto (5 s posible). |
| Chest opener | Sentado, manos en la silla | Simétrico | 1 | La referencia ya tiene silla sin apoyabrazos. |
| Big reach | Sentado | Simétrico | 1 | Brazos fuera del encuadre actual: revisar margen superior. |
| Seated curl and arch | Sentado | Simétrico | 1 | Mejor vista ¾ o lateral para leer la columna. |
| Side reach | Sentado | Bilateral | 1 + espejo | |
| March in place | **De pie** | — | 1 | **Necesita nueva referencia de pie** (image_gen o Unlimited de imagen en web). |

- **Con espejo:** 11 clips generados. **Sin espejo:** 14 (coincide con el escenario de 14 del handoff).
- El espejo horizontal es gratis, pero hay que revisar asimetrías del personaje (pelo, sombra). Es distinto de invertir el tiempo del video, que el README descarta con razón.
- Hallazgos del handoff confirmados en el código: la escena usa `prop: .mat` aunque los textos hablan de silla; al pausar se cambia a `.resting`; "Keep going" tiene acción vacía y no reanuda el reloj. No cambian el coste, pero sí la integración.

**Alcance propuesto para v1 (núcleo, 6 clips):** shoulder rolls, seated twist, ear to shoulder, shrug, seated curl and arch, big reach. Cubre cuello, hombros y espalda, todo sentado y con la referencia actual. Los otros 5 clips (yes, no, chest opener, side reach, march) quedan para la biblioteca completa; mientras tanto esos movimientos usan el demostrador actual o poses clave estáticas.

---

## 4. Escenarios de coste

**Fórmula:** `créditos = clips únicos × intentos por clip × créditos por intento`. Las partidas fuera de Higgsfield van aparte (§6). El equivalente en USD de los créditos **no se suma** a la suscripción: el desembolso es el plan.

Créditos por intento (cotizaciones históricas del 2-nov, MCP): Mini 8 s = 8 · Kling std 8 s = 12 · Fast 5 s = 12,5 · Fast 8 s = 20 · Seedance 2.5 720p 8 s = 56.

Intentos por clip: 1 = optimista, 2 = base bajo, 3 = base, 4 = conservador. **Ninguno es una tasa de éxito medida.**

### Dos pilotos (2 clips)

| Modelo | 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|
| Mini 8 s | 16 | 32 | 48 | 64 |
| Kling std 8 s (Plus) | 24 | 48 | 72 | 96 |
| Fast 5 s | 25 | 50 | 75 | 100 |
| Fast 8 s | 40 | 80 | 120 | 160 |
| Seedance 2.5 720p | 112 | 224 | 336 | 448 |

### Núcleo v1 (6 clips)

| Modelo | 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|
| Mini 8 s | 48 | 96 | 144 | 192 |
| Kling std 8 s | 72 | 144 | 216 | 288 |
| Fast 5 s | 75 | 150 | 225 | 300 |
| Fast 8 s | 120 | 240 | 360 | 480 |

### Biblioteca completa (11 clips con espejo / 14 sin espejo)

| Modelo | 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|
| Mini 8 s | 88 / 112 | 176 / 224 | 264 / 336 | 352 / 448 |
| Kling std 8 s | 132 / 168 | 264 / 336 | 396 / 504 | 528 / 672 |
| Fast 5 s | 138 / 175 | 275 / 350 | 413 / 525 | 550 / 700 |
| Fast 8 s | 220 / 280 | 440 / 560 | 660 / 840 | 880 / 1.120 |

Mezcla realista con Fast (5 clips simples a 5 s + 6 a 8 s = 182,5 créditos por ronda): 3 intentos ≈ 548 créditos.

### Qué plan cubre cada escenario (caso base, 3 intentos)

| Escenario | Créditos | Opción más barata | Desembolso |
|---|---:|---|---:|
| Pilotos, Fast | 120 | Starter 1 mes | 15 USD |
| Pilotos, Mini | 48 | Starter 1 mes | 15 USD |
| Núcleo v1, Mini | 144 | Starter 1 mes | 15 USD |
| Núcleo v1, Fast | 360 | Starter 2 meses (≈ 400) o Plus 1 mes | 30 / 49 USD |
| Completa (11), Mini | 264 | Starter 2 meses | 30 USD |
| Completa (11), Fast | 660 | Plus 1 mes (340 caducan) | 49 USD |
| Completa (14), Fast, 4 intentos | 1.120 | Excede Plus; Plus + otro mes | ≥ 64 USD |
| Completa (11), Kling por API | ~33 intentos × ~0,90 | Saldo API, sin plan | ≈ 30 USD (tarifa "desde", sin verificar) |

Lectura: **el modelo elegido pesa más que el plan.** Con Mini todo cabe en Starter; con Fast la biblioteca completa justifica Plus durante un mes; Seedance 2.5 no cabe en ningún escenario razonable.

---

## 5. Presupuesto propuesto del piloto (techo 160)

| Paso | Intentos | Créditos | Acumulado |
|---|---|---:|---:|
| R1: comparación, cada piloto en Mini y en Fast | 4 | 2×8 + 2×20 = 56 | 56 |
| Decisión: elegir el modelo más barato que pase la rúbrica | — | 0 | 56 |
| R2–R3 si gana Fast: hasta 2 correcciones por clip | ≤ 4 | ≤ 80 | ≤ 136 |
| R2–R3 si gana Mini: hasta 2 correcciones por clip | ≤ 4 | ≤ 32 | ≤ 88 |
| Margen sin asignar (no se gasta por iteraciones estéticas) | — | — | ≥ 24 hasta 160 |

Gasto esperado: **72 créditos** (ruta Mini, 1 corrección por clip) o **96** (ruta Fast). Máximo: 136. Desembolso real en todos los casos: 15 USD + impuestos.

Rúbrica para "pasa" (de README.md, resumida): se mueve lo que dice el nombre; identidad y extremidades estables en inicio/mitad/final; cámara quieta; el inicio y el final permiten bucle (o un fundido corto en la app lo disimula); personas nuevas entienden el ejercicio sin explicación.

Si ningún modelo pasa en R1 **y** R2 por el mismo tipo de fallo, parar: revisar referencia, encuadre o método antes de gastar más.

Límites operativos del handoff que mantengo: cotización nueva antes de cada envío; una generación a la vez con count=1; reservas pendientes cuentan como gasto; no reenviar por timeout sin el job_id; reembolsos solo confirmados; `confirmados + reservados + próxima cotización ≤ 160`; nada de upgrades, packs ni Auto-Refill por iniciativa propia.

---

## 6. Otros costes, separados

| Partida | Estado |
|---|---|
| Suscripción Higgsfield | 15 USD (Starter) / 49 USD (Plus) por mes + impuestos. Créditos no usados caducan. |
| Imagen de referencia de pie (march) | image_gen integrada (ya usada) o Unlimited de imagen en la web de Starter. **No cotizado** en créditos. |
| Edición/QA (recorte, bucle, espejo, compresión) | Herramientas libres (ffmpeg/AVFoundation). Tiempo humano, sin tarifa. |
| Revisión profesional de los ejercicios | **No cotizada. Sigue pendiente** y es requisito antes de publicar. |
| Almacenamiento/distribución | Clips en el bundle de la app (§7). Sin CDN ni backend. 0 USD. |
| Claude Code (esta sesión y las siguientes) | Separado de Higgsfield. Depende de tu modalidad (suscripción con límites de uso o API por tokens), que no conozco. No estimo un precio. Fórmula si es API: tokens de entrada × tarifa + tokens de salida × tarifa del modelo usado. |

---

## 7. Integración y coste por usuario

- Generar una vez y **empaquetar los MP4/HEVC en la app**. Estimación: 720×720, 5–8 s, ~1–2 MB por clip tras recomprimir; 11–14 clips ≈ 15–30 MB. Supuesto, no medido.
- **Coste de Higgsfield por usuario o reproducción: cero.** No hay llamadas en tiempo de ejecución.
- No hace falta CDN ni backend en v1. Si el tamaño molesta, On-Demand Resources de Apple, sin coste.
- El reloj, textos, Kip y su burbuja quedan en SwiftUI, como pide `companion-spec-v1.md`. Pausar el video congela un fotograma útil y arregla de paso el cambio a `.resting`.
- Bucle sin Start & End Frame (Starter): recortar a fotogramas con pose coincidente y/o un fundido de 0,2–0,3 s con `AVPlayerLooper`. Solo si el salto sigue siendo visible tras eso, Start & End Frame justifica Plus.

---

## 8. Plan por fases

1. **Sin gasto (ya posible):** fijar inventario (§3); escribir prompts de los 9 clips restantes; crear la referencia de pie; implementar en SwiftUI un reproductor con un video de prueba local más la capa de Kip; corregir pausa/"Keep going"; preparar la rúbrica y una hoja de prueba con personas.
2. **Piloto (Starter, ≤ 160 créditos):** subir `instructor-reference-v1.png`, obtener el media ID, recotizar, ejecutar R1 (56), decidir modelo, corregir hasta el techo.
3. **Decisión de método:** si pasa, elegir modelo y plan con §4. Si no, valorar animación 2D por keyframes (Rive/Lottie o un rig humano en Canvas): coste en tiempo, no en créditos, con bucles exactos y poses para Reduce Motion.
4. **Producción:** núcleo v1 (6 clips) y luego el resto, con techo por fase = clips × 3 × cotización, y parada por clip a los 4 intentos.
5. **Integración y revisión profesional** antes de publicar.

---

## 9. Incertidumbres

- **Tasa de aceptación desconocida.** Es el mayor factor: entre 1 y 4 intentos por clip, el coste se multiplica por 4.
- **Calidad Mini vs Fast vs Kling sin probar** para articulaciones legibles en estilo plano.
- **Precio de checkout no confirmado** (15/200 vs 19/270; impuestos y región).
- **Acceso por plan de Kling y Mini no reverificado** en esta sesión (sin conector).
- **Cotizaciones con medios** pendientes; las de la tabla se hicieron sin imagen subida.
- **Saldo y plan actuales** no reverificados (el handoff vio Free, 0 créditos).
- Tarifas de la API marcadas como "desde": pueden subir con modo o resolución.
- Prorrateo al pasar de Starter a Plus a mitad de ciclo: no verificado.
- Espejo de clips bilaterales: depende de la simetría del personaje.

## Fuentes

- Handoff y materiales: `docs/handoffs/claude-code-exercise-media-and-costs.md`, `higgsfield-budget.md/.json`, `pilot-requests.json`, `credit-ledger.json`, `companion-spec-v1.md`, `README.md` (2-nov-2026).
- Higgsfield, "Higgsfield pricing explained" (24-oct-2026): https://higgsfield.ai/blog/higgsfield-pricing-explained
- Higgsfield Help Center, cómo funcionan los créditos: https://higgsfield.ai/creator-hub/help-center/credits/how-credits-work
- Higgsfield Help Center, qué es Higgsfield MCP (1-ago-2026): https://higgsfield.ai/creator-hub/help-center/integrations/what-is-higgsfield-mcp
- Higgsfield, "Higgsfield API: How It Works" (16-sep-2026): https://higgsfield.ai/blog/higgsfield-api
- Higgsfield, "14-Day Unlimited Seedance" (30-jul-2026, solo web): https://higgsfield.ai/blog/seedance-unlimited-14-days
- Krea (competidor), precios de Higgsfield (actualizado 23-oct-2026): https://www.krea.ai/blog/higgsfield-pricing-explained-2026-unlimited-credits-and-real-monthly-costs
- No accesible desde esta sesión: https://higgsfield.ai/pricing (renderizado dinámico).
