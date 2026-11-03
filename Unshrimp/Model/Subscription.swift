import Foundation
import Observation
import RevenueCat
import UserNotifications

/// Store settings. The RevenueCat public key is safe to ship in the app.
enum Billing {
    /// RevenueCat → Project settings → API keys → the App Store public key ("appl_…").
    static let revenueCatAPIKey = "appl_REPLACE_WITH_REVENUECAT_PUBLIC_KEY"
    /// RevenueCat entitlement that unlocks the app.
    static let entitlement = "pro"
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    // TODO: replace with the real privacy policy before submitting.
    static let privacyURL = URL(string: "https://unshrimp.app/privacy")!

    static var isConfigured: Bool { !revenueCatAPIKey.contains("REPLACE") }
}

/// One plan on the paywall, read from the App Store through RevenueCat so prices and
/// trials can change in App Store Connect without a new build.
struct Plan: Identifiable, Equatable {
    enum Kind { case annual, monthly }
    let kind: Kind
    let package: Package
    /// Free trial length in days, when this person can still get one.
    let trialDays: Int?

    var id: String { package.identifier }
    var price: String { package.storeProduct.localizedPriceString }
    var pricePerMonth: String? { package.storeProduct.localizedPricePerMonth }
    var decimalPrice: Decimal { package.storeProduct.price }

    static func == (a: Plan, b: Plan) -> Bool { a.id == b.id && a.trialDays == b.trialDays }
}

/// Unshrimp has a hard paywall: after onboarding, nothing opens without an active
/// subscription (or its free trial).
@MainActor
@Observable
final class Subscription {
    static let shared = Subscription()

    /// Cached so a subscriber never sees the paywall flash on a cold start.
    private(set) var isActive = false
    private(set) var annual: Plan?
    private(set) var monthly: Plan?
    private(set) var isLoading = false
    var errorMessage: String?

    private static let activeKey = "subscription.active"
    private static let trialReminderID = "unshrimp.trial-ending"

    private init() {
        isActive = UserDefaults.standard.bool(forKey: Self.activeKey)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        // Lets UI tests and screenshots skip the store; -testPaywall forces it on.
        if args.contains("-skipPaywall") { isActive = true; return }
        if args.contains("-testPaywall") { isActive = false }
        // Until the RevenueCat key is in, debug builds behave as subscribed so development isn't blocked.
        else if !Billing.isConfigured { isActive = true; return }
        #endif
        guard Billing.isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .info
        #endif
        Purchases.configure(withAPIKey: Billing.revenueCatAPIKey)
        Task { await listen() }
    }

    var plans: [Plan] { [annual, monthly].compactMap { $0 } }

    /// "Save 64%" for the annual plan against twelve months of the monthly one.
    var annualSavingsPercent: Int? {
        guard let a = annual?.decimalPrice, let m = monthly?.decimalPrice, m > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: a / (m * 12)).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded())
        return percent >= 5 ? percent : nil
    }

    // MARK: Loading

    func loadPlans() async {
        guard Billing.isConfigured else {
            errorMessage = String(localized: "The store isn't set up yet (missing RevenueCat key).")
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                errorMessage = String(localized: "Plans aren't available right now. Please try again in a moment.")
                return
            }
            let packages = [offering.annual, offering.monthly].compactMap { $0 }
            let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: packages)
            func plan(_ package: Package?, _ kind: Plan.Kind) -> Plan? {
                guard let package else { return nil }
                let eligible = eligibility[package]?.status != .ineligible
                return Plan(kind: kind, package: package, trialDays: eligible ? Self.trialDays(package.storeProduct) : nil)
            }
            annual = plan(offering.annual, .annual)
            monthly = plan(offering.monthly, .monthly)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't reach the App Store. Check your connection and try again.")
        }
    }

    private static func trialDays(_ product: StoreProduct) -> Int? {
        guard let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
    }

    // MARK: Buying

    /// Returns true when the purchase unlocked the app.
    @discardableResult
    func purchase(_ plan: Plan) async -> Bool {
        do {
            let result = try await Purchases.shared.purchase(package: plan.package)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            return isActive
        } catch let error as RevenueCat.ErrorCode where error == .purchaseCancelledError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            if !isActive {
                errorMessage = String(localized: "No active subscription found for this Apple ID.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Updates

    private func listen() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Billing.entitlement]
        let active = entitlement?.isActive == true
        let changed = active != isActive
        isActive = active
        UserDefaults.standard.set(active, forKey: Self.activeKey)
        if changed {
            Task { await AppModel.shared.rescheduleReminders() }
        }
        Task { await updateTrialReminder(entitlement) }
    }

    /// The paywall promises a heads-up the day before the trial converts; this keeps that promise.
    private func updateTrialReminder(_ entitlement: EntitlementInfo?) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.trialReminderID])
        guard let entitlement, entitlement.isActive, entitlement.periodType == .trial,
              entitlement.willRenew, let end = entitlement.expirationDate else { return }
        let fireDate = end.addingTimeInterval(-24 * 3600)
        guard fireDate > Date() else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your free trial ends tomorrow")
        content.body = String(localized: "\(Brand.mascotName) is glad you're here. You can manage your plan anytime in Settings.")
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.trialReminderID, content: content, trigger: trigger))
    }
}
