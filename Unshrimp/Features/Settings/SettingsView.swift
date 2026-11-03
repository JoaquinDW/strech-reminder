import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmReset = false
    @State private var testSent = false
    @State private var showManageSubscription = false
    @State private var restoring = false
    @State private var subscription = Subscription.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    remindersSection
                    scheduleSection
                    breaksSection
                    subscriptionSection
                    aboutSection
                }
                .padding(Space.page)
            }
            .background(Palette.ivory.ignoresSafeArea())
            .navigationTitle("Reminders & breaks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(.uHeadline).tint(Palette.petrol)
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    model.resetEverything()
                    dismiss()
                }
            } message: {
                Text("This clears your breaks, energy and desk items, and restarts onboarding.")
            }
        }
        .task { await model.refreshNotificationStatus() }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding { model.prefs[keyPath: keyPath] } set: { v in model.updatePrefs { $0[keyPath: keyPath] = v } }
    }

    // MARK: Sections

    private var remindersSection: some View {
        VStack(spacing: Space.s) {
            SectionLabel(text: "Reminders")
            VStack(alignment: .leading, spacing: Space.m) {
                Toggle(isOn: binding(\.remindersEnabled)) {
                    Text("Movement reminders").font(.uHeadline).foregroundStyle(Palette.petrol)
                }
                .tint(Palette.coral)
                permissionRow
            }
            .card()
        }
    }

    @ViewBuilder private var permissionRow: some View {
        switch model.notificationStatus {
        case .denied:
            VStack(alignment: .leading, spacing: Space.s) {
                Label("Notifications are turned off for \(Brand.appName) in iOS Settings, so reminders can't appear. Breaks still work from the app.", systemImage: "bell.slash")
                    .font(.uCallout)
                    .foregroundStyle(Palette.petrol)
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.chunky(.secondary, compact: true))
            }
        case .notDetermined:
            VStack(alignment: .leading, spacing: Space.s) {
                Text("\(Brand.mascotName) needs permission to send reminders.")
                    .font(.uCallout).foregroundStyle(Palette.petrolSoft)
                Button("Allow notifications") { Task { await model.requestNotifications() } }
                    .buttonStyle(.chunky(.primary, compact: true))
            }
        default:
            HStack {
                Label(model.prefs.remindersEnabled ? LocalizedStringKey("Notifications allowed") : LocalizedStringKey("Allowed, but paused"), systemImage: "checkmark.circle.fill")
                    .font(.uCallout.weight(.semibold))
                    .foregroundStyle(Palette.mintDeep)
                Spacer()
                Button(testSent ? LocalizedStringKey("Sent!") : LocalizedStringKey("Test in 5 s")) {
                    Task {
                        await model.sendTestReminder()
                        testSent = true
                        try? await Task.sleep(for: .seconds(3))
                        testSent = false
                    }
                }
                .buttonStyle(.chunky(.secondary, compact: true))
                .disabled(testSent)
                .accessibilityHint(Text("Sends a sample reminder in five seconds. Lock the phone or leave the app to see it."))
            }
        }
    }

    private var scheduleSection: some View {
        VStack(spacing: Space.s) {
            SectionLabel(text: "Workdays and hours")
            VStack(spacing: Space.l) {
                WeekdayPicker(days: binding(\.schedule.workdays))
                TimeRangePicker(start: binding(\.schedule.startMinute), end: binding(\.schedule.endMinute))
                VStack(spacing: Space.s) {
                    SectionLabel(text: "Nudge every")
                    IntervalPicker(minutes: binding(\.schedule.intervalMinutes))
                }
                if let next = model.nextReminder() {
                    Text("Next nudge \(ReminderPlanner.describe(next))")
                        .font(.uCallout.weight(.semibold)).foregroundStyle(Palette.petrolSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()
        }
    }

    private var breaksSection: some View {
        VStack(spacing: Space.s) {
            SectionLabel(text: "Breaks")
            VStack(spacing: Space.l) {
                DurationPicker(selection: binding(\.breakLength))
                GoalStepper(goal: binding(\.dailyGoal))
                VStack(spacing: Space.s) {
                    SectionLabel(text: "Focus areas")
                    FocusPicker(selection: binding(\.focusAreas))
                }
            }
            .card()
        }
    }

    private var subscriptionSection: some View {
        VStack(spacing: Space.s) {
            SectionLabel(text: "Subscription")
            VStack(alignment: .leading, spacing: Space.m) {
                Button("Manage subscription") { showManageSubscription = true }
                    .buttonStyle(.chunky(.secondary, compact: true))
                Button(restoring ? LocalizedStringKey("Restoring…") : LocalizedStringKey("Restore purchases")) {
                    restoring = true
                    Task {
                        await subscription.restore()
                        restoring = false
                    }
                }
                .font(.uCallout.weight(.bold))
                .foregroundStyle(Palette.petrol)
                .frame(minHeight: 44)
                .disabled(restoring)
                if let message = subscription.errorMessage {
                    Text(message).font(.uCallout).foregroundStyle(Palette.coralDeep)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private var aboutSection: some View {
        VStack(spacing: Space.s) {
            SectionLabel(text: "About")
            VStack(alignment: .leading, spacing: Space.m) {
                Text(DemoLibrary.disclaimer).font(.uCallout).foregroundStyle(Palette.petrolSoft)
                Button("Replay onboarding") {
                    model.replayOnboarding()
                    dismiss()
                }
                .buttonStyle(.chunky(.secondary, compact: true))
                Button("Reset all progress", role: .destructive) { confirmReset = true }
                    .font(.uCallout.weight(.bold))
                    .foregroundStyle(Palette.coralDeep)
                    .frame(minHeight: 44)
            }
            .card()
        }
    }
}
