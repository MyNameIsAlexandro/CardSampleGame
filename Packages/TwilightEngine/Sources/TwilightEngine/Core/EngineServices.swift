/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineServices.swift
/// Назначение: Содержит реализацию файла EngineServices.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Engine Services (Dependency Container)

/// Aggregates all dependencies for TwilightGameEngine.
/// Replaces global singletons with explicit, injectable services.
public struct EngineServices {
    /// Deterministic RNG for all game logic.
    public let rng: WorldRNG

    /// Content registry for loading and querying game data.
    public let contentRegistry: ContentRegistry

    /// Localization manager for content-pack string tables.
    public let localizationManager: LocalizationManager

    /// Rules for region degradation.
    public let degradationRules: DegradationRuleSet

    public init(
        rng: WorldRNG,
        contentRegistry: ContentRegistry,
        localizationManager: LocalizationManager,
        degradationRules: DegradationRuleSet? = nil
    ) {
        self.rng = rng
        self.contentRegistry = contentRegistry
        self.localizationManager = localizationManager
        self.degradationRules = degradationRules ?? TwilightDegradationRules(
            anchorConfig: contentRegistry.getBalanceConfig()?.anchor
        )
    }

    public static func makeDefault() -> EngineServices {
        let registry = ContentRegistry()
        return EngineServices(
            rng: WorldRNG(),
            contentRegistry: registry,
            localizationManager: LocalizationManager()
        )
    }
}
