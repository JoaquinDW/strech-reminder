---
target: App actual, animaciones y claridad de rutinas; evaluación de Higgsfield
total_score: 28
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
target_identity: "file:/Users/balthasardeweert/Documents/Projects/strech-reminder/Unshrimp/Features/Break/BreakFlowView.swift"
target_fingerprint: "sha256:f3de91ab5c5056cd382fcca1d73508d58dc5383e2433113dc62c545ec09f5852"
target_path: /Users/balthasardeweert/Documents/Projects/strech-reminder/Unshrimp/Features/Break/BreakFlowView.swift
timestamp: 2026-11-02T18-54-29Z
slug: unshrimp-features-break-breakflowview-swift
---
# Revisión de Unshrimp y sus demostraciones de ejercicio

Fecha: 2026-11-02. Método: dos evaluaciones independientes (design_review y evidence_review), con revisión de código y capturas del commit 1c00729. Las capturas coinciden con la implementación actual. No se reprodujeron las animaciones en vivo; el comportamiento temporal se evaluó por código. No se modificó la app ni se generaron medios.

## Veredicto

La identidad visual y la experiencia de acompañamiento forman una base coherente para v1. La demostración de ejercicios necesita cambios antes de producción. La principal limitación es que una anatomía de camarón y un rig plano no explican de forma inequívoca movimientos humanos. Cambiar Canvas por video solo ayuda si cambia la claridad de la figura, el ángulo y la coreografía.

## Implementación actual

SwiftUI nativo, iOS 18+, estado con Observation, persistencia JSON local y notificaciones locales. El flujo cubre onboarding, preferencias, escritorio, rutina, confirmación y recompensa. DemoLibrary contiene diez movimientos y construye rutinas de 2/3/5 minutos con 4/6/8 movimientos. Las duraciones se distribuyen por igual entre movimientos; no existen fases explícitas de preparación o cambio de lado.

Kip se dibuja en Canvas con una columna de círculos y brazos articulados simples. ShrimpMotion calcula poses mediante funciones periódicas; PoseBlender interpola entre estados durante 0,6 segundos. LiveCanvas solicita hasta 30 fps y pausa su timeline con app inactiva, fuera de pantalla o Reduce Motion. No hay reproductor de video ni clips de ejercicio incluidos.

## Fortalezas

- Identidad específica: camarón encorvado en un escritorio, colores cálidos y controles que comparten el lenguaje de la ilustración.
- Tono amable: se aceptan pausas parciales y la finalización requiere confirmación del usuario.
- Jerarquía clara en la rutina: nombre, instrucción, tiempo y controles. El sistema de mascota ya contempla estados, transiciones y movimiento reducido.

## Prioridades

1. P1: la figura no explica con fidelidad el movimiento. Shoulder rolls alterna brazos; Shrug desplaza el cuerpo entero; Seated twist inclina la figura en el plano. Slow yes, slow no incluye mirar a ambos lados en el texto, pero la pose solo inclina la cabeza. Referencias: ShrimpPose.swift:156-198, ShrimpRenderer.swift:20-43 y 85-95, DemoRoutines.swift:27-47. Propuesta: figura humana o humanoide legible para la demostración, conservando Kip como acompañante.
2. P1: falta una coreografía instructiva. No hay preparación, cambio de lado o fases sincronizadas; el reloj arranca de inmediato y avanza automáticamente. Referencias: DemoRoutines.swift:66-83 y BreakFlowView.swift:110-114,263-270. Propuesta: preparación breve, una indicación actual por fase y transición explícita al siguiente movimiento.
3. P2: pausar elimina la referencia. BreakFlowView.swift:209 sustituye el ejercicio por resting. Propuesta: congelar un fotograma útil, permitir repetición y mantener las instrucciones visibles.
4. P2: movimiento reducido no ofrece una demostración equivalente. ShrimpPose.swift:86-88 elimina la oscilación y deja poses base muy parecidas. Propuesta: secuencia de inicio/fin con flechas y texto. Las transiciones generales y del contador tampoco están condicionadas a Reduce Motion.
5. P2: el contenido sigue siendo provisional. DemoRoutines.swift:3-5 lo identifica expresamente como no revisado profesionalmente. Finalizar instrucciones antes de producir la biblioteca de medios.

Hallazgos adicionales por código: Keep going deja el reloj pausado porque el cierre pausa y la cancelación del diálogo no lo reanuda (BreakFlowView.swift:119,184). El reloj usa tiempo de pared y puede completar un movimiento al volver de segundo plano, aunque Canvas se pausa. ConfettiBurst mantiene un timeline después de dejar de dibujar; conviene medirlo, sin afirmar un coste de rendimiento no observado.

## Higgsfield y propuesta para v1

La documentación oficial de Kling en Higgsfield describe Motion Control: imagen de personaje más video de referencia. Fuente consultada: https://higgsfield.ai/creator-hub/help-center/ai-models/how-do-i-use-kling

Recomendación de diseño: probar un clip de shoulder rolls y otro de seated twist con referencia de movimiento revisada, cámara fija, encuadre adecuado y figura humana estilizada en la paleta de la app. Evaluar si personas nuevas pueden reproducirlos sin explicación adicional. Higgsfield es una posible herramienta de producción; no garantiza que cada generación represente correctamente el movimiento.

Conservar Canvas para la mascota, el escritorio y las recompensas. Para las demostraciones, un clip corto por movimiento, repetible sin salto y con instrucciones/reloj superpuestos nativos. Preparación, pausa, cambio de lado y avance deben seguir controlados por la app. Para v1, priorizar una biblioteca pequeña y comprensible sobre diez demostraciones ambiguas.

## Heurísticas provisionales

| Heurística | Puntuación /4 |
|---|---:|
| Estado del sistema | 3 |
| Correspondencia con el mundo real | 2 |
| Control del usuario | 3 |
| Consistencia | 4 |
| Prevención de errores | 2 |
| Reconocimiento | 2 |
| Eficiencia | 3 |
| Estética y simplicidad | 4 |
| Recuperación | 3 |
| Ayuda | 2 |
| Total | 28/40 |

La carga cognitiva procede de interpretar el ejercicio mientras corre el reloj. Los perfiles más afectados son quien hace su primera rutina, quien pausa para estudiar y quien utiliza movimiento reducido.

## Validación y límites

El detector Impeccable devolvió [] y exit 0 para Unshrimp y para el archivo de rutina. No acredita cobertura semántica de SwiftUI; cero resultados no equivale a una auditoría nativa aprobada. La evaluación se apoya en fuente y capturas, no en ese resultado. Los tests existentes recorren el flujo principal con capturas y saltan manualmente entre movimientos; no comprueban fidelidad del ejercicio, tiempo completo, segundo plano o cancelación del diálogo. No se ejecutaron tests en esta revisión.

La inspección nativa por CUA falló por timeout. XcodeBuildMCP no localizó simctl con el directorio de herramientas activo. Una consulta con DEVELOPER_DIR local confirmó un simulador iniciado en Springboard, sin reproducción de la app. No se inició servidor web ni overlay: el producto es nativo. No existe lista de hallazgos ignorados.
