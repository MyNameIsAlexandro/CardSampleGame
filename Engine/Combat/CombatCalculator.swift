import Foundation

/// Результат атаки с полной разбивкой факторов
struct CombatResult {
    let isHit: Bool
    let attackRoll: AttackRoll
    let defenseValue: Int
    let damageCalculation: DamageCalculation?
    let specialEffects: [CombatEffect]

    /// Текстовое описание для лога
    var logDescription: String {
        var lines: [String] = []

        // Заголовок результата
        if isHit {
            lines.append("✅ ПОПАДАНИЕ!")
        } else {
            lines.append("❌ ПРОМАХ!")
        }

        // Бросок атаки
        lines.append("📊 Атака: \(attackRoll.total) vs Защита: \(defenseValue)")

        // Разбивка атаки
        var attackParts: [String] = []
        attackParts.append("Сила \(attackRoll.baseStrength)")

        if attackRoll.diceRolls.count == 1 {
            attackParts.append("🎲\(attackRoll.diceRolls[0])")
        } else {
            let diceStr = attackRoll.diceRolls.map { "🎲\($0)" }.joined(separator: "+")
            attackParts.append("(\(diceStr)=\(attackRoll.diceTotal))")
        }

        if attackRoll.bonusDice > 0 {
            attackParts.append("+\(attackRoll.bonusDice) бонус кубиков")
        }
        if attackRoll.bonusDamage > 0 {
            attackParts.append("+\(attackRoll.bonusDamage) бонус урона")
        }

        lines.append("   = \(attackParts.joined(separator: " + "))")

        // Модификаторы
        for effect in attackRoll.modifiers {
            lines.append("   \(effect.icon) \(effect.description): \(effect.value > 0 ? "+" : "")\(effect.value)")
        }

        // Расчёт урона (если попадание)
        if isHit, let damage = damageCalculation {
            lines.append("💥 Урон: \(damage.total)")
            lines.append("   Базовый: \(damage.base) (атака - защита + 2)")

            for modifier in damage.modifiers {
                lines.append("   \(modifier.icon) \(modifier.description): \(modifier.value > 0 ? "+" : "")\(modifier.value)")
            }
        }

        // Спецэффекты
        for effect in specialEffects {
            lines.append("\(effect.icon) \(effect.description)")
        }

        return lines.joined(separator: "\n")
    }
}

/// Бросок атаки
struct AttackRoll {
    let baseStrength: Int
    let diceRolls: [Int]
    let bonusDice: Int
    let bonusDamage: Int
    let modifiers: [CombatModifier]

    var diceTotal: Int {
        diceRolls.reduce(0, +)
    }

    var total: Int {
        baseStrength + diceTotal + bonusDamage + modifiers.reduce(0) { $0 + $1.value }
    }
}

/// Расчёт урона
struct DamageCalculation {
    let base: Int
    let modifiers: [CombatModifier]

    var total: Int {
        max(1, base + modifiers.reduce(0) { $0 + $1.value })
    }
}

/// Модификатор боя
struct CombatModifier {
    let source: ModifierSource
    let value: Int
    let description: String

    var icon: String {
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

/// Источник модификатора
enum ModifierSource {
    case heroAbility
    case curse
    case card
    case equipment
    case buff
    case debuff
    case spirit
    case environment
}

/// Боевой эффект (события в бою)
struct CombatEffect {
    let icon: String
    let description: String
    let type: CombatEffectType
}

/// Тип боевого эффекта
enum CombatEffectType {
    case damage
    case heal
    case buff
    case debuff
    case summon
    case special
}

/// Калькулятор боя - вычисляет результат атаки с полной разбивкой
struct CombatCalculator {

    /// Рассчитать атаку игрока по монстру
    static func calculatePlayerAttack(
        player: Player,
        monsterDefense: Int,
        monsterCurrentHP: Int,
        monsterMaxHP: Int,
        bonusDice: Int,
        bonusDamage: Int,
        isFirstAttack: Bool
    ) -> CombatResult {

        var modifiers: [CombatModifier] = []
        var damageModifiers: [CombatModifier] = []
        let specialEffects: [CombatEffect] = []

        let isTargetFullHP = monsterCurrentHP == monsterMaxHP

        // Бросок кубиков
        var totalDice = 1 + bonusDice

        // Способность героя: бонус кубиков (например, Следопыт при первой атаке)
        let heroBonusDice = player.getHeroBonusDice(isFirstAttack: isFirstAttack)
        if heroBonusDice > 0 {
            totalDice += heroBonusDice
            modifiers.append(CombatModifier(
                source: .heroAbility,
                value: 0,  // Не добавляет к атаке напрямую, только кубик
                description: "Способность героя (+\(heroBonusDice) кубик)"
            ))
        }

        var diceRolls: [Int] = []
        for _ in 0..<totalDice {
            diceRolls.append(WorldRNG.shared.nextInt(in: 1...6))
        }

        // Создаём бросок атаки
        let attackRoll = AttackRoll(
            baseStrength: player.strength,
            diceRolls: diceRolls,
            bonusDice: bonusDice,
            bonusDamage: bonusDamage,
            modifiers: modifiers
        )

        let isHit = attackRoll.total >= monsterDefense

        var damageCalculation: DamageCalculation? = nil

        if isHit {
            let baseDamage = max(1, attackRoll.total - monsterDefense + 2)

            // Модификаторы урона от проклятий
            if player.hasCurse(.weakness) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: -1,
                    description: "Слабость"
                ))
            }

            if player.hasCurse(.shadowOfNav) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: +3,
                    description: "Тень Нави"
                ))
            }

            // Бонус урона от способности героя (учитывает условия типа HP < 50% или цель на полном HP)
            let heroDamageBonus = player.getHeroDamageBonus(targetFullHP: isTargetFullHP)
            if heroDamageBonus > 0 {
                damageModifiers.append(CombatModifier(
                    source: .heroAbility,
                    value: heroDamageBonus,
                    description: "Способность героя"
                ))
            }

            damageCalculation = DamageCalculation(
                base: baseDamage,
                modifiers: damageModifiers
            )
        }

        return CombatResult(
            isHit: isHit,
            attackRoll: attackRoll,
            defenseValue: monsterDefense,
            damageCalculation: damageCalculation,
            specialEffects: specialEffects
        )
    }
}
