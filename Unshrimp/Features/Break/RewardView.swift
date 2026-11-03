import SwiftUI

/// Short celebration after a confirmed break: energy, bonuses, unlocks, then back to work.
struct RewardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: BreakResult
    var done: () -> Void

    @State private var shownEnergy = 0
    @State private var shownLines = 0
    @State private var barValue: Double = 0
    @State private var revealUnlock = false
    /// When the new wearable drops onto Kip's head at the top of the screen.
    @State private var revealAt = Date().timeIntervalSinceReferenceDate + 0.9

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.l) {
                    ZStack {
                        ShrimpStage(state: .celebrating, backdrop: Palette.butterSoft)
                            .frame(height: 220)
                            .environment(\.kipLook, stageLook)
                        ConfettiBurst(trigger: result.energyAfter)
                    }

                    VStack(spacing: 2) {
                        Text("+\(shownEnergy)")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.coralDeep)
                            .contentTransition(.numericText(value: Double(shownEnergy)))
                            .monospacedDigit()
                        Text("energy for \(Brand.mascotName)'s world")
                            .font(.uHeadline)
                            .foregroundStyle(Palette.petrol)
                    }
                    .accessibilityElement(children: .combine)

                    VStack(spacing: Space.s) {
                        ForEach(Array(result.lines.enumerated()), id: \.element.id) { i, line in
                            if i < shownLines {
                                HStack {
                                    Text(line.label).font(.uCallout.weight(.semibold))
                                    Spacer()
                                    Text("+\(line.amount)").font(.uCallout.weight(.heavy)).monospacedDigit()
                                }
                                .foregroundStyle(Palette.petrol)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .card()

                    if let stage = result.newStage {
                        growthCard(stage)
                    }

                    if let item = result.newlyUnlocked.first {
                        unlockCard(item)
                    } else if let next = model.nextItem {
                        nextCard(next)
                    }

                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack {
                            Text("Today").font(.uHeadline).foregroundStyle(Palette.petrol)
                            Spacer()
                            Text("\(result.breaksToday) of \(result.goal) breaks")
                                .font(.uCallout.weight(.bold)).foregroundStyle(Palette.petrolSoft)
                        }
                        ProgressPills(done: result.breaksToday, total: result.goal)
                        if result.reachedGoalNow {
                            Label(result.adventureStop > 0
                                  ? String(localized: "Goal reached! \(Brand.mascotName) hops to \(Adventure.stops[result.adventureStop - 1]).")
                                  : String(localized: "Daily goal reached!"),
                                  systemImage: "map.fill")
                                .font(.uCallout.weight(.semibold))
                                .foregroundStyle(Palette.mintDeep)
                        } else if result.breaksToday < result.goal {
                            Text("Spread the next one out a little. \(Brand.mascotName) will wave.")
                                .font(.uCaption.weight(.medium))
                                .foregroundStyle(Palette.petrolSoft)
                        }
                        if result.newStage == nil, let hint = model.growth.nextHint {
                            Label(String(localized: "\(Brand.mascotName) uncurls a bit with every break. \(hint)."), systemImage: "arrow.up.forward")
                                .font(.uCaption.weight(.medium))
                                .foregroundStyle(Palette.petrolSoft)
                        }
                    }
                    .card()
                }
                .padding(.horizontal, Space.page)
                .padding(.vertical, Space.m)
            }
            Button("Back to work", action: done)
                .buttonStyle(.chunky)
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.s)
        }
        .sensoryFeedback(.success, trigger: shownEnergy > 0)
        .sensoryFeedback(.impact(weight: .heavy), trigger: revealUnlock && result.newStage != nil)
        .task { await play() }
    }

    private var stageLook: KipLook {
        var look = model.look
        if result.newWearable != nil, !reduceMotion { look.revealAt = revealAt }
        return look
    }

    private func growthCard(_ stage: Int) -> some View {
        HStack(spacing: Space.l) {
            ShrimpView(state: .inviting)
                .frame(width: 76, height: 76)
                .padding(.top, 6)
                .background(Circle().fill(Palette.paper))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                .scaleEffect(revealUnlock ? 1 : 0.2)
                .rotationEffect(.degrees(revealUnlock ? 0 : 25))
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Brand.mascotName) uncurled a little more").font(.uMicro).textCase(.uppercase).tracking(1).foregroundStyle(Palette.coralDeep)
                Text(KipGrowth.title(stage)).font(.uTitle2).foregroundStyle(Palette.petrol)
                if let wearable = result.newWearable {
                    Text("New to wear: \(wearable.title). \(wearable.blurb)")
                        .font(.uCallout).foregroundStyle(Palette.petrolSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .card(Palette.butterSoft)
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2.5))
        .accessibilityElement(children: .combine)
    }

    private func unlockCard(_ item: DeskItem) -> some View {
        HStack(spacing: Space.l) {
            DeskItemIcon(item: item)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Palette.mintSoft))
                .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
                .scaleEffect(revealUnlock ? 1 : 0.2)
                .rotationEffect(.degrees(revealUnlock ? 0 : -25))
            VStack(alignment: .leading, spacing: 4) {
                Text("Unlocked for the desk").font(.uMicro).textCase(.uppercase).tracking(1).foregroundStyle(Palette.mintDeep)
                Text(item.title).font(.uTitle2).foregroundStyle(Palette.petrol)
                Text(item.blurb).font(.uCallout).foregroundStyle(Palette.petrolSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .card(Palette.mintSoft)
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2.5))
        .accessibilityElement(children: .combine)
    }

    private func nextCard(_ item: DeskItem) -> some View {
        let p = model.progress(toward: item)
        return HStack(spacing: Space.l) {
            DeskItemIcon(item: item, locked: true)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Palette.ivoryDeep))
            VStack(alignment: .leading, spacing: 6) {
                Text("Next for the desk: \(item.title)").font(.uHeadline).foregroundStyle(Palette.petrol)
                EnergyBar(value: barValue)
                Text("\(p.current) of \(p.needed) energy").font(.uCaption).foregroundStyle(Palette.petrolSoft).monospacedDigit()
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func play() async {
        let next = model.nextItem.map { model.progress(toward: $0) }
        let target = next.map { Double($0.current) / Double(max(1, $0.needed)) } ?? 1
        if reduceMotion {
            shownEnergy = result.earned
            shownLines = result.lines.count
            barValue = target
            revealUnlock = true
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.snappy(duration: 0.6)) { shownEnergy = result.earned }
        for i in 1...result.lines.count {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(Motion.snappy) { shownLines = i }
        }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { revealUnlock = true }
        withAnimation(.easeOut(duration: 0.9)) { barValue = target }
    }
}
