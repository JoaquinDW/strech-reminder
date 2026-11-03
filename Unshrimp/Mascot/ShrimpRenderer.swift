import SwiftUI

/// Vector rig for the shrimp companion. The body is a chain of overlapping circles
/// along a bendable spine, so a handful of numbers (heading, curl, tilt, arms)
/// produce every pose. Drawn in a 240×240 design space, standing on y = 232.
enum ShrimpRenderer {
    static let designSize: CGFloat = 240
    static let groundY: CGFloat = 232
    private static let radii: [CGFloat] = [35, 31, 30, 28.5, 26.5, 24, 21, 17.5, 14]
    private static let step: CGFloat = 19
    private static let outline: CGFloat = 3.6

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
        let round = StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)

        // Antennae (behind the head)
        let base = head + U * (r0 * 0.78) + F * (r0 * 0.30)
        let len = 0.85 + 0.25 * pose.antennaPerk
        func antenna(_ origin: CGPoint, up: Double, fwd: Double, sway: Double, curlDir: Double) {
            var end = origin + U * CGFloat(up * len) + F * CGFloat(fwd)
            end = end.rotated(by: sway, around: origin)
            let c1 = origin + U * CGFloat(up * 0.45 * len) + F * CGFloat(fwd * 0.1 + 12)
            let c2 = end + F * 18 - U * 18
            var path = Path()
            path.move(to: origin)
            path.addCurve(to: end, control1: c1, control2: c2)
            let tipDir = atan2(end.y - c2.y, end.x - c2.x) * 180 / .pi
            let cc = end + Geo.dir(tipDir + 90 * curlDir) * 6.5
            let start = tipDir - 90 * curlDir
            path.addArc(center: cc, radius: 6.5, startAngle: .degrees(start), endAngle: .degrees(start + curlDir * 270), clockwise: curlDir < 0)
            ctx.stroke(path, with: .color(Palette.petrol), style: round)
        }
        antenna(base - F * 6, up: 74, fwd: -26, sway: pose.antennaSway, curlDir: 1)
        antenna(base, up: 60, fwd: 10, sway: -pose.antennaSway * 0.7 + 4, curlDir: -1)

        // Arms
        let shoulder = Geo.mid(pts[2], pts[3]) + Geo.dir((hs[2] + hs[3]) / 2 + 90) * (rs[2] * 0.82 * CGFloat(1 - pose.shoulderShift))
        func arm(_ sh: CGPoint, angle: Double, color: Color) {
            let a = 180 + angle + pose.lean
            let el = sh + Geo.dir(a) * CGFloat(19 * pose.armLength)
            let hand = el + Geo.dir(a + pose.armBend) * CGFloat(16 * pose.armLength)
            let path = Geo.polyline([sh, el, hand])
            ctx.stroke(path, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 6 + ow * 2, lineCap: .round, lineJoin: .round))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        arm(shoulder + Geo.dir(hs[3]) * 9, angle: pose.armBack, color: Palette.shrimpDeep)

        // Little legs on the belly
        for i in 3...7 {
            let N = Geo.dir(hs[i] + 90)
            let root = pts[i] + N * (rs[i] * 0.72)
            let tip = root + Geo.dir(hs[i] + 118 + sin(pose.legPhase + Double(i)) * pose.legWiggle) * 11
            let path = Geo.polyline([root, tip])
            ctx.stroke(path, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 4 + ow * 2, lineCap: .round))
            ctx.stroke(path, with: .color(Palette.shrimp), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }

        // Body silhouette: outlines first, then fills, so only the outer edge is outlined.
        let last = pts[n - 1], hl = hs[n - 1]
        let lobes = [-40.0, 0, 40].map { a in Geo.ellipse(last + Geo.dir(hl + a) * 15, w: 24, h: 13, angle: hl + a) }
        let horn = Geo.polyline([
            head + U * (r0 - 5) - F * 9,
            head + U * (r0 + 11) + F * 9,
            head + U * (r0 - 7) + F * 11
        ], closed: true)
        let headShape = Geo.ellipse(head + F * 3, w: r0 * 2.12, h: r0 * 1.86, angle: f)
        var shapes: [Path] = [horn] + lobes
        for i in 1..<n { shapes.append(Geo.circle(pts[i], rs[i])) }
        shapes.append(headShape)

        let outlineStyle = StrokeStyle(lineWidth: ow * 2, lineCap: .round, lineJoin: .round)
        for s in shapes { ctx.stroke(s, with: .color(Palette.petrol), style: outlineStyle) }
        for s in shapes { ctx.fill(s, with: .color(Palette.shrimp)) }

        // Segment stripes, clipped to the body
        var body = Path()
        for i in 1..<n { body.addPath(Geo.circle(pts[i], rs[i])) }
        var clipped = ctx
        clipped.clip(to: body)
        for i in 2..<n {
            let c = Geo.mid(pts[i - 1], pts[i])
            let h = (hs[i - 1] + hs[i]) / 2
            let N = Geo.dir(h + 90)
            let r = (rs[i - 1] + rs[i]) / 2
            var stripe = Path()
            stripe.move(to: c + N * (r * 1.3))
            stripe.addQuadCurve(to: c - N * (r * 1.3), control: c + Geo.dir(h) * 7)
            clipped.stroke(stripe, with: .color(Palette.shrimpDeep), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }

        // Glossy highlights
        let gloss = Color.white.opacity(0.55)
        for i in 1...3 {
            ctx.fill(Geo.ellipse(pts[i] + Geo.dir(hs[i] - 90) * (rs[i] * 0.58), w: 13, h: 4.5, angle: hs[i]), with: .color(gloss))
        }
        ctx.fill(Geo.ellipse(head + U * (r0 * 0.55) - F * (r0 * 0.35), w: 10, h: 4.5, angle: f + 60), with: .color(gloss))

        // Face (kept close to screen-aligned so expressions stay readable)
        let FF = Geo.dir(180 + pose.headTilt * 0.6 + pose.lean)
        let UF = Geo.dir(270 + pose.headTilt * 0.6 + pose.lean)
        let eye = head + FF * 14 + UF * 6
        switch pose.eye {
        case .dot, .wide:
            let wide = pose.eye == .wide
            let w: CGFloat = wide ? 8.5 : 7
            let h: CGFloat = (wide ? 10.5 : 9) * CGFloat(max(0.12, pose.eyeOpen))
            ctx.fill(Geo.ellipse(eye, w: w, h: h), with: .color(Palette.petrol))
            if pose.eyeOpen > 0.5 {
                ctx.fill(Geo.circle(eye + CGPoint(x: -1.4, y: -2.4), wide ? 2.2 : 1.8), with: .color(.white))
            }
        case .happy:
            var p = Path()
            p.move(to: eye + CGPoint(x: -5, y: 2))
            p.addQuadCurve(to: eye + CGPoint(x: 5, y: 2), control: eye + CGPoint(x: 0, y: -7))
            ctx.stroke(p, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        case .closed:
            var p = Path()
            p.move(to: eye + CGPoint(x: -5, y: -1))
            p.addQuadCurve(to: eye + CGPoint(x: 5, y: -1), control: eye + CGPoint(x: 0, y: 6))
            ctx.stroke(p, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        let blush = head + FF * 8 - UF * 7
        ctx.fill(Geo.ellipse(blush, w: 10, h: 6), with: .color(Palette.blush.opacity(0.85 * pose.blush)))

        let m = head + FF * 25 - UF * 3
        switch pose.mouth {
        case .smile:
            var p = Path()
            p.move(to: m + CGPoint(x: -4, y: -1))
            p.addQuadCurve(to: m + CGPoint(x: 4, y: -1), control: m + CGPoint(x: 0, y: 4))
            ctx.stroke(p, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        case .open:
            var p = Path()
            p.move(to: m + CGPoint(x: -5, y: -1.5))
            p.addQuadCurve(to: m + CGPoint(x: 5, y: -1.5), control: m + CGPoint(x: 0, y: 9))
            p.closeSubpath()
            ctx.fill(p, with: .color(Palette.petrol))
        case .flat:
            ctx.stroke(Geo.polyline([m + CGPoint(x: -3, y: 0.5), m + CGPoint(x: 3, y: 0.5)]), with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }

        if let wearable = look.wearable {
            // Worn in the face's frame, which stays close to screen-aligned: up is up, the face looks left.
            let faceAngle = pose.headTilt * 0.6 + pose.lean
            var worn = ctx
            worn.translateBy(x: head.x, y: head.y)
            worn.rotate(by: .degrees(faceAngle))
            let localHead = headShape.applying(CGAffineTransform(translationX: -head.x, y: -head.y)
                .concatenating(CGAffineTransform(rotationAngle: -Geo.rad(faceAngle))))
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

        arm(shoulder, angle: pose.armFront, color: Palette.shrimp)
    }
}

/// Kip's wearables, drawn in the face frame: origin at the head's center, the face to the left.
enum WearableArt {
    static func draw(_ item: Wearable, in ctx: GraphicsContext, head: Path, t: Double, animated: Bool) {
        switch item {
        case .sweatband: sweatband(ctx, head: head, t: t, animated: animated)
        case .specs: specs(ctx)
        case .beanie: beanie(ctx)
        case .flower: flower(ctx, t: t, animated: animated)
        case .crown: crown(ctx)
        }
    }

    private static func sweatband(_ ctx: GraphicsContext, head: Path, t: Double, animated: Bool) {
        let flutter = animated ? sin(t * 4) * 6 : 0
        // Tails tied at the back of the head
        var tails = ctx
        tails.translateBy(x: 30, y: -18)
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
}
