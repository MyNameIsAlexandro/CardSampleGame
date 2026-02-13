/// Файл: Packages/TwilightEngine/Sources/PackAuthoring/PackValidator.swift
/// Назначение: Содержит реализацию файла PackValidator.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

// MARK: - Pack Validator

/// Comprehensive validator for content packs
/// Validates structure, references, balance, and content integrity
public final class PackValidator {
    // MARK: - Types

    /// Validation severity level
    public enum Severity: String, CaseIterable {
        case error = "ERROR"      // Pack cannot be loaded
        case warning = "WARNING"  // Pack loads but may have issues
        case info = "INFO"        // Informational, not a problem
    }

    /// Validation result for a single check
    public struct ValidationResult {
        public let severity: Severity
        public let category: String
        public let message: String
        public let file: String?
        public let line: Int?

        public var description: String {
            var desc = "[\(severity.rawValue)] \(category): \(message)"
            if let file = file {
                desc += " (in \(file)"
                if let line = line {
                    desc += ":\(line)"
                }
                desc += ")"
            }
            return desc
        }
    }

    /// Summary of validation results
    public struct ValidationSummary {
        public let packId: String
        public let results: [ValidationResult]
        public let duration: TimeInterval

        public var errorCount: Int { results.filter { $0.severity == .error }.count }
        public var warningCount: Int { results.filter { $0.severity == .warning }.count }
        public var infoCount: Int { results.filter { $0.severity == .info }.count }

        public var isValid: Bool { errorCount == 0 }

        var description: String {
            var lines: [String] = []
            lines.append("=== Pack Validation: \(packId) ===")
            lines.append("Duration: \(String(format: "%.2f", duration))s")
            lines.append("Errors: \(errorCount), Warnings: \(warningCount), Info: \(infoCount)")
            lines.append("")

            if !results.isEmpty {
                for result in results {
                    lines.append(result.description)
                }
            } else {
                lines.append("No issues found.")
            }

            lines.append("")
            lines.append(isValid ? "VALIDATION PASSED" : "VALIDATION FAILED")
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Properties

    var results: [ValidationResult] = []
    let packURL: URL
    var manifest: PackManifest?
    var loadedPack: LoadedPack?

    // MARK: - Initialization

    public init(packURL: URL) {
        self.packURL = packURL
    }

    // MARK: - Public API

    /// Validate a pack at the given URL
    /// - Returns: Validation summary with all results
    public func validate() -> ValidationSummary {
        let startTime = Date()
        results.removeAll()

        // Phase 1: Validate manifest
        validateManifest()

        // Phase 2: Validate file structure
        if manifest != nil {
            validateFileStructure()
        }

        // Phase 3: Load and validate content
        if manifest != nil {
            validateContent()
        }

        // Phase 4: Validate cross-references
        if loadedPack != nil {
            validateCrossReferences()
        }

        // Phase 5: Validate balance configuration
        if let pack = loadedPack, pack.balanceConfig != nil {
            validateBalanceConfig()
        }

        // Phase 6: Validate localization
        if let pack = loadedPack {
            validateLocalization(pack)
        }

        let duration = Date().timeIntervalSince(startTime)
        return ValidationSummary(
            packId: manifest?.packId ?? "unknown",
            results: results,
            duration: duration
        )
    }

    /// Validate pack and return just the error/warning count
    public static func quickValidate(packURL: URL) -> (errors: Int, warnings: Int) {
        let validator = PackValidator(packURL: packURL)
        let summary = validator.validate()
        return (summary.errorCount, summary.warningCount)
    }
}

// MARK: - CLI Support

extension PackValidator {
    /// Run validation and print results to console (DEBUG only)
    public static func validateAndPrint(packURL: URL) -> Bool {
        let validator = PackValidator(packURL: packURL)
        let summary = validator.validate()
        #if DEBUG
        print(summary.description)
        #endif
        return summary.isValid
    }

    /// Validate multiple packs (DEBUG only for console output)
    public static func validateMultiple(packURLs: [URL]) -> Bool {
        var allValid = true

        for url in packURLs {
            #if DEBUG
            print("\n" + String(repeating: "=", count: 60))
            #endif
            let isValid = validateAndPrint(packURL: url)
            allValid = allValid && isValid
        }

        #if DEBUG
        print("\n" + String(repeating: "=", count: 60))
        print(allValid ? "ALL PACKS VALID" : "SOME PACKS HAVE ERRORS")
        #endif

        return allValid
    }
}
