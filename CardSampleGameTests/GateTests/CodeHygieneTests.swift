/// Файл: CardSampleGameTests/GateTests/CodeHygieneTests.swift
/// Назначение: Содержит реализацию файла CodeHygieneTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

/// Audit tests to ensure Code Hygiene compliance (Epic 10)
/// These tests fail if:
/// - Public API methods lack `///` doc comments (10.1)
/// - Files contain too many types or exceed line limits (10.2)
final class CodeHygieneTests: XCTestCase {

    // MARK: - Configuration

    /// Hard maximum lines per Swift file in the first-party codebase.
    private let maxLinesPerFile = 600

    /// Maximum top-level types per file in TwilightEngine.
    /// Related small types (enums, helper structs) can stay together if cohesive.
    private let maxTypesPerFile = 5

    /// Project roots included in hard line-limit audit.
    private let lineLimitProjectDirectories = [
        "App",
        "Views",
        "ViewModels",
        "Utilities",
        "CardSampleGameTests",
        "Packages"
    ]

    /// Path fragments excluded from hard line-limit audit.
    /// Excludes build outputs and third-party/vendor code only.
    private let lineLimitExcludedPathFragments = [
        "/.build/",
        "/Packages/ThirdParty/",
        "/.codex_home/"
    ]

    /// Directories to audit in TwilightEngine
    private let engineDirectories = [
        "Cards",
        "Combat",
        "Config",
        "ContentPacks",
        "Encounter",
        "Heroes",
        "Core",
        "Data",
        "Models",
        "Quest",
        "Story",
        "Runtime"
    ]

    /// Critical public API files that MUST have doc comments on public methods
    /// These are the main entry points for engine consumers
    private let criticalAPIFiles = [
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

    func loadPbxprojContent() throws -> String {
        guard let root = projectRoot else {
            XCTFail("GATE TEST FAILURE: Could not determine project root path")
            throw NSError(domain: "CodeHygieneTests", code: 1)
        }

        let pbxproj = root
            .appendingPathComponent("CardSampleGame.xcodeproj")
            .appendingPathComponent("project.pbxproj")

        return try String(contentsOf: pbxproj, encoding: .utf8)
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
        let strictPropertyFiles = ["HeroRegistry.swift"]

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
        guard let root = projectRoot else {
            XCTFail("GATE TEST FAILURE: Could not determine project root path"); return
        }

        var violations: [(file: String, lines: Int)] = []

        for dir in lineLimitProjectDirectories {
            let dirPath = root.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirPath.path) else { continue }
            let files = findSwiftFiles(in: dirPath)

            for filePath in files {
                let relativePath = makeRelativePath(filePath: filePath, projectRoot: root)
                if shouldSkipLineLimit(relativePath: relativePath) {
                    continue
                }

                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let lineCount = content.components(separatedBy: .newlines).count

                if lineCount > maxLinesPerFile {
                    violations.append((relativePath, lineCount))
                }
            }
        }

        violations.sort {
            if $0.lines == $1.lines { return $0.file < $1.file }
            return $0.lines > $1.lines
        }

        if !violations.isEmpty {
            let message = violations.map { "  \($0.file): \($0.lines) lines (max \(maxLinesPerFile))" }.joined(separator: "\n")
            XCTFail("""
                Found \(violations.count) files exceeding hard line limit:
                \(message)

                Consider splitting into smaller files:
                - Extract related types into separate files
                - Move extensions to Type+Extension.swift files
                - Group by functionality, not just proximity
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
                let relativePath: String
                let enginePrefix = engine.path.hasSuffix("/") ? engine.path : engine.path + "/"
                if filePath.hasPrefix(enginePrefix) {
                    relativePath = String(filePath.dropFirst(enginePrefix.count))
                } else {
                    relativePath = URL(fileURLWithPath: filePath).lastPathComponent
                }

                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let types = findTopLevelTypeDeclarations(in: content)

                if types.count > maxTypesPerFile {
                    violations.append((relativePath, types))
                }
            }
        }

        if !violations.isEmpty {
            let message = violations.map { file, types in
                "  \(file): \(types.count) types [\(types.prefix(5).joined(separator: ", "))\(types.count > 5 ? "..." : "")]"
            }.joined(separator: "\n")
            XCTFail("""
                Found \(violations.count) engine files with too many top-level types (max \(maxTypesPerFile)):
                \(message)

                Follow "1 file = 1 main type" principle:
                - Primary type: MyType.swift
                - Extensions: MyType+Feature.swift
                - Related small types can stay together if cohesive
                """)
        }
    }

    // MARK: - Helpers

    private func shouldSkipLineLimit(relativePath: String) -> Bool {
        let normalized = "/" + relativePath
        return lineLimitExcludedPathFragments.contains { normalized.contains($0) }
    }
}
