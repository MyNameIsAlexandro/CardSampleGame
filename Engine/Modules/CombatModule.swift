import Foundation

// MARK: - Combat Module
// Engine integration for combat system
// Wraps CombatCalculator and provides state change diffs

/// Combat module for engine integration
final class CombatModule {
    // MARK: - State

    private(set) var isInCombat: Bool = false
    private(set) var currentEncounter: CombatEncounter?
    private(set) var combatLog: [CombatLogEntry] = []
    private(set) var turnNumber: Int = 0
    private(set) var playerActionsRemaining: Int = 3

    // MARK: - Combat Entry

    /// Start combat with an encounter
    func startCombat(encounter: CombatEncounter) -> [StateChange] {
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
    func endCombat(victory: Bool) -> [StateChange] {
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

    /// Execute player attack
    func executeAttack(
        player: Player,
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

        // Use CombatCalculator
        let result = CombatCalculator.calculatePlayerAttack(
            player: player,
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

    /// Execute player card play
    func playCard(
        cardId: UUID,
        player: Player,
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
                let newHealth = min(player.maxHealth, player.health + amount)
                stateChanges.append(.healthChanged(delta: amount, newValue: newHealth))

            case .drawCards(let count):
                stateChanges.append(.custom(key: "draw_cards", description: "Draw \(count) cards"))

            case .gainFaith(let amount):
                stateChanges.append(.faithChanged(delta: amount, newValue: player.faith + amount))

            case .bonusDice(let count):
                stateChanges.append(.custom(key: "bonus_dice", description: "Gained \(count) bonus dice"))

            case .bonusDamage(let amount):
                stateChanges.append(.custom(key: "bonus_damage", description: "Gained \(amount) bonus damage"))

            case .balanceShift(let amount):
                let newBalance = max(0, min(100, player.balance + amount))
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

    /// End player turn
    func endPlayerTurn(player: Player) -> CombatActionResult {
        guard let encounter = currentEncounter else {
            return CombatActionResult.failure("No active encounter")
        }

        var stateChanges: [StateChange] = []

        // Enemy attack
        let enemyAttack = calculateEnemyAttack(encounter: encounter, player: player)
        stateChanges.append(contentsOf: enemyAttack.stateChanges)

        // Check if player defeated
        let playerDefeated = player.health + (enemyAttack.healthChange) <= 0

        // Start new turn
        turnNumber += 1
        playerActionsRemaining = 3

        // Apply exhaustion curse if present
        if player.hasCurse(.exhaustion) {
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
        player: Player
    ) -> (stateChanges: [StateChange], hit: Bool, healthChange: Int, description: String) {

        var stateChanges: [StateChange] = []

        // Enemy attack roll
        let attackRoll = WorldRNG.shared.nextInt(in: 1...6) + encounter.strength
        let playerDefense = 5 + (player.strength / 2)

        let hit = attackRoll >= playerDefense
        var healthChange = 0

        if hit {
            var damage = max(1, encounter.strength - 2)

            // Priest reduces dark damage
            if player.heroClass == .priest {
                damage = max(1, damage - 1)
            }

            healthChange = -damage
            stateChanges.append(.healthChanged(delta: -damage, newValue: player.health - damage))
        }

        let description = hit
            ? "Enemy hit for \(-healthChange) damage"
            : "Enemy missed"

        return (stateChanges, hit, healthChange, description)
    }
}

// MARK: - Combat Encounter

/// Combat encounter state
struct CombatEncounter {
    let id: UUID
    let name: String
    let maxHP: Int
    var currentHP: Int
    let strength: Int
    let defense: Int
    let isBoss: Bool

    init(
        id: UUID = UUID(),
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
    static func from(card: Card) -> CombatEncounter {
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
struct CombatActionResult {
    let success: Bool
    let error: String?
    let stateChanges: [StateChange]
    let combatResult: CombatResult?
    let encounterDefeated: Bool
    let playerDefeated: Bool

    static func success(
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

    static func failure(_ error: String) -> CombatActionResult {
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
struct CombatLogEntry {
    let turn: Int
    let actor: CombatActor
    var action: String
    var result: String
    let details: String
}

enum CombatActor {
    case player
    case enemy
}

// MARK: - Card Effect

/// Effects that cards can have in combat
enum CardEffect {
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
enum CombatDamageKind {
    case physical
    case magical
    case light
    case dark
}
