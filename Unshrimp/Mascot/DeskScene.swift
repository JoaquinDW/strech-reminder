import SwiftUI

/// The shrimp's little world: wall, window, desk, laptop, unlockable decor and Kip.
/// Drawn in a 360×260 design space.
enum DeskSceneRenderer {
    static let size = CGSize(width: 360, height: 260)
    static let deskTop: CGFloat = 150
    static let floorY: CGFloat = 214

    struct Config {
        var unlocked: Set<DeskItem>
        var ghost: DeskItem?
        var popItem: DeskItem?
        var popStart: Double = 0
        var hour: Int
    }

    static func draw(_ context: GraphicsContext, canvas: CGSize, t: Double, animated: Bool, pose: ShrimpPose, config: Config) {
        var ctx = context
        let s = min(canvas.width / size.width, canvas.height / size.height)
        ctx.translateBy(x: (canvas.width - size.width * s) / 2, y: (canvas.height - size.height * s) / 2)
        ctx.scaleBy(x: s, y: s)

        // Wall and floor
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.wall))
        drawWindow(ctx, hour: config.hour, t: t, animated: animated)
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)), with: .color(Palette.floor))
        ctx.line(Geo.polyline([CGPoint(x: -4, y: floorY), CGPoint(x: size.width + 4, y: floorY)]))

        func item(_ item: DeskItem, at anchor: CGPoint) {
            let isUnlocked = config.unlocked.contains(item)
            let isGhost = !isUnlocked && config.ghost == item
            guard isUnlocked || isGhost else { return }
            var layer = ctx
            layer.translateBy(x: anchor.x, y: anchor.y)
            if isGhost {
                layer.opacity = 0.22
                layer.addFilter(.grayscale(1))
            } else if config.popItem == item, animated {
                let p = t - config.popStart
                if p < 2.0 {
                    let scale = max(0.01, 1 - exp(-6 * p) * cos(11 * p))
                    layer.scaleBy(x: scale, y: scale)
                    drawSparkles(ctx, around: anchor + CGPoint(x: 0, y: -26), progress: p)
                }
            }
            DeskItemArt.draw(item, in: layer, t: t, animated: animated)
        }

        item(.lights, at: CGPoint(x: 180, y: 0))
        item(.poster, at: CGPoint(x: 168, y: 96))

        // Desk
        ctx.outlined(Geo.roundRect(36, deskTop, 6, floorY - deskTop + 2, 3), Palette.woodDeep, width: 2.5)
        ctx.outlined(Geo.roundRect(192, deskTop, 6, floorY - deskTop + 2, 3), Palette.woodDeep, width: 2.5)
        item(.snail, at: CGPoint(x: 112, y: floorY))
        ctx.outlined(Geo.roundRect(18, deskTop - 6, 196, 13, 6), Palette.wood)

        item(.plant, at: CGPoint(x: 44, y: deskTop - 6))
        item(.lamp, at: CGPoint(x: 82, y: deskTop - 6))
        item(.mug, at: CGPoint(x: 116, y: deskTop - 6))

        // Laptop: base on the desk, lid facing Kip
        let base = Geo.polyline([
            CGPoint(x: 144, y: deskTop - 6), CGPoint(x: 196, y: deskTop - 6),
            CGPoint(x: 192, y: deskTop - 12), CGPoint(x: 150, y: deskTop - 12)
        ], closed: true)
        ctx.outlined(base, Palette.laptop, width: 2.5)
        let lid = Geo.polyline([
            CGPoint(x: 147, y: deskTop - 10), CGPoint(x: 135, y: deskTop - 56),
            CGPoint(x: 142, y: deskTop - 58), CGPoint(x: 154, y: deskTop - 11)
        ], closed: true)
        ctx.outlined(lid, Palette.laptopLid, width: 2.5)
        // tiny glow on the screen side
        let glow = Geo.polyline([CGPoint(x: 152, y: deskTop - 16), CGPoint(x: 142, y: deskTop - 53)])
        ctx.line(glow, Palette.mint, width: 2)

        // Kip
        var shrimp = ctx
        shrimp.translateBy(x: 180, y: 26)
        shrimp.scaleBy(x: 0.82, y: 0.82)
        ShrimpRenderer.drawInDesignSpace(pose, ctx: shrimp)
    }

    private static func drawWindow(_ ctx: GraphicsContext, hour: Int, t: Double, animated: Bool) {
        let frame = Geo.roundRect(24, 24, 98, 76, 16)
        let sky: Color
        let night = hour < 6 || hour >= 20
        switch hour {
        case 6..<11: sky = Palette.mintSoft
        case 11..<16: sky = Color(hex: 0xD3EEF2)
        case 16..<20: sky = Color(hex: 0xFFDCCB)
        default: sky = Color(hex: 0x2E5A66)
        }
        ctx.fill(frame, with: .color(sky))
        var inner = ctx
        inner.clip(to: frame)
        if night {
            inner.fill(Geo.circle(CGPoint(x: 96, y: 46), 9), with: .color(Palette.butterSoft))
            inner.fill(Geo.circle(CGPoint(x: 100, y: 43), 8), with: .color(sky))
            for (i, p) in [CGPoint(x: 40, y: 40), CGPoint(x: 60, y: 82), CGPoint(x: 108, y: 80), CGPoint(x: 52, y: 52)].enumerated() {
                let tw = animated ? 0.6 + 0.4 * sin(t * 2 + Double(i)) : 1
                inner.fill(Geo.circle(p, 1.8), with: .color(Palette.butter.opacity(tw)))
            }
        } else {
            let sunY: CGFloat = hour < 11 ? 70 : (hour < 16 ? 44 : 76)
            inner.fill(Geo.circle(CGPoint(x: 98, y: sunY), 11), with: .color(Palette.butter))
            let drift = animated ? CGFloat((t * 3).truncatingRemainder(dividingBy: 140)) : 40
            let cloudX = 10 + drift
            for (dx, dy, r) in [(0.0, 0.0, 8.0), (10.0, -4.0, 10.0), (21.0, 0.0, 7.0)] {
                inner.fill(Geo.circle(CGPoint(x: cloudX + dx, y: 60 + dy), r), with: .color(.white.opacity(0.9)))
            }
        }
        ctx.stroke(frame, with: .color(Palette.petrol), lineWidth: 3)
        ctx.line(Geo.polyline([CGPoint(x: 73, y: 25), CGPoint(x: 73, y: 99)]))
        ctx.line(Geo.polyline([CGPoint(x: 25, y: 62), CGPoint(x: 121, y: 62)]))
        // sill
        ctx.outlined(Geo.roundRect(18, 98, 110, 8, 4), Palette.paper, width: 2.5)
    }

    static func drawSparkles(_ ctx: GraphicsContext, around c: CGPoint, progress p: Double) {
        let fade = max(0, 1 - p / 2)
        for i in 0..<6 {
            let a = Double(i) * 60 + p * 40
            let d = CGFloat(20 + p * 18)
            let pt = c + Geo.dir(a) * d
            let r: CGFloat = 3.5 * CGFloat(fade)
            var star = Path()
            star.move(to: pt + CGPoint(x: 0, y: -r * 2))
            star.addQuadCurve(to: pt + CGPoint(x: r * 2, y: 0), control: pt)
            star.addQuadCurve(to: pt + CGPoint(x: 0, y: r * 2), control: pt)
            star.addQuadCurve(to: pt + CGPoint(x: -r * 2, y: 0), control: pt)
            star.addQuadCurve(to: pt + CGPoint(x: 0, y: -r * 2), control: pt)
            ctx.fill(star, with: .color((i.isMultiple(of: 2) ? Palette.butter : Palette.coral).opacity(fade)))
        }
    }
}

/// Drawings for each unlockable item, anchored at bottom-center (0, 0).
enum DeskItemArt {
    static func draw(_ item: DeskItem, in ctx: GraphicsContext, t: Double, animated: Bool) {
        switch item {
        case .plant: plant(ctx, t: t, animated: animated)
        case .mug: mug(ctx, t: t, animated: animated)
        case .lamp: lamp(ctx)
        case .poster: poster(ctx)
        case .lights: lights(ctx, t: t, animated: animated, width: 300)
        case .snail: snail(ctx, t: t, animated: animated)
        }
    }

    /// Visual bounds of each drawing relative to its anchor, used to center icons.
    static func bounds(_ item: DeskItem) -> CGRect {
        switch item {
        case .plant: CGRect(x: -22, y: -56, width: 44, height: 58)
        case .mug: CGRect(x: -14, y: -40, width: 32, height: 42)
        case .lamp: CGRect(x: -16, y: -60, width: 40, height: 62)
        case .poster: CGRect(x: -30, y: -70, width: 60, height: 72)
        case .lights: CGRect(x: -80, y: -2, width: 160, height: 34)
        case .snail: CGRect(x: -22, y: -30, width: 46, height: 32)
        }
    }

    private static func plant(_ ctx: GraphicsContext, t: Double, animated: Bool) {
        let sway = animated ? sin(t * 1.2) * 4 : 0
        var leaves = ctx
        leaves.translateBy(x: 0, y: -22)
        leaves.rotate(by: .degrees(sway))
        leaves.outlined(Geo.ellipse(CGPoint(x: -9, y: -14), w: 12, h: 28, angle: -28), Palette.leaf, width: 2.5)
        leaves.outlined(Geo.ellipse(CGPoint(x: 9, y: -15), w: 12, h: 30, angle: 26), Palette.leaf, width: 2.5)
        leaves.outlined(Geo.ellipse(CGPoint(x: 0, y: -20), w: 11, h: 30, angle: 0), Palette.mint, width: 2.5)
        let pot = Geo.polyline([CGPoint(x: -10, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 13, y: -20), CGPoint(x: -13, y: -20)], closed: true)
        ctx.outlined(pot, Palette.terracotta, width: 2.5)
        ctx.outlined(Geo.roundRect(-15, -25, 30, 7, 3), Palette.terracotta, width: 2.5)
    }

    private static func mug(_ ctx: GraphicsContext, t: Double, animated: Bool) {
        var handle = Path()
        handle.addArc(center: CGPoint(x: 9, y: -10), radius: 6, startAngle: .degrees(-80), endAngle: .degrees(80), clockwise: false)
        ctx.line(handle, width: 3)
        ctx.outlined(Geo.roundRect(-9, -21, 18, 21, 5), Palette.paper, width: 2.5)
        ctx.fill(Path(CGRect(x: -7.5, y: -13, width: 15, height: 5)), with: .color(Palette.coral))
        for i in 0..<2 {
            let phase = animated ? t * 1.4 + Double(i) * 1.6 : Double(i)
            let rise = CGFloat((phase.truncatingRemainder(dividingBy: 2.4)) / 2.4)
            let x: CGFloat = CGFloat(i) * 7 - 4
            var steam = Path()
            let y0: CGFloat = -25 - rise * 6
            steam.move(to: CGPoint(x: x, y: y0))
            steam.addQuadCurve(to: CGPoint(x: x, y: y0 - 10), control: CGPoint(x: x + 5, y: y0 - 5))
            steam.addQuadCurve(to: CGPoint(x: x, y: y0 - 18), control: CGPoint(x: x - 5, y: y0 - 14))
            ctx.stroke(steam, with: .color(Palette.petrol.opacity(animated ? 0.35 * (1 - rise) : 0.3)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private static func lamp(_ ctx: GraphicsContext) {
        // light cone
        let cone = Geo.polyline([CGPoint(x: 10, y: -46), CGPoint(x: 22, y: -44), CGPoint(x: 30, y: 0), CGPoint(x: -4, y: 0)], closed: true)
        ctx.fill(cone, with: .color(Palette.butter.opacity(0.35)))
        ctx.line(Geo.polyline([CGPoint(x: 0, y: -3), CGPoint(x: -8, y: -32), CGPoint(x: 8, y: -48)]), width: 3.5)
        ctx.outlined(Geo.ellipse(CGPoint(x: 0, y: -3), w: 24, h: 7), Palette.coral, width: 2.5)
        let shade = Geo.polyline([CGPoint(x: 2, y: -54), CGPoint(x: 14, y: -58), CGPoint(x: 24, y: -42), CGPoint(x: 8, y: -40)], closed: true)
        ctx.outlined(shade, Palette.butter, width: 2.5)
        ctx.outlined(Geo.circle(CGPoint(x: -8, y: -32), 3), Palette.paper, width: 2)
    }

    private static func poster(_ ctx: GraphicsContext) {
        let frame = Geo.roundRect(-26, -64, 52, 64, 8)
        ctx.outlined(frame, Palette.paper, width: 3)
        var inner = ctx
        inner.clip(to: Geo.roundRect(-22, -60, 44, 56, 5))
        inner.fill(Path(CGRect(x: -22, y: -60, width: 44, height: 56)), with: .color(Palette.butterSoft))
        inner.fill(Geo.circle(CGPoint(x: 8, y: -44), 7), with: .color(Palette.coral))
        var wave = Path()
        wave.move(to: CGPoint(x: -24, y: -22))
        wave.addQuadCurve(to: CGPoint(x: -8, y: -22), control: CGPoint(x: -16, y: -34))
        wave.addQuadCurve(to: CGPoint(x: 8, y: -22), control: CGPoint(x: 0, y: -10))
        wave.addQuadCurve(to: CGPoint(x: 24, y: -22), control: CGPoint(x: 16, y: -34))
        wave.addLine(to: CGPoint(x: 24, y: 0))
        wave.addLine(to: CGPoint(x: -24, y: 0))
        wave.closeSubpath()
        inner.fill(wave, with: .color(Palette.mint))
        inner.stroke(wave, with: .color(Palette.mintDeep), lineWidth: 2)
    }

    static func lights(_ ctx: GraphicsContext, t: Double, animated: Bool, width: CGFloat) {
        let left = CGPoint(x: -width / 2, y: 6), right = CGPoint(x: width / 2, y: 6)
        var wire = Path()
        wire.move(to: left)
        wire.addQuadCurve(to: right, control: CGPoint(x: 0, y: 34))
        ctx.line(wire, width: 2)
        let colors = [Palette.butter, Palette.coral, Palette.mint]
        let count = max(4, Int(width / 30))
        for i in 0...count {
            let u = CGFloat(i) / CGFloat(count)
            // point on quadratic curve
            let a = left * ((1 - u) * (1 - u))
            let b = CGPoint(x: 0, y: 34) * (2 * (1 - u) * u)
            let c = right * (u * u)
            let p = a + b + c
            let glow = animated ? 0.65 + 0.35 * sin(t * 2.5 + Double(i) * 1.3) : 1
            ctx.fill(Geo.circle(p + CGPoint(x: 0, y: 6), 9), with: .color(colors[i % 3].opacity(0.25 * glow)))
            ctx.outlined(Geo.ellipse(p + CGPoint(x: 0, y: 6), w: 7, h: 9), colors[i % 3].opacity(0.6 + 0.4 * glow), width: 2)
        }
    }

    private static func snail(_ ctx: GraphicsContext, t: Double, animated: Bool) {
        let bob = animated ? CGFloat(sin(t * 1.5)) * 1.2 : 0
        let body = Geo.roundRect(-20, -9, 42, 9, 4.5)
        ctx.line(Geo.polyline([CGPoint(x: -14, y: -8), CGPoint(x: -19, y: -22 + bob)]), width: 2.5)
        ctx.line(Geo.polyline([CGPoint(x: -10, y: -8), CGPoint(x: -11, y: -23 + bob)]), width: 2.5)
        ctx.fill(Geo.circle(CGPoint(x: -19, y: -23 + bob), 2.6), with: .color(Palette.petrol))
        ctx.fill(Geo.circle(CGPoint(x: -11, y: -24 + bob), 2.6), with: .color(Palette.petrol))
        ctx.outlined(body, Color(hex: 0xF6D9B8), width: 2.5)
        ctx.outlined(Geo.circle(CGPoint(x: 6, y: -16), 12), Palette.butter, width: 2.5)
        var swirl = Path()
        swirl.addArc(center: CGPoint(x: 6, y: -16), radius: 6, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: false)
        swirl.addArc(center: CGPoint(x: 6, y: -16), radius: 2.5, startAngle: .degrees(270), endAngle: .degrees(540), clockwise: false)
        ctx.line(swirl, Palette.woodDeep, width: 2)
    }
}

/// The animated desk scene used on Home and in onboarding.
struct DeskSceneView: View {
    var state: ShrimpState
    var unlocked: Set<DeskItem>
    var ghost: DeskItem? = nil
    var popItem: DeskItem? = nil
    var popStart: Double = 0
    @State private var blender = PoseBlender()

    var body: some View {
        LiveCanvas { ctx, size, t, animated in
            let pose = blender.pose(for: state, t: t, animated: animated)
            let hour = Calendar.current.component(.hour, from: Date())
            DeskSceneRenderer.draw(ctx, canvas: size, t: t, animated: animated, pose: pose,
                                   config: .init(unlocked: unlocked, ghost: ghost, popItem: popItem, popStart: popStart, hour: hour))
        }
        .aspectRatio(DeskSceneRenderer.size.width / DeskSceneRenderer.size.height, contentMode: .fit)
        .onChange(of: state) { old, _ in blender.didChange(from: old) }
        .accessibilityElement()
        .accessibilityLabel(Text(sceneLabel))
        .accessibilityAddTraits(.isImage)
    }

    private var sceneLabel: String {
        let items = DeskItem.allCases.filter { unlocked.contains($0) }.map(\.title).formatted(.list(type: .and))
        if items.isEmpty { return state.accessibilityLabel }
        return String(localized: "\(state.accessibilityLabel). On the desk: \(items).")
    }
}

/// A single desk item drawn on its own, for reward previews.
struct DeskItemIcon: View {
    var item: DeskItem
    var locked = false

    var body: some View {
        LiveCanvas { ctx, size, t, animated in
            let b = DeskItemArt.bounds(item)
            let s = min(size.width / b.width, size.height / b.height) * 0.9
            var c = ctx
            c.translateBy(x: size.width / 2 - b.midX * s, y: size.height / 2 - b.midY * s)
            c.scaleBy(x: s, y: s)
            if locked {
                c.opacity = 0.3
                c.addFilter(.grayscale(1))
            }
            DeskItemArt.draw(item, in: c, t: t, animated: animated && !locked)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
