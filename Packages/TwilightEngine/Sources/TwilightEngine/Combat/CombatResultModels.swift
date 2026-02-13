/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatResultModels.swift
/// Назначение: Содержит реализацию файла CombatResultModels.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Attack result with full breakdown.
public struct CombatResult {
    public let isHit: Bool
    public let attackRoll: AttackRoll
    public let defenseValue: Int
    public let damageCalculation: DamageCalculation?
    public let specialEffects: [CombatEffect]

    public init(
        isHit: Bool,
        attackRoll: AttackRoll,
        defenseValue: Int,
        damageCalculation: DamageCalculation?,
        specialEffects: [CombatEffect]
    ) {
        self.isHit = isHit
        self.attackRoll = attackRoll
        self.defenseValue = defenseValue
        self.damageCalculation = damageCalculation
        self.specialEffects = specialEffects
    }

    /// Text description for log.
    public var logDescription: String {
        var lines: [String] = []

        if isHit {
            lines.append(L10n.calcHit.localized)
        } else {
            lines.append(L10n.calcMiss.localized)
        }

        lines.append(L10n.calcAttackVsDefense.localized(with: attackRoll.total, defenseValue))

        var attackParts: [String] = []
        attackParts.append(L10n.calcStrength.localized(with: attackRoll.baseStrength))

        if attackRoll.diceRolls.count == 1 {
            attackParts.append("🎲\(attackRoll.diceRolls[0])")
        } else {
            let diceStr = attackRoll.diceRolls.map { "🎲\($0)" }.joined(separator: "+")
            attackParts.append("(\(diceStr)=\(attackRoll.diceTotal))")
        }

        if attackRoll.bonusDice > 0 {
            attackParts.append(L10n.calcBonusDice.localized(with: attackRoll.bonusDice))
        }
        if attackRoll.bonusDamage > 0 {
            attackParts.append(L10n.calcBonusDamage.localized(with: attackRoll.bonusDamage))
        }

        lines.append("   = \(attackParts.joined(separator: " + "))")

        for effect in attackRoll.modifiers {
            lines.append("   \(effect.icon) \(effect.description): \(effect.value > 0 ? "+" : "")\(effect.value)")
        }

        if isHit, let damage = damageCalculation {
            lines.append(L10n.calcDamage.localized(with: damage.total))
            lines.append(L10n.calcBaseDamage.localized(with: damage.base))

            for modifier in damage.modifiers {
                lines.append("   \(modifier.icon) \(modifier.description): \(modifier.value > 0 ? "+" : "")\(modifier.value)")
            }
        }

        for effect in specialEffects {
            lines.append("\(effect.icon) \(effect.description)")
        }

        return lines.joined(separator: "\n")
    }
}

/// Attack roll.
public struct AttackRoll {
    public let baseStrength: Int
    public let diceRolls: [Int]
    public let bonusDice: Int
    public let bonusDamage: Int
    public let modifiers: [CombatModifier]

    public init(baseStrength: Int, diceRolls: [Int], bonusDice: Int, bonusDamage: Int, modifiers: [CombatModifier]) {
        self.baseStrength = baseStrength
        self.diceRolls = diceRolls
        self.bonusDice = bonusDice
        self.bonusDamage = bonusDamage
        self.modifiers = modifiers
    }

    public var diceTotal: Int {
        diceRolls.reduce(0, +)
    }

    public var total: Int {
        baseStrength + diceTotal + bonusDamage + modifiers.reduce(0) { $0 + $1.value }
    }
}

/// Damage calculation.
public struct DamageCalculation {
    public let base: Int
    public let modifiers: [CombatModifier]

    public init(base: Int, modifiers: [CombatModifier]) {
        self.base = base
        self.modifiers = modifiers
    }

    public var total: Int {
        max(1, base + modifiers.reduce(0) { $0 + $1.value })
    }
}

/// Combat modifier.
public struct CombatModifier {
    public let source: ModifierSource
    public let value: Int
    public let description: String

    public init(source: ModifierSource, value: Int, description: String) {
        self.source = source
        self.value = value
        self.description = description
    }

    public var icon: String {
        switch source {
        case .heroAbility: return "⭐"
        case .curse: return "💀"
        case .card: return "🃏"
        case .equipment: return "🛡️"
        case .buff: return "✨"
        case .debuff: return "⚡"
        case .spirit: return "👻"
        case .environment: return "🌍"
        }
    }
}

/// Modifier source.
public enum ModifierSource {
    case heroAbility
    case curse
    case card
    case equipment
    case buff
    case debuff
    case spirit
    case environment
}
