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

    /// Wide italic display type for headlines (Archivo Expanded Black Italic, §7.10).
    /// Scales with Dynamic Type relative to `style`. Body text stays on the system font.
    static func display(_ style: Font.TextStyle = .largeTitle) -> Font {
        .custom(DisplayFace.headline.rawValue, size: DisplayFace.baseSize(style), relativeTo: style)
    }

    /// Scores and big numbers (Archivo Expanded ExtraBold Italic) with tabular digits.
    static func score(_ style: Font.TextStyle = .largeTitle) -> Font {
        .custom(DisplayFace.number.rawValue, size: DisplayFace.baseSize(style), relativeTo: style).monospacedDigit()
    }

    /// Dense numbers where space is tight (Archivo SemiExpanded ExtraBold Italic): box scores, tables.
    static func compactNumber(_ style: Font.TextStyle = .body) -> Font {
        .custom(DisplayFace.compactNumber.rawValue, size: DisplayFace.baseSize(style), relativeTo: style).monospacedDigit()
    }
}

/// The bundled Archivo faces (SIL OFL 1.1, `Resources/Fonts/Archivo-OFL.txt`), by PostScript name.
/// Registered through `UIAppFonts` in project.yml; `ThemeTests` checks every face loads.
enum DisplayFace: String, CaseIterable {
    case headline = "ArchivoExpanded-BlackItalic"
    case number = "ArchivoExpanded-ExtraBoldItalic"
    case compactNumber = "ArchivoSemiExpanded-ExtraBoldItalic"

    /// Apple's default point sizes per text style at the standard Dynamic Type setting.
    private static let baseSizes: [Font.TextStyle: CGFloat] = [
        .largeTitle: 34, .title: 28, .title2: 22, .title3: 20, .headline: 17, .body: 17,
        .callout: 16, .subheadline: 15, .footnote: 13, .caption: 12, .caption2: 11
    ]

    static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        baseSizes[style] ?? 17
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

    /// "#RRGGBB" (as in the remote config's club colours); nil for anything else.
    init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? hexString.dropFirst() : Substring(hexString)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else { return nil }
        self.init(hex: value)
    }

    static let ink = RGB(hex: 0x07060B)
    static let surface = RGB(hex: 0x14121C)
    static let textPrimary = RGB(hex: 0xF5F3FB)
    static let textSecondary = RGB(hex: 0xA9A4BD)
    static let textTertiary = RGB(hex: 0x8A84A3)
    static let lime = RGB(hex: 0xE2FF00)

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    /// Mixes towards white until the colour reaches `ratio` against `background` (WCAG non-text contrast is 3:1).
    /// Colours that already reach it come back unchanged. Used for club colours in graphics (REQUIREMENTS §5.1).
    func lifted(toContrast ratio: Double = 3, against background: RGB = .ink) -> RGB {
        guard contrast(with: background) < ratio else { return self }
        var low = 0.0, high = 1.0
        for _ in 0..<20 { // binary search on the mix amount; 20 steps is far below one 8-bit step
            let mid = (low + high) / 2
            if mixed(with: .white, amount: mid).contrast(with: background) < ratio { low = mid } else { high = mid }
        }
        return mixed(with: .white, amount: high)
    }

    func mixed(with other: RGB, amount: Double) -> RGB {
        RGB(red: red + (other.red - red) * amount, green: green + (other.green - green) * amount, blue: blue + (other.blue - blue) * amount)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    static let white = RGB(hex: 0xFFFFFF)
    static let violet = RGB(hex: 0x6441FF)

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
