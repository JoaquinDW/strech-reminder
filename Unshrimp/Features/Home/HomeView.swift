import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var activeRoutine: Routine?
    @State private var skipIntro = false
    @State private var breakSource: BreakSource = .app
    @State private var showSettings = false
    @State private var showCollection = false
    @State private var showRecap = false
    @State private var showStreak = false
    @State private var activeStand: StandMove?
    @State private var standSource: StandSource = .app
    @State private var now = Date()
    @State private var popItem: DeskItem?
    @State private var popStart: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                header
                scene
                if let offer = model.repairOffer(now) {
                    repairBanner(offer)
                }
                todayCard
                if model.stiffnessCheckinDue(now) {
                    StiffnessCheckinCard(areas: model.prefs.focusAreas)
                }
                startSection
                weekCard
                growthCard
                rewardCard
                Text(DemoLibrary.disclaimer)
                    .font(.uCaption.weight(.medium))
                    .foregroundStyle(Palette.petrolSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s)
            }
            .padding(.horizontal, Space.page)
            .padding(.bottom, Space.xl)
        }
        .background(Palette.ivory.ignoresSafeArea())
        .fullScreenCover(item: $activeRoutine, onDismiss: afterBreak) { routine in
            BreakFlowView(routine: routine, skipIntro: skipIntro, source: breakSource)
        }
        .fullScreenCover(item: $activeStand, onDismiss: afterBreak) { move in
            StandView(move: move, source: standSource)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showCollection) { CollectionView() }
        .sheet(isPresented: $showStreak) { StreakView() }
        .sheet(isPresented: $showRecap) {
            if let summary = model.weeklySummary(now) { WeeklyRecapView(summary: summary) }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        // Past midnight with the app open: check yesterday for the streak.
        .onChange(of: model.day(now)) { model.reconcileStreak(now) }
        .onChange(of: model.breakRequestedFromNotification, initial: true) { _, requested in
            guard requested else { return }
            model.breakRequestedFromNotification = false
            let skip = model.skipBreakIntro
            model.skipBreakIntro = false
            // A break already on screen wins; otherwise close any sheet and go.
            guard activeRoutine == nil else { return }
            let hadSheet = showSettings || showCollection || showRecap || showStreak
            showSettings = false
            showCollection = false
            showRecap = false
            showStreak = false
            if hadSheet {
                Task { try? await Task.sleep(for: .milliseconds(450)); startBreak(skippingIntro: skip, source: .reminder) }
            } else {
                startBreak(skippingIntro: skip, source: .reminder)
            }
        }
        .onChange(of: model.standRequested, initial: true) { _, requested in
            guard let id = requested else { return }
            model.standRequested = nil
            // A break or stand already on screen wins.
            guard activeRoutine == nil, activeStand == nil, let move = StandMove.move(id) else { return }
            let hadSheet = showSettings || showCollection || showRecap
            showSettings = false
            showCollection = false
            showRecap = false
            standSource = .reminderScreen
            if hadSheet {
                Task { try? await Task.sleep(for: .milliseconds(450)); activeStand = move }
            } else {
                activeStand = move
            }
        }
        .onChange(of: model.recapRequested, initial: true) { _, requested in
            guard requested else { return }
            model.recapRequested = false
            guard activeRoutine == nil, activeStand == nil, model.weeklySummary(now) != nil else { return }
            showSettings = false
            showCollection = false
            Task { try? await Task.sleep(for: .milliseconds(300)); showRecap = true }
        }
        .task { await model.refreshNotificationStatus() }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-testCollection") { showCollection = true }
            if args.contains("-testWeeklyRecap") { showRecap = true }
            if args.contains("-testStreak") { showStreak = true }
        }
        #endif
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.greeting(now))
                    .font(.uTitle)
                    .foregroundStyle(Palette.petrol)
                    .accessibilityAddTraits(.isHeader)
                Text(now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.uCallout)
                    .foregroundStyle(Palette.petrolSoft)
            }
            Spacer()
            StreakBadge(streak: model.streak(now), safe: model.streakSafeToday(now)) { showStreak = true }
                .animation(Motion.snappy, value: model.streak(now))
            CircleIconButton(systemName: "bell.badge", label: "Reminder settings") { showSettings = true }
        }
        .padding(.top, Space.s)
    }

    private func repairBanner(_ offer: StreakRepairOffer) -> some View {
        Button { showStreak = true } label: {
            HStack(spacing: Space.m) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Palette.petrol)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.butter))
                    .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Win back your \(offer.previous)-day streak")
                        .font(.uCallout.weight(.bold)).foregroundStyle(Palette.petrol)
                    Text("Reach today's goal and the missed day counts again.")
                        .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.uHeadline).foregroundStyle(Palette.petrolSoft)
            }
            .card(Palette.butterSoft)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    // MARK: Scene

    private var scene: some View {
        ZStack(alignment: .topLeading) {
            DeskSceneView(state: model.shrimpState(now), unlocked: model.unlocked, ghost: model.nextItem,
                          popItem: popItem, popStart: popStart)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2.5))
            SpeechBubble(text: model.speech(now))
                .frame(maxWidth: 176, alignment: .leading)
                .padding(Space.m)
                .animation(Motion.gentle, value: model.speech(now))
        }
    }

    // MARK: Today

    private var todayCard: some View {
        let done = model.breaksToday(now)
        let goal = model.prefs.dailyGoal
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(min(done, 99))")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.petrol)
                    .contentTransition(.numericText(value: Double(done)))
                Text("of \(goal) breaks today")
                    .font(.uHeadline)
                    .foregroundStyle(Palette.petrolSoft)
                Spacer()
                if done >= goal {
                    Label("Goal met", systemImage: "checkmark.seal.fill")
                        .font(.uCaption)
                        .foregroundStyle(Palette.mintDeep)
                }
            }
            .accessibilityElement(children: .combine)
            ProgressPills(done: done, total: goal)
            standsLine
            reminderLine
        }
        .card()
    }

    /// Quick stands sit beside the goal, not inside it, so the daily goal stays about breaks.
    @ViewBuilder private var standsLine: some View {
        let stands = model.standsToday(now)
        if model.prefs.standsEnabled || stands > 0 {
            HStack(spacing: Space.s) {
                Image(systemName: "figure.stand")
                Text(stands == 1 ? String(localized: "1 quick stand today") : String(localized: "\(stands) quick stands today"))
                Spacer()
            }
            .font(.uCallout.weight(.semibold))
            .foregroundStyle(Palette.petrol)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var reminderLine: some View {
        HStack(spacing: Space.s) {
            if !model.prefs.remindersEnabled {
                Image(systemName: "bell.slash.fill")
                Text("Reminders paused")
                Spacer()
                Button("Resume") { model.updatePrefs { $0.remindersEnabled = true } }
                    .font(.uCallout.weight(.bold))
                    .foregroundStyle(Palette.coralDeep)
                    .frame(minHeight: 44)
            } else if model.remindersBlocked {
                Image(systemName: "bell.slash.fill")
                Text("Notifications are off in iOS Settings")
                Spacer()
                Button("Fix") { showSettings = true }
                    .font(.uCallout.weight(.bold))
                    .foregroundStyle(Palette.coralDeep)
                    .frame(minHeight: 44)
            } else if model.notificationStatus == .notDetermined {
                Image(systemName: "bell")
                Text("Want a nudge when it's time?")
                Spacer()
                Button("Turn on") { Task { await model.requestNotifications() } }
                    .font(.uCallout.weight(.bold))
                    .foregroundStyle(Palette.coralDeep)
                    .frame(minHeight: 44)
            } else if let next = model.nextReminder(now) {
                Image(systemName: "bell.fill")
                Text("Next nudge \(ReminderPlanner.describe(next, now: now))")
                Spacer()
            } else {
                Image(systemName: "bell")
                Text("No nudges scheduled this week")
                Spacer()
            }
        }
        .font(.uCallout.weight(.semibold))
        .foregroundStyle(Palette.petrol)
        .frame(minHeight: 32)
    }

    // MARK: Start

    private var startSection: some View {
        VStack(spacing: Space.m) {
            Button(action: startBreak) {
                HStack(spacing: Space.s) {
                    Image(systemName: "figure.cooldown")
                    Text("Start a break")
                }
                .font(.system(.title3, design: .rounded, weight: .heavy))
            }
            .buttonStyle(.chunky)
            .accessibilityLabel(Text("Start a break"))
            .accessibilityHint(Text("\(model.prefs.breakLength.minutes) minutes, focused on \(FocusArea.summary(model.prefs.focusAreas))"))

            Button {
                standSource = .app
                activeStand = StandMove.pick(seed: model.data.stands.count &* 5 &+ Calendar.current.component(.hour, from: now))
            } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "figure.stand")
                    Text("Quick stand, under a minute")
                }
            }
            .buttonStyle(.chunky(.secondary))

            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    ForEach(BreakLength.allCases) { len in
                        Chip(title: len.label, isSelected: model.prefs.breakLength == len, stretch: true) {
                            model.updatePrefs { $0.breakLength = len }
                        }
                    }
                }
                FlowLayout(spacing: Space.s) {
                    Group {
                        ForEach(FocusArea.allCases) { area in
                            Chip(title: area.title, systemImage: area.symbol, isSelected: model.prefs.focusAreas.contains(area)) {
                                model.updatePrefs { p in
                                    if p.focusAreas.contains(area) {
                                        if p.focusAreas.count > 1 { p.focusAreas.remove(area) }
                                    } else {
                                        p.focusAreas.insert(area)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Week

    private var weekCard: some View {
        let week = model.week(now)
        let good = week.filter(\.goalMet).count
        let stops = model.adventureStops(now)
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Text("This week").font(.uHeadline).foregroundStyle(Palette.petrol)
                Spacer()
                Text(model.isFirstDay ? String(localized: "Fills in as you move") : good == 1 ? String(localized: "1 goal day") : String(localized: "\(good) goal days"))
                    .font(.uCaption)
                    .foregroundStyle(Palette.petrolSoft)
            }
            HStack(spacing: 0) {
                ForEach(week) { day in
                    VStack(spacing: 6) {
                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.uMicro)
                            .foregroundStyle(day.isToday ? Palette.petrol : Palette.petrolSoft)
                        DayDot(day: day, goal: model.prefs.dailyGoal)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(day.date.formatted(.dateTime.weekday(.wide))): \(day.count) breaks"))
                }
            }
            Divider().overlay(Palette.line)
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    Label(Brand.adventureName, systemImage: "map")
                        .font(.uCallout.weight(.bold))
                        .foregroundStyle(Palette.petrol)
                    Spacer()
                    Text("Stop \(stops) of \(Adventure.stops.count)")
                        .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                }
                AdventureTrail(stops: stops)
                Text(stops >= Adventure.stops.count
                     ? String(localized: "Trail complete! A new one starts next week.")
                     : String(localized: "Hit your daily goal to reach \(Adventure.stops[stops])."))
                    .font(.uCaption.weight(.medium))
                    .foregroundStyle(Palette.petrolSoft)
            }
            if let summary = model.weeklySummary(now) {
                Divider().overlay(Palette.line)
                recapRow(summary)
            }
        }
        .card()
    }

    private func recapRow(_ summary: WeeklySummary) -> some View {
        Button { showRecap = true } label: {
            HStack(spacing: Space.m) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.petrol)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.butter))
                    .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.isCurrent
                         ? String(localized: "This week you moved \(summary.minutes) min")
                         : String(localized: "Last week you moved \(summary.minutes) min"))
                        .font(.uCallout.weight(.bold))
                        .foregroundStyle(Palette.petrol)
                    Text("See and share your week with \(Brand.mascotName)")
                        .font(.uCaption)
                        .foregroundStyle(Palette.petrolSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.uHeadline).foregroundStyle(Palette.petrolSoft)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    // MARK: Kip's growth

    private var growthCard: some View {
        let growth = model.growth
        return Button { showCollection = true } label: {
            HStack(spacing: Space.l) {
                ShrimpView(state: .inviting)
                    .frame(width: 64, height: 64)
                    .padding(.top, 4)
                    .background(Circle().fill(Palette.butterSoft))
                    .clipShape(Circle())
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Brand.mascotName)'s growth").font(.uMicro).textCase(.uppercase).tracking(1).foregroundStyle(Palette.petrolSoft)
                    Text(growth.title).font(.uHeadline).foregroundStyle(Palette.petrol)
                    if let p = growth.progress, let hint = growth.nextHint {
                        EnergyBar(value: Double(p.current) / Double(max(1, p.needed)), tint: Palette.coral)
                        Text(hint).font(.uCaption).foregroundStyle(Palette.petrolSoft)
                    } else {
                        Text("Uncurled as far as a shrimp goes. Every outfit is yours.")
                            .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.uHeadline).foregroundStyle(Palette.petrolSoft)
            }
            .card()
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows \(Brand.mascotName)'s wardrobe and desk"))
    }

    // MARK: Reward preview

    @ViewBuilder private var rewardCard: some View {
        Button { showCollection = true } label: {
            HStack(spacing: Space.l) {
                if let next = model.nextItem {
                    let p = model.progress(toward: next)
                    DeskItemIcon(item: next, locked: true)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Palette.ivoryDeep))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next for the desk").font(.uMicro).textCase(.uppercase).tracking(1).foregroundStyle(Palette.petrolSoft)
                        Text(next.title).font(.uHeadline).foregroundStyle(Palette.petrol)
                        EnergyBar(value: Double(p.current) / Double(max(1, p.needed)))
                        Text("\(p.current) of \(p.needed) energy · about \(breaksAway(p)) breaks away")
                            .font(.uCaption).foregroundStyle(Palette.petrolSoft).monospacedDigit()
                    }
                } else {
                    Image(systemName: "sparkles").font(.title).foregroundStyle(Palette.coral)
                    Text("\(Brand.mascotName)'s desk is complete. More decor coming soon.")
                        .font(.uHeadline).foregroundStyle(Palette.petrol)
                }
                Image(systemName: "chevron.right").font(.uHeadline).foregroundStyle(Palette.petrolSoft)
            }
            .card()
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint(Text("Shows all desk items"))
    }

    private func breaksAway(_ p: (current: Int, needed: Int)) -> Int {
        max(1, Int((Double(p.needed - p.current) / Double(EnergyRules.base)).rounded(.up)))
    }

    // MARK: Actions

    private func startBreak() { startBreak(skippingIntro: false) }

    private func startBreak(skippingIntro: Bool, source: BreakSource = .app) {
        skipIntro = skippingIntro
        breakSource = source
        activeRoutine = model.nextRoutine()
    }

    private func afterBreak() {
        now = Date()
        if let item = model.celebrateItem {
            model.celebrateItem = nil
            popItem = item
            popStart = Date().timeIntervalSinceReferenceDate + 0.3
        }
    }
}

extension Routine: Identifiable {
    var id: String { moves.map(\.id).joined(separator: "-") + "-\(minutes)" }
}

private struct DayDot: View {
    var day: DaySummary
    var goal: Int

    var body: some View {
        ZStack {
            if day.goalMet {
                Circle().fill(Palette.coral)
                Circle().strokeBorder(Palette.petrol, lineWidth: 2)
                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(Palette.petrol)
            } else if day.count > 0 {
                Circle().fill(Palette.paper)
                Circle()
                    .trim(from: 0, to: Double(day.count) / Double(max(goal, 1)))
                    .stroke(Palette.coral, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                Circle().strokeBorder(Palette.petrol, lineWidth: 2)
            } else {
                Circle()
                    .strokeBorder(day.isFuture || !day.isWorkday ? Palette.line : Palette.petrol.opacity(0.35),
                                  style: StrokeStyle(lineWidth: 2, dash: day.isWorkday ? [] : [3, 3]))
            }
        }
        .frame(width: 34, height: 34)
        .overlay {
            if day.isToday {
                Circle().strokeBorder(Palette.coral, lineWidth: 2).padding(-5)
            }
        }
    }
}

private struct AdventureTrail: View {
    var stops: Int

    var body: some View {
        GeometryReader { geo in
            let count = Adventure.stops.count
            let w = geo.size.width
            let step = (w - 24) / CGFloat(count - 1)
            ZStack(alignment: .leading) {
                Path { p in
                    p.move(to: CGPoint(x: 12, y: 16))
                    p.addLine(to: CGPoint(x: w - 12, y: 16))
                }
                .stroke(Palette.line, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 8]))
                Capsule()
                    .fill(Palette.coral)
                    .frame(width: max(0, CGFloat(max(stops - 1, 0)) * step), height: 4)
                    .offset(x: 12, y: 0)
                    .frame(height: 32)
                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(i < stops ? Palette.coral : Palette.paper)
                        .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                        .frame(width: 18, height: 18)
                        .position(x: 12 + CGFloat(i) * step, y: 16)
                }
                // Kip's marker: a tiny shrimp head on the current stop
                ShrimpView(state: .celebrating)
                    .frame(width: 36, height: 36)
                    .position(x: 12 + CGFloat(min(max(stops - 1, 0), count - 1)) * step, y: 2)
                    .opacity(stops > 0 ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityLabel(Text("\(stops) of \(Adventure.stops.count) stops reached"))
    }
}
