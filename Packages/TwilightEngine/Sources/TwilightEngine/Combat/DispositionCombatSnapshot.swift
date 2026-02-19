/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCombatSnapshot.swift
/// Назначение: Codable snapshot for save/load/resume of disposition combat.
/// Зона ответственности: Encode all required state fields, decode and restore to simulation.
/// Контекст: Epic 23 — Integration & Save/Restore. Snapshot contract freeze after green tests.

import Foundation

/// Codable snapshot capturing full disposition combat state for save/resume.
public struct DispositionCombatSnapshot: Codable, Equatable {

    // MARK: - Disposition Track

    public let disposition: Int
    public let outcome: DispositionOutcome?

    // MARK: - Momentum

    public let streakType: DispositionActionType?
    public let streakCount: Int
    public let lastActionType: DispositionActionType?

    // MARK: - Energy

    public let energy: Int
    public let startingEnergy: Int

    // MARK: - Sacrifice

    public let sacrificeUsedThisTurn: Bool
    public let enemySacrificeBuff: Int

    // MARK: - Card Zones

    public let hand: [Card]
    public let discardPile: [Card]
    public let exhaustPile: [Card]

    // MARK: - Hero

    public let heroHP: Int
    public let heroMaxHP: Int

    // MARK: - Combat Context

    public let resonanceZone: ResonanceZone
    public let enemyType: String

    // MARK: - Enemy Effects

    public let defendReduction: Int
    public let provokePenalty: Int
    public let adaptPenalty: Int
    public let pleaBacklash: Int

    // MARK: - Echo State

    public let lastPlayedCardId: String?
    public let lastPlayedAction: DispositionActionType?
    public let lastPlayedBasePower: Int
    public let lastFateModifier: Int
    public let echoUsedThisAction: Bool

    // MARK: - Determinism

    public let seed: UInt64
    public let rngState: UInt64

    // MARK: - Create from Simulation

    /// Capture a snapshot from a live simulation.
    public static func capture(from sim: DispositionCombatSimulation) -> DispositionCombatSnapshot {
        DispositionCombatSnapshot(
            disposition: sim.disposition,
            outcome: sim.outcome,
            streakType: sim.streakType,
            streakCount: sim.streakCount,
            lastActionType: sim.lastActionType,
            energy: sim.energy,
            startingEnergy: sim.startingEnergy,
            sacrificeUsedThisTurn: sim.sacrificeUsedThisTurn,
            enemySacrificeBuff: sim.enemySacrificeBuff,
            hand: sim.hand,
            discardPile: sim.discardPile,
            exhaustPile: sim.exhaustPile,
            heroHP: sim.heroHP,
            heroMaxHP: sim.heroMaxHP,
            resonanceZone: sim.resonanceZone,
            enemyType: sim.enemyType,
            defendReduction: sim.defendReduction,
            provokePenalty: sim.provokePenalty,
            adaptPenalty: sim.adaptPenalty,
            pleaBacklash: sim.pleaBacklash,
            lastPlayedCardId: sim.lastPlayedCardId,
            lastPlayedAction: sim.lastPlayedAction,
            lastPlayedBasePower: sim.lastPlayedBasePower,
            lastFateModifier: sim.lastFateModifier,
            echoUsedThisAction: sim.echoUsedThisAction,
            seed: sim.seed,
            rngState: sim.rng.currentState()
        )
    }

    // MARK: - Restore to Simulation

    /// Restore a simulation from this snapshot.
    public func restore() -> DispositionCombatSimulation {
        let rng = WorldRNG(seed: seed)
        rng.restoreState(rngState)

        return DispositionCombatSimulation(
            disposition: disposition,
            outcome: outcome,
            streakType: streakType,
            streakCount: streakCount,
            lastActionType: lastActionType,
            energy: energy,
            startingEnergy: startingEnergy,
            sacrificeUsedThisTurn: sacrificeUsedThisTurn,
            enemySacrificeBuff: enemySacrificeBuff,
            hand: hand,
            discardPile: discardPile,
            exhaustPile: exhaustPile,
            heroHP: heroHP,
            heroMaxHP: heroMaxHP,
            resonanceZone: resonanceZone,
            enemyType: enemyType,
            defendReduction: defendReduction,
            provokePenalty: provokePenalty,
            adaptPenalty: adaptPenalty,
            pleaBacklash: pleaBacklash,
            lastPlayedCardId: lastPlayedCardId,
            lastPlayedAction: lastPlayedAction,
            lastPlayedBasePower: lastPlayedBasePower,
            lastFateModifier: lastFateModifier,
            echoUsedThisAction: echoUsedThisAction,
            rng: rng,
            seed: seed
        )
    }
}
