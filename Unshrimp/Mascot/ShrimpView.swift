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
    static let duration: Double = 0.6

    func pose(for state: ShrimpState, t: Double, animated: Bool) -> ShrimpPose {
        let target = ShrimpMotion.pose(state, t: t, animated: animated)
        guard animated, let previous, previous != state else { return target }
        let p = (t - changedAt) / Self.duration
        if p >= 1 { return target }
        let from = ShrimpMotion.pose(previous, t: t, animated: animated)
        return ShrimpPose.lerp(from, target, Geo.smoothstep(p))
    }

    func didChange(from old: ShrimpState) {
        previous = old
        changedAt = Date().timeIntervalSinceReferenceDate
    }
}

/// Reusable mascot component.
struct ShrimpView: View {
    var state: ShrimpState
    @State private var blender = PoseBlender()

    var body: some View {
        LiveCanvas { ctx, size, t, animated in
            let pose = blender.pose(for: state, t: t, animated: animated)
            ShrimpRenderer.draw(pose, in: ctx, rect: CGRect(origin: .zero, size: size))
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: state) { old, _ in blender.didChange(from: old) }
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
