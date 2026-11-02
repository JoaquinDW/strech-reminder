import SwiftUI

/// Wall-clock based countdown that survives pauses and view refreshes.
struct MoveTimer {
    var duration: Double
    private(set) var hasStarted = false
    private var banked: Double = 0
    private var runningSince: Date?
    private var now = Date()

    init(duration: Double) { self.duration = duration }

    var isRunning: Bool { runningSince != nil }
    var elapsed: Double { min(duration, banked + (runningSince.map { now.timeIntervalSince($0) } ?? 0)) }
    var progress: Double { duration > 0 ? elapsed / duration : 1 }
    var secondsLeft: Int { Int(ceil(max(0, duration - elapsed))) }
    var isComplete: Bool { elapsed >= duration }

    mutating func start() {
        hasStarted = true
        now = Date()
        runningSince = now
    }

    mutating func pause() {
        now = Date()
        banked = elapsed
        runningSince = nil
    }

    mutating func toggle() { isRunning ? pause() : start() }

    mutating func tick() {
        now = Date()
        if isRunning && isComplete { banked = duration; runningSince = nil }
    }

    mutating func restart(duration: Double) {
        self = MoveTimer(duration: duration)
        start()
    }
}

struct TimerRing: View {
    var progress: Double
    var label: String
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().fill(Palette.paper)
            Circle().stroke(Palette.ivoryDeep, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Palette.coral, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
            Circle().strokeBorder(Palette.petrol, lineWidth: 2).padding(-lineWidth / 2 - 1)
            Text(label)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.petrol)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: label)
        }
        .padding(lineWidth / 2 + 1)
        .accessibilityElement()
        .accessibilityLabel(Text("\(label) seconds left"))
    }
}

/// The guided break: overview → moves with timer → user-confirmed completion → reward.
struct BreakFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let routine: Routine

    enum Stage: Equatable { case intro, moving, confirm, reward(BreakResult), notThisTime }

    @State private var stage: Stage = .intro
    @State private var index = 0
    @State private var timer: MoveTimer
    @State private var showEndDialog = false
    @State private var advanceTick = 0

    init(routine: Routine) {
        self.routine = routine
        _timer = State(initialValue: MoveTimer(duration: Double(routine.secondsPerMove)))
    }

    private var move: Move { routine.moves[min(index, routine.moves.count - 1)] }

    var body: some View {
        ZStack {
            Palette.ivory.ignoresSafeArea()
            Group {
                switch stage {
                case .intro: intro
                case .moving: moving
                case .confirm: confirm
                case .reward(let result): RewardView(result: result) { dismiss() }
                case .notThisTime: notThisTime
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stage)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            guard stage == .moving else { return }
            timer.tick()
            if timer.isComplete { advance() }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: advanceTick)
        .confirmationDialog("End this break?", isPresented: $showEndDialog, titleVisibility: .visible) {
            Button("I moved enough, finish") { withAnimation { stage = .confirm } }
            Button("End without saving", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
                Spacer()
                DemoBadge()
            }
            .padding(.horizontal, Space.page)
            .padding(.top, Space.s)

            ScrollView {
                VStack(spacing: Space.l) {
                    ShrimpStage(state: .inviting, prop: .mat)
                        .frame(height: 210)
                    VStack(spacing: Space.xs) {
                        Text("\(routine.minutes)-minute break").font(.uTitle).foregroundStyle(Palette.petrol)
                        Text("Focus: \(FocusArea.summary(routine.focus))").font(.uBody).foregroundStyle(Palette.petrolSoft)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(routine.moves.enumerated()), id: \.element.id) { i, m in
                            HStack(spacing: Space.m) {
                                Text("\(i + 1)")
                                    .font(.uCaption)
                                    .foregroundStyle(Palette.petrol)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Palette.butterSoft))
                                Text(m.name).font(.uCallout.weight(.semibold)).foregroundStyle(Palette.petrol)
                                Spacer()
                                Text("\(routine.secondsPerMove)s").font(.uCaption).foregroundStyle(Palette.petrolSoft).monospacedDigit()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .card()
                    Text(DemoLibrary.disclaimer)
                        .font(.uCaption.weight(.medium))
                        .foregroundStyle(Palette.petrolSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.l)
            }
            Button("Let's move") {
                index = 0
                timer.restart(duration: Double(routine.secondsPerMove))
                stage = .moving
            }
            .buttonStyle(.chunky)
            .padding(.horizontal, Space.page)
            .padding(.bottom, Space.s)
        }
    }

    // MARK: Moving

    private var moving: some View {
        VStack(spacing: Space.m) {
            HStack(spacing: Space.m) {
                CircleIconButton(systemName: "xmark", label: "End break") {
                    timer.pause()
                    showEndDialog = true
                }
                VStack(spacing: 6) {
                    Text("Move \(index + 1) of \(routine.moves.count)")
                        .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                    HStack(spacing: 4) {
                        ForEach(0..<routine.moves.count, id: \.self) { i in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Palette.ivoryDeep)
                                    Capsule().fill(Palette.coral)
                                        .frame(width: geo.size.width * (i < index ? 1 : (i == index ? timer.progress : 0)))
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
                DemoBadge()
            }
            .padding(.horizontal, Space.page)
            .padding(.top, Space.s)

            ShrimpStage(state: timer.isRunning ? .exercise(move.pose) : .resting, prop: .mat)
                .frame(maxHeight: .infinity)
                .layoutPriority(-1)
                .id(move.id)
                .transition(.opacity)

            VStack(spacing: Space.s) {
                Text(move.name)
                    .font(.uTitle)
                    .foregroundStyle(Palette.petrol)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(move.cue)
                    .font(.uBody)
                    .foregroundStyle(Palette.petrolSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.page)
            .id("text-\(move.id)")

            HStack(spacing: Space.l) {
                Button {
                    timer.toggle()
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.chunky(.secondary, compact: true))
                .accessibilityLabel(timer.isRunning ? Text("Pause") : Text("Resume"))

                TimerRing(progress: timer.progress, label: "\(timer.secondsLeft)")
                    .frame(width: 96, height: 96)

                Button {
                    advance()
                } label: {
                    Image(systemName: index == routine.moves.count - 1 ? "checkmark" : "forward.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.chunky(.primary, compact: true))
                .accessibilityLabel(index == routine.moves.count - 1 ? Text("Finish") : Text("Next move"))
            }
            if !timer.isRunning {
                Text("Paused. Take your time.")
                    .font(.uCaption)
                    .foregroundStyle(Palette.petrolSoft)
            }
            Spacer(minLength: Space.s)
        }
    }

    private func advance() {
        advanceTick += 1
        if index >= routine.moves.count - 1 {
            withAnimation { stage = .confirm }
        } else {
            withAnimation(Motion.gentle) { index += 1 }
            timer.restart(duration: Double(routine.secondsPerMove))
        }
    }

    // MARK: Confirm

    private var confirm: some View {
        VStack(spacing: Space.l) {
            Spacer(minLength: 0)
            ShrimpStage(state: .stretching, backdrop: Palette.butterSoft)
                .frame(maxHeight: 260)
            VStack(spacing: Space.s) {
                Text("Did you move with \(Brand.mascotName)?")
                    .font(.uTitle).foregroundStyle(Palette.petrol)
                Text("You decide what counts. Partial breaks are welcome.")
                    .font(.uBody).foregroundStyle(Palette.petrolSoft)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.page)
            Spacer(minLength: 0)
            VStack(spacing: Space.xs) {
                Button("Yes, I moved") {
                    let result = model.recordBreak(minutes: routine.minutes, focus: routine.focus)
                    stage = .reward(result)
                }
                .buttonStyle(.chunky)
                Button("Not this time") { stage = .notThisTime }
                    .buttonStyle(.chunky(.quiet))
            }
            .padding(.horizontal, Space.page)
            .padding(.bottom, Space.s)
        }
    }

    private var notThisTime: some View {
        VStack(spacing: Space.l) {
            Spacer(minLength: 0)
            ShrimpStage(state: .resting)
                .frame(maxHeight: 260)
            VStack(spacing: Space.s) {
                Text("All good").font(.uTitle).foregroundStyle(Palette.petrol)
                Text("\(Brand.mascotName) will check in a bit later. Nothing lost.")
                    .font(.uBody).foregroundStyle(Palette.petrolSoft)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.page)
            Spacer(minLength: 0)
            Button("Back to work") { dismiss() }
                .buttonStyle(.chunky)
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.s)
        }
    }
}
