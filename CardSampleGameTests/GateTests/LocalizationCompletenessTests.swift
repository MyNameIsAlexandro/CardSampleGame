/// Файл: CardSampleGameTests/GateTests/LocalizationCompletenessTests.swift
/// Назначение: Содержит реализацию файла LocalizationCompletenessTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest

/// Gate tests for localization completeness.
/// Ensures L10n keys, en.lproj and ru.lproj are in sync.
final class LocalizationCompletenessTests: XCTestCase {

    // MARK: - Helpers

    private var projectRoot: URL? {
        var url = URL(fileURLWithPath: #filePath)
        // GateTests -> CardSampleGameTests -> Project Root
        for _ in 0..<3 { url = url.deletingLastPathComponent() }
        return url
    }

    /// Parse all `static let ... = "key"` values from Utilities/Localization*.swift
    private func parseAppL10nKeys() throws -> Set<String> {
        guard let root = projectRoot else {
            XCTFail("Could not determine project root"); return []
        }
        let utilitiesDir = root.appendingPathComponent("Utilities")
        let files = try FileManager.default.contentsOfDirectory(
            at: utilitiesDir,
            includingPropertiesForKeys: nil
        )
        .filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("Localization") && name.hasSuffix(".swift")
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var keys = Set<String>()
        // Pattern: static let someName = "some.key"
        let regex = try NSRegularExpression(pattern: #"static\s+let\s+\w+\s*=\s*"([^"]+)""#)
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(content.startIndex..., in: content)
            for match in regex.matches(in: content, range: range) {
                if let keyRange = Range(match.range(at: 1), in: content) {
                    keys.insert(String(content[keyRange]))
                }
            }
        }
        return keys
    }

    /// Parse all engine localization keys from TwilightEngine `L10n.swift`.
    private func parseEngineL10nKeys() throws -> Set<String> {
        guard let root = projectRoot else {
            XCTFail("Could not determine project root"); return []
        }

        let engineL10nFile = root
            .appendingPathComponent("Packages/TwilightEngine/Sources/TwilightEngine/Localization/L10n.swift")
        let content = try String(contentsOf: engineL10nFile, encoding: .utf8)

        var keys = Set<String>()
        let regex = try NSRegularExpression(pattern: #"case\s+\.\w+\s*:\s*return\s*"([^"]+)""#)
        let range = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: range) {
            if let keyRange = Range(match.range(at: 1), in: content) {
                keys.insert(String(content[keyRange]))
            }
        }
        return keys
    }

    /// Union of app and engine localization key spaces.
    private func parseL10nKeys() throws -> Set<String> {
        try parseAppL10nKeys().union(parseEngineL10nKeys())
    }

    /// Parse keys from a .strings file. Returns [key: value] dictionary.
    private func parseStringsFile(locale: String) throws -> [String: String] {
        guard let root = projectRoot else {
            XCTFail("Could not determine project root"); return [:]
        }
        let file = root.appendingPathComponent("\(locale).lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        var result: [String: String] = [:]
        // Pattern: "key" = "value";
        let regex = try NSRegularExpression(pattern: #""([^"]+)"\s*=\s*"([^"]*)";"#)
        let range = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: range) {
            if let keyRange = Range(match.range(at: 1), in: content),
               let valRange = Range(match.range(at: 2), in: content) {
                result[String(content[keyRange])] = String(content[valRange])
            }
        }
        return result
    }

    /// Count format specifiers (%d, %@, %f, %ld, %lld, etc.) in a string
    private func formatSpecifiers(in string: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%[\d$]*[dDiuUxXoOeEfFgGaAcCsSp@]|%[\d$]*l{0,2}[dDiuUxXoO]"#)
        let range = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: range).compactMap {
            Range($0.range, in: string).map { String(string[$0]) }
        }
    }

    // MARK: - Tests

    /// Every L10n key must exist in en.lproj/Localizable.strings
    func testAllL10nKeysExistInEnStrings() throws {
        let l10nKeys = try parseL10nKeys()
        let enKeys = try parseStringsFile(locale: "en")

        XCTAssertFalse(l10nKeys.isEmpty, "Failed to parse L10n keys")

        let missing = l10nKeys.filter { enKeys[$0] == nil }
        XCTAssertTrue(
            missing.isEmpty,
            "L10n keys missing from en.lproj/Localizable.strings (\(missing.count)):\n\(missing.sorted().joined(separator: "\n"))"
        )
    }

    /// Every L10n key must exist in ru.lproj/Localizable.strings
    func testAllL10nKeysExistInRuStrings() throws {
        let l10nKeys = try parseL10nKeys()
        let ruKeys = try parseStringsFile(locale: "ru")

        XCTAssertFalse(l10nKeys.isEmpty, "Failed to parse L10n keys")

        let missing = l10nKeys.filter { ruKeys[$0] == nil }
        XCTAssertTrue(
            missing.isEmpty,
            "L10n keys missing from ru.lproj/Localizable.strings (\(missing.count)):\n\(missing.sorted().joined(separator: "\n"))"
        )
    }

    /// en.lproj and ru.lproj must have the same set of keys
    func testEnAndRuHaveSameKeys() throws {
        let enKeys = Set(try parseStringsFile(locale: "en").keys)
        let ruKeys = Set(try parseStringsFile(locale: "ru").keys)

        let onlyEn = enKeys.subtracting(ruKeys).sorted()
        let onlyRu = ruKeys.subtracting(enKeys).sorted()

        if !onlyEn.isEmpty {
            XCTFail("Keys only in en.lproj (\(onlyEn.count)): \(onlyEn.joined(separator: ", "))")
        }
        if !onlyRu.isEmpty {
            XCTFail("Keys only in ru.lproj (\(onlyRu.count)): \(onlyRu.joined(separator: ", "))")
        }
    }

    /// Format argument count (%d, %@, etc.) must match between en and ru for every key
    func testFormatArgumentsMatch() throws {
        let enEntries = try parseStringsFile(locale: "en")
        let ruEntries = try parseStringsFile(locale: "ru")
        let commonKeys = Set(enEntries.keys).intersection(Set(ruEntries.keys))

        var mismatches: [String] = []
        for key in commonKeys.sorted() {
            let enSpecs = formatSpecifiers(in: enEntries[key]!)
            let ruSpecs = formatSpecifiers(in: ruEntries[key]!)
            if enSpecs.count != ruSpecs.count {
                mismatches.append("\(key): en has \(enSpecs.count) args, ru has \(ruSpecs.count)")
            }
        }

        XCTAssertTrue(
            mismatches.isEmpty,
            "Format argument count mismatch (\(mismatches.count)):\n\(mismatches.joined(separator: "\n"))"
        )
    }

    /// No empty values in .strings files (indicates untranslated keys)
    func testNoEmptyValuesInStrings() throws {
        for locale in ["en", "ru"] {
            let entries = try parseStringsFile(locale: locale)
            let emptyKeys = entries.filter { $0.value.isEmpty }.keys.sorted()
            XCTAssertTrue(
                emptyKeys.isEmpty,
                "Empty values in \(locale).lproj/Localizable.strings (\(emptyKeys.count)): \(emptyKeys.joined(separator: ", "))"
            )
        }
    }
}
