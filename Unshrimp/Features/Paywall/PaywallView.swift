import SwiftUI

/// Hard paywall shown after onboarding. No close button: the app opens with an active
/// subscription or its free trial. Prices and the trial come from the App Store.
struct PaywallView: View {
    @State private var store = Subscription.shared
    @State private var selectedID: String?
    @State private var purchasing = false
    @Environment(\.openURL) private var openURL

    private var selected: Plan? {
        store.plans.first { $0.id == selectedID } ?? store.annual ?? store.monthly
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.xl) {
                    ShrimpStage(state: .inviting, backdrop: Palette.butterSoft)
                        .frame(maxWidth: .infinity)
                        .containerRelativeFrame(.vertical) { h, _ in h * 0.24 }
                        .accessibilityHidden(true)
                    header
                    if let days = selected?.trialDays {
                        TrialTimeline(days: days, price: selected?.price ?? "", kind: selected?.kind ?? .annual)
                    } else {
                        benefits
                    }
                    plans
                }
                .padding(.horizontal, Space.page)
                .padding(.top, Space.s)
                .padding(.bottom, Space.l)
            }
            .scrollBounceBehavior(.basedOnSize)
            actions
        }
        .background(Palette.ivory.ignoresSafeArea())
        .task { await store.loadPlans() }
        .alert("Something went wrong", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: Space.s) {
            Text("Unshrimp your workday")
                .font(.uTitle)
                .foregroundStyle(Palette.petrol)
                .accessibilityAddTraits(.isHeader)
            Text(selected?.trialDays.map { String(localized: "Try everything free for \($0) days.") }
                 ?? String(localized: "Every break, every move, and \(Brand.mascotName)'s whole desk."))
                .font(.uBody)
                .foregroundStyle(Palette.petrolSoft)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            benefit("bell.badge.fill", String(localized: "Gentle nudges that fit your workday"))
            benefit("figure.cooldown", String(localized: "Guided breaks for neck, shoulders and lower back"))
            benefit("sparkles", String(localized: "\(Brand.mascotName) grows, dresses up and builds a desk with you"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.petrol)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.coralSoft))
            Text(text).font(.uCallout.weight(.semibold)).foregroundStyle(Palette.petrol)
        }
    }

    @ViewBuilder private var plans: some View {
        if store.plans.isEmpty {
            VStack(spacing: Space.m) {
                if store.isLoading || store.errorMessage == nil {
                    ProgressView().tint(Palette.petrol)
                } else {
                    Text(store.errorMessage ?? "")
                        .font(.uCallout).foregroundStyle(Palette.petrolSoft)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.loadPlans() } }
                        .buttonStyle(.chunky(.secondary, compact: true))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: Space.m) {
                ForEach(store.plans) { plan in
                    PlanCard(plan: plan,
                             isSelected: plan.id == selected?.id,
                             savings: plan.kind == .annual ? store.annualSavingsPercent : nil) {
                        selectedID = plan.id
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Space.s) {
            Button {
                guard let plan = selected else { return }
                purchasing = true
                Task {
                    await store.purchase(plan)
                    purchasing = false
                }
            } label: {
                if purchasing {
                    ProgressView().tint(Palette.petrol)
                } else if let days = selected?.trialDays {
                    Text("Start my free \(days) days")
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.chunky)
            .disabled(selected == nil || purchasing)

            if let plan = selected {
                Text(finePrint(plan))
                    .font(.uCaption)
                    .foregroundStyle(Palette.petrolSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Space.l) {
                Button("Restore") {
                    purchasing = true
                    Task {
                        await store.restore()
                        purchasing = false
                    }
                }
                Button("Terms") { openURL(Billing.termsURL) }
                Button("Privacy") { openURL(Billing.privacyURL) }
            }
            .font(.uCaption)
            .foregroundStyle(Palette.petrolSoft)
            .disabled(purchasing)
            .frame(minHeight: 32)
        }
        .padding(.horizontal, Space.page)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(Palette.ivory)
    }

    private func finePrint(_ plan: Plan) -> String {
        let period = plan.kind == .annual ? String(localized: "per year") : String(localized: "per month")
        if let days = plan.trialDays {
            return String(localized: "\(days) days free, then \(plan.price) \(period). Cancel anytime in Settings.")
        }
        return String(localized: "\(plan.price) \(period). Renews automatically. Cancel anytime in Settings.")
    }

    private var errorShown: Binding<Bool> {
        // Load errors show inline under the plans; purchase and restore errors use the alert.
        Binding {
            store.errorMessage != nil && !store.plans.isEmpty
        } set: { shown in
            if !shown { store.errorMessage = nil }
        }
    }
}

// MARK: Plan card

private struct PlanCard: View {
    let plan: Plan
    let isSelected: Bool
    let savings: Int?
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: Space.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? Palette.coral : Palette.line)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.kind == .annual ? "Yearly" : "Monthly")
                        .font(.uHeadline)
                        .foregroundStyle(Palette.petrol)
                    if plan.kind == .annual, let perMonth = plan.pricePerMonth {
                        Text("Just \(perMonth) a month")
                            .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                    } else if let days = plan.trialDays {
                        Text("\(days)-day free trial")
                            .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                    }
                }
                Spacer(minLength: Space.s)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.uHeadline)
                        .foregroundStyle(Palette.petrol)
                    Text(plan.kind == .annual ? "per year" : "per month")
                        .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                }
            }
            .padding(Space.l)
            .background {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(isSelected ? Palette.paper : Palette.ivory)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .strokeBorder(isSelected ? Palette.petrol : Palette.line, lineWidth: Stroke.control)
                    )
            }
            .overlay(alignment: .topTrailing) {
                if let savings {
                    Text("Save \(savings)%")
                        .font(.uMicro)
                        .foregroundStyle(Palette.petrol)
                        .padding(.horizontal, Space.s)
                        .padding(.vertical, Space.xs)
                        .background(Capsule().fill(Palette.butter))
                        .overlay(Capsule().strokeBorder(Palette.petrol, lineWidth: 1.5))
                        .offset(x: -Space.l, y: -11)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Trial timeline

/// "Today / reminder / charge" timeline that most trial paywalls use to calm the fear of a surprise charge.
private struct TrialTimeline: View {
    let days: Int
    let price: String
    let kind: Plan.Kind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            step("lock.open.fill", Palette.coral,
                 String(localized: "Today"),
                 String(localized: "Full access: every break, \(Brand.mascotName)'s desk and wardrobe."), last: false)
            step("bell.fill", Palette.butter,
                 String(localized: "Day \(max(1, days - 1))"),
                 String(localized: "We'll remind you that your trial ends tomorrow."), last: false)
            step("star.fill", Palette.mint,
                 String(localized: "Day \(days)"),
                 kind == .annual
                    ? String(localized: "You're charged \(price) for the year. Cancel anytime before.")
                    : String(localized: "You're charged \(price) for the month. Cancel anytime before."),
                 last: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func step(_ icon: String, _ color: Color, _ title: String, _ text: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.petrol)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(color))
                    .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 1.5))
                if !last {
                    Rectangle().fill(Palette.line).frame(width: 3).frame(minHeight: 18)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.uHeadline).foregroundStyle(Palette.petrol)
                Text(text).font(.uCallout).foregroundStyle(Palette.petrolSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, last ? 0 : Space.m)
        }
        .accessibilityElement(children: .combine)
    }
}
