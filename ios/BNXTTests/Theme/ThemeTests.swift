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

    /// A face missing from UIAppFonts or the bundle makes SwiftUI fall back to the system font silently.
    func testEveryDisplayFaceIsBundledAndRegistered() {
        for face in DisplayFace.allCases {
            XCTAssertNotNil(UIFont(name: face.rawValue, size: 17), "\(face.rawValue) isn't registered")
        }
        let registered = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String] ?? []
        XCTAssertEqual(Set(registered).count, DisplayFace.allCases.count, "UIAppFonts and DisplayFace disagree")
    }
}
