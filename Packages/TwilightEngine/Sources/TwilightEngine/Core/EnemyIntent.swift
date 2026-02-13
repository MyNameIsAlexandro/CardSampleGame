/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EnemyIntent.swift
/// Назначение: Содержит реализацию файла EnemyIntent.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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
    /// Preparation stance — no immediate effect
    case prepare
    /// Restores enemy willpower
    case restoreWP
    /// Weakens hero stats
    case debuff
    /// Defensive stance — reduces incoming damage
    case defend
}

/// Enemy's declared intention for the upcoming turn
/// Shown to player BEFORE they choose their action (Active Defense)
public struct EnemyIntent: Equatable, Codable {
    /// What type of action the enemy will perform
    public let type: IntentType

    /// Numeric value of the action (damage amount, heal amount, etc.)
    public let value: Int

    /// Localized description for UI display
    public let description: String

    /// Optional secondary value (e.g., resonance shift amount for rituals)
    public let secondaryValue: Int?

    /// Enemy ID to summon (only used with .summon type)
    public let summonEnemyId: String?

    public init(
        type: IntentType,
        value: Int,
        description: String,
        secondaryValue: Int? = nil,
        summonEnemyId: String? = nil
    ) {
        self.type = type
        self.value = value
        self.description = description
        self.secondaryValue = secondaryValue
        self.summonEnemyId = summonEnemyId
    }

    // MARK: - Factory Methods

    /// Create attack intent
    public static func attack(damage: Int) -> EnemyIntent {
        EnemyIntent(type: .attack, value: damage, description: "intent.attack.\(damage)")
    }

    /// Create ritual intent (shifts resonance toward Nav)
    public static func ritual(resonanceShift: Int) -> EnemyIntent {
        EnemyIntent(type: .ritual, value: resonanceShift, description: "intent.ritual", secondaryValue: resonanceShift)
    }

    /// Create block intent
    public static func block(reduction: Int) -> EnemyIntent {
        EnemyIntent(type: .block, value: reduction, description: "intent.block.\(reduction)")
    }

    /// Create buff intent
    public static func buff(amount: Int) -> EnemyIntent {
        EnemyIntent(type: .buff, value: amount, description: "intent.buff.\(amount)")
    }

    /// Create heal intent
    public static func heal(amount: Int) -> EnemyIntent {
        EnemyIntent(type: .heal, value: amount, description: "intent.heal.\(amount)")
    }

    /// Create prepare intent
    public static func prepare(value: Int = 0) -> EnemyIntent {
        EnemyIntent(type: .prepare, value: value, description: "intent.prepare")
    }

    /// Create restoreWP intent
    public static func restoreWP(amount: Int) -> EnemyIntent {
        EnemyIntent(type: .restoreWP, value: amount, description: "intent.restoreWP.\(amount)")
    }

    /// Create debuff intent
    public static func debuff(amount: Int) -> EnemyIntent {
        EnemyIntent(type: .debuff, value: amount, description: "intent.debuff.\(amount)")
    }

    /// Create defend intent
    public static func defend(reduction: Int) -> EnemyIntent {
        EnemyIntent(type: .defend, value: reduction, description: "intent.defend.\(reduction)")
    }

    /// Create summon intent
    public static func summon(enemyId: String) -> EnemyIntent {
        EnemyIntent(type: .summon, value: 0, description: "intent.summon", summonEnemyId: enemyId)
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
        turnNumber: Int,
        rng: WorldRNG
    ) -> EnemyIntent {
        let healthPercent = Double(enemyHealth) / Double(max(1, enemyMaxHealth))

        // Low health - defensive options
        if healthPercent < 0.3 && turnNumber > 2 {
            let roll = rng.nextInt(in: 0...2)
            if roll == 0 {
                return .block(reduction: 3)
            } else if roll == 1 && enemyHealth < enemyMaxHealth {
                return .heal(amount: min(5, enemyMaxHealth - enemyHealth))
            }
        }

        // Ritual on turns 3, 6, 9, etc.
        if turnNumber > 0 && turnNumber % 3 == 0 {
            let roll = rng.nextInt(in: 0...2)
            if roll == 0 {
                return .ritual(resonanceShift: -5)
            }
        }

        // Default: attack
        return .attack(damage: enemyPower)
    }

    /// Generate intent from a repeating pattern. Cycles through steps by round.
    public static func intentFromPattern(
        _ pattern: [EnemyPatternStep],
        round: Int,
        enemyPower: Int
    ) -> EnemyIntent {
        guard !pattern.isEmpty else { return .attack(damage: enemyPower) }
        let step = pattern[(round - 1) % pattern.count]
        switch step.type {
        case .attack:
            return .attack(damage: step.value > 0 ? step.value : enemyPower)
        case .heal:
            return .heal(amount: step.value > 0 ? step.value : 3)
        case .ritual:
            return .ritual(resonanceShift: step.value != 0 ? step.value : -5)
        case .block:
            return .block(reduction: step.value > 0 ? step.value : 3)
        case .buff:
            return .buff(amount: step.value > 0 ? step.value : 2)
        case .defend:
            return .defend(reduction: step.value > 0 ? step.value : 3)
        case .debuff:
            return .debuff(amount: step.value > 0 ? step.value : 2)
        case .prepare:
            return .prepare(value: step.value)
        case .summon:
            return .prepare(value: 0)
        case .restoreWP:
            return .restoreWP(amount: step.value > 0 ? step.value : 3)
        }
    }
}
