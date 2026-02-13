/// Файл: Packages/EchoEngine/Sources/EchoEngine/EchoCombatResult.swift
/// Назначение: Содержит реализацию файла EchoCombatResult.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import TwilightEngine

/// Result of a completed combat encounter, containing all deltas to apply back to the game.
public struct EchoCombatResult: Sendable {
    public let outcome: CombatOutcome
    /// Resonance shift: negative for kill (Nav), positive for pacify (Prav)
    public let resonanceDelta: Int
    public let faithDelta: Int
    public let lootCardIds: [String]
    public let updatedFateDeckState: FateDeckState?
    /// Net HP change for the player (negative = damage taken)
    public let hpDelta: Int
    public let turnsPlayed: Int
    public let totalDamageDealt: Int
    public let totalDamageTaken: Int
    public let cardsPlayed: Int

    public init(
        outcome: CombatOutcome,
        resonanceDelta: Int = 0,
        faithDelta: Int = 0,
        lootCardIds: [String] = [],
        updatedFateDeckState: FateDeckState? = nil,
        hpDelta: Int = 0,
        turnsPlayed: Int = 0,
        totalDamageDealt: Int = 0,
        totalDamageTaken: Int = 0,
        cardsPlayed: Int = 0
    ) {
        self.outcome = outcome
        self.resonanceDelta = resonanceDelta
        self.faithDelta = faithDelta
        self.lootCardIds = lootCardIds
        self.updatedFateDeckState = updatedFateDeckState
        self.hpDelta = hpDelta
        self.turnsPlayed = turnsPlayed
        self.totalDamageDealt = totalDamageDealt
        self.totalDamageTaken = totalDamageTaken
        self.cardsPlayed = cardsPlayed
    }
}
