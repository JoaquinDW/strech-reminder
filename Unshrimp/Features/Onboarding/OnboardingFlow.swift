import SwiftUI

/// Eight short steps, one purpose each. Answers live in `draft` so going back keeps them.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var forward = true
    @State private var draft = Preferences()
    @State private var loadedDraft = false

    static let stepCount = 8

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                page
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxHeight: .infinity)
            .clipped()
        }
        .background(Palette.ivory.ignoresSafeArea())
        .onAppear {
            guard !loadedDraft else { return }
            draft = model.prefs
            loadedDraft = true
        }
    }

    private var topBar: some View {
        HStack(spacing: Space.m) {
            CircleIconButton(systemName: "chevron.left", label: "Back") { go(to: step - 1) }
                .opacity(step > 0 ? 1 : 0)
                .disabled(step == 0)
            HStack(spacing: 5) {
                ForEach(0..<Self.stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Palette.coral : Palette.ivoryDeep)
                        .frame(width: i == step ? 22 : 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(Motion.snappy, value: step)
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(step + 1) of \(Self.stepCount)"))
            Button("Skip") { go(to: Self.stepCount - 1) }
                .font(.uCallout.weight(.bold))
                .foregroundStyle(Palette.petrolSoft)
                .frame(minWidth: 44, minHeight: 44)
                .opacity(step > 0 && step < Self.stepCount - 1 ? 1 : 0)
                .disabled(!(step > 0 && step < Self.stepCount - 1))
                .accessibilityHint(Text("Uses the defaults for the remaining questions"))
        }
        .padding(.horizontal, Space.page)
        .padding(.top, Space.s)
    }

    @ViewBuilder private var page: some View {
        switch step {
        case 0: WelcomeStep(next: next)
        case 1: FrictionStep(friction: $draft.friction, next: next)
        case 2: FocusStep(areas: $draft.focusAreas, next: next)
        case 3: DemoStep(next: next)
        case 4: RhythmStep(length: $draft.breakLength, goal: $draft.dailyGoal, next: next)
        case 5: ScheduleStep(schedule: $draft.schedule, next: next)
        case 6: RemindersStep(enabled: $draft.remindersEnabled, minutes: draft.breakLength.minutes, next: next)
        default: PlanStep(prefs: draft) { model.finishOnboarding(with: draft) }
        }
    }

    private func next() { go(to: step + 1) }

    private func go(to target: Int) {
        let clamped = min(max(target, 0), Self.stepCount - 1)
        guard clamped != step else { return }
        forward = clamped > step
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { step = clamped }
    }
}

/// Shared page layout: illustration, headline, content, actions pinned to the bottom.
struct OnboardingPage<Art: View, Content: View, Actions: View>: View {
    var title: String
    var subtitle: String? = nil
    var artFraction: CGFloat = 0.34
    @ViewBuilder var art: Art
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.xl) {
                    art
                        .frame(maxWidth: .infinity)
                        .containerRelativeFrame(.vertical) { h, _ in h * artFraction }
                    VStack(spacing: Space.s) {
                        Text(title)
                            .font(.uTitle)
                            .foregroundStyle(Palette.petrol)
                            .accessibilityAddTraits(.isHeader)
                        if let subtitle {
                            Text(subtitle)
                                .font(.uBody)
                                .foregroundStyle(Palette.petrolSoft)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    content
                }
                .padding(.horizontal, Space.page)
                .padding(.top, Space.s)
                .padding(.bottom, Space.l)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: Space.xs) { actions }
                .padding(.horizontal, Space.page)
                .padding(.top, Space.s)
                .padding(.bottom, Space.s)
                .background(Palette.ivory)
        }
    }
}

extension OnboardingPage where Content == EmptyView {
    init(title: String, subtitle: String? = nil, artFraction: CGFloat = 0.42, @ViewBuilder art: () -> Art, @ViewBuilder actions: () -> Actions) {
        self.init(title: title, subtitle: subtitle, artFraction: artFraction, art: art, content: { EmptyView() }, actions: actions)
    }
}

// MARK: 1. Welcome

private struct WelcomeStep: View {
    var next: () -> Void
    @State private var state: ShrimpState = .working

    var body: some View {
        OnboardingPage(
            title: String(localized: "Small breaks.\nA less stiff workday."),
            subtitle: String(localized: "Meet \(Brand.mascotName). \(Brand.mascotName) gets lost in work too, so you two can remind each other to move."),
            artFraction: 0.45
        ) {
            DeskSceneView(state: state, unlocked: [])
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2.5))
        } actions: {
            Button("Let's get moving", action: next).buttonStyle(.chunky)
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            state = .inviting
        }
    }
}

// MARK: 2. Friction

private struct FrictionStep: View {
    @Binding var friction: Friction
    var next: () -> Void

    var body: some View {
        OnboardingPage(title: String(localized: "What usually gets in the way?"),
                       subtitle: String(localized: "No wrong answers. This shapes how \(Brand.mascotName) helps.")) {
            ShrimpStage(state: .working, prop: .thought)
        } content: {
            VStack(spacing: Space.s) {
                option(.forget, String(localized: "I forget to take breaks"), String(localized: "Hours vanish at the keyboard."), "clock.badge.questionmark")
                option(.unsure, String(localized: "I'm not sure what to do"), String(localized: "Breaks feel vague, so I skip them."), "questionmark.bubble")
                option(.both, String(localized: "A bit of both"), String(localized: "Remind me and show me."), "sparkles")
            }
        } actions: {
            Button("Continue", action: next).buttonStyle(.chunky)
        }
    }

    private func option(_ value: Friction, _ title: String, _ subtitle: String, _ icon: String) -> some View {
        OptionCard(title: title, subtitle: subtitle, isSelected: friction == value) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.petrol)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Palette.butterSoft))
        } action: {
            withAnimation(Motion.snappy) { friction = value }
        }
    }
}

// MARK: 3. Focus areas

private struct FocusStep: View {
    @Binding var areas: Set<FocusArea>
    var next: () -> Void

    var body: some View {
        OnboardingPage(title: String(localized: "Where do you feel stiff?"),
                       subtitle: String(localized: "Pick any. Breaks will lean toward these areas.")) {
            ShrimpStage(state: .stretching, prop: .focus(areas), backdrop: Palette.butterSoft)
        } content: {
            VStack(spacing: Space.s) {
                ForEach(FocusArea.allCases) { area in
                    OptionCard(title: area.title, isSelected: areas.contains(area), multi: true) {
                        Image(systemName: area.symbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Palette.petrol)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Palette.mintSoft))
                    } action: {
                        withAnimation(Motion.snappy) {
                            if areas.contains(area) { areas.remove(area) } else { areas.insert(area) }
                        }
                    }
                }
                Text("\(Brand.mascotName) is a movement buddy, not a clinician. If something hurts or worries you, check in with a health professional.")
                    .font(.uCaption.weight(.medium))
                    .foregroundStyle(Palette.petrolSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.xs)
            }
        } actions: {
            Button("Continue", action: next)
                .buttonStyle(.chunky)
                .disabled(areas.isEmpty)
        }
    }
}

// MARK: 4. Demo break

private struct DemoStep: View {
    var next: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = ExerciseSession(routine: Routine(
        moves: [DemoLibrary.demoMove], secondsPerMove: 20, minutes: 0, focus: DemoLibrary.demoMove.focus))

    private var move: Move { session.move }
    private var finished: Bool { session.isComplete }

    var body: some View {
        OnboardingPage(title: finished ? String(localized: "Nice. That's the whole idea.") : String(localized: "Try a 20-second break"),
                       subtitle: finished
                        ? String(localized: "Short, guided, done. Then back to work feeling a little looser.")
                        : String(localized: "One move with \(Brand.mascotName). You can skip this.")) {
            ZStack {
                if finished {
                    ShrimpStage(state: .celebrating, prop: .mat)
                    ConfettiBurst(trigger: 1)
                } else {
                    // Loops before Start too, so the step shows the move instead of a seated still.
                    ExerciseDemonstration(move: move, isRunning: session.isRunning || !session.hasBegun,
                                          isPreparing: session.isPreparing,
                                          revision: session.playbackRevision, showsReplay: false)
                        // Kip's window sits behind the card's edge, so he peeks out without covering the instructor.
                        .background(alignment: .bottomTrailing) {
                            BuddyWindow(state: session.isRunning ? .exercise(.shrug) : .inviting)
                                .offset(x: 72, y: -Space.m)
                                .accessibilityHidden(true)
                        }
                }
            }
        } content: {
            if !finished {
                HStack(spacing: Space.l) {
                    TimerRing(progress: session.progress, label: "\(session.hasBegun ? session.secondsLeft : 20)")
                        .frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(move.name).font(.uHeadline).foregroundStyle(Palette.petrol)
                        Text(move.cue).font(.uCallout).foregroundStyle(Palette.petrolSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        if session.hasBegun {
                            Text(session.phaseTitle).font(.uCaption).foregroundStyle(Palette.petrolSoft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .card()
            }
        } actions: {
            if finished {
                Button("Continue", action: next).buttonStyle(.chunky)
            } else if session.hasBegun {
                Button(session.isRunning ? LocalizedStringKey("Pause") : LocalizedStringKey("Resume")) { session.toggle() }.buttonStyle(.chunky(.secondary))
                Button("Skip the demo", action: next).buttonStyle(.chunky(.quiet))
            } else {
                Button("Start the demo") { session.start() }.buttonStyle(.chunky)
                Button("Skip the demo", action: next).buttonStyle(.chunky(.quiet))
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in session.tick() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.pause() }
        }
        .onDisappear { session.pause() }
        .sensoryFeedback(.success, trigger: finished)
    }
}

// MARK: 5. Length and goal

private struct RhythmStep: View {
    @Binding var length: BreakLength
    @Binding var goal: Int
    var next: () -> Void

    var body: some View {
        OnboardingPage(title: String(localized: "How long, how often?"),
                       subtitle: String(localized: "Small and steady beats big and rare."),
                       artFraction: 0.26) {
            ShrimpStage(state: .inviting, prop: .stopwatch, backdrop: Palette.butterSoft)
        } content: {
            VStack(spacing: Space.l) {
                VStack(spacing: Space.s) {
                    SectionLabel(text: "Break length")
                    DurationPicker(selection: $length)
                    Text(lengthNote).font(.uCaption).foregroundStyle(Palette.petrolSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(spacing: Space.s) {
                    SectionLabel(text: "Daily goal")
                    GoalStepper(goal: $goal)
                        .card()
                }
            }
        } actions: {
            Button("Continue", action: next).buttonStyle(.chunky)
        }
    }

    private var lengthNote: String {
        switch length {
        case .two: String(localized: "A quick reset: four moves.")
        case .three: String(localized: "\(Brand.mascotName)'s pick: six moves, nothing rushed.")
        case .five: String(localized: "A proper unshrimp: eight moves at your own pace.")
        }
    }
}

// MARK: 6. Schedule

private struct ScheduleStep: View {
    @Binding var schedule: WorkSchedule
    var next: () -> Void

    private var valid: Bool { !schedule.workdays.isEmpty && schedule.endMinute > schedule.startMinute }

    var body: some View {
        OnboardingPage(title: String(localized: "When are you at your desk?"),
                       subtitle: String(localized: "Reminders stay inside these hours."),
                       artFraction: 0.24) {
            ShrimpStage(state: .working, prop: .calendar)
        } content: {
            VStack(spacing: Space.l) {
                VStack(spacing: Space.s) {
                    SectionLabel(text: "Workdays")
                    WeekdayPicker(days: $schedule.workdays)
                }
                VStack(spacing: Space.s) {
                    SectionLabel(text: "Working hours")
                    TimeRangePicker(start: $schedule.startMinute, end: $schedule.endMinute)
                }
                VStack(spacing: Space.s) {
                    SectionLabel(text: "Nudge me every")
                    IntervalPicker(minutes: $schedule.intervalMinutes)
                }
                Group {
                    if valid {
                        Text("That's about \(ReminderPlanner.nudgesPerDay(schedule)) nudges each workday.")
                    } else if schedule.workdays.isEmpty {
                        Text("Pick at least one workday.")
                    } else {
                        Text("Finish time needs to be after start time.")
                    }
                }
                .font(.uCallout.weight(.semibold))
                .foregroundStyle(valid ? Palette.petrolSoft : Palette.coralDeep)
            }
        } actions: {
            Button("Continue", action: next).buttonStyle(.chunky).disabled(!valid)
        }
    }
}

// MARK: 7. Reminders permission

private struct RemindersStep: View {
    @Environment(AppModel.self) private var model
    @Binding var enabled: Bool
    var minutes: Int
    var next: () -> Void
    @State private var asking = false

    var body: some View {
        OnboardingPage(title: String(localized: "Let \(Brand.mascotName) tap you on the shoulder"),
                       subtitle: subtitle,
                       artFraction: 0.46) {
            NotificationPreview(minutes: minutes)
        } content: {
            statusNote
        } actions: {
            switch model.notificationStatus {
            case .authorized, .provisional, .ephemeral, .denied:
                Button("Continue", action: next).buttonStyle(.chunky)
            default:
                Button {
                    asking = true
                    Task {
                        let granted = await model.requestNotifications()
                        enabled = granted
                        asking = false
                    }
                } label: {
                    if asking { ProgressView().tint(Palette.petrol) } else { Text("Turn on reminders") }
                }
                .buttonStyle(.chunky)
                .disabled(asking)
                Button("Not now", action: next).buttonStyle(.chunky(.quiet))
            }
        }
        .task { await model.refreshNotificationStatus() }
    }

    private var subtitle: String {
        String(localized: "Reminders only arrive on workdays, inside your hours. Snooze or change them anytime.")
    }

    @ViewBuilder private var statusNote: some View {
        switch model.notificationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Reminders are on. \(Brand.mascotName) will wave when it's time.", systemImage: "checkmark.circle.fill")
                .font(.uCallout.weight(.semibold))
                .foregroundStyle(Palette.mintDeep)
                .card(Palette.mintSoft)
        case .denied:
            Label("No problem. You can start breaks from the app anytime, and turn reminders on later in Settings.", systemImage: "bell.slash")
                .font(.uCallout.weight(.semibold))
                .foregroundStyle(Palette.petrol)
                .card(Palette.butterSoft)
        default:
            EmptyView()
        }
    }
}

// MARK: 8. Plan

private struct PlanStep: View {
    @Environment(AppModel.self) private var model
    var prefs: Preferences
    var finish: () -> Void

    var body: some View {
        OnboardingPage(title: String(localized: "Your movement plan"),
                       subtitle: String(localized: "Tweak it anytime from the bell on your desk."),
                       artFraction: 0.26) {
            ZStack {
                ShrimpStage(state: .celebrating, backdrop: Palette.butterSoft)
                ConfettiBurst(trigger: 8)
            }
        } content: {
            VStack(spacing: 0) {
                row("figure.cooldown", String(localized: "\(prefs.dailyGoal) breaks a day, \(prefs.breakLength.minutes) minutes each"))
                Divider().overlay(Palette.line)
                row("scope", String(localized: "Focus: \(FocusArea.summary(prefs.focusAreas))"))
                Divider().overlay(Palette.line)
                row("calendar", "\(prefs.schedule.workdaysSummary), \(prefs.schedule.hoursSummary)")
                Divider().overlay(Palette.line)
                row(remindersOn ? "bell.fill" : "bell.slash", remindersOn
                    ? String(localized: "A nudge every \(prefs.schedule.intervalMinutes) minutes")
                    : String(localized: "Reminders off for now"))
                Divider().overlay(Palette.line)
                row("leaf.fill", String(localized: "Each break grows \(Brand.mascotName)'s desk"))
            }
            .card()
        } actions: {
            Button("Go to my desk", action: finish).buttonStyle(.chunky)
        }
    }

    private var remindersOn: Bool {
        prefs.remindersEnabled && model.notificationsAllowed
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.petrol)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.coralSoft))
            Text(text).font(.uCallout.weight(.semibold)).foregroundStyle(Palette.petrol)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Space.s)
    }
}
