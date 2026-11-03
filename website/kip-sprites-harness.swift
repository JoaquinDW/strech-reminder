import SwiftUI
import AppKit

enum Brand { static let mascotName = "Kip"; static let appName = "Unshrimp" }
enum Wearable: String, CaseIterable { case sweatband, specs, beanie, flower, crown }

let S: CGFloat = 420  // px per frame
let outDir = CommandLine.arguments[1]

@MainActor func strip(_ poses: [(ShrimpPose, KipLook, Double)], name: String) {
    let n = poses.count
    let view = Canvas { ctx, size in
        for (i, item) in poses.enumerated() {
            let r = CGRect(x: CGFloat(i % 6) * S, y: CGFloat(i / 6) * S, width: S, height: S)
            ShrimpRenderer.draw(item.0, in: ctx, rect: r, look: item.1, t: item.2, animated: true)
        }
    }.frame(width: S * CGFloat(min(n, 6)), height: S * CGFloat((n + 5) / 6))
    let r = ImageRenderer(content: view)
    r.scale = 1
    guard let cg = r.cgImage else { print("fail", name); return }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print(name, n)
}

func ease(_ x: Double) -> Double { x < 0.5 ? 4*x*x*x : 1 - pow(-2*x + 2, 3)/2 }
@MainActor func run() {

// 1. Unshrimp: hunched at the desk -> fully upright stretch.
var hunch = ShrimpMotion.pose(.working, t: 0, animated: false)
hunch.curl = 215; hunch.heading = 6; hunch.headTilt = -12
hunch.armFront = 10; hunch.armBack = 16; hunch.armBend = -40; hunch.armLength = 1.4
hunch.mouth = .flat; hunch.eye = .dot
let mid = ShrimpMotion.pose(.inviting, t: 0.2, animated: false)
let tall = ShrimpMotion.pose(.stretching, t: 0, animated: false)
var seq: [(ShrimpPose, KipLook, Double)] = []
let N = 36
for i in 0..<N {
    let u = Double(i) / Double(N - 1)
    var p: ShrimpPose
    if u < 0.5 { p = ShrimpPose.lerp(hunch, mid, ease(u / 0.5)) }
    else { p = ShrimpPose.lerp(mid, tall, ease((u - 0.5) / 0.5)) }
    p.eye = u < 0.35 ? .dot : (u < 0.7 ? .wide : .closed)
    p.mouth = u < 0.3 ? .flat : (u < 0.7 ? .open : .smile)
    p.eyeOpen = 1
    seq.append((p, KipLook(), 0))
}
strip(seq, name: "kip-unshrimp")

// 2. Loops.
@MainActor func loop(_ state: ShrimpState, period: Double, frames: Int, look: KipLook = KipLook(), growth: Double = 0) -> [(ShrimpPose, KipLook, Double)] {
    (0..<frames).map { i in
        let t = 1.0 + period * Double(i) / Double(frames)
        var p = ShrimpMotion.pose(state, t: t, animated: true, growth: growth)
        p.eyeOpen = 1
        return (p, look, t)
    }
}
strip(loop(.celebrating, period: .pi / 3.6 * 2, frames: 24, look: KipLook(uncurl: 0.6, wearable: .crown)), name: "kip-celebrate")
strip(loop(.inviting, period: 2 * .pi / 3, frames: 24), name: "kip-wave")
strip(loop(.working, period: 2 * .pi / 0.8, frames: 40), name: "kip-work")
strip(loop(.exercise(.sideReach), period: 2 * .pi / 0.8, frames: 32), name: "kip-sidereach")

// 3. Wardrobe stills.
var still: [(ShrimpPose, KipLook, Double)] = []
let wears: [Wearable?] = [nil, .sweatband, .specs, .beanie, .flower, .crown]
for (i, w) in wears.enumerated() {
    let g = Double(i) / 5
    var p = ShrimpMotion.pose(.inviting, t: 0, animated: false, growth: g)
    p.armFront = -10; p.armBack = -20; p.armBend = -30; p.armLength = 1; p.shoulderShift = 0
    p.eye = .dot; p.mouth = .smile
    still.append((p, KipLook(uncurl: g, wearable: w), 0))
}
strip(still, name: "kip-wardrobe")
}
MainActor.assumeIsolated { run() }
enum DeskSceneRenderer { static func drawSparkles(_ c: GraphicsContext, around: CGPoint, progress: Double) {} }
