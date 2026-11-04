import SwiftUI

/// Vector rig for the shrimp companion. The body is a chain of overlapping circles
/// along a bendable spine, so a handful of numbers (heading, curl, tilt, arms)
/// produce every pose. Drawn in a 240×240 design space, standing on y = 232.
enum ShrimpRenderer {
    static let designSize: CGFloat = 240
    static let groundY: CGFloat = 232
    private static let radii: [CGFloat] = [35, 31, 30, 28.5, 26.5, 24, 21, 17.5, 14]
    private static let step: CGFloat = 19
    private static let outline: CGFloat = 3.1

    struct Rig {
        var points: [CGPoint]
        var headings: [Double]
        var radii: [CGFloat]
        var face: Double
    }

    static func rig(for pose: ShrimpPose) -> Rig {
        let n = radii.count
        let dh = pose.curl / Double(n - 1)
        var h = pose.heading
        var p = CGPoint.zero
        var pts: [CGPoint] = [p]
        var hs: [Double] = []
        for i in 0..<n {
            hs.append(h)
            if i < n - 1 {
                p = p + Geo.dir(h + dh / 2) * step
                pts.append(p)
                h += dh
            }
        }
        let rs = radii.enumerated().map { i, r in i == 0 ? r : r * (1 + 0.02 * pose.breath) }
        pts[0] = pts[0].rotated(by: pose.headTilt, around: pts[1])

        let cx = pts.reduce(0) { $0 + $1.x } / CGFloat(n)
        let maxY = zip(pts, rs).map { $0.y + $1 }.max() ?? 0
        let offset = CGPoint(x: 128 - cx, y: groundY - pose.bounce - maxY)
        let pivot = CGPoint(x: 128, y: groundY)
        pts = pts.map { ($0 + offset).rotated(by: pose.lean, around: pivot) }
        return Rig(points: pts, headings: hs.map { $0 + pose.lean }, radii: rs, face: pose.heading + 180 + pose.headTilt + pose.lean)
    }

    /// Draws the shrimp scaled to fit `rect`, feet on the rect's bottom edge.
    static func draw(_ pose: ShrimpPose, in context: GraphicsContext, rect: CGRect, look: KipLook = KipLook(), t: Double = 0, animated: Bool = false) {
        var ctx = context
        let s = min(rect.width, rect.height) / designSize
        ctx.translateBy(x: rect.midX - designSize / 2 * s, y: rect.maxY - designSize * s)
        ctx.scaleBy(x: s, y: s)
        drawInDesignSpace(pose, ctx: ctx, look: look, t: t, animated: animated)
    }

    static func drawInDesignSpace(_ pose: ShrimpPose, ctx: GraphicsContext, look: KipLook = KipLook(), t: Double = 0, animated: Bool = false) {
        let g = rig(for: pose)
        let pts = g.points, hs = g.headings, rs = g.radii
        let n = pts.count
        let head = pts[0], r0 = rs[0]
        let f = g.face
        let F = Geo.dir(f), U = Geo.dir(f + 90)
        let ow = outline

        // Antennae: one tapered stroke each, thick at the root, ending in a curl.
        let base = head + U * (r0 * 0.74) + F * (r0 * 0.22)
        let len = 0.85 + 0.25 * pose.antennaPerk
        func antenna(_ origin: CGPoint, up: Double, fwd: Double, sway: Double, curlDir: Double, width: CGFloat) {
            var end = origin + U * CGFloat(up * len) + F * CGFloat(fwd)
            end = end.rotated(by: sway, around: origin)
            let c1 = origin + U * CGFloat(up * 0.45 * len) + F * CGFloat(fwd * 0.1 + 12)
            let c2 = end + F * 18 - U * 18
            var stroke = (0...24).map { Geo.bezier(origin, c1, c2, end, Double($0) / 24) }
            let tipDir = Double(atan2(end.y - c2.y, end.x - c2.x)) * 180 / .pi
            let cc = end + Geo.dir(tipDir + 90 * curlDir) * 5.5
            let start = tipDir - 90 * curlDir
            for k in 1...14 {
                let u = Double(k) / 14
                stroke.append(cc + Geo.dir(start + curlDir * 250 * u) * CGFloat(5.5 * (1 - 0.25 * u)))
            }
            ctx.taperedLine(stroke, from: width, to: 1.3)
        }
        antenna(base - F * 6, up: 74, fwd: -26, sway: pose.antennaSway, curlDir: 1, width: 3.8)
        antenna(base, up: 60, fwd: 10, sway: -pose.antennaSway * 0.7 + 4, curlDir: -1, width: 3.4)

        // Arms end in little pincers instead of bare sticks.
        let shoulder = Geo.mid(pts[2], pts[3]) + Geo.dir((hs[2] + hs[3]) / 2 + 90) * (rs[2] * 0.82 * CGFloat(1 - pose.shoulderShift))
        func arm(_ sh: CGPoint, angle: Double, color: Color, seed: Double) {
            let a = 180 + angle + pose.lean
            let L = CGFloat(pose.armLength)
            let el = sh + Geo.dir(a) * (17 * L)
            let fa = a + pose.armBend
            let hand = el + Geo.dir(fa) * (13 * L)
            let limb = Geo.polyline([sh, el, hand])
            ctx.stroke(limb, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 7.5 + ow * 2, lineCap: .round, lineJoin: .round))
            ctx.stroke(limb, with: .color(color), style: StrokeStyle(lineWidth: 7.5, lineCap: .round, lineJoin: .round))
            ctx.line(Geo.polyline([el + Geo.dir(a + 90) * 3, el + Geo.dir(a - 90) * 3]), Palette.petrol.opacity(0.35), width: 1.6)
            let tip = hand + Geo.dir(fa) * 5
            ctx.inked(Geo.wobblyEllipse(tip, w: 15, h: 11, angle: fa, seed: seed), color, width: 2.6)
            let c0 = tip + Geo.dir(fa) * 7.5, c1 = tip - Geo.dir(fa) * 1
            var cut = Path()
            cut.move(to: c0)
            cut.addQuadCurve(to: c1, control: Geo.mid(c0, c1) + Geo.dir(fa + 90) * 1.5)
            ctx.line(cut, width: 2.2)
            ctx.fill(Geo.ellipse(tip + Geo.dir(fa - 90) * 2.6, w: 5, h: 1.8, angle: fa), with: .color(.white.opacity(0.5)))
        }
        arm(shoulder + Geo.dir(hs[3]) * 9, angle: pose.armBack, color: Palette.shrimpShade, seed: 11)

        // Swimmerets: small paddles under the belly
        for i in 3...7 {
            let N = Geo.dir(hs[i] + 90)
            let root = pts[i] + N * (rs[i] * 0.7)
            let a = hs[i] + 112 + sin(pose.legPhase + Double(i)) * pose.legWiggle
            ctx.inked(Geo.wobblyEllipse(root + Geo.dir(a) * 6, w: 12, h: 5.5, angle: a, seed: Double(i)), Palette.shrimpShade, width: 2.4)
        }

        // Tail fan: five blades with midribs, the outer ones behind
        let last = pts[n - 1], hl = hs[n - 1]
        for a in [-50.0, 50, -25, 25, 0] {
            let center = a == 0
            let blade = Geo.wobblyEllipse(last + Geo.dir(hl + a) * 23, w: center ? 30 : 26, h: center ? 13.5 : 12, angle: hl + a, seed: a + 3)
            ctx.inked(blade, center ? Palette.shrimp : Palette.shrimpShade, width: 2.6)
            ctx.line(Geo.polyline([last + Geo.dir(hl + a) * 13, last + Geo.dir(hl + a) * 33]), Palette.shrimpPlate.opacity(0.8), width: 1.6)
        }

        // Body: a smooth tube (each segment sub-sampled into overlapping circles), so the
        // silhouette reads as one shell rather than a string of beads.
        var tube: [(c: CGPoint, r: CGFloat, i: Int)] = []
        for i in 1..<(n - 1) {
            for k in 0..<4 {
                let u = CGFloat(k) / 4
                tube.append((c: pts[i] + (pts[i + 1] - pts[i]) * u, r: rs[i] + (rs[i + 1] - rs[i]) * u, i: i))
            }
        }
        tube.append((c: pts[n - 1], r: rs[n - 1], i: n - 1))
        let tubeShapes = tube.enumerated().map { j, s in Geo.wobblyCircle(s.c, s.r, seed: Double(j) * 0.7, amount: 0.6) }

        // Rostrum: the little spike over the eyes, in place of the old horn.
        let rostrum = Geo.polyline([
            head + U * (r0 * 0.62) + F * (r0 * 0.18),
            head + U * (r0 * 0.98) + F * (r0 * 0.78),
            head + U * (r0 * 0.90) + F * (r0 * 0.62),
            head + U * (r0 * 1.00) + F * (r0 * 0.52),
            head + U * (r0 * 0.66) + F * (r0 * 0.50)
        ], closed: true)
        let headShape = Geo.wobblyEllipse(head + F * 3, w: r0 * 2.18, h: r0 * 1.9, angle: f, seed: 5)
        let shapes = [rostrum] + tubeShapes + [headShape]

        // Ink: a heavier pass offset to the shadow side, the outline, then the fill on top,
        // so only the outer edge stays inked.
        var shadow = ctx
        shadow.translateBy(x: 0.7, y: 1.3)
        let outlineStyle = StrokeStyle(lineWidth: ow * 2, lineCap: .round, lineJoin: .round)
        let shadowStyle = StrokeStyle(lineWidth: ow * 2 + 1.2, lineCap: .round, lineJoin: .round)
        for s in shapes { shadow.stroke(s, with: .color(Palette.petrol), style: shadowStyle) }
        for s in shapes { ctx.stroke(s, with: .color(Palette.petrol), style: outlineStyle) }
        for s in shapes { ctx.fill(s, with: .color(Palette.shrimp)) }

        var tubePath = Path()
        for s in tubeShapes { tubePath.addPath(s) }
        var body = tubePath
        body.addPath(headShape)
        var inner = ctx
        inner.clip(to: body)

        // Volume: shade along the belly and under the head
        for s in tube {
            let N = Geo.dir(hs[min(s.i, n - 1)] + 90)
            inner.fill(Geo.circle(s.c + N * (s.r * 0.98), s.r * 0.62), with: .color(Palette.shrimpShade))
        }
        var underHead = inner
        underHead.clip(to: headShape)
        underHead.fill(Geo.ellipse(head - F * 4 - U * (r0 * 1.05), w: r0 * 1.9, h: r0 * 0.75, angle: f), with: .color(Palette.shrimpShade))

        // Shell plates, inked from the back and lifting off before the belly
        for i in 2..<n {
            let c = Geo.mid(pts[i - 1], pts[i])
            let h = (hs[i - 1] + hs[i]) / 2
            let N = Geo.dir(h + 90)
            let r = (rs[i - 1] + rs[i]) / 2
            let a = c - N * (r * 1.1), b = c + N * (r * 0.42), cp = c + Geo.dir(h) * 6
            inner.taperedLine((0...12).map { Geo.quad(a, cp, b, Double($0) / 12) }, from: 2.8, to: 0.6, color: Palette.shrimpPlate)
        }

        // Carapace seam: the head's back edge where it overlaps the tail
        var seam = inner
        seam.clip(to: tubePath)
        seam.stroke(headShape, with: .color(Palette.petrol.opacity(0.8)), lineWidth: 2)

        // Soft light along the back
        let back = (2...4).map { pts[$0] - Geo.dir(hs[$0] + 90) * (rs[$0] * 0.6) }
        var light = Path()
        light.move(to: back[0])
        for i in 1..<back.count {
            light.addQuadCurve(to: Geo.mid(back[i - 1], back[i]), control: back[i - 1])
        }
        inner.stroke(light, with: .color(Palette.shrimpLight), style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))

        // Speckles, like a real shrimp shell
        for i in 1..<(n - 1) {
            let N = Geo.dir(hs[i] + 90)
            for k in 0..<3 {
                let seed = Double(i * 3 + k)
                let q = pts[i] - N * (rs[i] * CGFloat(0.15 + Geo.hash(seed) * 0.5)) + Geo.dir(hs[i]) * CGFloat((Geo.hash(seed + 40) - 0.5) * 14)
                inner.fill(Geo.circle(q, CGFloat(0.8 + Geo.hash(seed + 80) * 0.7)), with: .color(Palette.shrimpPlate.opacity(0.55)))
            }
        }

        // One crisp highlight on the head
        ctx.fill(Geo.ellipse(head + U * (r0 * 0.58) - F * (r0 * 0.28), w: 9, h: 3.6, angle: f + 60), with: .color(.white.opacity(0.7)))
        ctx.fill(Geo.circle(head + U * (r0 * 0.5) - F * (r0 * 0.02), 1.6), with: .color(.white.opacity(0.7)))

        drawFace(ctx, pose: pose, head: head, showsBrow: !(look.wearable.map(WearableArt.hidesBrow) ?? false))

        if let wearable = look.wearable {
            // Worn in the face's frame, which stays close to screen-aligned: up is up, the face looks left.
            let faceAngle = pose.headTilt * 0.6 + pose.lean
            let lift = WearableArt.lift(wearable)
            var worn = ctx
            worn.translateBy(x: head.x, y: head.y)
            worn.rotate(by: .degrees(faceAngle))
            worn.translateBy(x: 0, y: -lift)
            let localHead = headShape.applying(CGAffineTransform(translationX: -head.x, y: -head.y)
                .concatenating(CGAffineTransform(rotationAngle: -Geo.rad(faceAngle)))
                .concatenating(CGAffineTransform(translationX: 0, y: lift)))
            var visible = true
            if animated, let reveal = look.revealAt {
                // Unlock moment: the new piece drops in from above, lands with a squash, then sparkles.
                let e = t - reveal
                if e < 0 {
                    visible = false
                } else {
                    let p = min(1, e / 0.5)
                    worn.translateBy(x: 0, y: -CGFloat(pow(1 - p, 2)) * 90)
                    if e > 0.5, e < 0.9 {
                        let squash = sin((e - 0.5) / 0.4 * .pi) * 0.12
                        worn.translateBy(x: 0, y: -20)
                        worn.scaleBy(x: 1 + squash, y: 1 - squash)
                        worn.translateBy(x: 0, y: 20)
                    }
                    if e > 0.5 { DeskSceneRenderer.drawSparkles(ctx, around: head + CGPoint(x: 0, y: -30), progress: e - 0.5) }
                }
            }
            if visible {
                WearableArt.draw(wearable, in: worn, head: localHead, t: t, animated: animated)
            }
        }

        arm(shoulder, angle: pose.armFront, color: Palette.shrimp, seed: 4)
    }

    /// Eyes, brows, cheeks, mouth and little extras, kept close to screen-aligned so they stay readable.
    private static func drawFace(_ ctx: GraphicsContext, pose: ShrimpPose, head: CGPoint, showsBrow: Bool) {
        let ang = pose.headTilt * 0.6 + pose.lean
        let FF = Geo.dir(180 + ang), UF = Geo.dir(270 + ang)
        func P(_ fx: CGFloat, _ uy: CGFloat) -> CGPoint { head + FF * fx + UF * uy }
        func curve(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, width: CGFloat = 3, color: Color = Palette.petrol) {
            var p = Path()
            p.move(to: a)
            p.addQuadCurve(to: b, control: c)
            ctx.line(p, color, width: width)
        }

        // Eyes
        let eye = P(15, 7) + CGPoint(x: -1.6 * pose.lookX, y: -1.4 * pose.lookY)
        func e(_ x: CGFloat, _ y: CGFloat) -> CGPoint { eye + CGPoint(x: x, y: y) }
        switch pose.eye {
        case .dot, .wide, .sparkle, .sleepy:
            let big = pose.eye == .wide || pose.eye == .sparkle
            let w: CGFloat = big ? 10.5 : 9
            let h: CGFloat = (big ? 13.5 : 11.5) * CGFloat(max(0.12, pose.eyeOpen))
            ctx.fill(Geo.wobblyEllipse(eye, w: w, h: h, seed: 2), with: .color(Palette.petrol))
            if pose.eyeOpen > 0.5 {
                if pose.eye == .sparkle {
                    ctx.fill(Geo.star(e(-1.2, -2.2), 4.2), with: .color(.white))
                    ctx.fill(Geo.circle(e(2.4, 3.4), 1.2), with: .color(.white))
                } else {
                    ctx.fill(Geo.circle(e(-1.6, -2.8), big ? 2.8 : 2.3), with: .color(.white))
                    ctx.fill(Geo.circle(e(1.8, 2.6), big ? 1.3 : 1), with: .color(.white))
                }
            }
            if pose.eye == .sleepy {
                ctx.fill(Geo.ellipse(e(0, -7), w: 14, h: 8, angle: -8), with: .color(Palette.shrimp))
                curve(e(-6, -2), e(0, -0.8), e(6, -4), width: 2.6)
            }
        case .happy:
            curve(e(-5.5, 2.5), e(0, -7.5), e(5.5, 2.5))
        case .closed:
            curve(e(-5.5, -1), e(0, 6), e(5.5, -1))
        case .squint:
            ctx.line(Geo.polyline([e(4.5, -4.5), e(-3.5, 0), e(4.5, 4.5)]), width: 3)
        }

        // Brow: lift moves it up; positive tilt raises the front end (worried), negative lowers it (determined).
        if showsBrow, pose.brow > 0.01, pose.eye != .squint {
            let c = e(0.5, CGFloat(-10.5 - 2.6 * pose.browLift))
            let l = c + CGPoint(x: -5, y: -3.2 * pose.browTilt)
            let r = c + CGPoint(x: 4.5, y: 1.2 * pose.browTilt)
            curve(l, Geo.mid(l, r) + CGPoint(x: 0, y: -1.8 + abs(pose.browTilt) * 0.6), r, width: 2.3, color: Palette.petrol.opacity(pose.brow))
        }

        // Cheek: a soft blush with pencil hatching
        let cheek = P(7, -7)
        ctx.fill(Geo.ellipse(cheek, w: 11, h: 6.5), with: .color(Palette.blush.opacity(0.6 * pose.blush)))
        for k in -1...1 {
            let x = CGFloat(k) * 3
            ctx.line(Geo.polyline([cheek + CGPoint(x: x - 1.5, y: 1.5), cheek + CGPoint(x: x + 1.5, y: -1.5)]), Palette.shrimpDeep.opacity(0.75 * pose.blush), width: 1.3)
        }

        // Mouth
        let m = P(25, -3)
        func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { m + CGPoint(x: x, y: y) }
        switch pose.mouth {
        case .smile:
            curve(q(-4.5, -1.5), q(0, 4.5), q(4, -1), width: 2.4)
        case .flat:
            curve(q(-3.5, 0.6), q(0, -0.6), q(3, 1.2), width: 2.4)
        case .sad:
            curve(q(-4, 2), q(0, -2.5), q(4, 2), width: 2.4)
        case .open, .grin:
            let wide: CGFloat = pose.mouth == .grin ? 6.5 : 5
            let deep: CGFloat = pose.mouth == .grin ? 11 : 9
            var p = Path()
            p.move(to: q(-wide, -1.5))
            p.addQuadCurve(to: q(wide, -1.5), control: q(0, deep))
            p.closeSubpath()
            ctx.fill(p, with: .color(Palette.petrol))
            ctx.line(p, width: 1.6)
            var inside = ctx
            inside.clip(to: p)
            inside.fill(Geo.ellipse(q(0.5, deep * 0.42), w: wide * 0.95, h: deep * 0.38), with: .color(Palette.tongue))
        case .tiny:
            ctx.fill(Geo.wobblyEllipse(q(0, 1), w: 4.2, h: 5, seed: 1), with: .color(Palette.petrol))
        case .yawn:
            let p = Geo.wobblyEllipse(q(0.5, 2.5), w: 7, h: 10, seed: 4)
            ctx.fill(p, with: .color(Palette.petrol))
            var inside = ctx
            inside.clip(to: p)
            inside.fill(Geo.ellipse(q(0.5, 6), w: 5, h: 4), with: .color(Palette.tongue))
        case .wobbly:
            var p = Path()
            p.move(to: q(-5, 1))
            p.addQuadCurve(to: q(-1.6, 0.6), control: q(-3.3, -1.6))
            p.addQuadCurve(to: q(1.6, 0.4), control: q(0, 2.6))
            p.addQuadCurve(to: q(5, 1), control: q(3.3, -1.6))
            ctx.line(p, width: 2.3)
        case .tongue:
            var t = Path()
            t.move(to: q(-2.8, 0))
            t.addQuadCurve(to: q(0, 6), control: q(-3, 6))
            t.addQuadCurve(to: q(2.6, 0), control: q(3, 6))
            ctx.fill(t, with: .color(Palette.tongue))
            ctx.line(t, width: 1.8)
            ctx.line(Geo.polyline([q(0, 1.5), q(0, 3.8)]), Palette.shrimpPlate.opacity(0.8), width: 1.1)
            curve(q(-4.5, -0.8), q(0, 1.4), q(4, -0.6), width: 2.4)
        }

        // Extras
        if pose.sweat > 0.01 {
            let d = P(-14, 24)
            var drop = Path()
            drop.move(to: d + CGPoint(x: 0, y: -6))
            drop.addQuadCurve(to: d + CGPoint(x: 0, y: 3.5), control: d + CGPoint(x: 5, y: 1))
            drop.addQuadCurve(to: d + CGPoint(x: 0, y: -6), control: d + CGPoint(x: -5, y: 1))
            var layer = ctx
            layer.opacity = pose.sweat
            layer.fill(drop, with: .color(Palette.sweat))
            layer.line(drop, width: 1.8)
        }
        if pose.sparkles > 0.01 {
            var layer = ctx
            layer.opacity = pose.sparkles
            // In front of the face and below any brim, so nothing Kip wears covers them.
            for (x, y, r) in [(47.0, 14.0, 5.0), (54, 3, 3.2), (47, -6, 3.8)] {
                let s = Geo.star(P(CGFloat(x), CGFloat(y)), CGFloat(r))
                layer.fill(s, with: .color(Palette.butter))
                layer.line(s, width: 1.4)
            }
        }
    }
}

/// Kip's wearables, drawn in the face frame: origin at the head's center, the face to the left.
enum WearableArt {
    /// How far up the head an item sits, so headwear stays clear of the eye.
    static func lift(_ item: Wearable) -> CGFloat {
        switch item {
        case .sweatband: 10
        case .beanie, .cap, .captain: 6
        case .specs, .flower, .crown, .starfish, .headphones, .shades, .coralCrown: 0
        }
    }

    /// A brim on the brow line already reads as the brow, so the drawn one would only clutter it.
    static func hidesBrow(_ item: Wearable) -> Bool {
        item == .sweatband || item == .beanie || item == .cap || item == .captain
    }

    static func draw(_ item: Wearable, in ctx: GraphicsContext, head: Path, t: Double, animated: Bool) {
        switch item {
        case .sweatband: sweatband(ctx, head: head, t: t, animated: animated)
        case .specs: specs(ctx)
        case .beanie: beanie(ctx)
        case .flower: flower(ctx, t: t, animated: animated)
        case .crown: crown(ctx)
        case .cap: cap(ctx)
        case .starfish: starfish(ctx, t: t, animated: animated)
        case .headphones: headphones(ctx)
        case .captain: captain(ctx)
        case .shades: shades(ctx)
        case .coralCrown: coralCrown(ctx)
        }
    }

    private static func sweatband(_ ctx: GraphicsContext, head: Path, t: Double, animated: Bool) {
        let flutter = animated ? sin(t * 4) * 6 : 0
        // Tails tied at the back of the head
        var tails = ctx
        tails.translateBy(x: 18, y: -17)
        tails.rotate(by: .degrees(flutter))
        tails.outlined(Geo.ellipse(CGPoint(x: 10, y: 5), w: 18, h: 7, angle: 30), Palette.mint, width: 2.5)
        tails.outlined(Geo.ellipse(CGPoint(x: 11, y: -3), w: 16, h: 6, angle: -10), Palette.mint, width: 2.5)
        let band = Geo.polyline([CGPoint(x: -44, y: -15), CGPoint(x: 44, y: -25), CGPoint(x: 44, y: -14), CGPoint(x: -44, y: -3)], closed: true)
        var inside = ctx
        inside.clip(to: head)
        inside.fill(band, with: .color(Palette.mint))
        inside.line(Geo.polyline([CGPoint(x: -44, y: -9), CGPoint(x: 44, y: -19.5)]), Palette.paper, width: 2.5)
        inside.line(Geo.polyline([CGPoint(x: -44, y: -15), CGPoint(x: 44, y: -25)]), width: 2.5)
        inside.line(Geo.polyline([CGPoint(x: -44, y: -3), CGPoint(x: 44, y: -14)]), width: 2.5)
    }

    private static func specs(_ ctx: GraphicsContext) {
        let eye = CGPoint(x: -14, y: -6)
        ctx.line(Geo.polyline([eye + CGPoint(x: 9, y: -1), CGPoint(x: 16, y: -9)]), width: 2.5)
        ctx.fill(Geo.circle(eye, 9.5), with: .color(.white.opacity(0.28)))
        ctx.stroke(Geo.circle(eye, 9.5), with: .color(Palette.petrol), lineWidth: 2.8)
        ctx.line(Geo.polyline([eye + CGPoint(x: -9.5, y: -1), eye + CGPoint(x: -14, y: -2)]), width: 2.5)
        ctx.line(Geo.polyline([eye + CGPoint(x: -4, y: -5), eye + CGPoint(x: 0, y: -6.5)]), .white.opacity(0.9), width: 2)
    }

    private static func beanie(_ ctx: GraphicsContext) {
        var dome = Path()
        dome.move(to: CGPoint(x: -35, y: -17))
        dome.addCurve(to: CGPoint(x: 33, y: -17), control1: CGPoint(x: -38, y: -66), control2: CGPoint(x: 34, y: -66))
        dome.closeSubpath()
        ctx.outlined(dome, Palette.mint, width: 3)
        for x in stride(from: -18.0, through: 18, by: 12) {
            var rib = Path()
            rib.move(to: CGPoint(x: x * 0.4 - 1, y: -50))
            rib.addQuadCurve(to: CGPoint(x: x, y: -20), control: CGPoint(x: x * 0.9, y: -42))
            ctx.line(rib, Palette.mintDeep.opacity(0.55), width: 2)
        }
        ctx.outlined(Geo.roundRect(-39, -24, 76, 12, 6), Palette.butter, width: 3)
        for x in stride(from: -30.0, through: 28, by: 8) {
            ctx.line(Geo.polyline([CGPoint(x: x, y: -21), CGPoint(x: x, y: -15)]), Palette.woodDeep.opacity(0.6), width: 1.6)
        }
        ctx.outlined(Geo.circle(CGPoint(x: -2, y: -55), 8), Palette.coralSoft, width: 3)
    }

    private static func flower(_ ctx: GraphicsContext, t: Double, animated: Bool) {
        var f = ctx
        f.translateBy(x: 16, y: -32)
        f.rotate(by: .degrees(animated ? sin(t * 1.4) * 8 : 0))
        f.outlined(Geo.ellipse(CGPoint(x: 10, y: 6), w: 14, h: 6, angle: 25), Palette.leaf, width: 2.2)
        for i in 0..<5 {
            let a = Double(i) * 72 - 90
            f.outlined(Geo.ellipse(Geo.dir(a) * 7, w: 10, h: 8, angle: a), Palette.paper, width: 2.2)
        }
        f.outlined(Geo.circle(.zero, 4.5), Palette.butter, width: 2.2)
    }

    private static func crown(_ ctx: GraphicsContext) {
        var c = ctx
        c.translateBy(x: -2, y: -26)
        c.rotate(by: .degrees(-8))
        c.scaleBy(x: 1.3, y: 1.3)
        let shape = Geo.polyline([
            CGPoint(x: -19, y: 0), CGPoint(x: 19, y: 0), CGPoint(x: 21, y: -20), CGPoint(x: 11, y: -10),
            CGPoint(x: 0, y: -24), CGPoint(x: -11, y: -10), CGPoint(x: -21, y: -20)
        ], closed: true)
        c.outlined(shape, Palette.butter, width: 3)
        c.line(Geo.polyline([CGPoint(x: -18, y: -5), CGPoint(x: 18, y: -5)]), Palette.woodDeep.opacity(0.6), width: 2)
        c.outlined(Geo.circle(CGPoint(x: 0, y: -24), 3.5), Palette.coral, width: 2)
        c.outlined(Geo.circle(CGPoint(x: -21, y: -20), 3), Palette.mint, width: 2)
        c.outlined(Geo.circle(CGPoint(x: 21, y: -20), 3), Palette.mint, width: 2)
    }

    // MARK: Streak milestone wearables

    private static func cap(_ ctx: GraphicsContext) {
        var dome = Path()
        dome.move(to: CGPoint(x: -32, y: -18))
        dome.addCurve(to: CGPoint(x: 31, y: -18), control1: CGPoint(x: -34, y: -60), control2: CGPoint(x: 31, y: -60))
        dome.closeSubpath()
        ctx.outlined(dome, Palette.butter, width: 3)
        var seam = Path()
        seam.move(to: CGPoint(x: -2, y: -50))
        seam.addQuadCurve(to: CGPoint(x: -8, y: -19), control: CGPoint(x: -9, y: -36))
        ctx.line(seam, Palette.woodDeep.opacity(0.6), width: 2)
        ctx.fill(Geo.ellipse(CGPoint(x: 14, y: -38), w: 12, h: 5, angle: 35), with: .color(.white.opacity(0.5)))
        // The brim points the way Kip faces.
        var brim = Path()
        brim.move(to: CGPoint(x: -26, y: -24))
        brim.addQuadCurve(to: CGPoint(x: -62, y: -15), control: CGPoint(x: -46, y: -30))
        brim.addQuadCurve(to: CGPoint(x: -24, y: -15), control: CGPoint(x: -44, y: -9))
        brim.closeSubpath()
        ctx.outlined(brim, Palette.mint, width: 3)
        ctx.outlined(Geo.circle(CGPoint(x: -2, y: -51), 4), Palette.mint, width: 2.4)
    }

    private static func starfish(_ ctx: GraphicsContext, t: Double, animated: Bool) {
        var s = ctx
        s.translateBy(x: 12, y: -34)
        s.rotate(by: .degrees(-12 + (animated ? sin(t * 1.2) * 6 : 0)))
        let points = (0..<10).map { k -> CGPoint in
            let r: CGFloat = k.isMultiple(of: 2) ? 13 : 5.5
            return Geo.dir(Double(k) * 36 - 90) * r
        }
        var star = Path()
        star.move(to: points[0])
        for k in 1...points.count {
            let p = points[k % points.count], prev = points[k - 1]
            star.addQuadCurve(to: p, control: Geo.mid(prev, p) * 1.08)
        }
        star.closeSubpath()
        s.outlined(star, Palette.terracotta, width: 2.4)
        for k in 0..<5 {
            s.fill(Geo.circle(Geo.dir(Double(k) * 72 - 90) * 6.5, 1.3), with: .color(Palette.butter))
        }
        s.fill(Geo.circle(.zero, 1.8), with: .color(Palette.butter))
    }

    private static func headphones(_ ctx: GraphicsContext) {
        var band = Path()
        band.move(to: CGPoint(x: -28, y: -27))
        band.addCurve(to: CGPoint(x: 18, y: -10), control1: CGPoint(x: -20, y: -58), control2: CGPoint(x: 24, y: -56))
        ctx.stroke(band, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
        ctx.stroke(band, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        // The far cup only peeks out past the edge of the head, clear of the brow.
        ctx.outlined(Geo.ellipse(CGPoint(x: -30, y: -24), w: 8, h: 12, angle: -35), Palette.mintDeep, width: 2.2)
        ctx.outlined(Geo.ellipse(CGPoint(x: 19, y: -3), w: 19, h: 25, angle: 12), Palette.mint, width: 3)
        ctx.outlined(Geo.ellipse(CGPoint(x: 18, y: -3), w: 10, h: 15, angle: 12), Palette.coralSoft, width: 2)
    }

    private static func captain(_ ctx: GraphicsContext) {
        var crown = Path()
        crown.move(to: CGPoint(x: -29, y: -20))
        crown.addLine(to: CGPoint(x: 29, y: -20))
        crown.addLine(to: CGPoint(x: 37, y: -45))
        crown.addQuadCurve(to: CGPoint(x: -37, y: -45), control: CGPoint(x: 0, y: -58))
        crown.closeSubpath()
        ctx.outlined(crown, Palette.paper, width: 3)
        ctx.outlined(Geo.roundRect(-31, -31, 62, 11, 3), Palette.petrol, width: 2.4)
        var brim = Path()
        brim.move(to: CGPoint(x: -24, y: -23))
        brim.addQuadCurve(to: CGPoint(x: -56, y: -14), control: CGPoint(x: -42, y: -27))
        brim.addQuadCurve(to: CGPoint(x: -22, y: -15), control: CGPoint(x: -40, y: -9))
        brim.closeSubpath()
        ctx.outlined(brim, Palette.petrol, width: 2.6)
        // A little gold anchor badge
        ctx.outlined(Geo.circle(CGPoint(x: -6, y: -40), 5), Palette.butter, width: 2.2)
        ctx.line(Geo.polyline([CGPoint(x: -6, y: -43), CGPoint(x: -6, y: -37)]), width: 1.4)
        var hook = Path()
        hook.move(to: CGPoint(x: -9, y: -39))
        hook.addQuadCurve(to: CGPoint(x: -3, y: -39), control: CGPoint(x: -6, y: -35.5))
        ctx.line(hook, width: 1.4)
    }

    private static func shades(_ ctx: GraphicsContext) {
        let eye = CGPoint(x: -14, y: -6)
        ctx.line(Geo.polyline([eye + CGPoint(x: 9, y: -3), CGPoint(x: 20, y: -11)]), width: 3)
        ctx.line(Geo.polyline([eye + CGPoint(x: -11, y: -3), eye + CGPoint(x: -17, y: -4)]), width: 3)
        ctx.outlined(Geo.roundRect(eye.x - 12, eye.y - 9, 24, 17, 7), Palette.petrol, width: 2.4)
        ctx.line(Geo.polyline([eye + CGPoint(x: -6, y: 1), eye + CGPoint(x: 0, y: -5)]), Palette.mint, width: 2.6)
        ctx.line(Geo.polyline([eye + CGPoint(x: 0, y: 3), eye + CGPoint(x: 4, y: -1)]), Palette.mint.opacity(0.7), width: 2)
    }

    private static func coralCrown(_ ctx: GraphicsContext) {
        var c = ctx
        c.translateBy(x: -2, y: -29)
        c.rotate(by: .degrees(-8))
        c.scaleBy(x: 1.25, y: 1.25)
        var branches = Path()
        for (root, tip, fork, forkTip) in [
            (CGPoint(x: 0, y: -4), CGPoint(x: 0, y: -27), CGPoint(x: 0, y: -15), CGPoint(x: 7, y: -22)),
            (CGPoint(x: -12, y: -4), CGPoint(x: -17, y: -22), CGPoint(x: -14, y: -13), CGPoint(x: -8, y: -19)),
            (CGPoint(x: 12, y: -4), CGPoint(x: 17, y: -22), CGPoint(x: 14, y: -13), CGPoint(x: 20, y: -15))
        ] {
            branches.move(to: root)
            branches.addLine(to: tip)
            branches.move(to: fork)
            branches.addLine(to: forkTip)
        }
        c.stroke(branches, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
        c.stroke(branches, with: .color(Palette.coralSoft), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        for tip in [CGPoint(x: 0, y: -27), CGPoint(x: -17, y: -22), CGPoint(x: 17, y: -22)] {
            c.outlined(Geo.circle(tip, 3.2), Palette.paper, width: 1.8)
        }
        c.outlined(Geo.roundRect(-20, -7, 40, 9, 4), Palette.butter, width: 2.6)
        c.outlined(Geo.circle(CGPoint(x: 0, y: -2.5), 2.6), Palette.mint, width: 1.6)
    }
}
