# Handoff para Codex: generar los clips de ejercicios con Seedance 2.0 Mini

Preparado el 2026-11-02. Repositorio: `/Users/balthasardeweert/Documents/Projects/strech-reminder`.

**El usuario autoriza con este documento gastar hasta 240 créditos de Higgsfield con Seedance 2.0 Mini, según las reglas de abajo.** Cualquier cosa que no esté aquí (otro modelo, más créditos, compras, cambios de plan) necesita una nueva aprobación suya.

## Contexto en 30 segundos

- App iPhone SwiftUI "Unshrimp". Mascota: Kip (camarón). Para las demostraciones de ejercicios se usa un **instructor humano ilustrado**; Kip sigue en pantalla como capa nativa aparte (no va dentro del video).
- Cuenta Higgsfield: plan **Plus**, workspace "Private", CLI de Higgsfield instalada y con sesión iniciada en este Mac. Saldo tras el piloto: **972 créditos**.
- Piloto R1 (círculos de hombros) con tres modelos: **Mini ganó**. Se ve bien, cámara fija, identidad estable, 8 créditos. Fast casi no se movía y costaba 20; Kling falló (reembolsado). Detalle en `docs/prototypes/illustrated-instructor/pilot/shoulder-rolls/r1-notes.md`.
- Problema de R1: de frente, el círculo de hombros se ve como un encogimiento. Por eso ese clip se reutiliza como **"Shrug and drop"** y los círculos se rehacen con una referencia lateral.
- En R1 la figura cerraba los ojos al subir los hombros: los prompts ahora piden ojos abiertos.

Lee también: `docs/prototypes/illustrated-instructor/README.md` (rúbrica), `claude-cost-review.md` (costes) y `credit-ledger.json`.

## Parámetros fijos (no cambiar)

| Parámetro | Valor |
|---|---|
| Modelo | `seedance_2_0_mini` |
| Duración | 8 s |
| Resolución | 720p |
| Aspecto | 1:1 |
| Audio | desactivado |
| count | 1 |
| Fotograma inicial | media ID de la referencia del clip |
| Fotograma final | **el mismo** media ID (para que el clip cierre en bucle) |
| Precio esperado | 8 créditos por intento |

Referencia frontal ya subida: `instructor-reference-v1.png` → media ID **`ddacd00b-e416-42ee-a15a-59c4ab80d849`** (verificado el 2026-11-02, subida gratis).

Los comandos exactos del CLI están en la sección "Comandos" al final.

## Presupuesto y reglas de gasto

- **Techo total: 240 créditos** (30 intentos de Mini). Saldo mínimo al terminar: 732.
- **Máximo 3 intentos por clip.** Si el tercero tampoco pasa, se marca "no aprobado" y se sigue con el siguiente.
- **Ningún intento por encima de 8 créditos.** Si la cotización sale distinta, parar y avisar.
- Antes de cada envío: cotizar con los parámetros completos y comprobar `gastado + próxima cotización ≤ 240`.
- Una generación a la vez, nunca en paralelo.
- Si una llamada supera el tiempo de espera, buscar el trabajo por su ID. **No reenviar a ciegas.**
- Un trabajo que falla cuenta como gastado hasta ver el reembolso en el saldo o el historial.
- Un reintento solo cuando el clip incumple la rúbrica, no para buscar variaciones estéticas. En el reintento, cambiar el prompt para corregir el fallo concreto y anotar por qué.
- Si dos intentos fallan de la misma forma, no hacer un tercero igual: anotar el problema (suele ser la referencia o el encuadre) y pasar al siguiente clip.
- **Prohibido:** otros modelos, subir resolución o duración, packs, Auto-Refill, cambios de plan, borrar assets en Higgsfield.
- Gasto esperado: unos 120 créditos (≈1,5 intentos por clip). Techo: 240.

## Inventario

`r1-mini.mp4` ya está aprobado como **shrug** (pendiente de que el usuario lo vea en movimiento). Copiarlo a `clips/final/shrug.mp4`.

Quedan **10 clips**. Los bilaterales se generan de un lado y el otro se hace con espejo horizontal (gratis).

| # | Clip (id de la app) | Referencia | Lado / nota | Fase |
|---|---|---|---|---|
| 1 | `neck-tilt` | frontal (ya subida) | derecha + espejo | A |
| 2 | `nod-yes` | frontal | parte "sí" de "Slow yes, slow no" | A |
| 3 | `nod-no` | frontal | parte "no" | A |
| 4 | `chest-opener` | frontal | manos en los lados del asiento | A |
| 5 | `reach-up` | frontal | revisar que las manos no se salgan del encuadre | A |
| 6 | `twist` | frontal (es ¾ suave) | derecha + espejo | A |
| 7 | `side-reach` | frontal | brazo derecho arriba, inclinación a la izquierda + espejo | A |
| 8 | `shoulder-roll` | **lateral (nueva)** | se ve el movimiento hacia atrás | B |
| 9 | `cat-cow` | **lateral (nueva)** | la misma referencia lateral, manos en las rodillas | B |
| 10 | `march` | **de pie (nueva)** | sin silla | B |

### Fase A (referencia frontal)

Generar los 7 primeros intentos, evaluarlos y hacer reintentos dentro de las reglas.

### Fase B (referencias nuevas)

Crear 2 imágenes de referencia con la herramienta de imagen integrada (image_gen), **sin gastar créditos de Higgsfield**:

1. **Lateral sentada:** el mismo personaje, la misma ropa y la misma silla de `instructor-reference-v1.png`, vista de perfil completo mirando a la derecha, sentada erguida, pies apoyados, manos sobre los muslos. Mismo fondo marfil y óvalo menta, mismos contornos. Para `shoulder-roll` y `cat-cow` (en cat-cow el prompt lleva las manos a las rodillas).
2. **De pie:** el mismo personaje de frente en ¾ suave, de pie, brazos relajados a los lados, sin silla, cuerpo entero con margen arriba y abajo para levantar las rodillas. Para `march`.

Usar `instructor-reference-v1.png` como imagen de entrada para conservar la identidad. Reutilizar el prompt de referencia del README cambiando solo el ángulo y la postura. Guardar como `instructor-reference-side-v1.png` e `instructor-reference-standing-v1.png`. Antes de subirlas, comparar con la original: misma cara, pelo, colores y grosor de línea. Si no se parecen, rehacer la imagen, que no cuesta créditos. Subirlas (es gratis) y anotar los media ID en el ledger.

## Prompts

Cada prompt = **BASE** + **ACCIÓN** + **NEGATIVO**. La referencia va como fotograma inicial y final.

**BASE**

```text
Animate the exact illustrated adult instructor from the reference image. Preserve identity, face, proportions, coral sleeveless top, dark petrol trousers, pale-wood armless chair, warm ivory background, mint oval and thick rounded dark outlines. Eight-second silent flat 2D instructional animation in one uninterrupted shot with a completely fixed camera and framing. Eyes stay open and calm throughout. Start and finish in the exact neutral reference pose, with a short calm beat at the start and at the end. Movement is slow, controlled and clearly readable.
```

(Para `march`, quitar "pale-wood armless chair".)

**NEGATIVO**

```text
No camera motion, no zoom, no pan, no scene cuts, no extra limbs, no body morphing, no distorted hands, no closed eyes, no text, no arrows, no interface, no audio. Keep the flat cartoon illustration style; no 3D, no live action.
```

**ACCIÓN por clip**

- **neck-tilt:** `Seated tall, the instructor slowly lets the right ear drift toward the right shoulder, holds for a breath, and returns to center. Shoulders stay relaxed and level, the torso stays upright and still; only the head and neck tilt sideways.`
- **nod-yes:** `Seated tall, the instructor slowly nods twice: the chin lowers gently toward the chest and lifts back to neutral, in a small comfortable range. Shoulders and torso stay completely still.`
- **nod-no:** `Seated tall, the instructor slowly turns the head to look to one side, returns to center, turns to the other side, and returns to center. The head rotates around the neck without tilting; shoulders and torso stay completely still.`
- **chest-opener:** `Seated tall, the instructor moves both hands from the thighs to hold the sides of the chair seat, lifts the chest and gently draws both shoulders back, holds for a breath, then releases and returns the hands to the thighs. The head stays level, with no neck arching; pelvis and feet stay still.`
- **reach-up:** `Seated tall, the instructor slowly reaches both arms up and slightly forward overhead, growing tall through the spine, holds for a breath, then lowers both arms back to rest on the thighs. Both hands stay fully inside the frame; pelvis and feet stay still.`
- **twist:** `Seated upright with both feet flat and pelvis and knees facing forward, the instructor gently rotates the ribcage and shoulder line toward the right around the upright axis of the torso, the head following naturally, holds for a breath, and returns to center. This must read as axial rotation, not side bending or leaning. Hands rest lightly and may slide with the body; feet, knees, pelvis and chair stay still.`
- **side-reach:** `Seated tall, the instructor raises the right arm overhead and gently bends the upper body to the left over the hip, holds for a breath, then returns upright and lowers the arm to the thigh. Both hips stay on the chair; no twisting; the left hand rests on the thigh.`
- **shoulder-roll** (referencia lateral): `Seen from the side, the seated instructor rolls both shoulders in two slow backward circles: up toward the ears, then clearly back, then down, then forward to neutral. The backward phase must be clearly visible. Arms hang relaxed, hands on thighs; head, pelvis, feet and chair stay still; the body does not bounce.`
- **cat-cow** (referencia lateral): `Seen from the side, the seated instructor places both hands on the knees, slowly rounds the whole back with the chin toward the chest, then lifts the chest and gently arches the upper back looking slightly forward, then returns to upright neutral and the hands return to the thighs. Pelvis stays on the chair and feet stay flat.`
- **march** (referencia de pie): `The standing instructor marches in place slowly for four steps: alternating knees lift to about hip height while the opposite arms swing naturally, then returns to the standing neutral pose. Feet land in the same spot; no travel across the frame; the whole body stays inside the frame.`

## Evaluación de cada intento (rúbrica)

Después de cada intento:

1. Descargar el MP4 a `docs/prototypes/illustrated-instructor/clips/<id>/<id>-a<N>.mp4`.
2. Con ffmpeg, sacar fotogramas al inicio, la mitad y el final (`<id>-a<N>-start|mid|end.png`) y **mirarlos**.
3. Aprobar solo si se cumple todo esto:
   - Se mueve lo que dice el nombre del ejercicio, y nada más (sin rebote del cuerpo, sin que la cámara simule el movimiento).
   - La misma persona, ropa y número de extremidades al inicio, a la mitad y al final. Manos sin deformar.
   - Ojos abiertos.
   - El último fotograma es casi igual al primero (para el bucle).
   - La figura no se sale del encuadre.
4. Anotar en `clips/<id>/notes.md` el veredicto y lo que no se puede juzgar con fotos fijas (fluidez, parpadeos).

## Postproceso de los aprobados

- Copiar a `docs/prototypes/illustrated-instructor/clips/final/<id>.mp4`.
- Bilaterales (`neck-tilt`, `twist`, `side-reach`): `ffmpeg -i <id>.mp4 -vf hflip -c:a copy <id>-left.mp4`. Renombrar el original a `<id>-right.mp4`. Revisar que el espejo no se vea raro (pelo, sombras).
- No recomprimir ni recortar todavía: eso se decide al integrar en la app.
- Generar `clips/final/contact-sheet.png` con todos los aprobados (inicio, mitad, final).

## Registro

Actualizar `docs/prototypes/illustrated-instructor/credit-ledger.json` **después de cada trabajo**: clip, intento, modelo, parámetros, media ID, job ID, cotización, cargo confirmado, reembolso confirmado, estado, ruta del archivo, saldo después. Cambiar `hard_cap` a 240 para este lote y conservar el registro del piloto R1.

## Puntos de parada (avisar al usuario)

- Al terminar la Fase A, antes de crear las referencias de la Fase B: resumen de aprobados, fallos, créditos gastados y la hoja de contactos.
- Si el gasto llega a 200 créditos.
- Si una cotización no es 8, el CLI pide algo nuevo o aparece un error de plan o permisos.
- Al terminar: tabla final (clip, intentos, créditos, estado, archivo).

## Fuera de alcance

- No tocar el código de la app (ni `BreakFlowView.swift` ni otros). La integración es otra tarea.
- No hacer commits, push ni cambios de rama sin pedirlo.
- No revertir los cambios sin commitear del repo (`Localizable.xcstrings`, `.impeccable/`, `Unshrimp.xcodeproj/`, `docs/prototypes/`).
- Los ejercicios son contenido provisional sin revisión profesional. No presentarlos como validados.

## Comandos

<!-- La sección siguiente se completa en el Mac con la sintaxis exacta del CLI usada en el piloto R1. -->
