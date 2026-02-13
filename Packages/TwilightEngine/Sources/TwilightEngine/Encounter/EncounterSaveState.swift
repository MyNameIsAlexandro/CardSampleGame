/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/EncounterSaveState.swift
/// Назначение: Содержит реализацию файла EncounterSaveState.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Serializable snapshot of an in-progress encounter for mid-combat save/resume.
public struct EncounterSaveState: Codable, Equatable {
    // MARK: - Core State
    public let currentPhase: EncounterPhase
    public let currentRound: Int
    public let heroHP: Int
    public let enemies: [EncounterEnemyState]
    public let currentIntent: EnemyIntent?
    public let isFinished: Bool
    public let mulliganDone: Bool
    public let lastAttackTrack: AttackTrack?
    public let lastFateDrawResult: FateDrawResult?

    // MARK: - Card Hand State
    public let hand: [Card]
    public let cardDiscardPile: [Card]
    public let turnAttackBonus: Int
    public let turnDefenseBonus: Int
    public let turnInfluenceBonus: Int
    public let heroFaith: Int
    public let pendingFateChoice: FateCard?
    public let finishActionUsed: Bool
    public let fleeSucceeded: Bool

    // MARK: - Context + RNG + Fate Deck
    public let context: EncounterContext
    public let rngState: UInt64
    public let fateDeckState: FateDeckState
    public let accumulatedResonanceDelta: Float
}
