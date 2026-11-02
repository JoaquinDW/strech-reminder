import SwiftUI

private struct ExerciseMotionOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Deterministic UI-test override; the system's Reduce Motion setting always wins.
    var exerciseMotionOverride: Bool {
        get { self[ExerciseMotionOverrideKey.self] }
        set { self[ExerciseMotionOverrideKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Design tokens: colors.
enum Palette {
    static let ivory = Color(hex: 0xFBF5EA)
    static let ivoryDeep = Color(hex: 0xF3E6CF)
    static let paper = Color(hex: 0xFFFCF6)
    static let wall = Color(hex: 0xFFF3DA)

    static let coral = Color(hex: 0xFF7A66)
    static let coralDeep = Color(hex: 0xE5543F)
    static let coralSoft = Color(hex: 0xFFDCD3)

    static let petrol = Color(hex: 0x1D4550)
    /// Secondary text. 5:1+ on ivory.
    static let petrolSoft = Color(hex: 0x4A6A72)
    static let petrolFaint = Color(hex: 0x1D4550, opacity: 0.12)

    static let mint = Color(hex: 0xA9E3CF)
    static let mintSoft = Color(hex: 0xDDF3EA)
    static let mintDeep = Color(hex: 0x2F8A6F)
    static let butter = Color(hex: 0xFFDD85)
    static let butterSoft = Color(hex: 0xFFF1C7)
    static let blush = Color(hex: 0xFF9FB0)

    static let line = Color(hex: 0xE8DAC2)

    // Illustration-only colors
    static let shrimp = Color(hex: 0xFF7A66)
    static let shrimpDeep = Color(hex: 0xE5543F)
    static let wood = Color(hex: 0xF2C185)
    static let woodDeep = Color(hex: 0xD99B5B)
    static let floor = Color(hex: 0xF4E3C6)
    static let laptop = Color(hex: 0x9FB3B8)
    static let laptopLid = Color(hex: 0x5E7F88)
    static let terracotta = Color(hex: 0xF09A7E)
    static let leaf = Color(hex: 0x7CCBA9)
}

/// Design tokens: type. All styles are rounded and scale with Dynamic Type.
extension Font {
    static let uDisplay = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let uTitle = Font.system(.title, design: .rounded, weight: .heavy)
    static let uTitle2 = Font.system(.title2, design: .rounded, weight: .bold)
    static let uHeadline = Font.system(.headline, design: .rounded, weight: .bold)
    static let uBody = Font.system(.body, design: .rounded, weight: .medium)
    static let uCallout = Font.system(.callout, design: .rounded, weight: .medium)
    static let uCaption = Font.system(.footnote, design: .rounded, weight: .semibold)
    static let uMicro = Font.system(.caption2, design: .rounded, weight: .bold)
}

/// Design tokens: spacing and shape.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Horizontal page gutter.
    static let page: CGFloat = 20
}

enum Radius {
    static let card: CGFloat = 28
    static let tile: CGFloat = 20
    static let chip: CGFloat = 999
    static let button: CGFloat = 999
}

enum Stroke {
    /// Outline weight used by controls so they match the illustration line.
    static let control: CGFloat = 2.5
}

enum Motion {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.85)
}
