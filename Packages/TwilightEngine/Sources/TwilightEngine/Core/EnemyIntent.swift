import Foundation

// MARK: - Enemy Intent System
// Shows what the enemy will do BEFORE player acts (Active Defense system)

/// Type of action the enemy intends to perform
public enum IntentType: String, Codable, Equatable {
    /// Physical attack dealing damage
    case attack
    /// Dark ritual - shifts resonance toward Nav
    case ritual
    /// Defensive stance - reduces damage taken
    case block
    /// Self-buff - increases stats for future turns
    case buff
    /// Heal - restores enemy health
    case heal
    /// Summon - calls reinforcements (not implemented yet)
    case summon
}

/// Enemy's declared intention for the upcoming turn
/// Shown to player BEFORE they choose their action (Active Defense)
public struct EnemyIntent: Equatable {
    /// What type of action the enemy will perform
    public let type: IntentType

    /// Numeric value of the action (damage amount, heal amount, etc.)
    public let value: Int

    /// Localized description for UI display
    public let description: String

    /// Optional secondary value (e.g., resonance shift amount for rituals)
    public let secondaryValue: Int?

    public init(
        type: IntentType,
        value: Int,
        description: String,
        secondaryValue: Int? = nil
    ) {
        self.type = type
        self.value = value
        self.description = description
        self.secondaryValue = secondaryValue
    }

    // MARK: - Factory Methods

    /// Create attack intent
    public static func attack(damage: Int) -> EnemyIntent {
        EnemyIntent(
            type: .attack,
            value: damage,
            description: "Атака на \(damage)"
        )
    }

    /// Create ritual intent (shifts resonance toward Nav)
    public static func ritual(resonanceShift: Int) -> EnemyIntent {
        EnemyIntent(
            type: .ritual,
            value: resonanceShift,
            description: "Ритуал Нави",
            secondaryValue: resonanceShift
        )
    }

    /// Create block intent
    public static func block(reduction: Int) -> EnemyIntent {
        EnemyIntent(
            type: .block,
            value: reduction,
            description: "Защита +\(reduction)"
        )
    }

    /// Create buff intent
    public static func buff(amount: Int) -> EnemyIntent {
        EnemyIntent(
            type: .buff,
            value: amount,
            description: "Усиление +\(amount)"
        )
    }

    /// Create heal intent
    public static func heal(amount: Int) -> EnemyIntent {
        EnemyIntent(
            type: .heal,
            value: amount,
            description: "Лечение \(amount)"
        )
    }
}

// MARK: - Enemy AI Intent Generator

/// Generates enemy intents based on enemy definition and combat state
public struct EnemyIntentGenerator {

    /// Generate intent for an enemy based on their stats and current state
    /// - Parameters:
    ///   - enemyPower: Enemy's attack power
    ///   - enemyHealth: Enemy's current health
    ///   - enemyMaxHealth: Enemy's maximum health
    ///   - turnNumber: Current combat turn
    /// - Returns: The enemy's intent for this turn
    public static func generateIntent(
        enemyPower: Int,
        enemyHealth: Int,
        enemyMaxHealth: Int,
        turnNumber: Int
    ) -> EnemyIntent {
        // Simple AI logic:
        // - If health < 30% and turn > 2, consider healing or blocking
        // - Every 3rd turn, consider ritual
        // - Otherwise, attack

        let healthPercent = Double(enemyHealth) / Double(max(1, enemyMaxHealth))

        // Low health - defensive options
        if healthPercent < 0.3 && turnNumber > 2 {
            let roll = WorldRNG.shared.nextInt(in: 0...2)
            if roll == 0 {
                return .block(reduction: 3)
            } else if roll == 1 && enemyHealth < enemyMaxHealth {
                return .heal(amount: min(5, enemyMaxHealth - enemyHealth))
            }
        }

        // Ritual on turns 3, 6, 9, etc.
        if turnNumber > 0 && turnNumber % 3 == 0 {
            let roll = WorldRNG.shared.nextInt(in: 0...2)
            if roll == 0 {
                return .ritual(resonanceShift: -5)
            }
        }

        // Default: attack
        return .attack(damage: enemyPower)
    }
}
