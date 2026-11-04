import SwiftUI

/// The moment the streak grows: the count rolls over, Kip hops, today fills in on the week.
/// Shown before the energy screen on the day's first break, on milestones and on a won-back streak.
struct StreakCelebrationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let update: StreakUpdate
    var done: () -> Void

    @State private var shown: Int
    @State private var revealToday = false
    @State private var bump = 0
    @State private var showExtras = false
    @State private var confetti = 0
    @State private var revealAt = Date().timeIntervalSinceReferenceDate + 1.4

    init(update: StreakUpdate, done: @escaping () -> Void) {
        self.update = update
        self.done = done
        _shown = State(initialValue: update.before)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.l) {
                    ZStack {
                        ShrimpStage(state: .celebrating, backdrop: Palette.coralSoft)
                            .frame(height: 200)
                            .environment(\.kipLook, look)
                        ConfettiBurst(trigger: confetti)
                    }

                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: Space.s) {
                            Image(systemName: StreakSymbol.name)
                                .font(.system(size: 44, weight: .heavy))
                                .foregroundStyle(Palette.coralDeep)
                                .symbolEffect(.bounce, value: bump)
                            Text("\(shown)")
                                .font(.system(size: 92, weight: .heavy, design: .rounded))
                                .foregroundStyle(Palette.petrol)
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(shown)))
                        }
                        .scaleEffect(bump > 0 || reduceMotion ? 1 : 0.86)
                        Text(StreakCopy.daysInARow(update.after))
                            .font(.uTitle2)
                            .foregroundStyle(Palette.petrol)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(update.after) \(StreakCopy.daysInARow(update.after))"))

                    VStack(spacing: Space.xs) {
                        Text(headline)
                            .font(.uHeadline)
                            .foregroundStyle(Palette.coralDeep)
                        Text(subline)
                            .font(.uCallout)
                            .foregroundStyle(Palette.petrolSoft)
                    }
                    .multilineTextAlignment(.center)

                    StreakWeekStrip(days: update.week, revealToday: revealToday)
                        .card()

                    if showExtras {
                        extras.transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Space.page)
                .padding(.vertical, Space.m)
            }
            Button("Continue", action: done)
                .buttonStyle(.chunky)
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.s)
                .accessibilityIdentifier("streak-continue")
        }
        .background(Palette.ivory.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .heavy), trigger: bump)
        .sensoryFeedback(.success, trigger: showExtras) { _, new in new && update.milestone != nil }
        .task { await play() }
    }

    private var look: KipLook {
        var look = model.look
        if update.newWearable != nil, !reduceMotion { look.revealAt = revealAt }
        return look
    }

    private var headline: String {
        if let m = update.milestone { return String(localized: "\(m)-day milestone!") }
        if update.repaired { return String(localized: "Streak won back!") }
        if update.isNewBest { return String(localized: "Your longest streak yet") }
        if update.after == 1 { return String(localized: "A new streak begins") }
        let lines = [
            String(localized: "\(Brand.mascotName) is on a roll"),
            String(localized: "Another day, another uncurl"),
            String(localized: "Look at us showing up"),
            String(localized: "The streak grows")
        ]
        return lines[update.after % lines.count]
    }

    private var subline: String {
        if update.repaired {
            return String(localized: "Today's goal brought back the missed day. Nicely done.")
        }
        guard let next = StreakRules.nextMilestone(after: update.after) else {
            return String(localized: "Every milestone reached. \(Brand.mascotName) is speechless.")
        }
        let left = next - update.after
        return left == 1
            ? String(localized: "One more day to the \(next)-day milestone.")
            : String(localized: "\(left) more days to the \(next)-day milestone.")
    }

    @ViewBuilder private var extras: some View {
        VStack(spacing: Space.m) {
            if let wearable = update.newWearable {
                HStack(spacing: Space.l) {
                    ShrimpView(state: .inviting)
                        .environment(\.kipLook, KipLook(uncurl: model.look.uncurl, wearable: wearable))
                        .frame(width: 76, height: 76)
                        .padding(.top, 6)
                        .background(Circle().fill(Palette.paper))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Streak reward").font(.uMicro).textCase(.uppercase).tracking(1).foregroundStyle(Palette.coralDeep)
                        Text(wearable.title).font(.uTitle2).foregroundStyle(Palette.petrol)
                        Text(wearable.blurb).font(.uCallout).foregroundStyle(Palette.petrolSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .card(Palette.butterSoft)
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2.5))
                .accessibilityElement(children: .combine)
            }
            if update.milestone != nil {
                HStack(spacing: Space.m) {
                    Image(systemName: StreakSymbol.freeze)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.petrol)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.mint))
                        .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(update.freezesEarned > 0
                             ? String(localized: "+\(update.freezesEarned) shell guard")
                             : String(localized: "Shell guards full"))
                            .font(.uHeadline).foregroundStyle(Palette.petrol)
                        Text("If you miss a workday, a shell guard keeps the streak going.")
                            .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .card(Palette.mintSoft)
                .accessibilityElement(children: .combine)
            }
            if update.isNewBest && update.milestone == nil {
                Label(String(localized: "New best: \(StreakCopy.days(update.best))"), systemImage: "trophy.fill")
                    .font(.uCallout.weight(.bold))
                    .foregroundStyle(Palette.petrol)
            }
        }
    }

    private func play() async {
        if reduceMotion {
            shown = update.after
            revealToday = true
            showExtras = true
            bump = 1
            return
        }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
            shown = update.after
            bump += 1
        }
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { revealToday = true }
        if update.milestone != nil || update.repaired || update.isNewBest {
            try? await Task.sleep(for: .milliseconds(250))
            confetti += 1
            revealAt = Date().timeIntervalSinceReferenceDate + 0.3
            withAnimation(Motion.gentle) { showExtras = true }
        }
    }
}
