import XCTest
@testable import CardSampleGame

/// Audit tests to ensure Code Hygiene compliance (Epic 10)
/// These tests fail if:
/// - Public API methods lack `///` doc comments (10.1)
/// - Files contain too many types or exceed line limits (10.2)
final class CodeHygieneTests: XCTestCase {

    // MARK: - Configuration

    /// Maximum lines per file before warning (for NEW files)
    /// Legacy files are grandfathered at their current size
    private let maxLinesPerFile = 600

    /// Maximum public types per file (for NEW files)
    /// Related small types (enums, helper structs) can stay together
    private let maxTypesPerFile = 5

    /// Files that are exempt from limits (legacy, grandfathered)
    /// These files existed before Epic 10 enforcement
    /// New files MUST follow the limits
    private let legacyFiles: Set<String> = [
        // Large files (>600 lines)
        "ExplorationModels.swift",      // 872 lines - exploration domain models
        "TwilightGameEngine.swift",     // 2247 lines - main engine
        "ContentRegistry.swift",        // 844 lines - registry
        "FateCard.swift",               // 8 cohesive fate card types
        "JSONContentProvider.swift",    // 969 lines - JSON loading
        // PackValidator.swift moved to PackAuthoring module
        // Files with many related types (>5 types)
        "EngineProtocols.swift",        // 30+ protocols - all engine contracts
        "CodeContentProvider.swift",    // JSON loading types
        "EventDefinition.swift",        // Event system types
        "HeroAbility.swift",            // Ability system types
        "PackTypes.swift",              // Pack-related types
        "BalanceConfiguration.swift",   // Balance config types (intentionally grouped)
        "CardDefinition.swift",         // Card system types
        "CardType.swift",               // Card enums
        "ContentManager.swift",         // Content management types (cohesive hot-reload API)
        "GameDefinition.swift",         // Game definition types
        "QuestDefinition.swift",        // Quest system types
        "AbilityRegistry.swift",        // Ability loading types
        "HeroRegistry.swift",           // Hero loading types
        "HeroDefinition.swift",         // Hero system types
        "CardRegistry.swift",           // Card loading types
        "EngineSave.swift",             // Save system types
        "TimeEngine.swift",             // Time system types
        "TwilightGameAction.swift",     // Action types
        "PressureEngine.swift",         // Pressure system types
        "ContentProvider.swift",        // Provider types
        "MiniGameChallengeDefinition.swift", // MiniGame types
        "EnemyDefinition.swift",        // Enemy types
        "EngineTypes.swift",            // Runtime types
    ]

    /// Directories to audit in TwilightEngine
    private let engineDirectories = [
        "Cards",
        "ContentPacks",
        "Heroes",
        "Core",
        "Data",
        "Models",
        "Runtime"
    ]

    /// Critical public API files that MUST have doc comments on public methods
    /// These are the main entry points for engine consumers
    private let criticalAPIFiles = [
        "CardRegistry.swift",
        "HeroRegistry.swift",
        "ContentRegistry.swift",
        "PackManifest.swift"
    ]

    /// Methods in critical API files that are allowed without docs (internal helpers)
    private let exemptMethods: Set<String> = [
        "loadHeroes()",     // Protocol implementation in data sources
        "loadCards()",      // Protocol implementation in data sources
        "toStandard()",     // Conversion helper
        "toHeroStats()",    // Conversion helper
    ]

    // MARK: - Path Resolution

    private var engineRoot: URL? {
        guard let root = projectRoot else { return nil }
        return root
            .appendingPathComponent("Packages")
            .appendingPathComponent("TwilightEngine")
            .appendingPathComponent("Sources")
            .appendingPathComponent("TwilightEngine")
    }

    private var projectRoot: URL? {
        // Try SRCROOT from scheme environment
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            return URL(fileURLWithPath: srcRoot)
        }

        // Fallback: Navigate up from test file location
        let thisFile = #file
        var url = URL(fileURLWithPath: thisFile)
        // Go up: Engine -> CardSampleGameTests -> Project Root
        for _ in 0..<3 {
            url = url.deletingLastPathComponent()
        }

        // Verify we found the right directory
        let packagesPath = url.appendingPathComponent("Packages")
        if FileManager.default.fileExists(atPath: packagesPath.path) {
            return url
        }

        return nil
    }

    // MARK: - 10.1 Documentation Tests

    func testPublicMethodsHaveDocComments() throws {
        guard let engine = engineRoot else {
            XCTFail("GATE TEST FAILURE: Could not determine engine root path"); return
        }

        var violations: [(file: String, method: String)] = []

        for apiFile in criticalAPIFiles {
            let filePath = findFile(named: apiFile, in: engine)
            guard let path = filePath else {
                XCTFail("Critical API file not found: \(apiFile)")
                continue
            }

            let content = try String(contentsOfFile: path, encoding: .utf8)
            let undocumentedMethods = findUndocumentedPublicMethods(in: content)

            for method in undocumentedMethods {
                // Skip exempt methods (internal helpers, protocol implementations)
                if exemptMethods.contains(method) {
                    continue
                }
                violations.append((apiFile, method))
            }
        }

        if !violations.isEmpty {
            let message = violations.map { "  \($0.file): \($0.method)" }.joined(separator: "\n")
            XCTFail("""
                Found \(violations.count) public methods without /// doc comments:
                \(message)

                Add documentation like:
                /// Brief description of what method does.
                /// - Parameter name: Description of parameter.
                /// - Returns: Description of return value.
                """)
        }
    }

    func testPublicPropertiesHaveDocComments() throws {
        guard let engine = engineRoot else {
            XCTFail("GATE TEST FAILURE: Could not determine engine root path"); return
        }

        var violations: [(file: String, property: String)] = []

        // Only check CardRegistry and HeroRegistry for now
        // ContentRegistry/PackLoader/PackManifest have many internal properties
        let strictPropertyFiles = ["CardRegistry.swift", "HeroRegistry.swift"]

        for apiFile in strictPropertyFiles {
            let filePath = findFile(named: apiFile, in: engine)
            guard let path = filePath else { continue }

            let content = try String(contentsOfFile: path, encoding: .utf8)
            let undocumentedProps = findUndocumentedPublicProperties(in: content)

            for prop in undocumentedProps {
                // Skip common property names that are self-documenting
                if ["id", "name", "shared", "fileURL"].contains(prop) {
                    continue
                }
                violations.append((apiFile, prop))
            }
        }

        if !violations.isEmpty {
            let message = violations.map { "  \($0.file): \($0.property)" }.joined(separator: "\n")
            XCTFail("""
                Found \(violations.count) public properties without /// doc comments:
                \(message)

                Add documentation like:
                /// Brief description of property.
                public let/var propertyName: Type
                """)
        }
    }

    // MARK: - 10.2 File Organization Tests

    func testFilesDoNotExceedLineLimit() throws {
        guard let engine = engineRoot else {
            XCTFail("GATE TEST FAILURE: Could not determine engine root path"); return
        }

        var violations: [(file: String, lines: Int)] = []

        for dir in engineDirectories {
            let dirPath = engine.appendingPathComponent(dir)
            let files = findSwiftFiles(in: dirPath)

            for filePath in files {
                let fileName = URL(fileURLWithPath: filePath).lastPathComponent

                // Skip legacy files (grandfathered)
                if legacyFiles.contains(fileName) {
                    continue
                }

                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let lineCount = content.components(separatedBy: .newlines).count

                if lineCount > maxLinesPerFile {
                    violations.append((fileName, lineCount))
                }
            }
        }

        if !violations.isEmpty {
            let message = violations.map { "  \($0.file): \($0.lines) lines (max \(maxLinesPerFile))" }.joined(separator: "\n")
            XCTFail("""
                Found \(violations.count) NEW files exceeding line limit:
                \(message)

                Consider splitting into smaller files:
                - Extract related types into separate files
                - Move extensions to Type+Extension.swift files
                - Group by functionality, not just proximity

                If this is intentional, add the file to legacyFiles in CodeHygieneTests.swift
                """)
        }
    }

    func testFilesDoNotHaveTooManyTypes() throws {
        guard let engine = engineRoot else {
            XCTFail("GATE TEST FAILURE: Could not determine engine root path"); return
        }

        var violations: [(file: String, types: [String])] = []

        for dir in engineDirectories {
            let dirPath = engine.appendingPathComponent(dir)
            let files = findSwiftFiles(in: dirPath)

            for filePath in files {
                let fileName = URL(fileURLWithPath: filePath).lastPathComponent

                // Skip legacy files (grandfathered)
                if legacyFiles.contains(fileName) {
                    continue
                }

                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let publicTypes = findPublicTypeDeclarations(in: content)

                if publicTypes.count > maxTypesPerFile {
                    violations.append((fileName, publicTypes))
                }
            }
        }

        if !violations.isEmpty {
            let message = violations.map { file, types in
                "  \(file): \(types.count) types [\(types.prefix(5).joined(separator: ", "))\(types.count > 5 ? "..." : "")]"
            }.joined(separator: "\n")
            XCTFail("""
                Found \(violations.count) NEW files with too many public types (max \(maxTypesPerFile)):
                \(message)

                Follow "1 file = 1 main type" principle:
                - Primary type: MyType.swift
                - Extensions: MyType+Feature.swift
                - Related small types can stay together if cohesive

                If this is intentional, add the file to legacyFiles in CodeHygieneTests.swift
                """)
        }
    }

    // MARK: - Helpers

    private func findFile(named name: String, in directory: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == name {
                return fileURL.path
            }
        }
        return nil
    }

    private func findSwiftFiles(in directory: URL) -> [String] {
        var files: [String] = []

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return files }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                files.append(fileURL.path)
            }
        }

        return files
    }

    /// Find public methods without preceding /// doc comment
    private func findUndocumentedPublicMethods(in content: String) -> [String] {
        var undocumented: [String] = []
        let lines = content.components(separatedBy: .newlines)

        // Pattern for public func/method declarations
        let methodPattern = #"^\s*public\s+(static\s+)?func\s+(\w+)"#
        let methodRegex = try? NSRegularExpression(pattern: methodPattern)

        // Attributes that can appear between doc comment and declaration
        let attributePattern = #"^\s*@\w+"#

        for (index, line) in lines.enumerated() {
            guard let regex = methodRegex,
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            // Extract method name
            if let nameRange = Range(match.range(at: 2), in: line) {
                let methodName = String(line[nameRange])

                // Check if previous non-empty, non-attribute line is a doc comment
                var prevIndex = index - 1
                var foundDocComment = false

                while prevIndex >= 0 {
                    let prevLine = lines[prevIndex].trimmingCharacters(in: .whitespaces)
                    if prevLine.isEmpty {
                        prevIndex -= 1
                        continue
                    }
                    // Skip Swift attributes (@discardableResult, @MainActor, etc.)
                    if prevLine.range(of: attributePattern, options: .regularExpression) != nil {
                        prevIndex -= 1
                        continue
                    }
                    // Check for doc comment
                    if prevLine.hasPrefix("///") || prevLine.hasPrefix("*/") {
                        foundDocComment = true
                    }
                    break
                }

                if !foundDocComment {
                    undocumented.append(methodName + "()")
                }
            }
        }

        return undocumented
    }

    /// Find public properties without preceding /// doc comment
    private func findUndocumentedPublicProperties(in content: String) -> [String] {
        var undocumented: [String] = []
        let lines = content.components(separatedBy: .newlines)

        // Pattern for public let/var declarations (not in function bodies)
        let propPattern = #"^\s*public\s+(static\s+)?(let|var)\s+(\w+)"#
        let propRegex = try? NSRegularExpression(pattern: propPattern)

        // Attributes that can appear between doc comment and declaration
        let attributePattern = #"^\s*@\w+"#

        for (index, line) in lines.enumerated() {
            guard let regex = propRegex,
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            // Skip computed properties (they have doc comments on the var line usually)
            if line.contains("{") && line.contains("return") {
                continue
            }

            // Extract property name
            if let nameRange = Range(match.range(at: 3), in: line) {
                let propName = String(line[nameRange])

                // Check if previous non-empty, non-attribute line is a doc comment
                var prevIndex = index - 1
                var foundDocComment = false

                while prevIndex >= 0 {
                    let prevLine = lines[prevIndex].trimmingCharacters(in: .whitespaces)
                    if prevLine.isEmpty {
                        prevIndex -= 1
                        continue
                    }
                    // Skip Swift attributes
                    if prevLine.range(of: attributePattern, options: .regularExpression) != nil {
                        prevIndex -= 1
                        continue
                    }
                    // Check for doc comment
                    if prevLine.hasPrefix("///") || prevLine.hasPrefix("*/") {
                        foundDocComment = true
                    }
                    break
                }

                if !foundDocComment {
                    undocumented.append(propName)
                }
            }
        }

        return undocumented
    }

    /// Find public type declarations (class, struct, enum, protocol)
    private func findPublicTypeDeclarations(in content: String) -> [String] {
        var types: [String] = []
        let lines = content.components(separatedBy: .newlines)

        // Pattern for public type declarations
        let typePattern = #"^\s*public\s+(final\s+)?(class|struct|enum|protocol|actor)\s+(\w+)"#
        let typeRegex = try? NSRegularExpression(pattern: typePattern)

        for line in lines {
            guard let regex = typeRegex,
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            if let nameRange = Range(match.range(at: 3), in: line) {
                types.append(String(line[nameRange]))
            }
        }

        return types
    }
}
