import SwiftUI

/// The streak up close: today's status, the month calendar, shell guards and milestones.
struct StreakView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var month = Date()
    @State private var now = Date()
    @State private var bought = 0
    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    hero
                    StreakTierStrip(streak: model.streak(now))
                    stats
                    if let offer = model.repairOffer(now) { repairCard(offer) }
                    calendarCard
                    guardsCard
                    milestonesCard
                    Text("Only your workdays count. A break on a day off still adds to the streak, and skipping one never breaks it.")
                        .font(.uCaption.weight(.medium))
                        .foregroundStyle(Palette.petrolSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.s)
                }
                .padding(Space.page)
            }
            .background(Palette.ivory.ignoresSafeArea())
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let shareImage {
                    ToolbarItem(placement: .cancellationAction) {
                        StreakShareButton(image: shareImage, streak: model.streak(now)) {
                            Image(systemName: "square.and.arrow.up").font(.uHeadline)
                        }
                        .tint(Palette.petrol)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(.uHeadline).tint(Palette.petrol)
                }
            }
        }
        .sensoryFeedback(.success, trigger: bought)
        .task {
            Analytics.capture("streak_viewed", properties: ["streak": model.streak(now), "freezes": model.streakFreezes])
            let streak = model.streak(now)
            if streak > 0 { shareImage = StreakShareCard.render(streak: streak, look: model.look) }
        }
    }

    // MARK: Hero

    private var hero: some View {
        let streak = model.streak(now)
        let safe = model.streakSafeToday(now)
        return VStack(spacing: Space.s) {
            HStack(spacing: Space.s) {
                StreakMark(tier: StreakTier(streak: streak), lit: safe, size: 60)
                Text("\(streak)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.petrol)
            }
            Text(StreakCopy.daysInARow(streak)).font(.uTitle2).foregroundStyle(Palette.petrol)
            Text(statusLine(streak: streak, safe: safe))
                .font(.uCallout)
                .foregroundStyle(Palette.petrolSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.l)
        .card(safe ? StreakTier(streak: streak).softColor : Palette.paper)
        .accessibilityElement(children: .combine)
    }

    private func statusLine(streak: Int, safe: Bool) -> String {
        if safe { return String(localized: "Safe for today. See you next workday.") }
        if model.repairOffer(now) != nil { return String(localized: "Reach today's goal and the missed day counts again.") }
        if streak == 0 { return String(localized: "Take a break today to start a streak.") }
        if model.streakAtRisk(now) { return String(localized: "One break today keeps it going.") }
        return String(localized: "Day off. Your streak waits for you.")
    }

    private var stats: some View {
        HStack(spacing: Space.m) {
            stat(value: "\(model.bestStreak(now))", label: String(localized: "Best streak"), symbol: "trophy.fill", tint: Palette.butter)
            stat(value: "\(model.streakFreezes)/\(StreakRules.maxFreezes)", label: String(localized: "Shell guards"), symbol: StreakSymbol.freeze, tint: Palette.mint)
        }
    }

    private func stat(value: String, label: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.petrol)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint))
                .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.uTitle2).monospacedDigit().foregroundStyle(Palette.petrol)
                Text(label).font(.uCaption).foregroundStyle(Palette.petrolSoft).lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    // MARK: Repair

    private func repairCard(_ offer: StreakRepairOffer) -> some View {
        let done = model.breaksToday(now), goal = model.prefs.dailyGoal
        return VStack(alignment: .leading, spacing: Space.s) {
            Label("Win back your \(offer.previous)-day streak", systemImage: "arrow.uturn.backward")
                .font(.uHeadline).foregroundStyle(Palette.petrol)
            Text("Reach today's goal and the missed day counts again.")
                .font(.uCaption).foregroundStyle(Palette.petrolSoft)
            ProgressPills(done: done, total: goal)
        }
        .card(Palette.butterSoft)
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2.5))
    }

    // MARK: Calendar

    private var calendarCard: some View {
        let calendar = Calendar.current
        let days = model.streakMonth(month, now: now)
        let isCurrentMonth = calendar.isDate(month, equalTo: now, toGranularity: .month)
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: Space.m) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(Text("Previous month"))
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.uHeadline).foregroundStyle(Palette.petrol)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(isCurrentMonth)
                    .accessibilityLabel(Text("Next month"))
            }
            .font(.uHeadline)
            .foregroundStyle(Palette.petrol)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(order, id: \.self) { i in
                    Text(calendar.veryShortWeekdaySymbols[i]).font(.uMicro).foregroundStyle(Palette.petrolSoft)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        StreakDayDot(kind: day.kind, isToday: day.isToday, label: "\(day.day.value % 100)", size: 36)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(day.day.date().formatted(date: .complete, time: .omitted)))
                            .accessibilityValue(Text(day.kind.accessibilityValue))
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
            legend
        }
        .card()
    }

    private var legend: some View {
        FlowLayout(spacing: Space.m) {
            Group {
                legendItem(.done(perfect: false), String(localized: "Break done"))
                legendItem(.done(perfect: true), String(localized: "Goal met"))
                legendItem(.frozen, String(localized: "Shell guard"))
                legendItem(.repaired, String(localized: "Won back"))
                legendItem(.rest, String(localized: "Day off"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(_ kind: StreakDayKind, _ text: String) -> some View {
        HStack(spacing: 6) {
            StreakDayDot(kind: kind, isToday: false, label: kind == .rest ? "" : nil, size: 18)
            Text(text).font(.uMicro).foregroundStyle(Palette.petrolSoft)
        }
        .accessibilityElement(children: .combine)
    }

    private func shiftMonth(_ by: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: by, to: month) else { return }
        withAnimation(Motion.snappy) { month = next }
    }

    // MARK: Shell guards

    private var guardsCard: some View {
        let freezes = model.streakFreezes
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                ForEach(0..<StreakRules.maxFreezes, id: \.self) { i in
                    Image(systemName: StreakSymbol.freeze)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(i < freezes ? Palette.petrol : Palette.petrolSoft.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(i < freezes ? Palette.mint : Palette.ivoryDeep))
                        .overlay(Circle().strokeBorder(Palette.petrol.opacity(i < freezes ? 1 : 0.3), lineWidth: 2))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shell guards").font(.uHeadline).foregroundStyle(Palette.petrol)
                    Text("Missed a workday? One is used for you, and the streak carries on.")
                        .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(StreakCopy.guards(freezes)))

            Button {
                model.buyFreeze()
                bought += 1
            } label: {
                Label(freezes >= StreakRules.maxFreezes
                      ? String(localized: "Guards full")
                      : String(localized: "Get one for \(StreakRules.freezeCost) energy"),
                      systemImage: "bolt.heart.fill")
            }
            .buttonStyle(.chunky(.secondary, compact: true))
            .disabled(!model.canBuyFreeze)
            .frame(maxWidth: .infinity)

            Text("\(model.spendableEnergy) energy to spend. Spending it never takes anything off the desk. Each milestone also brings a free guard.")
                .font(.uMicro)
                .foregroundStyle(Palette.petrolSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: Milestones

    private var milestonesCard: some View {
        let reached = Set(model.data.streak.milestones)
        let next = StreakRules.milestones.first { !reached.contains($0) }
        return VStack(alignment: .leading, spacing: Space.m) {
            Text("Milestones").font(.uTitle2).foregroundStyle(Palette.petrol).accessibilityAddTraits(.isHeader)
            ForEach(StreakRules.milestones, id: \.self) { m in
                let done = reached.contains(m)
                HStack(spacing: Space.m) {
                    reward(for: m, done: done)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(StreakCopy.days(m)).font(.uHeadline).foregroundStyle(Palette.petrol)
                        Text(StreakRules.wearable(forMilestone: m).map { String(localized: "\($0.title) + a shell guard") }
                             ?? String(localized: "A shell guard"))
                            .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                        if m == next {
                            EnergyBar(value: Double(model.streak(now)) / Double(m), tint: Palette.coral)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                    if done {
                        Image(systemName: "checkmark.seal.fill").font(.title3).foregroundStyle(Palette.mintDeep)
                    }
                }
                .opacity(done || m == next ? 1 : 0.55)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(done ? String(localized: "Reached") : String(localized: "Not yet")))
            }
        }
        .card()
    }

    @ViewBuilder private func reward(for milestone: Int, done: Bool) -> some View {
        if let wearable = StreakRules.wearable(forMilestone: milestone) {
            ShrimpView(state: .inviting)
                .environment(\.kipLook, KipLook(uncurl: model.look.uncurl, wearable: wearable))
                .frame(width: 52, height: 52)
                .padding(.top, 4)
                .background(Circle().fill(done ? Palette.butterSoft : Palette.ivoryDeep))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                .grayscale(done ? 0 : 1)
                .allowsHitTesting(false)
        } else {
            Image(systemName: StreakSymbol.freeze)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.petrol)
                .frame(width: 52, height: 52)
                .background(Circle().fill(done ? Palette.mint : Palette.ivoryDeep))
                .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
        }
    }
}
