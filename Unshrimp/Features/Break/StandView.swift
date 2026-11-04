import SwiftUI

/// One quick standing move with Kip: a short countdown, then back to work. Opened from a stand
/// reminder's "Show me" or from Home.
struct StandView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let move: StandMove
    var source: StandSource = .app

    @State private var elapsed: Double = 0
    @State private var running = true
    @State private var earned: Int?
    @State private var saving = false

    private var secondsLeft: Int { max(0, move.seconds - Int(elapsed)) }
    private var progress: Double { min(1, elapsed / Double(move.seconds)) }

    var body: some View {
        VStack(spacing: Space.l) {
            HStack {
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
                Spacer()
            }
            .padding(.top, Space.s)

            if let earned {
                done(earned)
            } else {
                moving
            }
        }
        .padding(.horizontal, Space.page)
        .padding(.bottom, Space.s)
        .background(Palette.ivory.ignoresSafeArea())
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            guard running, earned == nil, elapsed < Double(move.seconds) else { return }
            elapsed += 0.1
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { running = false }
        }
        .sensoryFeedback(.success, trigger: earned != nil)
        .onAppear { Analytics.capture("stand_screen_opened", properties: ["move_id": move.id, "source": source.rawValue]) }
    }

    private var moving: some View {
        VStack(spacing: Space.l) {
            ShrimpStage(state: .exercise(move.pose), backdrop: Palette.mintSoft)
                .frame(maxHeight: 240)
            VStack(spacing: Space.xs) {
                Text("Quick stand").font(.uCaption).textCase(.uppercase).tracking(1).foregroundStyle(Palette.petrolSoft)
                Text(move.name).font(.uTitle).foregroundStyle(Palette.petrol).accessibilityAddTraits(.isHeader)
                Text(move.cue).font(.uBody).foregroundStyle(Palette.petrolSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            HStack(spacing: Space.l) {
                Button { running.toggle() } label: {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.chunky(.secondary, compact: true))
                .accessibilityLabel(running ? Text("Pause") : Text("Resume"))
                TimerRing(progress: progress, label: "\(secondsLeft)")
                    .frame(width: 88, height: 88)
            }
            VStack(spacing: Space.xs) {
                Button(secondsLeft == 0 ? LocalizedStringKey("Done, I stood up") : LocalizedStringKey("Done already")) { finish() }
                    .buttonStyle(.chunky)
                    .disabled(saving)
                Button("Not now") {
                    Task {
                        await model.skipStand(moveID: move.id)
                        dismiss()
                    }
                }
                .buttonStyle(.chunky(.quiet))
            }
        }
    }

    private func done(_ earned: Int) -> some View {
        VStack(spacing: Space.l) {
            ZStack {
                ShrimpStage(state: .celebrating, backdrop: Palette.butterSoft)
                    .frame(maxHeight: 240)
                ConfettiBurst(trigger: 1)
            }
            VStack(spacing: Space.s) {
                Text(earned > 0 ? String(localized: "+\(earned) energy") : String(localized: "Nice one"))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.coralDeep)
                Text(standsLine)
                    .font(.uBody).foregroundStyle(Palette.petrolSoft)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            Button("Back to work") { dismiss() }.buttonStyle(.chunky)
        }
    }

    private var standsLine: String {
        let n = model.standsToday()
        return n == 1
            ? String(localized: "First quick stand today. My legs thank you.")
            : String(localized: "\(n) quick stands today. Less sitting, more shrimp.")
    }

    private func finish() {
        saving = true
        Task {
            let energy = await model.recordStand(moveID: move.id, source: source)
            withAnimation(Motion.snappy) { earned = energy }
            saving = false
        }
    }
}
