import SwiftUI

// MARK: Buttons

/// Sticker-style pill button: petrol outline with a lip that compresses when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    var kind: Kind = .primary
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let fill: Color = switch kind {
        case .primary: Palette.coral
        case .secondary: Palette.paper
        case .quiet: .clear
        }
        let shape = Capsule(style: .continuous)
        return configuration.label
            .font(compact ? .uCallout.weight(.bold) : .uHeadline)
            .foregroundStyle(kind == .quiet ? Palette.petrolSoft : Palette.petrol)
            .multilineTextAlignment(.center)
            .padding(.horizontal, compact ? Space.l : Space.xl)
            .padding(.vertical, compact ? Space.s : Space.m)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 56)
            .background {
                if kind != .quiet {
                    shape.fill(fill).overlay(shape.strokeBorder(Palette.petrol, lineWidth: Stroke.control))
                }
            }
            .offset(y: kind != .quiet && pressed ? 3 : 0)
            .background {
                if kind != .quiet { shape.fill(Palette.petrol).offset(y: 4) }
            }
            .padding(.bottom, kind != .quiet ? 4 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(shape)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: pressed) { _, new in new }
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }
    static func chunky(_ kind: ChunkyButtonStyle.Kind, compact: Bool = false) -> ChunkyButtonStyle {
        ChunkyButtonStyle(kind: kind, compact: compact)
    }
}

/// Small press-scale feedback for tappable cards and chips.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CircleIconButton: View {
    var systemName: String
    var label: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.petrol)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.paper))
                .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

// MARK: Selection

/// A large option row for single or multi select.
struct OptionCard<Leading: View>: View {
    var title: String
    var subtitle: String? = nil
    var isSelected: Bool
    var multi = false
    @ViewBuilder var leading: Leading
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.uHeadline).foregroundStyle(Palette.petrol)
                    if let subtitle {
                        Text(subtitle).font(.uCallout).foregroundStyle(Palette.petrolSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SelectionMark(isSelected: isSelected, multi: multi)
            }
            .padding(Space.l)
            .frame(minHeight: 64)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(isSelected ? Palette.coralSoft : Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(isSelected ? Palette.petrol : Palette.line, lineWidth: isSelected ? Stroke.control : 1.5))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(subtitle ?? ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension OptionCard where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, isSelected: Bool, multi: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, isSelected: isSelected, multi: multi, leading: { EmptyView() }, action: action)
    }
}

struct SelectionMark: View {
    var isSelected: Bool
    var multi = false

    var body: some View {
        ZStack {
            if multi {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Palette.coral : Palette.paper)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2))
            } else {
                Circle().fill(isSelected ? Palette.coral : Palette.paper)
                    .overlay(Circle().strokeBorder(Palette.petrol, lineWidth: 2))
            }
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Palette.petrol)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 28, height: 28)
        .animation(Motion.snappy, value: isSelected)
        .accessibilityHidden(true)
    }
}

/// Pill chip.
struct Chip: View {
    var title: String
    var systemImage: String? = nil
    var isSelected: Bool
    var stretch = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .bold)) }
                Text(title).font(.uCallout.weight(.bold))
            }
            .foregroundStyle(Palette.petrol)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, stretch ? 8 : 14)
            .frame(maxWidth: stretch ? .infinity : nil, minHeight: 44)
            .background(Capsule().fill(isSelected ? Palette.coralSoft : Palette.paper))
            .overlay(Capsule().strokeBorder(isSelected ? Palette.petrol : Palette.line, lineWidth: isSelected ? 2 : 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Wrapping row of chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Wrap against the width sizeThatFits measured with; bounds can be that measured width,
        // and rounding there used to push the last chip of a row onto its own line.
        let maxX = bounds.minX + max(proposal.width ?? bounds.width, bounds.width) + 0.5
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: Containers

struct CardBackground: ViewModifier {
    var fill: Color = Palette.paper
    func body(content: Content) -> some View {
        content
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))
    }
}

extension View {
    func card(_ fill: Color = Palette.paper) -> some View { modifier(CardBackground(fill: fill)) }
}

struct SectionLabel: View {
    var text: LocalizedStringKey
    var body: some View {
        Text(text)
            .font(.uMicro)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Palette.petrolSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Speech bubble with a tail pointing toward the mascot (bottom-right).
struct SpeechBubble: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.uCallout.weight(.semibold))
            .foregroundStyle(Palette.petrol)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(BubbleShape().fill(Palette.paper))
            .overlay(BubbleShape().stroke(Palette.petrol, style: StrokeStyle(lineWidth: 2, lineJoin: .round)))
            .padding(.bottom, 10)
            .id(text)
            .transition(.scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity))
    }
}

struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        var p = Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.maxX - 40, y: rect.maxY - 1))
        tail.addQuadCurve(to: CGPoint(x: rect.maxX - 18, y: rect.maxY + 10), control: CGPoint(x: rect.maxX - 26, y: rect.maxY + 6))
        tail.addLine(to: CGPoint(x: rect.maxX - 24, y: rect.maxY - 1))
        p.addPath(tail)
        return p.normalized()
    }
}

/// Segmented "1 of 3" progress.
struct ProgressPills: View {
    var done: Int
    var total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < done ? Palette.coral : Palette.ivoryDeep)
                    .overlay(Capsule().strokeBorder(Palette.petrol, lineWidth: i < done ? 2 : 0))
                    .frame(height: 14)
                    .animation(Motion.gentle.delay(Double(i) * 0.05), value: done)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(min(done, total)) of \(total) breaks"))
    }
}

/// Rounded energy bar.
struct EnergyBar: View {
    var value: Double  // 0...1
    var tint: Color = Palette.butter
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ivoryDeep)
                Capsule().fill(tint)
                    .frame(width: max(14, geo.size.width * min(max(value, 0), 1)))
                    .overlay(Capsule().strokeBorder(Palette.petrol, lineWidth: 2))
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}

