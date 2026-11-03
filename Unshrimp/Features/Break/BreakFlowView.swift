import SwiftUI

struct TimerRing: View {
    var progress: Double
    var label: String
    var lineWidth: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.exerciseMotionOverride) private var motionOverride
    private var reduceMotion: Bool { systemReduceMotion || motionOverride }

    var body: some View {
        ZStack {
            Circle().fill(Palette.paper)
            Circle().stroke(Palette.ivoryDeep, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Palette.coral, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: progress)
            Circle().strokeBorder(Palette.petrol, lineWidth: 2).padding(-lineWidth / 2 - 1)
            Text(label)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.petrol)
                .minimumScaleFactor(0.5)
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .animation(reduceMotion ? nil : .snappy, value: label)
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.exerciseMotionOverride) private var motionOverride
    private var reduceMotion: Bool { systemReduceMotion || motionOverride }

    let routine: Routine

    enum Stage: Equatable { case intro, moving, confirm, reward(BreakResult), notThisTime }

    @State private var stage: Stage = .intro
    @State private var session: ExerciseSession
    @State private var showEndDialog = false
    @State private var resumeAfterDialog = false
    @State private var analytics: BreakAnalytics

    init(routine: Routine, skipIntro: Bool = false, source: BreakSource = .app) {
        self.routine = routine
        _analytics = State(initialValue: BreakAnalytics(minutes: routine.minutes, source: source))
        let session = ExerciseSession(routine: routine)
        if skipIntro { session.start() }
        _session = State(initialValue: session)
        _stage = State(initialValue: skipIntro ? .moving : .intro)
    }

    private var move: Move { session.move }

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
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: stage)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            guard stage == .moving else { return }
            session.tick()
            if session.isComplete { stage = .confirm }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: session.index)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.pause() }
        }
        .onAppear {
            if session.hasBegun { analytics.start() }
        }
        .onDisappear {
            session.pause()
            analytics.abandon(reason: "dismissed")
        }
        .alert("End this break?", isPresented: $showEndDialog) {
            Button("I moved enough, finish") { withAnimation { stage = .confirm } }
            Button("End without saving", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {
                if resumeAfterDialog { session.resume() }
                resumeAfterDialog = false
            }
        } message: {
            Text("Your session is paused while you decide.")
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
                        ForEach(Array(routine.moves.enumerated()), id: \.offset) { i, m in
                            HStack(spacing: Space.m) {
                                Text("\(i + 1)")
                                    .font(.uCaption)
                                    .foregroundStyle(Palette.petrol)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Palette.butterSoft))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.name).font(.uCallout.weight(.semibold)).foregroundStyle(Palette.petrol)
                                    if routine.moves.prefix(i).contains(where: { $0.id == m.id }) {
                                        Text("Another round").font(.uCaption).foregroundStyle(Palette.petrolSoft)
                                    }
                                }
                                Spacer()
                                Text("\(routine.seconds(for: i))s").font(.uCaption).foregroundStyle(Palette.petrolSoft).monospacedDigit()
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
                session.start()
                analytics.start()
                stage = .moving
            }
            .buttonStyle(.chunky)
            .padding(.horizontal, Space.page)
            .padding(.bottom, Space.s)
        }
    }

    // MARK: Moving

    private var moving: some View {
        GeometryReader { geometry in
            let demonstrationSize = max(180, min(geometry.size.width - Space.page * 2, geometry.size.height * 0.42))
            VStack(spacing: Space.s) {
                HStack(spacing: Space.m) {
                    CircleIconButton(systemName: "xmark", label: "End break") {
                        resumeAfterDialog = session.isRunning
                        session.pause()
                        showEndDialog = true
                    }
                    VStack(spacing: 6) {
                        Text("Move \(session.index + 1) of \(routine.moves.count)")
                            .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                        HStack(spacing: 4) {
                            ForEach(0..<routine.moves.count, id: \.self) { i in
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Palette.ivoryDeep)
                                        Capsule().fill(Palette.coral)
                                            .frame(width: geo.size.width * (i < session.index ? 1 : (i == session.index ? session.progress : 0)))
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    Color.clear.frame(width: 44, height: 1).accessibilityHidden(true)
                }
                .padding(.horizontal, Space.page)
                .padding(.top, Space.s)

                TrainingBuddy(comment: move.companionComment(occurrence: session.occurrence),
                              showsComment: session.showsComment, showsBubble: !dynamicTypeSize.isAccessibilitySize)
                    .padding(.horizontal, Space.page)

                ScrollView {
                    VStack(spacing: Space.s) {
                        ExerciseDemonstration(move: move, isRunning: session.isRunning,
                                              isPreparing: session.isPreparing, mirrored: session.isMirrored,
                                              revision: session.playbackRevision, isObscured: showEndDialog)
                            .frame(width: demonstrationSize)
                            .id(session.index)
                        VStack(spacing: Space.xs) {
                            Text(move.name)
                                .font(.uTitle).foregroundStyle(Palette.petrol)
                                .accessibilityAddTraits(.isHeader)
                            Text(move.cue)
                                .font(.uBody).foregroundStyle(Palette.petrolSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.page)
                        if dynamicTypeSize.isAccessibilitySize {
                            Text(move.companionComment(occurrence: session.occurrence))
                                .font(.uCallout).foregroundStyle(Palette.petrolSoft)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, Space.page)
                                .opacity(session.showsComment ? 1 : 0)
                                .accessibilityHidden(!session.showsComment)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Space.s)
                }
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: Space.xs) {
                    Text(session.isRunning ? session.phaseTitle : String(localized: "Paused"))
                        .font(.uCallout.weight(.semibold)).foregroundStyle(Palette.petrol)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("exercise-phase")
                    HStack(spacing: Space.l) {
                        Button { session.toggle() } label: {
                            Image(systemName: session.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .heavy))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.chunky(.secondary, compact: true))
                        .accessibilityLabel(session.isRunning ? Text("Pause") : Text("Resume"))

                        TimerRing(progress: session.progress, label: "\(session.secondsLeft)")
                            .frame(width: 88, height: 88)
                            .accessibilityIdentifier("exercise-countdown")

                        Button { advance() } label: {
                            Image(systemName: session.index == routine.moves.count - 1 ? "checkmark" : "forward.fill")
                                .font(.system(size: 22, weight: .heavy))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.chunky(.primary, compact: true))
                        .accessibilityLabel(session.index == routine.moves.count - 1 ? Text("Finish") : Text("Next move"))
                    }
                }
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.s)
            }
        }
    }

    private func advance() {
        session.advance()
        if session.isComplete { stage = .confirm }
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
                    guard !analytics.hasEnded else { return }
                    let result = model.recordBreak(minutes: routine.minutes, focus: routine.focus)
                    analytics.complete(routineReachedEnd: session.isComplete,
                                       isFirstBreak: model.data.breaks.count == 1, breaksToday: result.breaksToday)
                    if result.reachedGoalNow {
                        Analytics.capture("daily_goal_reached", properties: ["daily_goal": result.goal])
                    }
                    stage = .reward(result)
                }
                .buttonStyle(.chunky)
                Button("Not this time") {
                    analytics.abandon(reason: "not_confirmed")
                    stage = .notThisTime
                }
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
