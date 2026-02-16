/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/FateAttackResults.swift
/// Назначение: Содержит реализацию файла FateAttackResults.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Result of an attack resolved via Fate Deck (Unified Resolution System).
public struct FateAttackResult {
    public let baseStrength: Int
    public let cardPower: Int
    public let effortBonus: Int
    public let fateDrawResult: FateDrawResult?
    public let totalAttack: Int
    public let defenseValue: Int
    public let isHit: Bool
    public let damage: Int
    public let fateDrawEffects: [FateDrawEffect]
    public let specialEffects: [CombatEffect]

    public var logDescription: String {
        let fateValue = fateDrawResult?.effectiveValue ?? 0
        let cardName = fateDrawResult?.card.name ?? "?"
        let hitStr = isHit ? "HIT(\(damage) dmg)" : "MISS"
        return "Attack: \(baseStrength) + card(\(cardPower)) + effort(\(effortBonus)) + fate[\(cardName)](\(fateValue)) = \(totalAttack) vs \(defenseValue) → \(hitStr)"
    }
}

/// Result of a spirit/will attack (Pacify path).
public struct SpiritAttackResult {
    public let damage: Int
    public let baseStat: Int
    public let cardPower: Int
    public let fateModifier: Int
    public let newWill: Int
    public let isPacified: Bool
    public let fateDrawResult: FateDrawResult?
    public let fateDrawEffects: [FateDrawEffect]

    public init(damage: Int, baseStat: Int, cardPower: Int = 0, fateModifier: Int, newWill: Int, isPacified: Bool, fateDrawResult: FateDrawResult? = nil, fateDrawEffects: [FateDrawEffect] = []) {
        self.damage = damage
        self.baseStat = baseStat
        self.cardPower = cardPower
        self.fateModifier = fateModifier
        self.newWill = newWill
        self.isPacified = isPacified
        self.fateDrawResult = fateDrawResult
        self.fateDrawEffects = fateDrawEffects
    }

    public var logDescription: String {
        var lines: [String] = []
        lines.append("✨ Spirit Attack")
        lines.append("   Base: \(baseStat) + Card: \(cardPower) + Fate: \(fateModifier > 0 ? "+" : "")\(fateModifier) = \(damage) damage")
        if isPacified {
            lines.append("   🕊️ Enemy pacified!")
        }
        return lines.joined(separator: "\n")
    }
}
