import SwiftUI
import AVFoundation

@MainActor
final class ExercisePlayback: ObservableObject {
    /// The source clips read as sluggish at 1x; 1.5x keeps the form while matching a desk-break pace.
    static let rate: Float = 1.5
    let player = AVQueuePlayer()
    @Published var hasFrame = false
    @Published var failed = false
    @Published var isPreviewing = false
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?
    private var loading: Task<Void, Never>?
    private var preview: Task<Void, Never>?
    private var wantsPlayback = false
    private var revision = 0
    private var duration = 8.04

    init(media: ExerciseMedia?) {
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.defaultRate = Self.rate
        guard let url = media?.url else { failed = true; return }
        statusObservation = player.observe(\.status, options: [.new]) { [weak self] player, _ in
            let didFail = player.status == .failed
            Task { @MainActor [weak self] in
                if didFail { self?.failed = true }
            }
        }
        loading = Task { [weak self] in
            let asset = AVURLAsset(url: url)
            do {
                let time = try await asset.load(.duration)
                guard !Task.isCancelled, let self else { return }
                self.duration = time.seconds.isFinite ? time.seconds : 8.04
                let item = AVPlayerItem(asset: asset)
                self.looper = AVPlayerLooper(player: self.player, templateItem: item)
                if self.wantsPlayback { self.player.play() }
            } catch {
                guard !Task.isCancelled else { return }
                self?.failed = true
            }
        }
    }

    func setPlaying(_ playing: Bool) {
        revision += 1
        preview?.cancel()
        preview = nil
        isPreviewing = false
        wantsPlayback = playing
        if playing { player.play() } else { player.pause() }
    }

    func restart(playing: Bool, previewOnce: Bool = false) {
        setPlaying(false)
        revision += 1
        let token = revision
        wantsPlayback = playing
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self, finished, token == self.revision else { return }
                guard playing || previewOnce else { return }
                self.player.play()
                if previewOnce && !playing {
                    self.isPreviewing = true
                    self.preview = Task { [weak self] in
                        guard let seconds = self.map({ $0.duration / Double(Self.rate) }) else { return }
                        do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                        guard let self, token == self.revision else { return }
                        self.player.pause()
                        self.isPreviewing = false
                    }
                }
            }
        }
    }

    deinit {
        loading?.cancel()
        preview?.cancel()
        player.pause()
        looper?.disableLooping()
    }
}

private final class ExercisePlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// AVPlayerLayer avoids a second set of transport controls over the instructor.
private struct ExercisePlayerSurface: UIViewRepresentable {
    @ObservedObject var playback: ExercisePlayback

    final class Coordinator {
        var observation: NSKeyValueObservation?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ExercisePlayerView {
        let view = ExercisePlayerView()
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = playback.player
        view.isAccessibilityElement = false
        context.coordinator.observation = view.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak playback] layer, _ in
            guard layer.isReadyForDisplay else { return }
            Task { @MainActor [weak playback] in playback?.hasFrame = true }
        }
        return view
    }

    func updateUIView(_ view: ExercisePlayerView, context: Context) {
        if view.playerLayer.player !== playback.player { view.playerLayer.player = playback.player }
    }

    static func dismantleUIView(_ view: ExercisePlayerView, coordinator: Coordinator) {
        coordinator.observation?.invalidate()
        view.playerLayer.player = nil
    }
}

struct ExerciseDemonstration: View {
    let move: Move
    var isRunning: Bool
    var isPreparing = false
    var mirrored = false
    var revision = 0
    var showsReplay = true
    var isObscured = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.exerciseMotionOverride) private var motionOverride
    private var reduceMotion: Bool { systemReduceMotion || motionOverride }
    @StateObject private var playback: ExercisePlayback
    @State private var selectedPose = 1
    @State private var visible = false

    init(move: Move, isRunning: Bool, isPreparing: Bool = false, mirrored: Bool = false, revision: Int = 0, showsReplay: Bool = true, isObscured: Bool = false) {
        self.move = move
        self.isRunning = isRunning
        self.isPreparing = isPreparing
        self.mirrored = mirrored
        self.revision = revision
        self.showsReplay = showsReplay
        self.isObscured = isObscured
        _playback = StateObject(wrappedValue: ExercisePlayback(media: move.media))
    }

    /// Playing through "Get ready" shows the movement right away instead of a still poster for the countdown.
    private var shouldPlay: Bool { visible && scenePhase == .active && isRunning && !reduceMotion && !isObscured }
    private var pose: String { isPreparing ? "start" : ["start", "mid", "end"][selectedPose] }
    private var status: String {
        if reduceMotion { return String(localized: "Still movement guide") }
        if playback.failed { return String(localized: "Follow the steps below") }
        if !playback.hasFrame { return String(localized: "Loading demonstration") }
        return shouldPlay || playback.isPreviewing ? String(localized: "Playing") : String(localized: "Paused")
    }

    var body: some View {
        VStack(spacing: Space.xs) {
            ZStack {
                if let media = move.media {
                    Image(media.poster(reduceMotion ? pose : "start"))
                        .resizable().scaledToFit()
                    if !reduceMotion {
                        ExercisePlayerSurface(playback: playback)
                            .opacity(playback.hasFrame && !playback.failed ? 1 : 0)
                    }
                } else {
                    VStack(spacing: Space.m) {
                        Image(systemName: "figure.cooldown").font(.largeTitle)
                        Text("Follow the steps below").font(.uCallout)
                    }
                    .foregroundStyle(Palette.petrolSoft)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel(Text("Demonstration: \(move.name)"))
            .accessibilityValue(Text(status))
            .accessibilityIdentifier("exercise-demonstration")

            if reduceMotion, move.media != nil {
                HStack(spacing: Space.s) {
                    poseButton(0, title: String(localized: "Start pose"))
                    poseButton(1, title: String(localized: "Movement"))
                    poseButton(2, title: String(localized: "Return"))
                }
            } else if showsReplay && !playback.failed {
                Button {
                    playback.restart(playing: shouldPlay, previewOnce: true)
                } label: {
                    Label("Replay demo", systemImage: "arrow.counterclockwise")
                        .font(.uCaption.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .foregroundStyle(Palette.petrolSoft)
                .disabled(!playback.hasFrame)
                .accessibilityIdentifier("replay-demonstration")
            }
            if playback.failed {
                Text("Follow the steps below").font(.uCaption).foregroundStyle(Palette.petrolSoft)
            }
        }
        .onAppear { visible = true; playback.setPlaying(shouldPlay) }
        .onDisappear { visible = false; playback.setPlaying(false) }
        .onScrollVisibilityChange(threshold: 0.1) { isVisible in
            visible = isVisible
            playback.setPlaying(shouldPlay)
        }
        .onChange(of: shouldPlay) { _, playing in playback.setPlaying(playing) }
        .onChange(of: revision) { _, _ in playback.restart(playing: shouldPlay) }
        .onChange(of: isObscured) { _, obscured in
            if obscured { playback.setPlaying(false) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { playback.setPlaying(false) }
        }
    }

    private func poseButton(_ index: Int, title: String) -> some View {
        Button { selectedPose = index } label: {
            Text(title)
                .font(.uCaption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Palette.petrol)
                .background(selectedPose == index ? Palette.mintSoft : Palette.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(selectedPose == index ? Palette.petrol : Palette.line, lineWidth: 1.5))
        }
        .accessibilityAddTraits(selectedPose == index ? .isSelected : [])
    }
}

/// The buddy keeps a reserved place even when its occasional comment is hidden.
struct TrainingBuddy: View {
    let comment: String
    var showsComment: Bool
    var showsBubble = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.exerciseMotionOverride) private var motionOverride
    private var reduceMotion: Bool { systemReduceMotion || motionOverride }

    var body: some View {
        HStack(spacing: Space.s) {
            Spacer(minLength: 0)
            if showsBubble {
            Text(comment)
                .font(.uCallout.weight(.medium))
                .foregroundStyle(Palette.petrol)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.tile))
                .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(Palette.petrol, lineWidth: 2))
                .opacity(showsComment ? 1 : 0)
                .accessibilityHidden(!showsComment)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showsComment)
            }
            ShrimpView(state: showsComment ? .inviting : .resting)
                .frame(width: 76, height: 76)
                .accessibilityLabel(Text("\(Brand.mascotName) is here with you"))
        }
        .frame(minHeight: 76)
        .accessibilityIdentifier("training-buddy")
    }
}
