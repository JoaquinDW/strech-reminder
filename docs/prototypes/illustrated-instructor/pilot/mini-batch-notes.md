# Lote Mini: ejercicios sentados

Fecha: 2026-11-02. Modelo exclusivo: Seedance 2.0 Mini. Parámetros: 8 s, 720p solicitados, 1:1, audio desactivado y la misma referencia como fotograma inicial y final.

## Créditos y alcance

- Techo aprobado en el handoff suministrado por el usuario: **96 créditos nuevos**. Estado del lote: **complete**.
- Saldo inicial del lote: **972**. Último saldo comprobado: **876**.
- Cargos brutos del lote: **96**; devoluciones confirmadas: **0**; gasto neto: **96/96**; reservas pendientes: **0**.
- El piloto anterior costó 28 netos y está fuera de este techo. El ledger conserva su convención histórica: confirmed_deductions es NETO y confirmed_gross_charges es BRUTO; no restar dos veces los reembolsos.
- No se ha integrado contenido en SwiftUI ni hecho commit/push. No se compraron planes, packs o recargas.

## Resumen por ejercicio

| Ejercicio | Veredicto actual | Trabajo | Archivo / motivo |
|---|---|---|---|
| shoulder-roll | Aceptado previamente por el usuario; no regenerado | 3ebfeb66-b11b-455c-9017-3a159161deb7 | [r1-mini.mp4](shoulder-rolls/r1-mini.mp4) |
| shrug | apto | 5692cfe3-bfc4-4676-895b-2a83ad8be087 | [r2-mini.mp4](shrug/r2-mini.mp4) |
| neck-tilt | apto | 7c2ebd65-0458-48c5-a3d2-e6ecc0c5a8cf | [r1-mini.mp4](neck-tilt/r1-mini.mp4) |
| nod | no apto con Mini | 9d8edc47-1a8d-42fd-be54-69d5f367fc35 | [r2-mini.mp4](nod/r2-mini.mp4) |
| chest-opener | apto | deaf1066-e0e7-4d84-831d-b9afb666f7da | [r1-mini.mp4](chest-opener/r1-mini.mp4) |
| reach-up | no apto con Mini | 8d4c2acb-d6e7-4ee8-bd0c-91109ae826d3 | [r2-mini.mp4](reach-up/r2-mini.mp4) |
| twist | apto | d57bf0b9-d93b-4df4-80d3-36939ed203bc | [r1-mini.mp4](twist/r1-mini.mp4) |
| cat-cow | no apto | 509c0324-eecf-429f-a7b2-f3ba56192292 | [r1-mini.mp4](cat-cow/r1-mini.mp4) |
| side-reach | apto | ae217b21-17c1-47d5-8d66-86da7c73d326 | [r2-mini.mp4](side-reach/r2-mini.mp4) |
| march | Pendiente: necesita referencia de pie | — | No generado por instrucción |

## Rúbrica y evidencia por intento

Se inspeccionan fotogramas extraídos, incluida una tira cronológica cada 16 frames. Un veredicto apto significa apto visualmente como candidato según esas muestras, no validación profesional ni reproducción en tiempo real.

### shrug — R1

- Trabajo: `69955bb5-bc15-41d1-b986-6d67d46e5302`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.968385**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: retomar
- Movimiento: Falla: eleva codos y lleva ambas manos a los hombros; no muestra un encogimiento aislado con manos apoyadas en muslos.
- Identidad y extremidades: Persona y número de extremidades estables en los 12 fotogramas; ojos se cierran durante parte del movimiento.
- Cámara: Sin desplazamiento o zoom evidente en los fotogramas.
- Artefactos: No deformaciones claras; el problema principal es la acción equivocada.
- Bucle: SSIM inicio/fin 0.968385; proximidad visual, no garantía de bucle fluido.
- Evidencia: r1-mini-strip.png, 12 fotogramas cada 16 frames, más inicio/mitad/final extraídos.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo y profundidad no comprobados.

### neck-tilt — R1

- Trabajo: `7c2ebd65-0458-48c5-a3d2-e6ecc0c5a8cf`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.977663**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: apto
- Movimiento: La cabeza se inclina lateralmente hacia un hombro, sostiene y vuelve al centro. Hombros, manos, pelvis y pies permanecen suficientemente estables en las muestras.
- Identidad y extremidades: Identidad y extremidades estables. Cierra los ojos durante la inclinación, pese al prompt; se registra sin retoma estética.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: No deformaciones claras en las muestras.
- Bucle: SSIM inicio/fin 0.977663; revisar continuidad perceptual en reproducción.
- Evidencia: pilot/neck-tilt/r1-mini-strip.png; 12 muestras cronológicas cada 16 fotogramas.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### nod — R1

- Trabajo: `cec28b1d-4080-4f0b-bfac-52a743582409`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.977936**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: retomar
- Movimiento: Giros laterales de cabeza visibles, pero no se distinguen dos asentimientos de sí. La primera fase cambia sobre todo los ojos y el gesto de la cara, con desplazamiento de cabeza muy pequeño.
- Identidad y extremidades: Persona y extremidades estables; ojos cerrados y gesto más serio durante el movimiento.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: Sin deformaciones claras. El fallo funcional es una demostración incompleta de la secuencia sí/no.
- Bucle: SSIM inicio/fin 0.977936; revisar continuidad perceptual en reproducción.
- Evidencia: Tira r1-mini-strip.png y detalle r1-mini-head-detail.png: 24 muestras de los primeros 3 segundos.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### chest-opener — R1

- Trabajo: `deaf1066-e0e7-4d84-831d-b9afb666f7da`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.978000**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: apto
- Movimiento: Coloca las manos a los lados del asiento y eleva el pecho antes de volver a los muslos. Candidato visual: la vista frontal limita juzgar la retracción de hombros; en el pico parecen subir algo, así que debe revisarse técnica antes de producción.
- Identidad y extremidades: Identidad y extremidades estables; las manos alcanzan los bordes del asiento. Los ojos vuelven a cerrarse durante el gesto.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: No se ven extremidades extra, recorte de manos o movimiento de silla. El componente hacia atrás no se puede confirmar con estas muestras.
- Bucle: SSIM inicio/fin 0.978000; revisar continuidad perceptual en reproducción.
- Evidencia: pilot/chest-opener/r1-mini-strip.png; 12 muestras cronológicas cada 16 fotogramas.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### twist — R1

- Trabajo: `d57bf0b9-d93b-4df4-80d3-36939ed203bc`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.978446**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: apto
- Movimiento: Se ve cambiar la orientación del pecho y de la línea de hombros, con pelvis, rodillas y pies esencialmente fijos, y regresa al centro. Hay un giro inicial de cabeza antes del torso, pero no se limita a una inclinación lateral.
- Identidad y extremidades: Misma persona y extremidades estables. Las manos se deslizan sobre muslos sin apoyarse para forzar el giro.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: No deformaciones ni recortes evidentes en las muestras; revisar transición intermedia y perspectiva al reproducir.
- Bucle: SSIM inicio/fin 0.978446; revisar continuidad perceptual en reproducción.
- Evidencia: pilot/twist/r1-mini-strip.png; 12 muestras cronológicas cada 16 fotogramas.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### side-reach — R1

- Trabajo: `eb694a21-cfd9-46ce-8a03-715ee3439b69`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.978583**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: retomar
- Movimiento: La elevación de un brazo y la inclinación lateral se entienden, pero la mano sale por el borde superior durante la subida. Incumple mantener la articulación visible durante toda la demostración.
- Identidad y extremidades: Identidad y extremidades estables en la fase mantenida; un brazo arriba y la otra mano en muslo. Cierra los ojos en parte del gesto.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: Recorte visible de dedos/mano en muestras de subida (aprox. 2–2,7 s); no se observa zoom que lo compense.
- Bucle: SSIM inicio/fin 0.978583; revisar continuidad perceptual en reproducción.
- Evidencia: pilot/side-reach/r1-mini-strip.png; 12 muestras cronológicas cada 16 fotogramas.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### reach-up — R1

- Trabajo: `64170c35-6c58-4237-ba82-60510491a33a`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.978031**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: retomar
- Movimiento: Eleva ambos brazos, pero los abre lateralmente en V en vez de llevarlos hacia delante y arriba. Las puntas de ambas manos quedan recortadas en la postura mantenida.
- Identidad y extremidades: Persona, silla y extremidades estables; no brazos extra.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: Recorte superior de dedos confirmado en r1-mini-mid.png a tamaño completo. El encuadre actual deja poco margen para brazos extendidos.
- Bucle: SSIM inicio/fin 0.978031; revisar continuidad perceptual en reproducción.
- Evidencia: r1-mini-strip.png y r1-mini-mid.png a 960×960.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### cat-cow — R1

- Trabajo: `509c0324-eecf-429f-a7b2-f3ba56192292`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.978736**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: no apto
- Movimiento: Solo muestra inclinar el torso hacia delante y volver a neutral. No aparece de forma legible la segunda fase de abrir/arquear el pecho, por lo que no demuestra curl and arch completo.
- Identidad y extremidades: Persona y extremidades estables; manos en las rodillas/muslos y pelvis sentada. Ojos cerrados en parte del gesto.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: No deformaciones claras; la vista frontal oculta la curvatura de columna. No se programa retoma: el problema pide otro encuadre/referencia y las cuatro retomas del lote se asignan a fallos más concretos de gesto o recorte.
- Bucle: SSIM inicio/fin 0.978736; revisar continuidad perceptual en reproducción.
- Evidencia: pilot/cat-cow/r1-mini-strip.png; 12 muestras cronológicas cada 16 fotogramas.
- Limitaciones: No se concluye que Mini sea incapaz en general: este resultado con la referencia frontal no es apto. Fluidez, parpadeo y profundidad no comprobados en tiempo real.

### shrug — R2

- Trabajo: `5692cfe3-bfc4-4676-895b-2a83ad8be087`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.967599**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: apto
- Movimiento: La retoma corrige el fallo: ambos hombros suben hacia las orejas, sostienen y bajan, mientras manos y codos permanecen apoyados/quietos sobre los muslos y la cabeza sigue erguida.
- Identidad y extremidades: Misma persona y extremidades estables; sin el gesto de tocarse los hombros de R1.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: No deformaciones, recortes ni desplazamiento de silla evidentes en las muestras.
- Bucle: SSIM inicio/fin 0.967599; revisar continuidad perceptual en reproducción.
- Evidencia: pilot/shrug/r2-mini-strip.png; 12 muestras cronológicas cada 16 fotogramas.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### nod — R2

- Trabajo: `9d8edc47-1a8d-42fd-be54-69d5f367fc35`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.977196**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: no apto con Mini
- Movimiento: R2 mejora ligeramente el cabeceo, pero el detalle de los primeros 3 segundos muestra solo una bajada/vuelta muy pequeña y no dos asentimientos legibles. Los giros de no sí son claros. No apruebo la secuencia combinada completa con esta referencia y duración.
- Identidad y extremidades: Persona y extremidades estables; cierre repetido de ojos pese al prompt. No se rechaza por estética sino por falta de legibilidad de la fase sí.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: Sin deformaciones claras; el componente vertical sigue siendo demasiado sutil a tamaño de app.
- Bucle: SSIM inicio/fin 0.977196; revisar continuidad perceptual en reproducción.
- Evidencia: r2-mini-strip.png y r2-mini-head-detail.png: 24 muestras de los primeros tres segundos.
- Limitaciones: No habrá tercera versión. Recomendación: separar sí y no o usar otro ángulo/referencia; requiere otro encargo, no se ejecuta en este lote. Fluidez y parpadeo en tiempo real pendientes.

### side-reach — R2

- Trabajo: `ae217b21-17c1-47d5-8d66-86da7c73d326`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.977416**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: apto
- Movimiento: La retoma mantiene la mano completa dentro del encuadre en las muestras de entrada, postura mantenida y salida. Se ve la inclinación lateral, con un brazo por encima de la cabeza y la otra mano apoyada.
- Identidad y extremidades: Persona y extremidades estables. Codos flexionados durante entrada/salida para evitar el recorte; ojos cerrados en parte del gesto.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: No recortes ni deformaciones claras en las muestras; debe revisarse el rango de inclinación en la revisión profesional.
- Bucle: SSIM inicio/fin 0.977416; revisar continuidad perceptual en reproducción.
- Evidencia: pilot/side-reach/r2-mini-strip.png; 12 muestras cronológicas cada 16 fotogramas.
- Limitaciones: No reproducción en tiempo real: fluidez, parpadeo fino y profundidad no comprobados.

### reach-up — R2

- Trabajo: `8d4c2acb-d6e7-4ee8-bd0c-91109ae826d3`; estado: `completed`; cargo neto: 8; devolución confirmada: 0.
- Salida medida: 960×960, 24/1 fps, 193 fotogramas, 8.041667 s.
- SSIM inicio/fin: **0.977887**. No prueba que el movimiento o el bucle sean correctos.
- Veredicto: no apto con Mini
- Movimiento: R2 modifica la trayectoria y flexiona codos, pero sigue cortando las puntas de los dedos durante la postura alta. Las palmas tampoco quedan claramente enfrentadas. No pasa el requisito de articulaciones completas visibles.
- Identidad y extremidades: Persona y extremidades estables; sin brazos extra. Ojos cerrados en parte del gesto.
- Cámara: Sin desplazamiento ni zoom evidente en las muestras.
- Artefactos: Recorte superior de dedos confirmado en r2-mini-mid.png a 960×960. Hace falta una referencia con más margen superior, no una tercera repetición del mismo método.
- Bucle: SSIM inicio/fin 0.977887; revisar continuidad perceptual en reproducción.
- Evidencia: r2-mini-strip.png y r2-mini-mid.png a tamaño completo.
- Limitaciones: Cuarta y última retoma del lote. No se generan más versiones ni otra referencia. No implica incapacidad general del modelo: este encuadre no es apto; fluidez y parpadeo en reproducción pendientes.

## Límites de la revisión y pendientes

- Los fotogramas no bastan para certificar fluidez, parpadeo fino, profundidad o continuidad perceptual del bucle. Revisar los MP4 en reproducción y probar comprensión con personas antes de aprobar producción.
- El clip shoulder-roll aceptado se conserva exactamente. Las notas originales advierten que se lee más como encogimiento que como círculo; la aceptación del usuario no borra esa limitación.
- March necesita una referencia de pie y no forma parte del lote.
- Neck-tilt, twist y side-reach muestran un lado. El handoff propone espejo horizontal en la app para el otro; falta revisar asimetrías, perspectiva y correspondencia de indicaciones. No invertir el tiempo del video.
- La revisión profesional del contenido sigue pendiente.

## Próximos pasos de integración (sin implementar)

1. Aprobar solo los clips comprensibles; corregir los no aptos con otro encuadre/método sin reabrir gasto por defecto.
2. Definir un manifest id de Move → archivo aceptado, duración, lados, postura y observaciones. Mantener march pendiente.
3. Reproductor local con pausa/congelado, revisión del bucle y fases de preparación/cambio de lado. No confundir SSIM alto con bucle perfecto.
4. Mantener Kip y comentarios en capa nativa independiente. No tapar articulaciones, instrucciones o controles.
5. Alternativa de poses clave y texto para movimiento reducido; comprobar segundo plano, Keep going, accesibilidad y tamaños de pantalla.
6. Revisar comprensión del ejercicio, movimiento, artefactos y técnica antes de publicar.

## Hoja del lote y archivos

- [Hoja de comparación](mini-batch-contact-sheet.png): columnas inicio, mitad y final; filas shoulder-roll, shrug, neck-tilt, nod, chest-opener, reach-up, twist, cat-cow, side-reach y march. La fila gris es march, sin generar.
- [Resultados estructurados](mini-batch-results.json), con la versión elegida para cada fila, todos los IDs de sus intentos y las observaciones.
- Conciliación final: 12 transacciones nuevas de gasto de 8 créditos, 0 devoluciones nuevas; 972 − 96 = 876. No queda ningún trabajo pendiente. SHA256 del clip aceptado de hombros verificado sin cambios.
- Balance global del proyecto: 124 créditos netos (28 anteriores + 96 nuevos). El techo de este lote era 96, no 160. No se hicieron más generaciones al alcanzarlo.
