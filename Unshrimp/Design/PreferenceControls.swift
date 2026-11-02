import SwiftUI

/// Preference controls shared by onboarding and settings.

struct DurationPicker: View {
    @Binding var selection: BreakLength

    var body: some View {
        HStack(spacing: Space.s) {
            ForEach(BreakLength.allCases) { length in
                let on = selection == length
                Button {
                    withAnimation(Motion.snappy) { selection = length }
                } label: {
                    VStack(spacing: 2) {
                        Text("\(length.minutes)").font(.uTitle).monospacedDigit()
                        Text("min").font(.uCaption)
                    }
                    .foregroundStyle(Palette.petrol)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(on ? Palette.coralSoft : Palette.paper))
                    .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .strokeBorder(on ? Palette.petrol : Palette.line, lineWidth: on ? Stroke.control : 1.5))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("\(length.minutes) minutes"))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct GoalStepper: View {
    @Binding var goal: Int

    var body: some View {
        HStack(spacing: Space.m) {
            stepButton("minus", label: "Fewer breaks", enabled: goal > Preferences.goalRange.lowerBound) { goal -= 1 }
            VStack(spacing: 0) {
                Text("\(goal)")
                    .font(.uDisplay)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(goal)))
                Text(goal == 1 ? "break a day" : "breaks a day")
                    .font(.uCaption)
                    .foregroundStyle(Palette.petrolSoft)
            }
            .foregroundStyle(Palette.petrol)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            stepButton("plus", label: "More breaks", enabled: goal < Preferences.goalRange.upperBound) { goal += 1 }
        }
        .sensoryFeedback(.selection, trigger: goal)
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: if goal < Preferences.goalRange.upperBound { goal += 1 }
            case .decrement: if goal > Preferences.goalRange.lowerBound { goal -= 1 }
            @unknown default: break
            }
        }
    }

    private func stepButton(_ icon: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.snappy) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .heavy))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.chunky(.secondary, compact: true))
        .frame(width: 64)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct WeekdayPicker: View {
    @Binding var days: Set<Int>

    var body: some View {
        let cal = Calendar.current
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = days.contains(day)
                Button {
                    withAnimation(Motion.snappy) {
                        if on { days.remove(day) } else { days.insert(day) }
                    }
                } label: {
                    Text(cal.veryShortWeekdaySymbols[day - 1])
                        .font(.uHeadline)
                        .foregroundStyle(Palette.petrol)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Circle().fill(on ? Palette.coral : Palette.paper))
                        .overlay(Circle().strokeBorder(on ? Palette.petrol : Palette.line, lineWidth: on ? 2 : 1.5))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text(cal.weekdaySymbols[day - 1]))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: days)
    }
}

struct TimeRangePicker: View {
    @Binding var start: Int
    @Binding var end: Int

    var body: some View {
        VStack(spacing: 0) {
            row(title: "Start", minute: $start)
            Divider().overlay(Palette.line)
            row(title: "Finish", minute: $end)
        }
        .padding(.horizontal, Space.l)
        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))
    }

    private func row(title: LocalizedStringKey, minute: Binding<Int>) -> some View {
        HStack {
            Text(title).font(.uHeadline).foregroundStyle(Palette.petrol)
            Spacer()
            DatePicker(title, selection: dateBinding(minute), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Palette.coral)
        }
        .frame(minHeight: 56)
    }

    private func dateBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minute.wrappedValue / 60, minute: minute.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        } set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            minute.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}

struct IntervalPicker: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: Space.s) {
            ForEach(WorkSchedule.intervalOptions, id: \.self) { m in
                Chip(title: label(m), isSelected: minutes == m, stretch: true) {
                    withAnimation(Motion.snappy) { minutes = m }
                }
            }
        }
    }

    private func label(_ m: Int) -> String {
        m % 60 == 0 ? String(localized: "\(m / 60) h") : String(localized: "\(m) min")
    }
}

struct FocusPicker: View {
    @Binding var selection: Set<FocusArea>

    var body: some View {
        FlowLayout(spacing: Space.s) {
            ForEach(FocusArea.allCases) { area in
                Chip(title: area.title, systemImage: area.symbol, isSelected: selection.contains(area)) {
                    withAnimation(Motion.snappy) { toggle(area) }
                }
            }
        }
    }

    private func toggle(_ area: FocusArea) {
        if selection.contains(area) {
            if selection.count > 1 { selection.remove(area) }
        } else {
            selection.insert(area)
        }
    }
}
