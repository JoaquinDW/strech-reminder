# Instructor humano ilustrado — exploración v1

Fecha: 2026-11-02.

Presupuesto y preparación de generación: ver `higgsfield-budget.md`, `higgsfield-budget.json`, `pilot-requests.json` y `credit-ledger.json`. El lote piloto tiene un techo propuesto de 160 créditos; no se ha generado video ni autorizado gasto desde estos archivos.

## Entregables y estado

- `instructor-reference-v1.png`: referencia visual del personaje en posición inicial.
- `exercise-screen-concept-v1.png`: mockup estático de la pantalla existente con el instructor.
- Imágenes creadas con la herramienta integrada image_gen, no con Higgsfield.
- La llamada a Higgsfield fue rechazada con `Requires basic plan or higher.` No devolvió ningún trabajo de generación.
- Los dos clips están definidos abajo, pero todavía no se generaron.
- El mockup es una imagen de exploración; no se ha integrado ningún cambio en SwiftUI.
- El movimiento y las instrucciones definitivas siguen pendientes de revisión profesional, como el contenido actual del prototipo.

## Dirección visual

Actualización: Kip también acompaña en la pantalla de entrenamiento. Ver `exercise-screen-with-kip-v2.png` y `companion-spec-v1.md` para su ubicación y comentarios. Esta variante conserva al instructor humano y añade la mascota en una capa aparte.

Persona adulta con proporciones legibles, pelo verde petróleo, camiseta coral sin mangas y pantalón verde petróleo. Hombros, cuello y brazos diferenciados. Silla sin apoyabrazos para los movimientos sentados, fondo marfil y óvalo menta. Conservamos a Kip en el escritorio, las invitaciones y las recompensas.

La referencia neutral define identidad y estilo. La imagen completa de UI no debe usarse como entrada del video: produciría texto y controles animados. Animar solamente el personaje y su escenario.

## Clip piloto A: círculos de hombros

Objetivo de evaluación: distinguir rotación de ambos hombros de balanceo de brazos o salto del cuerpo.

Duración propuesta: 8 segundos, sin audio. Cámara fija, plano suficientemente cercano para leer hombros y cuello. Identidad y ropa de la referencia. No usar zoom durante el movimiento.

Guion visual de trabajo:
- Inicio neutral reconocible.
- Un ciclo lento y legible de ambos hombros.
- Regreso a la misma posición neutral.
- Verificar primer/último fotograma antes de aceptar que funciona en bucle.

Prompt de generación en inglés:

> Animate the illustrated adult instructor from the reference image, preserving exactly the same identity, face, coral sleeveless top, dark petrol trousers, armless wooden chair, warm ivory background and mint oval. Eight-second silent 2D instructional animation with a completely fixed camera, consistent framing and the same clean dark outlines. The seated instructor demonstrates one slow controlled backward shoulder-roll cycle: both shoulder contours rise together, move backward, descend and return naturally to their relaxed starting position. Make shoulder articulation clearly visible. The head, pelvis, feet, chair and background stay stable; the forearms remain relaxed and hands remain loosely on the thighs. The entire body must not bounce or rotate. Start and finish in the exact neutral reference pose, with a short calm beat at each end. No camera motion, no scene cuts, no waving, no exaggerated range, no extra limbs, no body morphing, no text, no arrows, no interface and no audio. Preserve a flat illustrated style rather than converting the person into 3D or live action.

## Clip piloto B: giro sentado

Objetivo de evaluación: distinguir rotación del torso de una inclinación lateral. Sin forzar el giro con las manos ni mover la silla.

Duración propuesta: 8 segundos, sin audio. Encuadre de tres cuartos con pelvis y hombros visibles. Para una prueba de ambos lados, producir luego un segundo clip controlado o extender la secuencia: no invertir el video para simular otra perspectiva.

Guion visual de trabajo:
- Inicio neutral.
- Giro suave y visible de torso hacia un solo lado; la cámara se mantiene fija.
- Regreso al centro.
- La app puede repetir, pausar o indicar el cambio de lado; esas instrucciones no se hornean en el video.

Prompt de generación en inglés:

> Animate the exact illustrated adult instructor from the reference image. Preserve identity, proportions, coral sleeveless top, petrol trousers, wooden armless chair, ivory background, mint oval and thick rounded dark outlines. Eight-second silent 2D instructional animation in one uninterrupted shot, fixed camera in the same mild frontal three-quarter view. Begin seated upright in the reference pose, both feet resting flat, pelvis and knees facing forward. Demonstrate one gentle seated torso rotation toward one side and then return to the initial center position. The ribcage and shoulder line visibly turn around the upright axis of the torso; the head follows naturally. This must read as axial rotation, not side bending or sideways leaning. Hands rest lightly and may slide naturally with the body; do not pull or lever against the chair. Keep feet, knees, pelvis, chair and background stationary. Use a modest natural movement and a calm beat at the start and end. Start and finish in the same neutral pose. No camera orbit, no pan, no zoom, no scene cuts, no chair movement, no exaggerated twist, no distorted hands, no extra limbs, no text, no arrows, no interface and no audio. Preserve the original flat cartoon artwork.

## Validación antes de integrar

1. Revisar que lo que se mueve coincide con el nombre y la instrucción del ejercicio.
2. Comparar inicio, mitad y final: identidad, número de extremidades y contacto con silla/suelo consistentes.
3. Verificar que la cámara no simula el movimiento y que el bucle no tiene un salto visible.
4. Comprobar comprensión con personas nuevas sin explicación adicional.
5. Mantener reloj, preparación, texto y controles en SwiftUI. Pausar debe congelar un fotograma útil.
6. Con movimiento reducido, ofrecer poses clave y pasos de texto. Una posición neutral sola no demuestra el ejercicio.

## Prompt usado para la referencia visual

```text
Create a single polished 2D flat vector-style illustration for an iPhone desk-break companion app called Unshrimp, to be used as the initial frame for instructional exercise animation. One friendly adult human instructor, natural adult proportions and clearly readable shoulders, neck, elbows and torso, warm medium tan skin, short dark petrol wavy hair, small simple facial features and gentle smile, coral sleeveless exercise top (#FF7A66), dark petrol straight-leg trousers (#1D4550), ivory flat shoes. Seated upright on a simple stable armless pale-wood chair with a low backrest, both feet flat on the floor hip width apart, hands resting loosely on thighs, shoulders relaxed, neutral head. Camera at chest height in a mild frontal three-quarter view, near frontal so both shoulders and both arms are separately visible, full figure and entire chair fully inside frame with generous headroom and side clearance for movement. Uniform warm ivory background #FBF5EA with one soft pale mint oval #DDF3EA behind the figure, simple pale mint ground shadow. Thick clean rounded dark petrol outlines, warm friendly editorial cartoon craft, minimal flat color shading, matching a charming shrimp mascot app. Human anatomy must remain readable, head proportion realistic rather than giant mascot head. Clean separation between hands, torso, chair and legs. No shrimp character, no text, no labels, no arrows, no interface, no typography, no photo realism, no 3D rendering, no gradients, no texture, no extra people, no equipment. Single scene, centered, square composition. This is a visual concept for subsequent animation, not a diagram or a character sheet.
Use case: stylized-concept. Deliver a polished original illustration, not code. This is the human exercise instructor replacing only the ambiguous exercise demonstrator, while the app retains its shrimp mascot elsewhere. Make the shoulder contours and bare upper arms especially clear, with the dark outline separating upper arm from chest. Use the charming warm flat outlined visual language visible in the app screenshot, but draw a HUMAN adult with a clearly differentiated neck, two shoulders and two normal arms.
```

## Prompt usado para el mockup estático

```text
Use case: ui-mockup / precise-object-edit. Image 1 is the EDIT TARGET: the existing tall iPhone exercise screen from the Unshrimp app. Image 2 is the EXACT HUMAN INSTRUCTOR REFERENCE to insert. Produce a high-fidelity visual mockup of that same iPhone screen with ONLY the central exercise illustration replaced. Preserve the original warm ivory page, header close button, four-step progress indicator, 'Move 1 of 4', 'Demo routine' badge, exercise heading 'Shoulder rolls', instruction text, timer ring and bottom pause/next controls in the same layout, style, color and typography as image 1. In the central visual area replace the shrimp, old mint blob and mat with the seated HUMAN instructor and chair from image 2 on its soft mint oval, sized to leave generous surrounding whitespace. Preserve the human identity, coral sleeveless top, petrol trousers, medium tan skin, wavy petrol hair and clean thick outlines. Show both shoulders clearly visible in a relaxed neutral seated starting position, feet supported and hands resting on thighs. This is a static reference pose preview, do not add arrows or imply an animated demonstration. The human and chair must fit entirely in the existing central illustration area above the title, without overlap with header or text. Preserve all remaining UI exactly; render timer as a legible static '28' without the original captured digit motion blur. Do not add smartphone hardware frame or extra screens, no marketing headline, no new buttons, no shrimp, no photographic elements. Single portrait app screen matching the original aspect ratio.
```

