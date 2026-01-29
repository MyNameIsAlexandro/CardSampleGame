import Foundation

/// Encounter Engine — processes encounters as pure input→output
/// Reference: ENCOUNTER_SYSTEM_DESIGN.md
///
/// All methods are stubs (fatalError) until implementation.
/// Tests are RED TDD — they compile but fail at runtime.
public final class EncounterEngine {

    // MARK: - State (read-only externally)

    public private(set) var currentPhase: EncounterPhase
    public private(set) var currentRound: Int
    public private(set) var heroHP: Int
    public private(set) var enemies: [EncounterEnemyState]
    public private(set) var currentIntent: EnemyIntent?
    public private(set) var isFinished: Bool
    public private(set) var mulliganDone: Bool
    public private(set) var lastAttackTrack: AttackTrack?

    private let context: EncounterContext
    private let rng: WorldRNG
    private var fateDeck: FateDeckManager

    // MARK: - Init

    public init(context: EncounterContext) {
        self.context = context
        self.currentPhase = .intent
        self.currentRound = 1
        self.heroHP = context.hero.hp
        self.enemies = context.enemies.map { EncounterEnemyState(from: $0) }
        self.isFinished = false
        self.mulliganDone = false
        self.rng = WorldRNG(seed: context.rngSeed)
        if let state = context.rngState {
            self.rng.restoreState(state)
        }
        self.fateDeck = FateDeckManager(cards: [], rng: rng)
        self.fateDeck.restoreState(context.fateDeckSnapshot)
    }

    // MARK: - Actions

    public func performAction(_ action: PlayerAction) -> EncounterActionResult {
        fatalError("EncounterEngine.performAction not implemented — TDD RED")
    }

    public func advancePhase() -> EncounterPhase {
        fatalError("EncounterEngine.advancePhase not implemented — TDD RED")
    }

    public func generateIntent(for enemyId: String) -> EnemyIntent {
        fatalError("EncounterEngine.generateIntent not implemented — TDD RED")
    }

    public func resolveEnemyAction(enemyId: String) -> EncounterActionResult {
        fatalError("EncounterEngine.resolveEnemyAction not implemented — TDD RED")
    }

    public func finishEncounter() -> EncounterResult {
        fatalError("EncounterEngine.finishEncounter not implemented — TDD RED")
    }
}

/// Mutable enemy state within an encounter
public struct EncounterEnemyState: Equatable {
    public let id: String
    public let name: String
    public var hp: Int
    public let maxHp: Int
    public var wp: Int?
    public let maxWp: Int?
    public var power: Int
    public var defense: Int
    public var rageShield: Int
    public var outcome: EntityOutcome?

    public var hasSpiritTrack: Bool { wp != nil }
    public var isAlive: Bool { hp > 0 }
    public var isPacified: Bool { wp != nil && wp! <= 0 && hp > 0 }

    public init(from enemy: EncounterEnemy) {
        self.id = enemy.id
        self.name = enemy.name
        self.hp = enemy.hp
        self.maxHp = enemy.maxHp
        self.wp = enemy.wp
        self.maxWp = enemy.maxWp
        self.power = enemy.power
        self.defense = enemy.defense
        self.rageShield = 0
        self.outcome = nil
    }
}

/// Which track was last attacked (for escalation/de-escalation)
public enum AttackTrack: Equatable {
    case physical
    case spiritual
}
