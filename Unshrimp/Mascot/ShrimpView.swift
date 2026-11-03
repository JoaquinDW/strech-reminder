import SwiftUI

/// A Canvas driven by a TimelineView that pauses when Reduce Motion is on,
/// when the view scrolls offscreen, or when the app is in the background.
struct LiveCanvas: View {
    /// (context, size, time in seconds, animated)
    var renderer: (GraphicsContext, CGSize, Double, Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = true

    var body: some View {
        let paused = reduceMotion || !isVisible || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
            Canvas { context, size in
                renderer(context, size, timeline.date.timeIntervalSinceReferenceDate, !reduceMotion)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onScrollVisibilityChange(threshold: 0.02) { isVisible = $0 }
    }
}

/// Tracks state changes so the rig can blend between poses instead of snapping.
@Observable
final class PoseBlender {
    var previous: ShrimpState?
    var changedAt: Double = 0
    var pokedAt: Double = -10
    static let duration: Double = 0.75
    /// How far behind the head the antennae trail, for follow-through.
    private static let lag: Double = 0.14

    func pose(for state: ShrimpState, t: Double, animated: Bool, growth: Double = 0) -> ShrimpPose {
        var p = blended(state, t: t, animated: animated, growth: growth)
        guard animated else { return p }
        // Follow-through: antennae swing against the head's and body's motion.
        let behind = blended(state, t: t - Self.lag, animated: true, growth: growth)
        let headSwing: Double = (p.headTilt - behind.headTilt) * 1.4
        let leanSwing: Double = (p.lean - behind.lean) * 1.2
        let hopSwing: Double = (p.bounce - behind.bounce) * 1.6
        p.antennaSway += headSwing + leanSwing - hopSwing
        applyPoke(&p, t: t)
        return p
    }

    private func blended(_ state: ShrimpState, t: Double, animated: Bool, growth: Double) -> ShrimpPose {
        let target = ShrimpMotion.pose(state, t: t, animated: animated, growth: growth)
        guard animated, let previous, previous != state else { return target }
        let p = (t - changedAt) / Self.duration
        if p >= 1 { return target }
        if p <= 0 { return ShrimpMotion.pose(previous, t: t, animated: animated, growth: growth) }
        let from = ShrimpMotion.pose(previous, t: t, animated: animated, growth: growth)
        var out = ShrimpPose.lerp(from, target, Geo.backOut(p))
        // Anticipation: a small dip and squint before the new pose lands.
        let dip = sin(min(p / 0.35, 1) * .pi)
        out.bounce -= dip * 3
        out.eyeOpen = min(out.eyeOpen, 1 - dip * 0.6)
        return out
    }

    /// A happy wiggle when the user taps Kip.
    private func applyPoke(_ p: inout ShrimpPose, t: Double) {
        let e = t - pokedAt
        guard e >= 0, e < 0.9 else { return }
        let decay = exp(-4 * e)
        p.bounce += abs(sin(e * 14)) * 7 * decay
        p.lean += sin(e * 18) * 5 * decay
        p.antennaPerk = 1
        p.eye = .happy
        p.mouth = .open
        p.blush = 1
    }

    func didChange(from old: ShrimpState) {
        previous = old
        changedAt = Date().timeIntervalSinceReferenceDate
    }

    func poke() {
        pokedAt = Date().timeIntervalSinceReferenceDate
    }
}

extension View {
    /// Lets the user tap the mascot for a little reaction.
    func pokeable(_ blender: PoseBlender) -> some View {
        contentShape(Rectangle())
            .onTapGesture { blender.poke() }
            .sensoryFeedback(.impact(weight: .light), trigger: blender.pokedAt)
    }
}

private struct KipLookKey: EnvironmentKey {
    static let defaultValue = KipLook()
}

extension EnvironmentValues {
    /// Kip's growth and outfit, set once at the root so every illustration agrees.
    var kipLook: KipLook {
        get { self[KipLookKey.self] }
        set { self[KipLookKey.self] = newValue }
    }
}

/// Reusable mascot component.
struct ShrimpView: View {
    var state: ShrimpState
    @Environment(\.kipLook) private var look
    @State private var blender = PoseBlender()

    var body: some View {
        LiveCanvas { ctx, size, t, animated in
            let pose = blender.pose(for: state, t: t, animated: animated, growth: look.uncurl)
            ShrimpRenderer.draw(pose, in: ctx, rect: CGRect(origin: .zero, size: size), look: look, t: t, animated: animated)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: state) { old, _ in blender.didChange(from: old) }
        .pokeable(blender)
        .accessibilityElement()
        .accessibilityLabel(Text(state.accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }
}

#Preview("States") {
    ScrollView {
        VStack {
            ForEach([ShrimpState.working, .inviting, .stretching, .celebrating, .resting], id: \.self) { s in
                ShrimpView(state: s).frame(height: 200)
            }
        }
    }
    .background(Palette.ivory)
}
