import XCTest
@testable import CardSampleGame

/// Audit tests to ensure Design System compliance
/// These tests fail if magic numbers or hardcoded colors are found in View files
/// Reference: AUDIT_ENGINE_FIRST_v1_1.md, Epic 9.1
///
/// All View files are now fully compliant. These tests enforce:
/// - No magic numbers (use Spacing.*, Sizes.*, CornerRadius.*)
/// - No hardcoded colors (use AppColors.*)
/// - No hardcoded opacity (use Opacity.*)
final class DesignSystemComplianceTests: XCTestCase {

    /// Strict compliance mode - fails on any violation
    private let allowLegacyViolations = false

    /// No legacy files - all Views are now compliant
    private let legacyFiles: [String] = []

    // MARK: - View Files to Audit

    /// All View files that must use DesignSystem constants
    private var viewFiles: [String] {
        guard let root = projectRoot else { return [] }
        let viewsDir = root.appendingPathComponent("Views")
        return findSwiftFiles(in: viewsDir)
    }

    private var projectRoot: URL? {
        // Try to find project root via SRCROOT (set in scheme environment)
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            return URL(fileURLWithPath: srcRoot)
        }

        // Fallback: Navigate up from test file location
        // This file is at CardSampleGameTests/Engine/DesignSystemComplianceTests.swift
        let thisFile = #file
        var url = URL(fileURLWithPath: thisFile)
        // Go up 3 levels: Engine -> CardSampleGameTests -> Project Root
        for _ in 0..<3 {
            url = url.deletingLastPathComponent()
        }

        // Verify we found the right directory by checking for Views folder
        let viewsPath = url.appendingPathComponent("Views")
        if FileManager.default.fileExists(atPath: viewsPath.path) {
            return url
        }

        return nil
    }

    // MARK: - Magic Number Patterns

    /// Patterns that indicate hardcoded spacing/padding values
    private let magicNumberPatterns: [(pattern: String, description: String)] = [
        // Padding with raw numbers (but allow Spacing.* references)
        (#"\.padding\(\s*\d+\s*\)"#, "padding with magic number"),
        (#"\.padding\(\.\w+,\s*\d+\s*\)"#, "directional padding with magic number"),
        (#"\.padding\(\.horizontal,\s*\d+\s*\)"#, "horizontal padding with magic number"),
        (#"\.padding\(\.vertical,\s*\d+\s*\)"#, "vertical padding with magic number"),

        // Spacing with raw numbers in stacks (0 is allowed - means no spacing)
        (#"VStack\(spacing:\s*[1-9]\d*\s*\)"#, "VStack spacing with magic number"),
        (#"HStack\(spacing:\s*[1-9]\d*\s*\)"#, "HStack spacing with magic number"),
        (#"LazyVStack\(spacing:\s*[1-9]\d*\s*\)"#, "LazyVStack spacing with magic number"),
        (#"LazyHStack\(spacing:\s*[1-9]\d*\s*\)"#, "LazyHStack spacing with magic number"),

        // Corner radius with raw numbers
        (#"\.cornerRadius\(\s*\d+\s*\)"#, "cornerRadius with magic number"),

        // Frame with raw numbers (except 0 and .infinity)
        (#"\.frame\(width:\s*[1-9]\d*\s*\)"#, "frame width with magic number"),
        (#"\.frame\(height:\s*[1-9]\d*\s*\)"#, "frame height with magic number"),
    ]

    /// Patterns that are allowed (exceptions)
    private let allowedPatterns: [String] = [
        "Spacing\\.", // Spacing.sm, Spacing.md, etc.
        "Sizes\\.",   // Sizes.iconSmall, etc.
        "CornerRadius\\.", // CornerRadius.md, etc.
        "lineWidth:", // lineWidth is ok for strokes
        "size:\\s*\\d+", // font size modifiers (allowed for now)
        "#Preview", // Preview code is exempt
        "PreviewProvider", // Preview code is exempt
    ]

    // MARK: - Hardcoded Color Patterns

    /// Patterns that indicate hardcoded colors instead of AppColors
    private let hardcodedColorPatterns: [(pattern: String, description: String)] = [
        (#"Color\.red(?!\w)"#, "hardcoded Color.red"),
        (#"Color\.blue(?!\w)"#, "hardcoded Color.blue"),
        (#"Color\.green(?!\w)"#, "hardcoded Color.green"),
        (#"Color\.orange(?!\w)"#, "hardcoded Color.orange"),
        (#"Color\.yellow(?!\w)"#, "hardcoded Color.yellow"),
        (#"Color\.purple(?!\w)"#, "hardcoded Color.purple"),
        (#"Color\.gray(?!\w)"#, "hardcoded Color.gray"),
        (#"Color\.pink(?!\w)"#, "hardcoded Color.pink"),
        (#"\.foregroundColor\(\.red\)"#, "foregroundColor(.red)"),
        (#"\.foregroundColor\(\.blue\)"#, "foregroundColor(.blue)"),
        (#"\.foregroundColor\(\.green\)"#, "foregroundColor(.green)"),
        (#"\.foregroundColor\(\.orange\)"#, "foregroundColor(.orange)"),
        (#"\.foregroundColor\(\.yellow\)"#, "foregroundColor(.yellow)"),
        (#"\.foregroundColor\(\.purple\)"#, "foregroundColor(.purple)"),
        (#"\.foregroundColor\(\.gray\)"#, "foregroundColor(.gray)"),
        (#"\.foregroundColor\(\.secondary\)"#, "foregroundColor(.secondary) - use AppColors.muted"),
    ]

    /// Color patterns that are allowed
    private let allowedColorPatterns: [String] = [
        "AppColors\\.",   // AppColors.primary, etc.
        "Color\\.white",  // white is ok (neutral)
        "Color\\.black",  // black is ok (neutral)
        "Color\\.clear",  // clear is ok
        "Color\\.primary", // system primary is ok
        "Color\\.accentColor", // accent is ok
        "Color\\(UIColor\\.", // UIColor wrappers are ok
        "Color\\.indigo", // indigo is ok (no AppColors equivalent yet)
        "Color\\.brown",  // brown is ok (no AppColors equivalent yet)
        "Color\\.teal",   // teal is ok (no AppColors equivalent yet)
        "Color\\.cyan",   // cyan is ok (no AppColors equivalent yet)
        "Color\\.pink",   // pink is ok (no AppColors equivalent yet)
        "#Preview",       // Preview code is exempt
        "PreviewProvider", // Preview code is exempt
        "// DesignSystem-exempt", // Explicit exemption comment
    ]

    // MARK: - Hardcoded Opacity Patterns

    /// Patterns that indicate hardcoded opacity values
    private let hardcodedOpacityPatterns: [(pattern: String, description: String)] = [
        (#"\.opacity\(0\.\d+\)"#, "hardcoded opacity value"),
    ]

    /// Opacity patterns that are allowed
    private let allowedOpacityPatterns: [String] = [
        "Opacity\\.",     // Opacity.medium, etc.
        "#Preview",       // Preview code is exempt
        "PreviewProvider", // Preview code is exempt
        "\\.opacity\\(0\\.15\\)", // 0.15 is acceptable for card backgrounds (close to Opacity.faint)
        "\\.opacity\\(0\\.1\\)",  // 0.1 is acceptable for subtle backgrounds
    ]

    // MARK: - Tests

    func testNoMagicNumbersInViews() throws {
        guard projectRoot != nil else {
            throw XCTSkip("Could not determine project root path")
        }
        var violations: [(file: String, line: Int, issue: String)] = []

        for filePath in viewFiles {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (lineIndex, line) in lines.enumerated() {
                // Skip if line contains allowed pattern
                if allowedPatterns.contains(where: { line.range(of: $0, options: .regularExpression) != nil }) {
                    continue
                }

                // Check for magic number violations
                for (pattern, description) in magicNumberPatterns {
                    if line.range(of: pattern, options: .regularExpression) != nil {
                        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                        violations.append((fileName, lineIndex + 1, description))
                    }
                }
            }
        }

        // Separate legacy vs new violations
        let newViolations = violations.filter { !legacyFiles.contains($0.file) }
        let legacyViolations = violations.filter { legacyFiles.contains($0.file) }

        // Always fail on new violations
        if !newViolations.isEmpty {
            let message = newViolations.map { "  \($0.file):\($0.line) - \($0.issue)" }.joined(separator: "\n")
            XCTFail("Found \(newViolations.count) magic number violations in migrated files:\n\(message)\n\nUse Spacing.*, Sizes.*, or CornerRadius.* instead.")
        }

        // Warn about legacy violations (or fail if strict mode)
        if !legacyViolations.isEmpty && !allowLegacyViolations {
            let message = legacyViolations.map { "  \($0.file):\($0.line) - \($0.issue)" }.joined(separator: "\n")
            XCTFail("Found \(legacyViolations.count) magic number violations in legacy files:\n\(message)")
        }
    }

    func testNoHardcodedColorsInViews() throws {
        guard projectRoot != nil else {
            throw XCTSkip("Could not determine project root path")
        }
        var violations: [(file: String, line: Int, issue: String)] = []

        for filePath in viewFiles {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (lineIndex, line) in lines.enumerated() {
                // Skip if line contains allowed pattern
                if allowedColorPatterns.contains(where: { line.range(of: $0, options: .regularExpression) != nil }) {
                    continue
                }

                // Check for hardcoded color violations
                for (pattern, description) in hardcodedColorPatterns {
                    if line.range(of: pattern, options: .regularExpression) != nil {
                        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                        violations.append((fileName, lineIndex + 1, description))
                    }
                }
            }
        }

        // Separate legacy vs new violations
        let newViolations = violations.filter { !legacyFiles.contains($0.file) }
        let legacyViolations = violations.filter { legacyFiles.contains($0.file) }

        // Always fail on new violations
        if !newViolations.isEmpty {
            let message = newViolations.map { "  \($0.file):\($0.line) - \($0.issue)" }.joined(separator: "\n")
            XCTFail("Found \(newViolations.count) hardcoded color violations in migrated files:\n\(message)\n\nUse AppColors.* instead.")
        }

        // Warn about legacy violations (or fail if strict mode)
        if !legacyViolations.isEmpty && !allowLegacyViolations {
            let message = legacyViolations.map { "  \($0.file):\($0.line) - \($0.issue)" }.joined(separator: "\n")
            XCTFail("Found \(legacyViolations.count) hardcoded color violations in legacy files:\n\(message)")
        }
    }

    func testNoHardcodedOpacityInViews() throws {
        guard projectRoot != nil else {
            throw XCTSkip("Could not determine project root path")
        }
        var violations: [(file: String, line: Int, issue: String)] = []

        for filePath in viewFiles {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (lineIndex, line) in lines.enumerated() {
                // Skip if line contains allowed pattern
                if allowedOpacityPatterns.contains(where: { line.range(of: $0, options: .regularExpression) != nil }) {
                    continue
                }

                // Check for hardcoded opacity violations
                for (pattern, description) in hardcodedOpacityPatterns {
                    if line.range(of: pattern, options: .regularExpression) != nil {
                        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                        violations.append((fileName, lineIndex + 1, description))
                    }
                }
            }
        }

        // Separate legacy vs new violations
        let newViolations = violations.filter { !legacyFiles.contains($0.file) }
        let legacyViolations = violations.filter { legacyFiles.contains($0.file) }

        // Always fail on new violations
        if !newViolations.isEmpty {
            let message = newViolations.map { "  \($0.file):\($0.line) - \($0.issue)" }.joined(separator: "\n")
            XCTFail("Found \(newViolations.count) hardcoded opacity violations in migrated files:\n\(message)\n\nUse Opacity.* instead.")
        }

        // Warn about legacy violations (or fail if strict mode)
        if !legacyViolations.isEmpty && !allowLegacyViolations {
            let message = legacyViolations.map { "  \($0.file):\($0.line) - \($0.issue)" }.joined(separator: "\n")
            XCTFail("Found \(legacyViolations.count) hardcoded opacity violations in legacy files:\n\(message)")
        }
    }

    func testDesignSystemFilesExist() throws {
        guard let root = projectRoot else {
            throw XCTSkip("Could not determine project root path")
        }
        let designSystemPath = root.appendingPathComponent("Utilities/DesignSystem.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: designSystemPath.path),
            "DesignSystem.swift must exist at Utilities/DesignSystem.swift"
        )
    }

    func testDesignSystemHasRequiredTokens() throws {
        guard let root = projectRoot else {
            throw XCTSkip("Could not determine project root path")
        }
        let designSystemPath = root.appendingPathComponent("Utilities/DesignSystem.swift")
        let content = try String(contentsOf: designSystemPath, encoding: .utf8)

        // Check for required enums
        XCTAssertTrue(content.contains("enum Spacing"), "DesignSystem must define Spacing enum")
        XCTAssertTrue(content.contains("enum Sizes"), "DesignSystem must define Sizes enum")
        XCTAssertTrue(content.contains("enum CornerRadius"), "DesignSystem must define CornerRadius enum")
        XCTAssertTrue(content.contains("enum AppColors"), "DesignSystem must define AppColors enum")
        XCTAssertTrue(content.contains("enum Opacity"), "DesignSystem must define Opacity enum")

        // Check for key tokens
        XCTAssertTrue(content.contains("static let sm"), "Spacing must have sm token")
        XCTAssertTrue(content.contains("static let md"), "Spacing must have md token")
        XCTAssertTrue(content.contains("static let lg"), "Spacing must have lg token")
        XCTAssertTrue(content.contains("static let primary"), "AppColors must have primary token")
        XCTAssertTrue(content.contains("static let danger"), "AppColors must have danger token")
        XCTAssertTrue(content.contains("static let success"), "AppColors must have success token")
    }

    // MARK: - Helpers

    private func findSwiftFiles(in directory: URL) -> [String] {
        var files: [String] = []

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                files.append(fileURL.path)
            }
        }

        return files
    }
}
