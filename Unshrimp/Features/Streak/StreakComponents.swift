import SwiftUI

/// The streak's mark: a little wave, in Kip's coral once today is safe.
enum StreakSymbol {
    static let name = "water.waves"
    static let freeze = "shield.lefthalf.filled"
}

/// The streak counter at the top of Home. Coral once today has a break, quiet until then.
struct StreakBadge: View {
    var streak: Int
    var safe: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: StreakSymbol.name)
                    .font(.system(size: 15, weight: .heavy))
                    .symbolEffect(.bounce, value: safe)
                Text("\(streak)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(streak)))
            }
            .foregroundStyle(safe ? Palette.petrol : Palette.petrolSoft)
            .padding(.horizontal, 14)
            .frame(minWidth: 64, minHeight: 44)
            .background(Capsule().fill(safe ? Palette.coral : Palette.paper))
            .overlay(Capsule().strokeBorder(safe ? Palette.petrol : Palette.petrol.opacity(0.45), lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(streak == 1 ? String(localized: "1-day streak") : String(localized: "\(streak)-day streak")))
        .accessibilityValue(Text(safe ? String(localized: "Safe for today") : String(localized: "No break yet today")))
        .accessibilityHint(Text("Shows your streak calendar"))
    }
}

/// One day on the streak calendar or the week strip.
struct StreakDayDot: View {
    var kind: StreakDayKind
    var isToday: Bool
    var label: String? = nil
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            switch kind {
            case .done(let perfect):
                Circle().fill(Palette.coral)
                Circle().strokeBorder(Palette.petrol, lineWidth: perfect ? 3 : 2)
                content(Palette.petrol, symbol: label == nil ? StreakSymbol.name : nil)
            case .frozen:
                Circle().fill(Palette.mint)
                Circle().strokeBorder(Palette.petrol, lineWidth: 2)
                Image(systemName: StreakSymbol.freeze).font(.system(size: size * 0.38, weight: .bold)).foregroundStyle(Palette.petrol)
            case .repaired:
                Circle().fill(Palette.butter)
                Circle().strokeBorder(Palette.petrol, lineWidth: 2)
                Image(systemName: "arrow.uturn.backward").font(.system(size: size * 0.36, weight: .heavy)).foregroundStyle(Palette.petrol)
            case .missed:
                Circle().strokeBorder(Palette.petrol.opacity(0.3), lineWidth: 2)
                content(Palette.petrolSoft.opacity(0.8))
            case .rest:
                Circle().strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                content(Palette.petrolSoft.opacity(0.7))
            case .pending:
                Circle().fill(Palette.paper)
                Circle().strokeBorder(Palette.coral, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
                content(Palette.petrol)
            case .future, .before:
                content(Palette.petrolSoft.opacity(0.45))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if isToday { Circle().strokeBorder(Palette.coralDeep, lineWidth: 2).padding(-4) }
        }
    }

    @ViewBuilder private func content(_ color: Color, symbol: String? = nil) -> some View {
        if let label {
            Text(label).font(.system(size: size * 0.4, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(color)
        } else if let symbol {
            Image(systemName: symbol).font(.system(size: size * 0.38, weight: .heavy)).foregroundStyle(color)
        }
    }
}

/// The last seven days, ending today.
struct StreakWeekStrip: View {
    var days: [StreakWeekDay]
    /// Until true, today shows as it was before this break, so it can fill in on cue.
    var revealToday = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { d in
                VStack(spacing: 6) {
                    Text(d.day.date().formatted(.dateTime.weekday(.narrow)))
                        .font(.uMicro)
                        .foregroundStyle(d.isToday ? Palette.petrol : Palette.petrolSoft)
                    StreakDayDot(kind: d.isToday && !revealToday ? .pending : d.kind, isToday: d.isToday)
                        .scaleEffect(d.isToday && revealToday ? 1.08 : 1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(d.day.date().formatted(.dateTime.weekday(.wide))))
                .accessibilityValue(Text(d.kind.accessibilityValue))
            }
        }
    }
}

extension StreakDayKind {
    var accessibilityValue: String {
        switch self {
        case .done(let perfect): perfect ? String(localized: "Goal met") : String(localized: "Break done")
        case .frozen: String(localized: "Kept by a shell guard")
        case .repaired: String(localized: "Won back")
        case .missed: String(localized: "Missed")
        case .rest: String(localized: "Day off")
        case .pending: String(localized: "No break yet")
        case .future, .before: ""
        }
    }
}

/// Words for streak counts, so singular and plural read right in every language.
enum StreakCopy {
    static func daysInARow(_ n: Int) -> String {
        n == 1 ? String(localized: "day in a row") : String(localized: "days in a row")
    }

    static func days(_ n: Int) -> String {
        n == 1 ? String(localized: "1 day") : String(localized: "\(n) days")
    }

    static func guards(_ n: Int) -> String {
        n == 1 ? String(localized: "1 shell guard") : String(localized: "\(n) shell guards")
    }
}
