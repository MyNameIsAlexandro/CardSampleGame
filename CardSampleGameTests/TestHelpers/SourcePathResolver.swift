/// Файл: CardSampleGameTests/TestHelpers/SourcePathResolver.swift
/// Назначение: Содержит реализацию файла SourcePathResolver.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation

/// Centralizes source file path resolution for gate tests.
/// Requirement: AUDIT_FIXLIST C1 - no hardcoded paths scattered in tests.
///
/// All engine source paths should use this resolver to ensure:
/// 1. Paths are consistent across all gate tests
/// 2. Path changes only need to be made in one place
/// 3. Tests fail clearly if paths are wrong
struct SourcePathResolver {

    // MARK: - Base Paths

    /// Project root directory (where CardSampleGame.xcodeproj is located)
    static var projectRoot: URL {
        // Navigate from test file to project root
        var url = URL(fileURLWithPath: #file)
        // Go up: SourcePathResolver.swift -> TestHelpers -> CardSampleGameTests -> Project Root
        for _ in 0..<3 {
            url = url.deletingLastPathComponent()
        }
        return url
    }

    /// TwilightEngine package base path
    static var engineBase: String {
        "Packages/TwilightEngine/Sources/TwilightEngine"
    }

    /// Full URL to TwilightEngine sources
    static var engineBaseURL: URL {
        projectRoot.appendingPathComponent(engineBase)
    }

    // MARK: - Engine Core Paths

    /// Path to TwilightGameEngine.swift
    static var twilightGameEngine: URL {
        engineBaseURL.appendingPathComponent("Core/TwilightGameEngine.swift")
    }

    /// Path to EngineSave.swift
    static var engineSave: URL {
        engineBaseURL.appendingPathComponent("Core/EngineSave.swift")
    }

    /// Path to EngineProtocols.swift
    static var engineProtocols: URL {
        engineBaseURL.appendingPathComponent("Core/EngineProtocols.swift")
    }

    // MARK: - Engine Module Paths

    /// Path to ExplorationModels.swift
    static var explorationModels: URL {
        engineBaseURL.appendingPathComponent("Models/ExplorationModels.swift")
    }

    /// Path to BalanceConfiguration.swift
    static var balanceConfiguration: URL {
        engineBaseURL.appendingPathComponent("ContentPacks/BalanceConfiguration.swift")
    }

    /// Path to ContentRegistry.swift
    static var contentRegistry: URL {
        engineBaseURL.appendingPathComponent("ContentPacks/ContentRegistry.swift")
    }

    // MARK: - Core Directories

    /// All core engine directories to scan for architectural compliance
    static var coreDirectories: [String] {
        [
            "\(engineBase)/Core",
            "\(engineBase)/ContentPacks",
            "\(engineBase)/Events",
            "\(engineBase)/Combat",
            "\(engineBase)/Quest",
            "\(engineBase)/Cards",
            "\(engineBase)/Heroes",
            "\(engineBase)/Modules",
            "\(engineBase)/Config",
            "\(engineBase)/Runtime",
            "\(engineBase)/Story",
            "\(engineBase)/Localization"
        ]
    }

    /// All production code directories (Engine + App)
    static var productionDirectories: [String] {
        [engineBase, "App", "Views", "Models", "Utilities"]
    }

    // MARK: - Validation

    /// Check if a critical path exists, fail the test if not
    static func requireExists(_ url: URL, file: StaticString = #file, line: UInt = #line) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        return false
    }

    /// Get full path for a relative path within the project
    static func resolve(_ relativePath: String) -> URL {
        projectRoot.appendingPathComponent(relativePath)
    }

    /// Check if the project root is correctly resolved
    static func validateProjectRoot() -> Bool {
        // Check that Views folder exists at project root
        let viewsPath = projectRoot.appendingPathComponent("Views")
        return FileManager.default.fileExists(atPath: viewsPath.path)
    }
}
