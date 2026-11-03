# Handoff para Codex: clips de ejercicios con Seedance 2.0 Mini

Preparado el 2 de noviembre de 2026 por Claude Code. Repositorio: `/Users/balthasardeweert/Documents/Projects/strech-reminder`.

## Autorización de gasto (la completa el usuario)

> Apruebo hasta **96 créditos** de Higgsfield para este lote.
> Sugerencia: 96 = 8 clips × 8 créditos en la primera pasada, más hasta 4 retomas de 8.

Sin una cifra aprobada por el usuario, prepara todo y cotiza, pero no generes.

## Encargo

El usuario probó tres modelos con «Shoulder rolls» y **eligió Seedance 2.0 Mini**. Quiere usar ese modelo para generar los clips del resto de ejercicios de la app.

Tu trabajo:
1. Generar un clip de 8 s por ejercicio sentado (lista abajo), con el mismo método que funcionó en el piloto.
2. Descargar cada clip y extraer sus fotogramas.
3. Registrar cada trabajo en el ledger y evaluar cada clip con honestidad.

Este encargo no incluye integrar los clips en SwiftUI, hacer commits ni push.

## Qué ya está hecho

- El piloto R1 está en `docs/prototypes/illustrated-instructor/pilot/shoulder-rolls/`. Lee `r1-notes.md` primero.
- **`r1-mini.mp4` es el clip aceptado para `shoulder-roll`**: el usuario dijo «me gustó mucho el de Mini». No lo regeneres.
- Kling 3.0 std falló y se reembolsó. Seedance 2.0 Fast casi no movía los hombros y cuesta 20. **Usa solo Mini.**
- Saldo tras el piloto: **972 créditos** (plan Plus, workspace «Private»). Compruébalo de nuevo antes de empezar.
- La referencia ya está subida. **Media ID: `ddacd00b-e416-42ee-a15a-59c4ab80d849`** (`docs/prototypes/illustrated-instructor/instructor-reference-v1.png`). Reutilízalo; no hace falta volver a subirla.

## Lo que aprendimos del piloto

- Usar la misma referencia como `start_image` y `end_image` funciona: el clip vuelve casi a la pose inicial. En Mini, el SSIM entre el primer y el último fotograma fue 0,959 (1 = idénticos); con un fundido corto se puede repetir en bucle.
- Mini sí mueve claramente lo que se le pide. Pero en vista frontal **no se ve la profundidad**: el círculo de hombros se leyó como «subir, mantener, bajar».
  - Para giros y movimientos hacia atrás o adelante, el prompt debe pedir que el movimiento se vea en el plano de la imagen: hacia arriba o abajo, hacia los lados, o el giro del pecho.
- Mini tiende a cerrar los ojos durante el esfuerzo. Los prompts de abajo piden ojos abiertos.
- La salida real es **960×960, 24 fps, 193 fotogramas, 8,04 s**, aunque se pida 720p. El coste no cambia.
- Coste por clip: **8 créditos**. Subir medios y cotizar no cuesta nada.

## Ejercicios (de `Unshrimp/Model/DemoRoutines.swift`)

| id | Nombre | Estado | Nota |
|---|---|---|---|
| `shoulder-roll` | Shoulder rolls | **Hecho** (`pilot/shoulder-rolls/r1-mini.mp4`) | No regenerar |
| `shrug` | Shrug and drop | Generar | El clip más fácil para Mini |
| `neck-tilt` | Ear to shoulder | Generar | Un solo lado; el otro lo resuelve la app (espejo) |
| `nod` | Slow yes, slow no | Generar | «Sí» y luego «no» en el mismo clip |
| `chest-opener` | Chest opener | Generar | Manos en los lados de la silla |
| `reach-up` | Big reach | Generar | Riesgo: los brazos pueden salir del encuadre por arriba |
| `twist` | Seated twist | Generar | Un solo lado; espejo en la app |
| `cat-cow` | Seated curl and arch | Generar | La vista frontal puede ocultar la curva de la columna |
| `side-reach` | Side reach | Generar | Un solo lado; espejo en la app |
| `march` | March in place | **No generar** | Necesita una referencia de pie que no existe. Repórtalo como pendiente. |

Son 8 clips nuevos, 64 créditos en la primera pasada.

## Reglas de gasto (obligatorias)

- Usa solo `seedance_2_0_mini`. Nada de compras, packs, cambios de plan ni Auto-Refill.
- **Cotiza cada clip antes de generarlo.** Si la cotización no es 8, para y repórtalo.
- Genera **un clip a la vez**, nunca en paralelo, y comprueba el saldo antes de cada uno.
- Lleva la cuenta: `gastado + próxima cotización ≤ techo aprobado`. Si se pasaría del techo, para.
- **Retomas:** como máximo 1 por ejercicio, solo si el clip falla claramente la rúbrica (se mueve otra cosa, extremidades deformadas, la cámara se mueve) y queda presupuesto. Una retoma por motivos estéticos no cuenta como motivo. Si la retoma también falla, marca el ejercicio como «no apto con Mini» y sigue con el siguiente.
- Si un trabajo falla, comprueba en `higgsfield account transactions` si se reembolsó. Cuenta el reembolso solo si aparece ahí. Ese trabajo no se reintenta como retoma automática.
- Si algo se cuelga, busca el trabajo por su ID (`higgsfield generate get <id>`). **Nunca lo reenvíes a ciegas.**
- Si el entorno bloquea un comando de pago por permisos, para y pide al usuario que lo apruebe. No busques otra vía.

## Comandos (Higgsfield CLI 1.2.2, ya autenticada)

```bash
cd /Users/balthasardeweert/Documents/Projects/strech-reminder/docs/prototypes/illustrated-instructor
M=ddacd00b-e416-42ee-a15a-59c4ab80d849
higgsfield account status --json

# 1. Cotizar (gratis). Debe devolver {"credits": 8}
higgsfield generate cost seedance_2_0_mini --prompt "$PROMPT" \
  --start-image $M --end-image $M --duration 8 --resolution 720p \
  --aspect_ratio 1:1 --generate_audio false --json

# 2. Crear SIN --wait: así guardas el job ID antes de esperar
higgsfield generate create seedance_2_0_mini --prompt "$PROMPT" \
  --start-image $M --end-image $M --duration 8 --resolution 720p \
  --aspect_ratio 1:1 --generate_audio false --json
# → ["<job_id>"]

# 3. Esperar y comprobar
higgsfield generate wait <job_id>        # imprime la URL del MP4 (no acepta --wait-timeout)
higgsfield generate get <job_id> --json  # status, result_url
higgsfield account status --json
```

Notas sobre la CLI:
- `generate wait` a veces termina antes de que el trabajo acabe. Si `get` dice `in_progress`, vuelve a ejecutar `wait`.
- No hay parámetro `count`: cada `create` es un solo trabajo.
- Guarda el prompt en un archivo y pásalo con `--prompt "$(cat archivo)"`.

## Salida por ejercicio

Carpeta: `docs/prototypes/illustrated-instructor/pilot/<id>/`. No sobrescribas archivos existentes. Una retoma lleva sufijo `r2`.

```bash
D=docs/prototypes/illustrated-instructor/pilot/<id>; mkdir -p $D
curl -fsSL -o $D/r1-mini.mp4 "<result_url>"
N=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 $D/r1-mini.mp4)
ffmpeg -v error -i $D/r1-mini.mp4 -vf "select=eq(n\,0)" -frames:v 1 $D/r1-mini-start.png
ffmpeg -v error -i $D/r1-mini.mp4 -vf "select=eq(n\,$((N/2)))" -frames:v 1 $D/r1-mini-mid.png
ffmpeg -v error -i $D/r1-mini.mp4 -vf "select=eq(n\,$((N-1)))" -frames:v 1 $D/r1-mini-end.png
# Hoja para revisar el movimiento (un fotograma cada 16), no un entregable
ffmpeg -v error -i $D/r1-mini.mp4 -vf "select='not(mod(n\,16))',scale=320:320,tile=4x3" -fps_mode vfr -frames:v 1 $D/r1-mini-strip.png
# Bucle: SSIM entre el primer y el último fotograma
ffmpeg -i $D/r1-mini-start.png -i $D/r1-mini-end.png -lavfi ssim -f null - 2>&1 | grep -o 'All:[0-9.]*'
```

El ffmpeg de esta Mac no tiene `drawtext`: no intentes poner texto en las imágenes.

Al final, crea una hoja de todo el lote en `docs/prototypes/illustrated-instructor/pilot/mini-batch-contact-sheet.png`: una fila por ejercicio, columnas inicio, mitad y final, en el orden de la tabla.

## Registro

Añade cada trabajo al array `jobs` de `docs/prototypes/illustrated-instructor/credit-ledger.json`, con el mismo formato que los de R1:
- `clip_id`, `round`, `model`, parámetros, media ID, `job_id`
- `quoted_credits`, `confirmed_deduction`, `refund`
- `status`, `output`

Actualiza también `confirmed_deductions`, `confirmed_refunds`, `balance_checks`, `final_balance` y `status`. No borres entradas existentes.

Escribe `docs/prototypes/illustrated-instructor/pilot/mini-batch-notes.md` con:
- saldo antes y después, y total gastado
- job IDs
- por cada ejercicio, una evaluación con la rúbrica:
  - ¿se mueve lo que dice el nombre del ejercicio?
  - ¿la identidad y las extremidades se mantienen estables?
  - ¿la cámara está fija?
  - ¿el primer y el último fotograma coinciden (SSIM)?
  - ¿hay artefactos?
- un veredicto apto / retomar / no apto
- lo que no se puede juzgar con fotogramas fijos (fluidez, parpadeo, profundidad)

Mira los fotogramas antes de juzgar.

## Prompts

Todos los prompts comparten el mismo principio y el mismo final. Construye cada prompt así: `BASE_START + MOVIMIENTO + BASE_END`, separados por un espacio.

**BASE_START**
```text
Animate the illustrated adult instructor from the reference image, preserving exactly the same identity, face, coral sleeveless top, dark petrol trousers, armless wooden chair, warm ivory background and mint oval. Eight-second silent 2D instructional animation with a completely fixed camera, consistent framing and the same clean dark outlines.
```

**BASE_END**
```text
Eyes stay open with the same gentle expression. Feet, pelvis, chair and background stay stable and the entire body must not bounce. Start and finish in the exact neutral reference pose, with a short calm beat at each end. No camera motion, no zoom, no scene cuts, no exaggerated range, no extra limbs, no distorted hands, no body morphing, no text, no arrows, no interface and no audio. Preserve a flat illustrated style rather than converting the person into 3D or live action.
```

**MOVIMIENTO** de cada ejercicio:

`shrug`
```text
The seated instructor demonstrates one slow shrug: both shoulders lift straight up toward the ears together, hold for a moment at the top, then drop and relax fully back to the starting position. Make the vertical shoulder travel clearly visible. Arms stay relaxed and hands remain loosely on the thighs; the head stays upright.
```

`neck-tilt`
```text
The seated instructor sits tall and slowly tilts her head sideways so her right ear drifts toward her right shoulder, holds gently for a breath, then returns the head upright to center. Only the head and neck tilt; both shoulders stay level and relaxed and do not rise to meet the ear. Hands remain loosely on the thighs. Small comfortable range.
```

`nod`
```text
The seated instructor makes two slow gentle nods (chin moving a little down and back up), then slowly turns her head to look left, back to center, right, and back to center. Small comfortable range; only the head and neck move. Shoulders stay level and relaxed and hands remain loosely on the thighs.
```

`chest-opener`
```text
The seated instructor moves her hands from her thighs to hold the sides of the chair seat beside her hips, then slowly lifts her chest and draws both shoulders gently back and down so the chest visibly opens and the collarbones widen, holds a breath, then relaxes and returns the hands to the thighs. The head stays level, no backward lean of the whole torso.
```

`reach-up`
```text
The seated instructor slowly raises both arms forward and up overhead, palms facing each other, sitting tall as the spine lengthens, holds briefly, then lowers both arms down the same path and returns the hands to the thighs. Keep both hands and arms fully inside the frame at all times. Both arms move together and symmetrically; elbows and hands stay anatomically correct.
```

`twist`
```text
The seated instructor sits tall and gently rotates her ribcage and shoulders toward her right side around the upright axis of the torso, the head following naturally, holds a breath, then returns to face forward. This must read as rotation, not side bending or leaning. Hands rest lightly on the thighs and may slide naturally; knees and pelvis keep facing forward and the chair does not move.
```

`cat-cow`
```text
The seated instructor, hands resting on her knees, slowly rounds her upper back so the shoulders curl forward and the head lowers slightly with the chin toward the chest, then slowly reverses, lifting the chest up and forward with the shoulders drawn back and the gaze lifting slightly, then returns to the upright neutral pose. Make the change in chest and shoulder position clearly visible from the front. Pelvis stays seated on the chair.
```

`side-reach`
```text
The seated instructor slowly raises her right arm overhead and leans her upper body gently to her left side in a smooth side bend, the left hand resting on the left thigh, holds a breath, then returns upright and lowers the right arm back to the thigh. Keep the raised hand fully inside the frame. Both hips stay on the chair; no forward lean and no twisting.
```

Escribe el prompt completo de cada clip en `pilot/<id>/prompt.txt` antes de cotizar.

## Orden sugerido

Primero los clips con más probabilidad de salir bien, para detectar pronto un problema general:

`shrug` → `neck-tilt` → `nod` → `chest-opener` → `twist` → `side-reach` → `reach-up` → `cat-cow`

Si los dos primeros fallan por la misma razón, para el lote y repórtalo antes de seguir gastando.

## Informe final para el usuario

Incluye:
- saldo antes y después, y créditos gastados frente al techo
- tabla por ejercicio: veredicto, job ID y ruta del clip
- qué ejercicios necesitan otro enfoque: `march` necesita una referencia de pie; los bilaterales se resuelven con espejo
- próximos pasos para integrar los clips en SwiftUI, sin implementarlos

Contexto adicional:
- `docs/prototypes/illustrated-instructor/README.md`: rúbrica y dirección visual
- `docs/prototypes/illustrated-instructor/claude-cost-review.md`: costes y espejo de clips bilaterales
- `docs/handoffs/claude-code-exercise-media-and-costs.md`: contexto general de la app
