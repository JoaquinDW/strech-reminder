# Kip acompaña durante el entrenamiento

Fecha: 2026-11-02. Dirección solicitada por el usuario: conservar visible a la mascota durante los ejercicios, arriba o a un costado, con comentarios breves y humor.

Mockup: `exercise-screen-with-kip-v2.png`. Generado con image_gen integrada. Es una imagen conceptual, sin cambios en la aplicación.

## Comportamiento propuesto

- La figura humana ocupa el área principal y muestra el movimiento.
- Kip permanece pequeño, arriba y a un costado, sin tapar cabeza, hombros, brazos, instrucciones ni controles.
- Su posición permanece estable durante la sesión.
- Los comentarios aparecen brevemente al comenzar o terminar algunos ejercicios, sin competir con la preparación, las indicaciones de técnica o un cambio de lado.
- Como punto de partida, un máximo de un comentario por ejercicio y sin repetir una frase dentro de la misma sesión. Ajustar según pruebas de atención.
- Al desaparecer el globo, Kip sigue visible. No debe cambiar el tamaño ni la posición de la demostración.
- El humor es amable, sobre su propia vida de camarón; no juzga el cuerpo ni el rendimiento del usuario.
- Sus reacciones pueden ser discretas: mirar, asentir o estirarse un poco. El video es la referencia de técnica.
- Durante pausa y movimiento reducido se mantiene una pose tranquila. Un comentario decorativo no se anuncia automáticamente por VoiceOver ni interrumpe la instrucción.
- En pantallas pequeñas y texto grande se prioriza la demostración; el globo puede aparecer solo entre ejercicios, con Kip aún visible.
- Kip y sus frases se implementan como una capa nativa independiente del video, para poder traducirlas y cambiar frecuencia y tamaño sin regenerar medios.

## Primeras frases de exploración

- «Ese me vendría muy bien…»
- «Creo que ya puedo cerrar una pestaña.»
- «Yo también necesitaba salir del modo camarón.»
- «Bueno, esto cuenta como salir de la oficina.»
- «Una pausa corta. Mi especialidad.»

## Prompt exacto del mockup

```text
Use case: precise-object-edit / ui-mockup.
Image 1 is the edit target: the current tall iPhone training screen mockup containing a seated human instructor. Image 2 is a CHARACTER REFERENCE ONLY for Kip, the coral shrimp mascot (ignore the other UI in image 2).
Create a polished revision of image 1 that keeps the HUMAN instructor, clothing, chair, mint backdrop, title, instruction, timer and all controls unchanged, and adds Kip as a small companion ABOVE AND TO THE RIGHT of the human demonstration.
Use the empty ivory space between the header progress bar and the instructor's head. At the right end of this space add a small recognizable Kip from image 2: same coral segmented curled shrimp silhouette, dark petrol rounded outlines, two antennae, tiny arms, dot eye and warm smile, looking toward the human. The mascot is about 12 percent of screen width and visually subordinate to the human instructor; it must NOT replace or overlap the instructor or the shoulder/neck demonstration.
To the LEFT of this small Kip, draw one compact rounded paper-ivory speech bubble outlined in dark petrol, with a small tail pointing to Kip. It contains exactly this Spanish text, in a legible rounded dark petrol font over two lines: "Ese me vendría" / "muy bien…". Spell vendría with the accented í. Keep the bubble and mascot as a single quiet companion row under the existing navigation header, within margins. No panels, no colored card background behind the row, no decorative badges. Leave comfortable white space between the companion row and the person's head.
Preserve all original English exercise UI text verbatim, including "Move 1 of 4", "Demo routine", "Shoulder rolls", "Roll both shoulders up, back and down in slow circles." and the timer "28". Preserve original single-screen portrait aspect ratio and full screen, no phone frame. This is a static visual concept for a native app where the human video demonstrates and a separate native mascot occasionally comments. Do not add more characters, speech bubbles, exclamation marks, arrows, shadows, confetti or extra controls.
```

