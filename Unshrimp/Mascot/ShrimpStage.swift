import SwiftUI

/// Small props that turn the mascot into a distinctive illustration per screen.
enum StageProp: Equatable {
    case none
    case thought
    case stopwatch
    case calendar
    case focus(Set<FocusArea>)
    case mat
}

/// Mascot on a soft backdrop with an optional prop. Design space 320×240.
struct ShrimpStage: View {
    var state: ShrimpState
    var prop: StageProp = .none
    var backdrop: Color = Palette.mintSoft
    @State private var blender = PoseBlender()

    var body: some View {
        LiveCanvas { context, size, t, animated in
            var ctx = context
            let s = min(size.width / 320, size.height / 240)
            ctx.translateBy(x: (size.width - 320 * s) / 2, y: (size.height - 240 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            let hasSideProp = prop == .thought || prop == .stopwatch || prop == .calendar
            let shrimpX: CGFloat = hasSideProp ? 96 : 40

            // Backdrop blob and ground shadow
            let wobble = animated ? CGFloat(sin(t * 0.8)) * 3 : 0
            ctx.fill(Geo.ellipse(CGPoint(x: 160, y: 122), w: 270 + wobble, h: 210 - wobble), with: .color(backdrop))
            if prop == .mat {
                ctx.outlined(Geo.ellipse(CGPoint(x: 160 + 8, y: 226), w: 220, h: 26), Palette.mint, width: 2.5)
            } else {
                ctx.fill(Geo.ellipse(CGPoint(x: shrimpX + 128, y: 230), w: 150, h: 14), with: .color(Palette.petrol.opacity(0.08)))
            }

            switch prop {
            case .thought: drawThought(ctx, t: t, animated: animated)
            case .stopwatch: drawStopwatch(ctx, t: t, animated: animated)
            case .calendar: drawCalendar(ctx)
            default: break
            }

            let pose = blender.pose(for: state, t: t, animated: animated)
            var shrimp = ctx
            shrimp.translateBy(x: shrimpX, y: 0)
            ShrimpRenderer.drawInDesignSpace(pose, ctx: shrimp)

            if case .focus(let areas) = prop {
                drawFocus(shrimp, pose: pose, areas: areas, t: t, animated: animated)
            }
        }
        .onChange(of: state) { old, _ in blender.didChange(from: old) }
        .accessibilityElement()
        .accessibilityLabel(Text(state.accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }

    private func drawThought(_ ctx: GraphicsContext, t: Double, animated: Bool) {
        let bob = animated ? CGFloat(sin(t * 1.6)) * 3 : 0
        ctx.outlined(Geo.circle(CGPoint(x: 112, y: 112 + bob), 5), Palette.paper, width: 2.5)
        ctx.outlined(Geo.circle(CGPoint(x: 98, y: 96 + bob), 8), Palette.paper, width: 2.5)
        let cloud = Geo.roundRect(26, 34 + bob, 82, 52, 26)
        ctx.outlined(cloud, Palette.paper, width: 3)
        // a tiny clock and a question mark: forgetting time, not sure what to do
        let c = CGPoint(x: 50, y: 60 + bob)
        ctx.outlined(Geo.circle(c, 13), Palette.butter, width: 2.5)
        let spin = animated ? t * 90 : 30
        ctx.line(Geo.polyline([c, c + Geo.dir(spin) * 8]), width: 2.5)
        ctx.line(Geo.polyline([c, c + Geo.dir(-90) * 6]), width: 2.5)
        ctx.draw(Text("?").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Palette.coral), at: CGPoint(x: 86, y: 60 + bob))
    }

    private func drawStopwatch(_ ctx: GraphicsContext, t: Double, animated: Bool) {
        let c = CGPoint(x: 70, y: 150)
        ctx.outlined(Geo.roundRect(c.x - 7, c.y - 62, 14, 12, 4), Palette.coral, width: 2.5)
        ctx.outlined(Geo.circle(c, 48), Palette.paper, width: 3.5)
        let sweep = animated ? (t * 30).truncatingRemainder(dividingBy: 360) : 120
        var wedge = Path()
        wedge.move(to: c)
        wedge.addArc(center: c, radius: 38, startAngle: .degrees(-90), endAngle: .degrees(-90 + sweep), clockwise: false)
        wedge.closeSubpath()
        ctx.fill(wedge, with: .color(Palette.butter))
        for i in 0..<12 {
            let a = Double(i) * 30
            ctx.line(Geo.polyline([c + Geo.dir(a) * 40, c + Geo.dir(a) * 44]), Palette.petrol.opacity(0.5), width: 2)
        }
        ctx.line(Geo.polyline([c, c + Geo.dir(-90 + sweep) * 34]), width: 3)
        ctx.fill(Geo.circle(c, 4), with: .color(Palette.petrol))
    }

    private func drawCalendar(_ ctx: GraphicsContext) {
        let page = Geo.roundRect(20, 84, 100, 108, 14)
        ctx.outlined(page, Palette.paper, width: 3)
        var top = ctx
        top.clip(to: page)
        top.fill(Path(CGRect(x: 20, y: 84, width: 100, height: 26)), with: .color(Palette.coral))
        ctx.stroke(page, with: .color(Palette.petrol), lineWidth: 3)
        ctx.line(Geo.polyline([CGPoint(x: 20, y: 110), CGPoint(x: 120, y: 110)]), width: 2.5)
        for (i, x) in [44.0, 70, 96].enumerated() {
            ctx.outlined(Geo.roundRect(CGFloat(x) - 3, 76, 6, 16, 3), Palette.ivoryDeep, width: 2)
            _ = i
        }
        for row in 0..<3 {
            for col in 0..<4 {
                let p = CGPoint(x: 36 + col * 23, y: 128 + row * 22)
                let checked = (row * 4 + col) % 3 != 2 && row < 2
                if checked {
                    ctx.fill(Geo.circle(p, 8), with: .color(Palette.mint))
                    ctx.line(Geo.polyline([p + CGPoint(x: -4, y: 0), p + CGPoint(x: -1, y: 3), p + CGPoint(x: 4, y: -3)]), width: 2.2)
                } else {
                    ctx.fill(Geo.circle(p, 3), with: .color(Palette.petrol.opacity(0.25)))
                }
            }
        }
    }

    private func drawFocus(_ ctx: GraphicsContext, pose: ShrimpPose, areas: Set<FocusArea>, t: Double, animated: Bool) {
        let rig = ShrimpRenderer.rig(for: pose)
        let pts = rig.points, hs = rig.headings, rs = rig.radii
        var spots: [CGPoint] = []
        if areas.contains(.neck) || areas.contains(.wholeBody) {
            spots.append(Geo.mid(pts[0], pts[1]) + Geo.dir(hs[1] - 90) * (rs[1] * 0.6))
        }
        if areas.contains(.shoulders) || areas.contains(.wholeBody) {
            spots.append(pts[2] + Geo.dir(hs[2] - 90) * (rs[2] * 0.3))
        }
        if areas.contains(.back) || areas.contains(.wholeBody) {
            spots.append(pts[4] + Geo.dir(hs[4] - 90) * (rs[4] * 0.45))
        }
        if areas.contains(.wholeBody) {
            spots.append(pts[7])
        }
        for (i, p) in spots.enumerated() {
            let pulse = animated ? 0.5 + 0.5 * sin(t * 3 + Double(i)) : 0.6
            ctx.fill(Geo.circle(p, CGFloat(10 + pulse * 6)), with: .color(Palette.butter.opacity(0.45 * (1 - pulse * 0.5))))
            ctx.outlined(Geo.circle(p, 6), Palette.butter, width: 2.5)
        }
    }
}

/// One-shot confetti burst. Replays when `trigger` changes. Hidden with Reduce Motion.
struct ConfettiBurst: View {
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { tl in
                let e = tl.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    guard e < 2.4 else { return }
                    let colors = [Palette.coral, Palette.butter, Palette.mint, Palette.petrol, Palette.blush]
                    var rng = SeededRandom(seed: UInt64(trigger) &+ 7)
                    for i in 0..<70 {
                        let angle = -90 + rng.next(-65, 65)
                        let speed = rng.next(380, 760)
                        let v = Geo.dir(angle) * CGFloat(speed)
                        let g: CGFloat = 900
                        let x = size.width / 2 + v.x * e
                        let y = size.height * 0.62 + v.y * e + 0.5 * g * e * e
                        let fade = max(0, 1 - e / 2.4)
                        var c = ctx
                        c.opacity = fade
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .degrees(rng.next(0, 360) + e * rng.next(-400, 400)))
                        let w = CGFloat(rng.next(6, 11)), h = CGFloat(rng.next(4, 7))
                        let shape = i % 3 == 0 ? Geo.circle(.zero, w / 2) : Geo.roundRect(-w / 2, -h / 2, w, h, 1.5)
                        c.fill(shape, with: .color(colors[i % colors.count]))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start = Date() }
            .onChange(of: trigger) { start = Date() }
        }
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next(_ lo: Double, _ hi: Double) -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return lo + (hi - lo) * Double(state % 10_000) / 10_000
    }
}
