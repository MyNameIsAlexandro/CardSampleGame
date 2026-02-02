import Foundation

// MARK: - Engine Services (Dependency Container)

/// Aggregates all dependencies for TwilightGameEngine.
/// Replaces global singletons with explicit, injectable services.
public struct EngineServices {
    /// Deterministic RNG for all game logic.
    public let rng: WorldRNG

    /// Content registry for loading and querying game data.
    public let contentRegistry: ContentRegistry

    /// Rules for region degradation.
    public let degradationRules: DegradationRuleSet

    public init(
        rng: WorldRNG = .shared,
        contentRegistry: ContentRegistry = .shared,
        degradationRules: DegradationRuleSet? = nil
    ) {
        self.rng = rng
        self.contentRegistry = contentRegistry
        self.degradationRules = degradationRules ?? TwilightDegradationRules(
            anchorConfig: contentRegistry.getBalanceConfig()?.anchor
        )
    }

    /// Default services using shared instances (backward compatibility).
    public static let `default` = EngineServices()
}
