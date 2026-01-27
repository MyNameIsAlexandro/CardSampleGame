import Foundation

// MARK: - Combat Module
// Engine integration for combat system
// Wraps CombatCalculator and provides state change diffs

/// Combat module for engine integration
public final class CombatModule {
    // MARK: - State

    private(set) var isInCombat: Bool = false
    private(set) var currentEncounter: CombatEncounter?
    private(set) var combatLog: [CombatLogEntry] = []
    private(set) var turnNumber: Int = 0
    private(set) var playerActionsRemaining: Int = 3

    // MARK: - Combat Entry

    /// Start combat with an encounter
    public func startCombat(encounter: CombatEncounter) -> [StateChange] {
        isInCombat = true
        currentEncounter = encounter
        combatLog = []
        turnNumber = 1
        playerActionsRemaining = 3

        return [
            .custom(key: "combat_started", description: "Combat started with \(encounter.name)")
        ]
    }

    /// End combat
    public func endCombat(victory: Bool) -> [StateChange] {
        let changes: [StateChange] = [
            .combatEnded(victory: victory)
        ]

        isInCombat = false
        currentEncounter = nil
        combatLog = []
        turnNumber = 0
        playerActionsRemaining = 0

        return changes
    }

    // MARK: - Combat Actions

    /// Execute player attack using CombatPlayerContext (Engine-First Architecture)
    public func executeAttack(
        context: CombatPlayerContext,
        bonusDice: Int = 0,
        bonusDamage: Int = 0,
        isFirstAttack: Bool = false
    ) -> CombatActionResult {

        guard let encounter = currentEncounter else {
            return CombatActionResult.failure("No active encounter")
        }

        guard playerActionsRemaining > 0 else {
            return CombatActionResult.failure("No actions remaining")
        }

        playerActionsRemaining -= 1

        // Use CombatCalculator with context
        let result = CombatCalculator.calculatePlayerAttack(
            context: context,
            monsterDefense: encounter.defense,
            monsterCurrentHP: encounter.currentHP,
            monsterMaxHP: encounter.maxHP,
            bonusDice: bonusDice,
            bonusDamage: bonusDamage,
            isFirstAttack: isFirstAttack
        )

        var stateChanges: [StateChange] = []
        var logEntry = CombatLogEntry(
            turn: turnNumber,
            actor: .player,
            action: "Attack",
            result: result.isHit ? "Hit" : "Miss",
            details: result.logDescription
        )

        if result.isHit, let damage = result.damageCalculation {
            // Apply damage to encounter
            currentEncounter?.currentHP -= damage.total
            stateChanges.append(.enemyDamaged(
                enemyId: encounter.id,
                damage: damage.total,
                newHealth: currentEncounter?.currentHP ?? 0
            ))

            // Check if defeated
            if currentEncounter?.currentHP ?? 0 <= 0 {
                stateChanges.append(.enemyDefeated(enemyId: encounter.id))
                logEntry.result = "Defeat!"
            }
        }

        combatLog.append(logEntry)

        return CombatActionResult.success(
            stateChanges: stateChanges,
            combatResult: result,
            encounterDefeated: currentEncounter?.currentHP ?? 0 <= 0
        )
    }

    /// Execute player card play using CombatPlayerContext (Engine-First Architecture)
    public func playCard(
        cardId: String,
        context: CombatPlayerContext,
        effects: [CardEffect]
    ) -> CombatActionResult {

        guard currentEncounter != nil else {
            return CombatActionResult.failure("No active encounter")
        }

        guard playerActionsRemaining > 0 else {
            return CombatActionResult.failure("No actions remaining")
        }

        playerActionsRemaining -= 1

        var stateChanges: [StateChange] = []

        // Apply card effects
        for effect in effects {
            switch effect {
            case .damage(let amount, _):
                currentEncounter?.currentHP -= amount
                if let encounter = currentEncounter {
                    stateChanges.append(.enemyDamaged(
                        enemyId: encounter.id,
                        damage: amount,
                        newHealth: encounter.currentHP
                    ))
                }

            case .heal(let amount):
                let newHealth = min(context.maxHealth, context.health + amount)
                stateChanges.append(.healthChanged(delta: amount, newValue: newHealth))

            case .drawCards(let count):
                stateChanges.append(.custom(key: "draw_cards", description: "Draw \(count) cards"))

            case .gainFaith(let amount):
                stateChanges.append(.faithChanged(delta: amount, newValue: context.faith + amount))

            case .bonusDice(let count):
                stateChanges.append(.custom(key: "bonus_dice", description: "Gained \(count) bonus dice"))

            case .bonusDamage(let amount):
                stateChanges.append(.custom(key: "bonus_damage", description: "Gained \(amount) bonus damage"))

            case .balanceShift(let amount):
                let newBalance = max(0, min(100, context.balance + amount))
                stateChanges.append(.balanceChanged(delta: amount, newValue: newBalance))
            }
        }

        // Check if encounter defeated
        if currentEncounter?.currentHP ?? 0 <= 0 {
            if let encounter = currentEncounter {
                stateChanges.append(.enemyDefeated(enemyId: encounter.id))
            }
        }

        let logEntry = CombatLogEntry(
            turn: turnNumber,
            actor: .player,
            action: "Card",
            result: "Applied",
            details: "Card effects applied"
        )
        combatLog.append(logEntry)

        return CombatActionResult.success(
            stateChanges: stateChanges,
            combatResult: nil,
            encounterDefeated: currentEncounter?.currentHP ?? 0 <= 0
        )
    }

    /// End player turn using CombatPlayerContext (Engine-First Architecture)
    public func endPlayerTurn(context: CombatPlayerContext) -> CombatActionResult {
        guard let encounter = currentEncounter else {
            return CombatActionResult.failure("No active encounter")
        }

        var stateChanges: [StateChange] = []

        // Enemy attack
        let enemyAttack = calculateEnemyAttack(encounter: encounter, context: context)
        stateChanges.append(contentsOf: enemyAttack.stateChanges)

        // Check if player defeated
        let playerDefeated = context.health + (enemyAttack.healthChange) <= 0

        // Start new turn
        turnNumber += 1
        playerActionsRemaining = 3

        // Apply exhaustion curse if present
        if context.hasCurse(.exhaustion) {
            playerActionsRemaining -= 1
            stateChanges.append(.custom(key: "exhaustion", description: "Exhaustion: -1 action"))
        }

        let logEntry = CombatLogEntry(
            turn: turnNumber - 1,
            actor: .enemy,
            action: "Attack",
            result: enemyAttack.hit ? "Hit" : "Miss",
            details: enemyAttack.description
        )
        combatLog.append(logEntry)

        return CombatActionResult.success(
            stateChanges: stateChanges,
            combatResult: nil,
            encounterDefeated: false,
            playerDefeated: playerDefeated
        )
    }

    // MARK: - Enemy AI

    private func calculateEnemyAttack(
        encounter: CombatEncounter,
        context: CombatPlayerContext
    ) -> (stateChanges: [StateChange], hit: Bool, healthChange: Int, description: String) {

        var stateChanges: [StateChange] = []

        // Enemy attack roll
        let attackRoll = WorldRNG.shared.nextInt(in: 1...6) + encounter.strength
        let playerDefense = 5 + (context.strength / 2)

        let hit = attackRoll >= playerDefense
        var healthChange = 0

        if hit {
            var damage = max(1, encounter.strength - 2)

            // Hero ability may reduce damage (e.g., Priest vs dark sources)
            let heroReduction = context.getHeroDamageReduction(fromDarkSource: true)
            damage = max(1, damage - heroReduction)

            healthChange = -damage
            stateChanges.append(.healthChanged(delta: -damage, newValue: context.health - damage))
        }

        let description = hit
            ? "Enemy hit for \(-healthChange) damage"
            : "Enemy missed"

        return (stateChanges, hit, healthChange, description)
    }
}

// MARK: - Combat Encounter

/// Combat encounter state
public struct CombatEncounter {
    public let id: String
    public let name: String
    public let maxHP: Int
    public var currentHP: Int
    public let strength: Int
    public let defense: Int
    public let isBoss: Bool

    public init(
        id: String,
        name: String,
        maxHP: Int,
        strength: Int,
        defense: Int,
        isBoss: Bool = false
    ) {
        self.id = id
        self.name = name
        self.maxHP = maxHP
        self.currentHP = maxHP
        self.strength = strength
        self.defense = defense
        self.isBoss = isBoss
    }

    /// Create from Card (monster)
    /// Maps Card stats: health -> maxHP, power -> strength, defense -> defense
    /// Boss detection: legendary rarity or "boss" trait
    public static func from(card: Card) -> CombatEncounter {
        // Determine if card is a boss (legendary rarity or has boss trait)
        let isBoss = card.rarity == .legendary || card.traits.contains("boss")

        return CombatEncounter(
            id: card.id,
            name: card.name,
            maxHP: card.health ?? 10,
            strength: card.power ?? 3,
            defense: card.defense ?? 5,
            isBoss: isBoss
        )
    }
}

// MARK: - Combat Action Result

/// Result of combat action
public struct CombatActionResult {
    public let success: Bool
    public let error: String?
    public let stateChanges: [StateChange]
    public let combatResult: CombatResult?
    public let encounterDefeated: Bool
    public let playerDefeated: Bool

    public static func success(
        stateChanges: [StateChange],
        combatResult: CombatResult?,
        encounterDefeated: Bool,
        playerDefeated: Bool = false
    ) -> CombatActionResult {
        CombatActionResult(
            success: true,
            error: nil,
            stateChanges: stateChanges,
            combatResult: combatResult,
            encounterDefeated: encounterDefeated,
            playerDefeated: playerDefeated
        )
    }

    public static func failure(_ error: String) -> CombatActionResult {
        CombatActionResult(
            success: false,
            error: error,
            stateChanges: [],
            combatResult: nil,
            encounterDefeated: false,
            playerDefeated: false
        )
    }
}

// MARK: - Combat Log Entry

/// Entry in combat log
public struct CombatLogEntry {
    public let turn: Int
    public let actor: CombatActor
    public var action: String
    public var result: String
    public let details: String
}

public enum CombatActor {
    case player
    case enemy
}

// MARK: - Card Effect

/// Effects that cards can have in combat
public enum CardEffect {
    case damage(amount: Int, type: CombatDamageKind)
    case heal(amount: Int)
    case drawCards(count: Int)
    case gainFaith(amount: Int)
    case bonusDice(count: Int)
    case bonusDamage(amount: Int)
    case balanceShift(amount: Int)
}

/// Simplified damage categories for combat resolution
/// Different from DamageType in CardType.swift (detailed card damage types)
public enum CombatDamageKind {
    case physical
    case magical
    case light
    case dark
}
