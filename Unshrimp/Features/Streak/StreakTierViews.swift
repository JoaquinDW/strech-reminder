import AVFoundation
import SwiftUI

extension StreakTier {
    var color: Color {
        switch self {
        case .ripple: Palette.mint
        case .wave: Palette.coral
        case .tide: Palette.coralDeep
        case .swell, .tsunami: Palette.butter
        }
    }

    var softColor: Color {
        switch self {
        case .ripple: Palette.mintSoft
        case .wave, .tide: Palette.coralSoft
        case .swell, .tsunami: Palette.butterSoft
        }
    }

    /// How tall the wave stands in its square, from 0 to 1.
    fileprivate var waveHeight: CGFloat {
        switch self {
        case .ripple: 0.55
        case .wave: 0.66
        case .tide: 0.78
        case .swell: 0.9
        case .tsunami: 1
        }
    }
}

/// A breaking wave that grows with `height`, so a new level can animate into the next.
private struct WaveShape: Shape {
    var height: CGFloat

    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, s = rect.height
        let base = s * 0.94, h = s * 0.88 * height
        func p(_ x: CGFloat, _ up: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + base - up * h) }

        var path = Path()
        path.move(to: p(0.04, 0))
        path.addLine(to: p(0.96, 0))
        // Up the back of the wave to the crest
        path.addCurve(to: p(0.5, 1), control1: p(1.0, 0.55), control2: p(0.82, 1.02))
        // Over the top and down to the tip of the curl
        path.addCurve(to: p(0.17, 0.62), control1: p(0.32, 0.98), control2: p(0.17, 0.86))
        // Back under the curl
        path.addCurve(to: p(0.44, 0.4), control1: p(0.26, 0.78), control2: p(0.5, 0.72))
        // Along the trough to the front edge
        path.addCurve(to: p(0.04, 0.26), control1: p(0.38, 0.24), control2: p(0.2, 0.18))
        path.closeSubpath()
        return path
    }
}

/// The streak's mark: a wave that gets bigger at every level. Grey until today has a break.
struct StreakMark: View {
    var tier: StreakTier
    var lit = true
    var size: CGFloat

    var body: some View {
        ZStack {
            WaveShape(height: tier.waveHeight).fill(lit ? tier.color : Palette.ivoryDeep)
            WaveShape(height: tier.waveHeight)
                .stroke(lit ? Palette.petrol : Palette.petrolSoft,
                        style: StrokeStyle(lineWidth: max(1.8, size * 0.07), lineJoin: .round))
            if lit && tier >= .swell { foam }
            if lit && tier == .tsunami { sparkles }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var foam: some View {
        Canvas { ctx, canvas in
            let s = canvas.width
            let crest = 0.94 - 0.88 * tier.waveHeight
            for (x, y, r) in [(0.46, 0.14, 0.05), (0.6, 0.16, 0.04), (0.35, 0.21, 0.04)] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.fill(Geo.circle(CGPoint(x: s * x, y: canvas.height * (crest + y)), s * r), with: .color(Palette.paper))
            }
        }
    }

    private var sparkles: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * 0.26, weight: .heavy))
            .foregroundStyle(Palette.coralDeep)
            .offset(x: size * 0.42, y: -size * 0.36)
    }
}

/// Every level in a row, with how far the next one is.
struct StreakTierStrip: View {
    var streak: Int

    var body: some View {
        let current = StreakTier(streak: streak)
        VStack(spacing: Space.m) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(StreakTier.allCases, id: \.self) { tier in
                    VStack(spacing: 4) {
                        StreakMark(tier: tier, lit: tier <= current, size: 44)
                            .opacity(tier <= current ? 1 : 0.5)
                        Text(tier.title)
                            .font(.uMicro)
                            .foregroundStyle(tier == current ? Palette.petrol : Palette.petrolSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(progressLine(current))
                .font(.uCaption.weight(.medium))
                .foregroundStyle(Palette.petrolSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(current.title))
        .accessibilityValue(Text(progressLine(current)))
    }

    private func progressLine(_ current: StreakTier) -> String {
        guard let next = current.next else { return String(localized: "The biggest wave there is.") }
        let left = next.minDays - streak
        return left == 1
            ? String(localized: "One more day to \(next.title).")
            : String(localized: "\(left) more days to \(next.title).")
    }
}

/// A fixed-size 4:5 card of the streak, for sharing as an image.
struct StreakShareCard: View {
    static let size = CGSize(width: 360, height: 450)

    let streak: Int
    let look: KipLook

    @MainActor
    static func render(streak: Int, look: KipLook) -> Image? {
        let renderer = ImageRenderer(content: StreakShareCard(streak: streak, look: look))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }

    var body: some View {
        let tier = StreakTier(streak: streak)
        VStack(spacing: 0) {
            HStack {
                Text(Brand.appName)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.coralDeep)
                Spacer()
                Text(tier.title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.petrol)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Palette.paper))
                    .overlay(Capsule().strokeBorder(Palette.petrol, lineWidth: 2))
            }

            kip.frame(width: 316, height: 214)

            HStack(spacing: 10) {
                StreakMark(tier: tier, size: 58)
                Text("\(streak)")
                    .font(.system(size: 84, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.petrol)
                    .monospacedDigit()
            }
            Text(StreakCopy.daysInARow(streak))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.petrol)
                .padding(.top, -8)

            Spacer(minLength: 0)

            Text("— \(Brand.mascotName), desk shrimp")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.petrolSoft)
        }
        .padding(22)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(tier.softColor)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 3))
        .environment(\.dynamicTypeSize, .large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(streak) \(StreakCopy.daysInARow(streak))"))
    }

    /// A still Kip, dressed as in the app. Canvas without a timeline so ImageRenderer captures it.
    private var kip: some View {
        Canvas { ctx, size in
            let pose = ShrimpMotion.pose(.celebrating, t: 0, animated: false, growth: look.uncurl)
            var still = look
            still.revealAt = nil
            ShrimpRenderer.draw(pose, in: ctx, rect: CGRect(origin: .zero, size: size), look: still)
        }
    }
}

/// A short rising chime for milestones. Mixes with whatever is playing and obeys the silent switch.
@MainActor
enum StreakChime {
    private static var player: AVAudioPlayer?

    static func play() {
        guard let url = Bundle.main.url(forResource: "streak-chime", withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
