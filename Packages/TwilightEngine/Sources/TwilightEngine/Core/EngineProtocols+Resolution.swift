/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+Resolution.swift
/// Назначение: Содержит реализацию файла EngineProtocols+Resolution.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 4. Resolution System (Conflicts)
// ═══════════════════════════════════════════════════════════════════════════════

/// Types of challenges/conflicts
public enum ChallengeType: String, Codable {
    case combat
    case skillCheck
    case socialEncounter
    case puzzle
    case tradeOff
    case sacrifice
}

/// Abstract challenge definition
public protocol ChallengeDefinition {
    var type: ChallengeType { get }
    var difficulty: Int { get }
    var context: Any? { get }
}

/// Result of challenge resolution
public enum ResolutionResult<Reward, Penalty> {
    case success(Reward)
    case failure(Penalty)
    case partial(reward: Reward, penalty: Penalty)
    case cancelled
}

/// Conflict resolver protocol - pluggable resolution mechanics
public protocol ConflictResolverProtocol {
    associatedtype Challenge: ChallengeDefinition
    associatedtype Actor
    associatedtype Reward
    associatedtype Penalty

    /// Resolve a challenge. Can be async for animations/UI.
    func resolve(
        challenge: Challenge,
        actor: Actor
    ) async -> ResolutionResult<Reward, Penalty>
}
