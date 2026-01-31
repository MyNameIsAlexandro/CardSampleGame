import XCTest

/// WCAG 2.1 Contrast Compliance Gate Tests
/// Verifies all text-on-background color pairs meet minimum contrast ratios.
/// AA standard: ≥ 4.5:1 normal text, ≥ 3.0:1 large text (≥18pt bold / ≥24pt).
/// Gate rules: pure math, no UI framework, < 2s.
final class ContrastComplianceTests: XCTestCase {

    // MARK: - WCAG Math

    /// Linearize an sRGB component (0…1) per WCAG 2.1
    private func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Relative luminance per WCAG 2.1
    private func luminance(r: Double, g: Double, b: Double) -> Double {
        0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// Contrast ratio per WCAG 2.1 (always ≥ 1)
    private func contrastRatio(fg: (Double, Double, Double), bg: (Double, Double, Double)) -> Double {
        let lFg = luminance(r: fg.0, g: fg.1, b: fg.2)
        let lBg = luminance(r: bg.0, g: bg.1, b: bg.2)
        let lighter = max(lFg, lBg)
        let darker = min(lFg, lBg)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Color Definitions (mirrors AppColors in DesignSystem.swift)

    // Backgrounds
    let backgroundSystem = (0.08, 0.06, 0.10)
    let backgroundTertiary = (0.12, 0.10, 0.15)
    let cardBackground = (0.14, 0.12, 0.18)

    // Text / foreground colors
    let colors: [(String, (Double, Double, Double))] = [
        // Primary actions
        ("primary", (0.85, 0.65, 0.20)),
        ("secondary", (0.58, 0.53, 0.63)),
        // Game states
        ("success", (0.20, 0.62, 0.30)),
        ("warning", (0.90, 0.60, 0.15)),
        ("danger", (0.90, 0.35, 0.35)),
        ("info", (0.40, 0.60, 0.90)),
        // Theme
        ("light", (0.95, 0.85, 0.50)),
        ("dark", (0.65, 0.45, 0.80)),
        ("neutral", (0.62, 0.60, 0.57)),
        // Resonance
        ("resonanceNav", (0.68, 0.45, 0.85)),
        ("resonancePrav", (0.85, 0.70, 0.20)),
        ("resonanceYav", (0.62, 0.60, 0.57)),
        ("spirit", (0.40, 0.58, 0.95)),
        // Resources
        ("health", (0.90, 0.35, 0.35)),
        ("faith", (0.90, 0.75, 0.25)),
        ("power", (0.90, 0.48, 0.20)),
        ("defense", (0.40, 0.55, 0.80)),
        // UI
        ("highlight", (0.90, 0.75, 0.30)),
        ("muted", (0.65, 0.60, 0.65)),
        // Rarity
        ("rarityCommon", (0.65, 0.62, 0.60)),
        ("rarityUncommon", (0.20, 0.65, 0.35)),
        ("rarityRare", (0.35, 0.55, 0.90)),
        ("rarityEpic", (0.70, 0.42, 0.90)),
        ("rarityLegendary", (0.90, 0.65, 0.15)),
        // Card types
        ("cardTypeItem", (0.70, 0.50, 0.30)),
        ("cardTypeLocation", (0.30, 0.65, 0.70)),
        ("cardTypeScenario", (0.58, 0.48, 0.92)),
        ("cardTypeCurse", (0.80, 0.45, 0.45)),
        ("cardTypeSpirit", (0.30, 0.75, 0.85)),
        ("cardTypeRitual", (0.58, 0.48, 0.92)),
        ("cardTypeResource", (0.82, 0.45, 0.62)),
    ]

    // Colors used only at large sizes (headlines, titles) — 3:1 threshold
    let largeTextOnly: Set<String> = []

    // MARK: - Tests

    func test_allTextColors_meetAA_onCardBackground() {
        var failures: [(String, Double)] = []

        for (name, rgb) in colors {
            let ratio = contrastRatio(fg: rgb, bg: cardBackground)
            let threshold: Double = largeTextOnly.contains(name) ? 3.0 : 4.5
            if ratio < threshold {
                failures.append((name, ratio))
            }
        }

        if !failures.isEmpty {
            let msg = failures.map { "  \($0.0): \(String(format: "%.2f", $0.1)):1 (need ≥4.5:1)" }.joined(separator: "\n")
            XCTFail("WCAG AA contrast failures on cardBackground:\n\(msg)")
        }
    }

    func test_allTextColors_meetAA_onBackgroundSystem() {
        var failures: [(String, Double)] = []

        for (name, rgb) in colors {
            let ratio = contrastRatio(fg: rgb, bg: backgroundSystem)
            let threshold: Double = largeTextOnly.contains(name) ? 3.0 : 4.5
            if ratio < threshold {
                failures.append((name, ratio))
            }
        }

        if !failures.isEmpty {
            let msg = failures.map { "  \($0.0): \(String(format: "%.2f", $0.1)):1 (need ≥4.5:1)" }.joined(separator: "\n")
            XCTFail("WCAG AA contrast failures on backgroundSystem:\n\(msg)")
        }
    }

    func test_buttonText_dark_onPrimaryBackground() {
        let darkText = (0.08, 0.06, 0.10) // backgroundSystem as button text
        let primary = (0.85, 0.65, 0.20)
        let ratio = contrastRatio(fg: darkText, bg: primary)
        // Dark text on gold — large text threshold (buttons are bold)
        XCTAssertGreaterThanOrEqual(ratio, 3.0,
            "Dark on primary: \(String(format: "%.2f", ratio)):1 — need ≥3.0:1 for large text")
    }

    func test_buttonText_white_onSuccessBackground() {
        let white = (1.0, 1.0, 1.0)
        let success = (0.20, 0.62, 0.30)
        let ratio = contrastRatio(fg: white, bg: success)
        XCTAssertGreaterThanOrEqual(ratio, 3.0,
            "White on success: \(String(format: "%.2f", ratio)):1 — need ≥3.0:1 for large text")
    }

    func test_buttonText_white_onDangerBackground() {
        let white = (1.0, 1.0, 1.0)
        let danger = (0.90, 0.35, 0.35)
        let ratio = contrastRatio(fg: white, bg: danger)
        XCTAssertGreaterThanOrEqual(ratio, 3.0,
            "White on danger: \(String(format: "%.2f", ratio)):1 — need ≥3.0:1 for large text")
    }

    func test_mutedText_meetsAA_onAllBackgrounds() {
        let muted = (0.65, 0.60, 0.65)
        let backgrounds: [(String, (Double, Double, Double))] = [
            ("backgroundSystem", backgroundSystem),
            ("backgroundTertiary", backgroundTertiary),
            ("cardBackground", cardBackground),
        ]

        for (bgName, bg) in backgrounds {
            let ratio = contrastRatio(fg: muted, bg: bg)
            XCTAssertGreaterThanOrEqual(ratio, 4.5,
                "muted on \(bgName): \(String(format: "%.2f", ratio)):1 — need ≥4.5:1")
        }
    }

    func test_wcagMath_knownValues() {
        // Black on white = 21:1
        let bw = contrastRatio(fg: (0, 0, 0), bg: (1, 1, 1))
        XCTAssertEqual(bw, 21.0, accuracy: 0.01)

        // White on white = 1:1
        let ww = contrastRatio(fg: (1, 1, 1), bg: (1, 1, 1))
        XCTAssertEqual(ww, 1.0, accuracy: 0.01)
    }
}
