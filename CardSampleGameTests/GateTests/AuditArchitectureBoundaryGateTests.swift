/// Файл: CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests.swift
/// Назначение: Содержит реализацию файла AuditArchitectureBoundaryGateTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

/// Архитектурные гейт-тесты границ слоёв.
/// Проверяют, что UI/bridge/engine взаимодействуют только по разрешённым контрактам.
final class AuditArchitectureBoundaryGateTests: XCTestCase {

    func checkForbiddenPatternsInFile(_ fileURL: URL, patterns: [String]) throws -> [String] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        var violations: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }

            var lineToCheck = trimmedLine
            if let commentRange = lineToCheck.range(of: "//") {
                lineToCheck = String(lineToCheck[..<commentRange.lowerBound])
            }

            for pattern in patterns where lineToCheck.contains(pattern) {
                let fileName = fileURL.lastPathComponent
                violations.append("  \(fileName):\(lineNumber): \(trimmedLine) [pattern: \(pattern)]")
            }
        }

        return violations
    }

    func findSwiftFiles(in directory: URL) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            result.append(fileURL)
        }

        return result
    }

    func isCommentLine(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*")
    }

    func stripInlineComment(from rawLine: String) -> String {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        if let commentRange = line.range(of: "//") {
            line = String(line[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    func collectImportViolations(
        in directories: [URL],
        forbiddenModules: Set<String>
    ) throws -> [String] {
        let projectRoot = SourcePathResolver.projectRoot
        var violations: [String] = []

        for directory in directories where FileManager.default.fileExists(atPath: directory.path) {
            for fileURL in findSwiftFiles(in: directory) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, rawLine) in lines.enumerated() {
                    let trimmed = stripInlineComment(from: rawLine)
                    if isCommentLine(trimmed) || trimmed.isEmpty { continue }
                    guard trimmed.hasPrefix("import ") else { continue }

                    let parts = trimmed.split(whereSeparator: \.isWhitespace)
                    guard parts.count >= 2 else { continue }
                    let module = String(parts[1])
                    if forbiddenModules.contains(module) {
                        violations.append("\(relPath):\(index + 1): \(trimmed)")
                    }
                }
            }
        }

        return violations
    }

    func collectSwiftUIViewTypeNames(in directories: [URL]) throws -> Set<String> {
        let pattern = #"^\s*(?:public|internal|private|fileprivate|open)?\s*(?:final\s+)?(?:struct|class)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*[^/\n]*\bView\b"#
        let regex = try NSRegularExpression(pattern: pattern)
        var names: Set<String> = []

        for directory in directories where FileManager.default.fileExists(atPath: directory.path) {
            for fileURL in findSwiftFiles(in: directory) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for rawLine in content.components(separatedBy: .newlines) {
                    let trimmed = stripInlineComment(from: rawLine)
                    if isCommentLine(trimmed) || trimmed.isEmpty { continue }
                    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                    guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
                          match.numberOfRanges > 1,
                          let nameRange = Range(match.range(at: 1), in: trimmed) else { continue }
                    names.insert(String(trimmed[nameRange]))
                }
            }
        }

        return names
    }

    func collectTypeReferenceViolations(
        in directories: [URL],
        forbiddenTypes: Set<String>
    ) throws -> [String] {
        guard !forbiddenTypes.isEmpty else { return [] }

        let projectRoot = SourcePathResolver.projectRoot
        let patterns = forbiddenTypes.map {
            "\\b\(NSRegularExpression.escapedPattern(for: $0))\\b"
        }
        var violations: [String] = []

        for directory in directories where FileManager.default.fileExists(atPath: directory.path) {
            for fileURL in findSwiftFiles(in: directory) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, rawLine) in lines.enumerated() {
                    let trimmed = stripInlineComment(from: rawLine)
                    if isCommentLine(trimmed) || trimmed.isEmpty { continue }

                    for pattern in patterns where trimmed.range(of: pattern, options: .regularExpression) != nil {
                        violations.append("\(relPath):\(index + 1): \(trimmed)")
                        break
                    }
                }
            }
        }

        return violations
    }

    func lineContainsAssignment(_ line: String, field: String) -> Bool {
        let escapedField = NSRegularExpression.escapedPattern(for: field)
        let declarationPattern = "\\b(var|let)\\s+\(escapedField)\\b"
        let assignmentPattern = "\\b\(escapedField)\\b\\s*=(?!=)"

        if line.range(of: declarationPattern, options: .regularExpression) != nil {
            return false
        }
        return line.range(of: assignmentPattern, options: .regularExpression) != nil
    }

    func collectXCTestMethodNames(in fileURL: URL) throws -> Set<String> {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        let pattern = #"^\s*func\s+(test[A-Za-z0-9_]+)\s*\("#
        let regex = try NSRegularExpression(pattern: pattern)
        var names: Set<String> = []

        for rawLine in lines {
            let trimmed = stripInlineComment(from: rawLine)
            if isCommentLine(trimmed) || trimmed.isEmpty { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
                  match.numberOfRanges > 1,
                  let nameRange = Range(match.range(at: 1), in: trimmed) else { continue }
            names.insert(String(trimmed[nameRange]))
        }

        return names
    }
}
