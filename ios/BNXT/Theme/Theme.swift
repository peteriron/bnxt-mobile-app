import SwiftUI

/// Design tokens (REQUIREMENTS.md §5.1). Views use these, never literal colours.
/// Dark mode only for v1 (§7.9).
enum Theme {
    // Background layers
    static let ink = RGB.ink.color
    static let surface = RGB.surface.color
    static let surface2 = RGB(hex: 0x1D1A28).color
    static let surface3 = RGB(hex: 0x29253A).color

    // Text levels
    static let textPrimary = RGB.textPrimary.color
    static let textSecondary = RGB.textSecondary.color
    static let textTertiary = RGB.textTertiary.color

    // Brand accents
    static let violet = RGB(hex: 0x6441FF).color
    static let violetHigh = RGB(hex: 0xA08CFF).color
    static let lime = RGB.lime.color
    static let orange = RGB(hex: 0xFF6A13).color

    // Semantic
    static let live = RGB(hex: 0xFF3B52).color
    static let win = RGB(hex: 0x3DDC97).color
    static let loss = RGB(hex: 0xFF5C74).color

    /// Wide italic display type for headlines and numbers. System font until the brand-font
    /// decision (§7.10) lands; then this becomes the bundled face. Scales with Dynamic Type.
    static func display(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .default).weight(.black).width(.expanded).italic()
    }

    static func score(_ style: Font.TextStyle = .largeTitle) -> Font {
        display(style).monospacedDigit()
    }
}

/// An sRGB colour from a 0xRRGGBB literal. Separate from `Color` so contrast is testable.
struct RGB: Hashable, Sendable {
    let red: Double, green: Double, blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    static let ink = RGB(hex: 0x07060B)
    static let surface = RGB(hex: 0x14121C)
    static let textPrimary = RGB(hex: 0xF5F3FB)
    static let textSecondary = RGB(hex: 0xA9A4BD)
    static let textTertiary = RGB(hex: 0x8A84A3)
    static let lime = RGB(hex: 0xE2FF00)

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    /// WCAG 2.x relative luminance.
    var luminance: Double {
        func channel(_ value: Double) -> Double { value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG contrast ratio between two colours (1...21).
    func contrast(with other: RGB) -> Double {
        let (lighter, darker) = luminance > other.luminance ? (self, other) : (other, self)
        return (lighter.luminance + 0.05) / (darker.luminance + 0.05)
    }
}
