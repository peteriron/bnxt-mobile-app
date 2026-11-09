@testable import BNXT
import UIKit
import XCTest

final class ThemeTests: XCTestCase {
    func testDecodesBrandViolet() {
        let violet = RGB(hex: 0x6441FF)
        XCTAssertEqual(violet.red, 100.0 / 255)
        XCTAssertEqual(violet.green, 65.0 / 255)
        XCTAssertEqual(violet.blue, 1)
    }

    func testContrastRatioMatchesWCAGExtremes() {
        XCTAssertEqual(RGB(hex: 0xFFFFFF).contrast(with: RGB(hex: 0x000000)), 21, accuracy: 0.01)
        XCTAssertEqual(RGB(hex: 0x777777).contrast(with: RGB(hex: 0x777777)), 1, accuracy: 0.001)
    }

    func testParsesHexStrings() {
        XCTAssertEqual(RGB(hexString: "#6441FF"), RGB(hex: 0x6441FF))
        XCTAssertEqual(RGB(hexString: "e2ff00"), RGB(hex: 0xE2FF00))
        for bad in ["", "#FFF", "#GGGGGG", "#1234567", "red", "#+12345"] {
            XCTAssertNil(RGB(hexString: bad), bad)
        }
    }

    /// Every text token must clear WCAG AA (4.5:1) on the backgrounds it's used on.
    func testTextTokensClearAAContrast() {
        let texts: [(String, RGB)] = [
            ("textPrimary", .textPrimary), ("textSecondary", .textSecondary),
            ("textTertiary", .textTertiary), ("lime", .lime)
        ]
        for background in [RGB.ink, RGB.surface] {
            for (name, text) in texts {
                XCTAssertGreaterThanOrEqual(text.contrast(with: background), 4.5, "\(name) fails AA on \(background)")
            }
        }
    }

    /// Badge text (LIVE, W/L, Compare's "Change") sits on its own colour as a tint. The audit flagged LIVE at 4.46:1.
    /// Colours are listed here, not taken from Theme, so a changed token can't pass by changing both sides.
    func testBadgeTextClearsAAOnItsOwnTint() {
        // name: (text, tint)
        let badges: [String: (text: RGB, tint: RGB)] = [
            "live": (RGB(hex: 0xFF3B52), RGB(hex: 0xFF3B52)), "win": (RGB(hex: 0x3DDC97), RGB(hex: 0x3DDC97)),
            "loss": (RGB(hex: 0xFF5C74), RGB(hex: 0xFF5C74)), "compare first": (RGB(hex: 0xA08CFF), RGB(hex: 0x6441FF)),
            "compare second": (RGB(hex: 0xFF6A13), RGB(hex: 0xFF6A13))
        ]
        for background in [RGB.ink, RGB.surface] {
            for (name, badge) in badges {
                let fill = background.mixed(with: badge.tint, amount: Theme.badgeTintOpacity)
                XCTAssertGreaterThanOrEqual(badge.text.contrast(with: fill), 4.5, "\(name) badge on \(background)")
            }
        }
    }

    /// A face missing from UIAppFonts or the bundle makes SwiftUI fall back to the system font silently.
    func testEveryDisplayFaceIsBundledAndRegistered() {
        for face in DisplayFace.allCases {
            XCTAssertNotNil(UIFont(name: face.rawValue, size: 17), "\(face.rawValue) isn't registered")
        }
        let registered = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String] ?? []
        XCTAssertEqual(Set(registered).count, DisplayFace.allCases.count, "UIAppFonts and DisplayFace disagree")
    }
}
