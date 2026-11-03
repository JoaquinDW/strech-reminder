# Unshrimp website

Static marketing site: `index.html` (landing), `support.html`, `privacy.html`. No build step; serve the folder as is.

- Brand name appears as plain text; search for "Unshrimp" to rename.
- Support email (support.html, privacy.html): balthasardeweert@gmail.com.
- Kip sprites in `assets/kip-*.webp` are rendered from the app's own rig with `kip-sprites-harness.swift`:

```sh
M=../Unshrimp
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -o kip kip-sprites-harness.swift \
  $M/Design/Theme.swift $M/Mascot/Geometry.swift $M/Mascot/ShrimpPose.swift $M/Mascot/ShrimpRenderer.swift
./kip out   # PNG sheets, 6 columns of 420px frames; convert with cwebp -q 88 -alpha_q 100
```

- `assets/clips` are copies of `Unshrimp/Resources/ExerciseVideos`; screenshots come from the simulator with the debug launch args.
