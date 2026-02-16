/// Файл: CardSampleGameTests/GateTests/CodeHygieneTests+XcodeProjectStructure.swift
/// Назначение: Содержит реализацию файла CodeHygieneTests+XcodeProjectStructure.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

extension CodeHygieneTests {

    func testXcodeProjectAppGroupUsesGroupRelativePaths() throws {
        let content = try loadPbxprojContent()

        let forbiddenSubstrings = [
            "path = App/CardGameApp.swift; sourceTree = SOURCE_ROOT;",
            "path = App/ContentView.swift; sourceTree = SOURCE_ROOT;",
            "path = App/BundledPackURLs.swift; sourceTree = SOURCE_ROOT;",
            "path = App/GameEngineObservable.swift; sourceTree = SOURCE_ROOT;"
        ]

        for substring in forbiddenSubstrings {
            XCTAssertFalse(
                content.contains(substring),
                "Xcode project drift: App group should use group-relative paths, found forbidden substring: \(substring)"
            )
        }

        let requiredSubstrings = [
            "path = CardGameApp.swift; sourceTree = \"<group>\";",
            "path = ContentView.swift; sourceTree = \"<group>\";",
            "path = BundledPackURLs.swift; sourceTree = \"<group>\";",
            "path = GameEngineObservable.swift; sourceTree = \"<group>\";"
        ]

        for substring in requiredSubstrings {
            XCTAssertTrue(
                content.contains(substring),
                "Xcode project drift: expected App file reference not found: \(substring)"
            )
        }
    }

    func testXcodeProjectModelsCombatGroupUsesGroupRelativePaths() throws {
        let content = try loadPbxprojContent()

        XCTAssertFalse(
            content.contains("path = Models/Combat/AppCombatSummary.swift; sourceTree = SOURCE_ROOT;"),
            "Xcode project drift: Models/Combat should not be referenced via SOURCE_ROOT path prefix"
        )

        XCTAssertTrue(
            content.contains("path = AppCombatSummary.swift; sourceTree = \"<group>\";"),
            "Xcode project drift: expected Models/Combat AppCombatSummary file reference not found (group-relative)"
        )
    }

    func testXcodeProjectViewsWorldMapGroupUsesGroupRelativePaths() throws {
        let content = try loadPbxprojContent()

        let forbiddenSubstrings = [
            "path = WorldMap/EventLogEntryView.swift; sourceTree = \"<group>\";",
            "path = WorldMap/EngineRegionCardView.swift; sourceTree = \"<group>\";",
            "path = WorldMap/EngineRegionDetailView.swift; sourceTree = \"<group>\";",
            "path = WorldMap/EngineEventLogView.swift; sourceTree = \"<group>\";",
            "path = WorldMap/CardReceivedNotificationOverlay.swift; sourceTree = \"<group>\";"
        ]

        for substring in forbiddenSubstrings {
            XCTAssertFalse(
                content.contains(substring),
                "Xcode project drift: Views/WorldMap should use subgroup-relative paths, found forbidden substring: \(substring)"
            )
        }

        let requiredSubstrings = [
            "path = EventLogEntryView.swift; sourceTree = \"<group>\";",
            "path = EngineRegionCardView.swift; sourceTree = \"<group>\";",
            "path = EngineRegionDetailView.swift; sourceTree = \"<group>\";",
            "path = EngineEventLogView.swift; sourceTree = \"<group>\";",
            "path = CardReceivedNotificationOverlay.swift; sourceTree = \"<group>\";"
        ]

        for substring in requiredSubstrings {
            XCTAssertTrue(
                content.contains(substring),
                "Xcode project drift: expected Views/WorldMap file reference not found: \(substring)"
            )
        }
    }

    func testXcodeProjectViewsComponentsGroupUsesGroupRelativePaths() throws {
        let content = try loadPbxprojContent()

        let forbiddenSubstrings = [
            "path = Views/Components/HeroPanel.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/HeroSelectionCard.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/StatDisplay.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/StatMini.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/LoadSlotCard.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/SaveSlotCard.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/ResonanceWidget.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/DualHealthBar.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/EnemyCardView.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/PhaseBanner.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/FateDeckWidget.swift; sourceTree = SOURCE_ROOT;",
            "path = Views/Components/FateCardChoiceSheet.swift; sourceTree = SOURCE_ROOT;"
        ]

        for substring in forbiddenSubstrings {
            XCTAssertFalse(
                content.contains(substring),
                "Xcode project drift: Views/Components should use group-relative paths, found forbidden substring: \(substring)"
            )
        }

        let requiredSubstrings = [
            "path = HeroPanel.swift; sourceTree = \"<group>\";",
            "path = HeroSelectionCard.swift; sourceTree = \"<group>\";",
            "path = StatDisplay.swift; sourceTree = \"<group>\";",
            "path = StatMini.swift; sourceTree = \"<group>\";",
            "path = LoadSlotCard.swift; sourceTree = \"<group>\";",
            "path = SaveSlotCard.swift; sourceTree = \"<group>\";",
            "path = ResonanceWidget.swift; sourceTree = \"<group>\";",
            "path = DualHealthBar.swift; sourceTree = \"<group>\";",
            "path = EnemyCardView.swift; sourceTree = \"<group>\";",
            "path = PhaseBanner.swift; sourceTree = \"<group>\";",
            "path = FateDeckWidget.swift; sourceTree = \"<group>\";",
            "path = FateCardChoiceSheet.swift; sourceTree = \"<group>\";"
        ]

        for substring in requiredSubstrings {
            XCTAssertTrue(
                content.contains(substring),
                "Xcode project drift: expected Views/Components file reference not found: \(substring)"
            )
        }
    }

    func testXcodeProjectViewModelsGroupUsesGroupRelativePaths() throws {
        let content = try loadPbxprojContent()

        XCTAssertFalse(
            content.contains("path = ViewModels/ContentManagerVM.swift; sourceTree = SOURCE_ROOT;"),
            "Xcode project drift: ViewModels should not be referenced via SOURCE_ROOT path prefix"
        )

        XCTAssertTrue(
            content.contains("path = ContentManagerVM.swift; sourceTree = \"<group>\";"),
            "Xcode project drift: expected ViewModels ContentManagerVM file reference not found (group-relative)"
        )
    }

    func testXcodeProjectRootGroupStaysFeatureOriented() throws {
        let content = try loadPbxprojContent()
        let rootGroupName = "SourceRoot"
        guard let rootGroupBlock = extractPBXGroupBlock(
            named: rootGroupName,
            in: content
        ) ?? extractPBXGroupBlock(
            named: ".",
            in: content
        ) else {
            XCTFail("Xcode project drift: root PBXGroup block (`\(rootGroupName)`/`.`) not found")
            return
        }

        let children = extractChildNames(from: rootGroupBlock)
        let requiredChildren = [
            "App",
            "Models",
            "Views",
            "ViewModels",
            "Utilities",
            "Managers",
            "Assets.xcassets",
            "CardSampleGame.entitlements",
            "Localizable.strings"
        ]

        for child in requiredChildren {
            XCTAssertTrue(
                children.contains(child),
                "Xcode project drift: root group missing canonical child: \(child)"
            )
        }

        let swiftChildren = children.filter { $0.hasSuffix(".swift") }
        XCTAssertTrue(
            swiftChildren.isEmpty,
            """
            Xcode project drift: root group contains flat Swift file references:
            \(swiftChildren.joined(separator: ", "))
            """
        )
    }

    func testXcodeProjectTestsGroupUsesCanonicalSubgroups() throws {
        let content = try loadPbxprojContent()
        guard let testsGroupBlock = extractPBXGroupBlock(
            named: "CardSampleGameTests",
            in: content
        ) else {
            XCTFail("Xcode project drift: `CardSampleGameTests` PBXGroup block not found")
            return
        }

        let children = extractChildNames(from: testsGroupBlock)
        let requiredChildren = ["TestHelpers", "Unit", "GateTests", "Views"]

        for child in requiredChildren {
            XCTAssertTrue(
                children.contains(child),
                "Xcode project drift: CardSampleGameTests group missing canonical subgroup: \(child)"
            )
        }

        let swiftChildren = children.filter { $0.hasSuffix(".swift") }
        XCTAssertTrue(
            swiftChildren.isEmpty,
            """
            Xcode project drift: CardSampleGameTests group has flat Swift files:
            \(swiftChildren.joined(separator: ", "))
            """
        )
    }

    func testXcodeProjectGateTestsGroupAvoidsSourceRootDrift() throws {
        let content = try loadPbxprojContent()
        let forbiddenSubstrings = [
            "path = CardSampleGameTests/GateTests/CodeHygieneTests.swift; sourceTree = SOURCE_ROOT;",
            "path = CardSampleGameTests/GateTests/AuditGateTests.swift; sourceTree = SOURCE_ROOT;",
            "path = CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests.swift; sourceTree = SOURCE_ROOT;"
        ]

        for substring in forbiddenSubstrings {
            XCTAssertFalse(
                content.contains(substring),
                "Xcode project drift: GateTests file reference must stay group-relative, found: \(substring)"
            )
        }

        guard let gateTestsGroupBlock = extractPBXGroupBlock(named: "GateTests", in: content) else {
            XCTFail("Xcode project drift: `GateTests` PBXGroup block not found")
            return
        }

        let children = extractChildNames(from: gateTestsGroupBlock)
        let requiredChildren = [
            "AuditGateTests.swift",
            "AuditArchitectureBoundaryGateTests.swift",
            "CodeHygieneTests.swift"
        ]

        for child in requiredChildren {
            XCTAssertTrue(
                children.contains(child),
                "Xcode project drift: GateTests group missing required file reference: \(child)"
            )
        }
    }

    func testAllGateTestSwiftFilesAreIncludedInCardSampleGameTestsTarget() throws {
        let root = resolveHeaderContractProjectRoot()

        let gateTestsRoot = root.appendingPathComponent("CardSampleGameTests/GateTests")
        guard FileManager.default.fileExists(atPath: gateTestsRoot.path) else {
            XCTFail("GATE TEST FAILURE: GateTests directory not found at \(gateTestsRoot.path)")
            return
        }

        let gateTestFiles = findSwiftFiles(in: gateTestsRoot)
            .map { URL(fileURLWithPath: $0).lastPathComponent }
            .sorted()

        XCTAssertFalse(gateTestFiles.isEmpty, "GATE TEST FAILURE: no Swift files found under GateTests")

        let pbxprojContent = try loadPbxprojContent()
        var missingSourceEntries: [String] = []

        for fileName in gateTestFiles {
            let buildPhaseToken = "/* \(fileName) in Sources */"
            if !pbxprojContent.contains(buildPhaseToken) {
                missingSourceEntries.append(fileName)
            }
        }

        XCTAssertTrue(
            missingSourceEntries.isEmpty,
            """
            Xcode project drift: gate test files are not included in CardSampleGameTests target Sources.
            Missing build-phase entries:
            \(missingSourceEntries.joined(separator: "\n"))
            """
        )
    }

    func testFirstPartySwiftFilesHaveCanonicalFileHeaders() throws {
        let projectRoot = resolveHeaderContractProjectRoot()
        let files = collectFirstPartySwiftFiles(in: projectRoot)

        XCTAssertFalse(files.isEmpty, "GATE TEST FAILURE: no Swift files found for header contract validation")

        var violations: [String] = []

        for fileURL in files {
            let relativePath = makeHeaderContractRelativePath(fileURL: fileURL, root: projectRoot)
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let nonEmptyLines = firstNonEmptyLines(in: content, limit: 4)

            if nonEmptyLines.count < 4 {
                violations.append("\(relativePath): missing canonical 4-line header block")
                continue
            }

            let expectedFileLine = "/// Файл: \(relativePath)"
            if nonEmptyLines[0] != expectedFileLine {
                violations.append("\(relativePath): line 1 must be `\(expectedFileLine)`")
            }
            if !nonEmptyLines[1].hasPrefix("/// Назначение:") {
                violations.append("\(relativePath): line 2 must start with `/// Назначение:`")
            }
            if !nonEmptyLines[2].hasPrefix("/// Зона ответственности:") {
                violations.append("\(relativePath): line 3 must start with `/// Зона ответственности:`")
            }
            if !nonEmptyLines[3].hasPrefix("/// Контекст:") {
                violations.append("\(relativePath): line 4 must start with `/// Контекст:`")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            File header contract violations (\(violations.count)):
            \(violations.prefix(50).joined(separator: "\n"))

            Every first-party Swift file must start with:
            /// Файл: <relative path>
            /// Назначение: ...
            /// Зона ответственности: ...
            /// Контекст: ...
            """
        )
    }

    private func extractPBXGroupBlock(named groupName: String, in content: String) -> String? {
        let marker = "/* \(groupName) */ = {"
        guard let markerRange = content.range(of: marker) else { return nil }
        let suffix = content[markerRange.lowerBound...]

        guard let isaRange = suffix.range(of: "isa = PBXGroup;") else { return nil }
        guard isaRange.lowerBound < suffix.endIndex else { return nil }
        guard let endRange = suffix.range(of: "\n\t\t};") else { return nil }
        guard isaRange.lowerBound < endRange.lowerBound else { return nil }

        return String(suffix[..<endRange.upperBound])
    }

    private func extractChildNames(from groupBlock: String) -> [String] {
        guard let childrenStart = groupBlock.range(of: "children = (") else { return [] }
        guard let childrenEnd = groupBlock[childrenStart.upperBound...].range(of: ");") else { return [] }

        let childrenBody = groupBlock[childrenStart.upperBound..<childrenEnd.lowerBound]
        var names: [String] = []

        for rawLine in childrenBody.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let commentStart = line.range(of: "/* "),
                  let commentEnd = line.range(of: " */") else { continue }

            let name = String(line[commentStart.upperBound..<commentEnd.lowerBound])
            names.append(name)
        }

        return names
    }

    private func resolveHeaderContractProjectRoot() -> URL {
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            return URL(fileURLWithPath: srcRoot).resolvingSymlinksInPath()
        }

        let fileURL = URL(fileURLWithPath: #filePath)
        return fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .resolvingSymlinksInPath()
    }

    private func collectFirstPartySwiftFiles(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let relativePath = makeHeaderContractRelativePath(fileURL: fileURL, root: root)
            if shouldSkipHeaderContract(relativePath: relativePath) {
                continue
            }
            files.append(fileURL)
        }

        return files.sorted { $0.path < $1.path }
    }

    private func shouldSkipHeaderContract(relativePath: String) -> Bool {
        let normalized = "/" + relativePath
        let excludedFragments = [
            "/.build/",
            "/Packages/ThirdParty/",
            "/.codex_home/",
            "/Package.swift"
        ]

        return excludedFragments.contains { normalized.contains($0) }
    }

    private func makeHeaderContractRelativePath(fileURL: URL, root: URL) -> String {
        let normalizedRootPath = normalizeHeaderContractPath(root.path)
        let normalizedFilePath = normalizeHeaderContractPath(fileURL.path)
        let rootPrefix = normalizedRootPath.hasSuffix("/") ? normalizedRootPath : normalizedRootPath + "/"

        guard normalizedFilePath.hasPrefix(rootPrefix) else {
            return normalizedFilePath
        }

        return String(normalizedFilePath.dropFirst(rootPrefix.count))
    }

    private func normalizeHeaderContractPath(_ path: String) -> String {
        let resolved = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        if resolved.hasPrefix("/private/var/") {
            return String(resolved.dropFirst("/private".count))
        }

        return resolved
    }

    private func firstNonEmptyLines(in content: String, limit: Int) -> [String] {
        var lines: [String] = []
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }
            lines.append(line)
            if lines.count == limit {
                break
            }
        }
        return lines
    }
}
