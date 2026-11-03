# Handoff para Claude Code — Unshrimp: ejercicios ilustrados, Kip y costes

Preparado el 2 de noviembre de 2026. Este documento transmite contexto y trabajo pendiente; no equivale a una autorización para comprar suscripciones o gastar créditos.

## Encargo del usuario

El usuario pidió revisar la app y sus animaciones. Le gusta la estructura de rutinas para v1, pero las demostraciones actuales no explican bien los ejercicios. Preguntó si videos hechos con Higgsfield ayudarían. Eligió explorar una figura humana ilustrada y aclaró que quiere conservar a la mascota durante el entrenamiento, arriba o a un costado, haciendo comentarios como «Ese me vendría muy bien…».

Después pidió comparar Starter y Plus, preparar el material y estimar el consumo para no excederse. Ahora quiere que Claude Code reciba el contexto y haga también un análisis independiente de costes.

**Tu objetivo inmediato:** revisar el repositorio y los materiales, contrastar el análisis existente y entregar una recomendación propia de plan, modelo, presupuesto y próximos pasos. No asumir que la recomendación anterior es correcta ni que los números siguen vigentes.

Continúa con la investigación y preparación sin pedir confirmaciones rutinarias. Este encargo es de análisis y preparación: no incluye compras, recargas, generaciones pagadas o integración en producción.

## Repositorio y estado

Ruta local: `/Users/balthasardeweert/Documents/Projects/strech-reminder`.

- App iPhone nativa SwiftUI, iOS 18+, proyecto generado con XcodeGen desde `project.yml`.
- Marca de trabajo: Unshrimp. Mascota: Kip, un camarón.
- Estado con Observation, persistencia JSON local y notificaciones locales.
- Flujo: onboarding → escritorio/home → presentación de rutina → ejercicios con reloj → confirmación de usuario → recompensa.
- Rutinas de 2/3/5 minutos y diez movimientos de demostración.
- La nueva figura y las pantallas propuestas son imágenes conceptuales. **No se ha modificado el código de entrenamiento para integrarlas.**
- No hay videos de ejercicio generados, descargados o incorporados.
- La imagen del instructor y los mockups se hicieron con image_gen integrada, no con Higgsfield.
- Higgsfield rechazó el primer intento de imagen con `Requires basic plan or higher.`; no devolvió job ID.
- La consulta de saldo posterior informó Free, 0 créditos y sin Unlimited disponible. Verificar de nuevo si hace falta; el usuario puede haber cambiado de plan.

Estado de Git observado al preparar este handoff:

```text
 M Unshrimp/Resources/Localizable.xcstrings
?? .impeccable/
?? Unshrimp.xcodeproj/
?? docs/prototypes/
```

No revertir ni sobrescribir cambios existentes. Revisar instrucciones AGENTS.md/CLAUDE.md aplicables antes de trabajar; no se encontraron esos archivos dentro del repositorio durante esta preparación.

## Qué leer primero

Todos los paths siguientes son relativos al repositorio.

1. `README.md` y `project.yml`.
2. `Unshrimp/Features/Break/BreakFlowView.swift`.
3. `Unshrimp/Model/DemoRoutines.swift`.
4. `Unshrimp/Mascot/ShrimpPose.swift`, `ShrimpRenderer.swift`, `ShrimpView.swift` y `ShrimpStage.swift`.
5. `Unshrimp/Features/Onboarding/OnboardingFlow.swift`.
6. `docs/prototypes/illustrated-instructor/README.md`.
7. `docs/prototypes/illustrated-instructor/companion-spec-v1.md`.
8. `docs/prototypes/illustrated-instructor/higgsfield-budget.md` y `higgsfield-budget.json`.
9. `docs/prototypes/illustrated-instructor/pilot-requests.json` y `credit-ledger.json`.

Capturas reales de la app: `docs/screenshots/`. Mockup preferido: `docs/prototypes/illustrated-instructor/exercise-screen-with-kip-v2.png`.

La revisión detallada anterior está en `.impeccable/critique/2026-11-02T18-54-29Z__unshrimp-features-break-breakflowview-swift.md`.

## Diagnóstico técnico y de experiencia previo

Este diagnóstico se obtuvo de código y capturas, no de reproducción en vivo de las animaciones. Contrástalo.

Kip se dibuja en Canvas con una cadena de círculos y brazos simples. ShrimpMotion calcula poses periódicas; PoseBlender interpola entre estados durante 0,6 segundos. LiveCanvas contempla 30 fps, visibilidad, segundo plano y Reduce Motion.

El sistema funciona como mascota expresiva. La limitación al enseñar es anatómica y de coreografía:

- Shoulder rolls alterna brazos y añade rebote; no explica claramente rotación de hombros.
- Shrug desplaza el cuerpo entero.
- Seated twist inclina la figura en 2D en lugar de representar rotación del torso.
- Slow yes, slow no incluye varios movimientos en el texto pero la pose solo inclina la cabeza.
- La instrucción de algunos ejercicios menciona una silla, mientras la escena muestra una colchoneta.

Otros hallazgos relevantes para una futura integración:

- Al pausar se cambia de exercise a resting, perdiendo la referencia del ejercicio.
- No hay preparación ni fases explícitas de cambio de lado.
- El reloj comienza inmediatamente y avanza de ejercicio automáticamente.
- El cierre pausa el reloj y Keep going no lo reanuda.
- Canvas se pausa en segundo plano; el reloj usa tiempo de pared y puede completar el movimiento al volver.
- Reduce Motion elimina oscilaciones sin ofrecer poses de inicio/fin equivalentes.
- El código marca el contenido como provisional y sin revisión profesional.

Los tests existentes recorren el flujo con capturas y saltos manuales; no verifican fidelidad de movimiento o todos esos casos de reloj. No se ejecutaron tests en esta revisión. No describirlos como aprobados.

## Dirección de producto acordada

- Mantener la identidad visual actual: marfil, coral, verde petróleo y menta; contornos redondeados.
- Figura humana ilustrada para mostrar el movimiento, con articulaciones legibles.
- Kip permanece visible durante el entrenamiento, pequeño arriba o a un costado.
- Comentarios breves, amables y sobre sí mismo; no juzgar al usuario.
- La burbuja aparece en momentos puntuales y no coincide con instrucciones importantes o cambio de lado.
- No tapar al instructor, cuello, hombros, brazos, reloj o controles.
- Kip y sus frases son una capa nativa independiente del video: facilita traducción y variaciones sin regenerar medios.
- Conservar las animaciones por código para Kip, escritorio y recompensas.
- Reutilizar clips entre rutinas. La duración de una rutina no determina la longitud de un video generado.
- Un video vistoso no sustituye claridad o corrección del movimiento.

Referencia del instructor: `instructor-reference-v1.png`. Persona sentada en silla sin apoyabrazos, camiseta coral sin mangas y pantalón petróleo. La imagen neutral define aspecto; no demuestra por sí sola los ejercicios.

**No usar como entrada de video la pantalla completa con UI y Kip.** Usar la referencia aislada del instructor y mantener texto/reloj/mascota fuera de los medios generados.

## Piloto preparado

Dos clips: círculos de hombros y giro sentado.

Parámetros presupuestados:
- `model: seedance_2_0`
- `mode: fast`
- `resolution: 720p`
- `duration: 8`
- `aspect_ratio: 1:1`
- `generate_audio: false`
- `count: 1`

Los prompts completos están en README.md y exportados a pilot-requests.json.

Falta subir la referencia y obtener un media ID válido. No inventar IDs ni tratar los JSON como solicitudes listas para enviar sin ese paso. Las cotizaciones se hicieron sin medios; deben repetirse para los parámetros completos. No hay un video real de referencia disponible para Motion Control: incorporarlo requeriría preparar o conseguir uno adecuado.

Starter no ofrece el control dedicado Start & End Frame según la comparación observada. El piloto presupuestado usa solo start_image. Pedir en el prompt que el clip vuelva al inicio no garantiza un bucle perfecto. Evaluar si esa limitación altera la recomendación de plan o exige otro método.

## Análisis de costes anterior: datos que debes revalidar

Se recomienda consultar fuentes primarias y la oferta renderizada, no solo resultados de búsqueda. Registrar fecha, moneda, facturación mensual/anual, resolución, duración, audio y canal.

Oferta visible en el navegador, tarjetas principales con Monthly seleccionado, el 2026-11-02:

| Plan | Precio mensual USD antes de impuestos | Créditos/mes |
|---|---:|---:|
| Starter | 15 | 200 |
| Plus | 49 | 1.000 |

La misma web mostraba Plus anual equivalente a 39 USD/mes, facturado anualmente: no confundirlo con un mes independiente.

**Discrepancia real:** algunas páginas oficiales indexadas mostraban Starter 19 USD/270 y Plus 59 USD/1.200. No ocultar la diferencia. Se priorizó la oferta renderizada, pero no se inició checkout ni se confirmó el precio regional de la cuenta. Si vuelve a aparecer otra oferta, recalcular.

Fuentes:
- https://higgsfield.ai/pricing
- https://higgsfield.ai/blog/higgsfield-pricing-explained
- https://higgsfield.ai/creator-hub/help-center/credits/how-credits-work

Siete cotizaciones de Higgsfield MCP estimate_video_cost, sin enviar trabajos:

| Modelo/configuración | Duración | Audio | Créditos/intento |
|---|---:|---|---:|
| Seedance 2.0 Mini 720p | 8 s | Desactivado | 8 |
| Kling 3.0 std | 8 s | off | 12 |
| Kling 3.0 pro | 8 s | off | 14 |
| Seedance 2.0 Fast 720p | 5 s | Desactivado | 12,5 |
| Seedance 2.0 Fast 720p | 8 s | Desactivado | 20 |
| Seedance 2.5 omni_reference 720p | 8 s | Desactivado | 56 |
| Seedance 2.5 omni_reference 1080p | 8 s | Desactivado | 128 |

Los parámetros exactos están guardados en higgsfield-budget.json. La cotización no acredita acceso del plan al modelo ni calidad del resultado.

El catálogo del conector identifica Seedance 2.0 Fast como disponible desde Basic/Starter y std desde Plus. La elección previa de Fast fue por acceso explícito y presupuesto, **no porque se haya comprobado que es el mejor para estos ejercicios**.

La ayuda oficial y la página de planes señalaban que Unlimited y free generations de planes se aplican en la web; MCP/CLI, Canvas y Supercomputer consumen créditos. No dar por hecho que una promoción de la web aplica desde Claude Code. Verificar la regla vigente y el canal real.

No mezclar créditos de suscripción con saldo API en USD sin comprobar que son el mismo sistema. Tampoco mezclar el coste de la conversación con Claude o las imágenes hechas aquí con los créditos Higgsfield.

## Presupuesto previo y límites

Recomendación anterior: Starter mensual para el piloto; Plus al escalar. **Es una hipótesis para revisar, no una conclusión que debas repetir.**

Lote de dos clips, Fast a 20 créditos/intento:
- Primera versión de cada uno: 2 intentos, 40 créditos.
- Planificación de 2–3 intentos/clip: 80–120 créditos.
- Techo propuesto: 4 intentos/clip, 8 totales, 160 créditos.
- Margen no asignado en Starter observado: 40 créditos.

No hay datos empíricos de tasa de éxito. Las rondas son una reserva de planificación. Un primer intento puede ser suficiente; también puede fallar el método completo.

Escenario separado de diez clips a ese precio:
- 3 intentos/clip: 600 créditos.
- 4 intentos/clip: 800 créditos.
- Catorce clips con 4 intentos: 1.120, excediendo Plus de 1.000.

No asumir que diez movimientos equivalen a diez archivos finales: lados, posiciones, movimientos combinados y duraciones pueden ampliar el inventario.

Los techos están documentados, **no configurados como límites de plataforma**. El usuario quiere evitar pasarse; no ha autorizado consumir automáticamente esas cantidades.

Para una ejecución futura:
- Cotización nueva antes de cada envío.
- Una generación a la vez y count=1.
- Incluir trabajos pendientes/desconocidos como gasto reservado.
- No reenviar por timeout sin resolver el resultado del trabajo original.
- No restar devoluciones hasta confirmar su abono.
- Cargos netos confirmados + reservas + próxima cotización deben caber en el límite.
- No cambiar modelo/resolución/duración/audio ni superar 20 créditos por intento sin recalcular.
- Tras dos fallos parecidos de técnica, replantear referencia o método.
- Sin compras, top-ups, Auto-Refill, upgrades o nuevas suscripciones por iniciativa propia.
- No agotar reservas si el clip ya cumple el objetivo.
- El ledger está vacío: no confundir cotizaciones con cargos.

## Tu análisis independiente de costes

Hazlo completo pero práctico. Entrega una conclusión propia con fuentes y supuestos visibles.

1. **Verificar precios y acceso:** planes actuales, mensual frente a anual, impuestos/región no confirmados, modelos y funciones disponibles, restricciones por web/MCP/API y promociones temporales. Si no tienes el conector, indícalo; no presentar tarifas web como una cotización de MCP.
2. **Revisar el inventario real:** diez movimientos actuales, cuáles requieren silla/de pie, otro ángulo, otro lado o separación de movimientos. Proponer un alcance pequeño para v1 y contar archivos únicos.
3. **Comparar modelos/métodos:** Fast, Mini, Kling y alternativa de Motion Control con referencia real, si el catálogo actual los permite. Valorar coste por clip aceptable, identidad y legibilidad de articulaciones. Sin generar para este análisis.
4. **Construir escenarios:** dos pilotos, biblioteca pequeña y biblioteca completa. Mostrar 1/2/3/4 intentos por clip o escenarios optimista/base/conservador bien definidos. Variar duración y calidad donde tenga sentido.
5. **Mostrar la fórmula:** clips únicos × intentos por clip × créditos por intento, más partidas separadas justificadas. No sumar como gasto extra los dólares equivalentes de créditos a una suscripción que ya los incluye.
6. **Separar costes:** desembolso real de suscripción, créditos consumidos, saldo sobrante/caducidad, posibles imágenes nuevas, preparación de referencia, edición/QA, revisión profesional y almacenamiento/distribución si se usan. Partidas sin tarifa verificada deben figurar como no cotizadas.
7. **Evaluar integración:** clips locales frente a CDN. Generarlos una vez evita regenerar por cada sesión. No inventar un coste de Higgsfield por usuario o reproducción; si se estima tráfico/CDN, mostrar tamaño, reproducciones y proveedor. No añadir un backend sin necesidad.
8. **Revisar gasto del agente:** si el usuario quiere estimar tokens de Claude Code, distinguirlo de Higgsfield y de su modalidad de facturación. No inventar un conteo o precio exacto de una sesión futura. Dar fórmulas/escenarios solo con modelo, tarifa y modalidad verificados.
9. **Recomendar una opción concreta:** plan/ciclo/modelo inicial, límite por intento, techo de lote, señal para detenerse y condición objetiva para pasar a Plus. Si otra alternativa conviene más, explicarla.
10. **Cuantificar incertidumbre:** aceptación de clips aún no medida, precios discrepantes, acceso regional y funciones no verificadas. La revisión profesional del ejercicio continúa pendiente.

## Entregables esperados de Claude

- Un resumen en español con recomendación, tabla comparativa, gasto esperado y techo.
- `docs/prototypes/illustrated-instructor/claude-cost-review.md`: análisis independiente con fuentes, fecha, fórmulas y limitaciones.
- Si recalculas cifras, crear `claude-budget-proposal.json` o una versión nueva; conservar las cotizaciones históricas y no sobrescribirlas como si fueran actuales.
- Un inventario de clips propuesto para v1 y plan por fases: validación de dos movimientos, decisión de método, producción del resto e integración.
- Enumerar brevemente qué falta para ejecutar y qué se puede hacer sin gasto.
- No afirmar que se generaron videos, se probó movimiento en vivo, se integró UI o se aprobaron tests si no ocurrió.

Prioridad: demostrar que una persona entiende el ejercicio y mantener a Kip presente, con gasto controlado. No perseguir un acabado visual más caro antes de validar esa comprensión.

