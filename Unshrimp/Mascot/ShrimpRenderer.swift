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
    static func draw(_ pose: ShrimpPose, in context: GraphicsContext, rect: CGRect) {
        var ctx = context
        let s = min(rect.width, rect.height) / designSize
        ctx.translateBy(x: rect.midX - designSize / 2 * s, y: rect.maxY - designSize * s)
        ctx.scaleBy(x: s, y: s)
        drawInDesignSpace(pose, ctx: ctx)
    }

    static func drawInDesignSpace(_ pose: ShrimpPose, ctx: GraphicsContext) {
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
        let shoulder = pts[2] + Geo.dir(hs[2] + 90) * (rs[2] * 0.8)
        func arm(_ sh: CGPoint, angle: Double, color: Color) {
            let a = 180 + angle + pose.lean
            let el = sh + Geo.dir(a) * CGFloat(19 * pose.armLength)
            let hand = el + Geo.dir(a + pose.armBend) * CGFloat(16 * pose.armLength)
            let path = Geo.polyline([sh, el, hand])
            ctx.stroke(path, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: 6 + ow * 2, lineCap: .round, lineJoin: .round))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        arm(shoulder + Geo.dir(hs[2]) * 8, angle: pose.armBack, color: Palette.shrimpDeep)

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

        arm(shoulder, angle: pose.armFront, color: Palette.shrimp)
    }
}
