/// Файл: CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests+LocaleGates.swift
/// Назначение: Gate-тест запрета прямого Locale.current в production-коде (CLAUDE.md §4.2).
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

extension AuditArchitectureBoundaryGateTests {

    // MARK: - Locale Resolution Gates (CLAUDE.md §4.2)

    /// Gate test: production code must not use `Locale.current` directly.
    /// Localization must go through the centralized `EngineLocaleResolver` (CLAUDE.md §4.2).
    func testProductionCodeDoesNotUseLocaleCurrentDirectly() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = [
            "App",
            "Views",
            "ViewModels",
            "Models",
            "Managers",
            "Utilities",
            "Packages/TwilightEngine/Sources/TwilightEngine",
            "Packages/EchoEngine/Sources",
            "Packages/EchoScenes/Sources"
        ]

        let allowedFiles: Set<String> = [
            "EngineLocaleResolver.swift"
        ]

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                if allowedFiles.contains(fileURL.lastPathComponent) { continue }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, rawLine) in lines.enumerated() {
                    let trimmed = stripInlineComment(from: rawLine)
                    if isCommentLine(trimmed) || trimmed.isEmpty { continue }

                    if trimmed.contains("Locale.current") {
                        violations.append("\(relPath):\(index + 1): \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found direct `Locale.current` usage in production code (CLAUDE.md §4.2):
            \(violations.joined(separator: "\n"))

            Use `EngineLocaleResolver.currentLanguageCode()` instead of accessing `Locale.current` directly.
            All locale resolution must go through the centralized resolver.
            """
        )
    }
}
