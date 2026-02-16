/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatSnapshot.swift
/// Назначение: Codable snapshot DTO для полного состояния CombatSimulation.
/// Зона ответственности: Save/load/replay — детерминированное восстановление боя.
/// Контекст: Phase 3 Ritual Combat (R1). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import Foundation

// MARK: - Combat Simulation Phase

/// Phase of the ritual combat state machine
public enum CombatSimulationPhase: String, Codable, Equatable, Sendable {
    case playerAction
    case resolution
    case finished
}

// MARK: - Combat Snapshot

/// Immutable snapshot of full CombatSimulation state for save/load/replay.
/// All fields are non-optional — snapshot is always complete.
public struct CombatSnapshot: Codable, Equatable {

    // MARK: Hero state

    public let heroHP: Int
    public let heroMaxHP: Int
    public let heroStrength: Int
    public let heroWisdom: Int
    public let heroArmor: Int

    // MARK: Hand management

    public let hand: [Card]
    public let discardPile: [Card]
    public let exhaustPile: [Card]

    // MARK: Effort state

    public let effortBonus: Int
    public let effortCardIds: [String]
    public let selectedCardIds: Set<String>
    public let maxEffort: Int

    // MARK: Energy

    public let energy: Int
    public let reservedEnergy: Int

    // MARK: Enemies

    public let enemies: [EncounterEnemyState]

    // MARK: Determinism state

    public let fateDeckState: FateDeckState
    public let rngState: UInt64

    // MARK: World context

    public let worldResonance: Float
    public let balanceConfig: CombatBalanceConfig

    // MARK: Phase

    public let phase: CombatSimulationPhase
    public let round: Int
}
