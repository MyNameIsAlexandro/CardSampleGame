import Foundation

/// Attack result with full breakdown
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

    /// Text description for log
    public var logDescription: String {
        var lines: [String] = []

        // Заголовок результата
        if isHit {
            lines.append(L10n.calcHit.localized)
        } else {
            lines.append(L10n.calcMiss.localized)
        }

        // Бросок атаки
        lines.append(L10n.calcAttackVsDefense.localized(with: attackRoll.total, defenseValue))

        // Разбивка атаки
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

        // Модификаторы
        for effect in attackRoll.modifiers {
            lines.append("   \(effect.icon) \(effect.description): \(effect.value > 0 ? "+" : "")\(effect.value)")
        }

        // Расчёт урона (если попадание)
        if isHit, let damage = damageCalculation {
            lines.append(L10n.calcDamage.localized(with: damage.total))
            lines.append(L10n.calcBaseDamage.localized(with: damage.base))

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

/// Attack roll
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

/// Damage calculation
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

/// Combat modifier
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

/// Modifier source
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

/// Combat effect (events in combat)
public struct CombatEffect {
    public let icon: String
    public let description: String
    public let type: CombatEffectType

    public init(icon: String, description: String, type: CombatEffectType) {
        self.icon = icon
        self.description = description
        self.type = type
    }
}

/// Combat effect type
public enum CombatEffectType {
    case damage
    case heal
    case buff
    case debuff
    case summon
    case special
}

// MARK: - Fate Attack Result

/// Result of an attack resolved via Fate Deck (Unified Resolution System)
public struct FateAttackResult {
    public let baseStrength: Int
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
        return "Attack: \(baseStrength) + effort(\(effortBonus)) + fate[\(cardName)](\(fateValue)) = \(totalAttack) vs \(defenseValue) → \(hitStr)"
    }
}

/// Combat calculator - computes attack result with full breakdown
public struct CombatCalculator {

    // MARK: - Attack with Fate Deck (Unified Resolution)

    /// Calculate attack using Fate Deck instead of dice.
    /// Formula: totalAttack = baseStrength + effortBonus + fateEffectiveValue
    /// Hit if totalAttack >= monsterDefense
    /// Damage = max(1, totalAttack - monsterDefense + 2) + bonusDamage + modifiers
    public static func calculateAttackWithFate(
        context: CombatPlayerContext,
        fateDeck: FateDeckManager?,
        worldResonance: Float,
        effortCards: Int,
        monsterDefense: Int,
        bonusDamage: Int
    ) -> FateAttackResult {
        let baseStrength = context.strength
        let effortBonus = max(0, effortCards)

        // Draw fate card (replaces dice roll)
        let fateResult: FateDrawResult?
        let fateValue: Int
        if let deck = fateDeck, let result = deck.drawAndResolve(worldResonance: worldResonance) {
            fateResult = result
            fateValue = result.effectiveValue
        } else {
            fateResult = nil
            fateValue = WorldRNG.shared.nextInt(in: -1...2)  // fallback if no deck
        }

        let totalAttack = baseStrength + effortBonus + fateValue + bonusDamage
        let isHit = totalAttack >= monsterDefense

        // Damage calculation
        var damage = 0
        var specialEffects: [CombatEffect] = []

        if isHit {
            var baseDamage = max(1, totalAttack - monsterDefense + 2)

            // Apply curse modifiers
            if context.activeCurses.contains(.weakness) {
                baseDamage = max(1, baseDamage - 1)
                specialEffects.append(CombatEffect(
                    icon: "💀",
                    description: "Weakness: -1 damage",
                    type: .debuff
                ))
            }
            if context.activeCurses.contains(.shadowOfNav) {
                baseDamage += 3
                specialEffects.append(CombatEffect(
                    icon: "💀",
                    description: "Shadow of Nav: +3 damage",
                    type: .buff
                ))
            }

            // Hero damage bonus
            if context.heroDamageBonus > 0 {
                baseDamage += context.heroDamageBonus
                specialEffects.append(CombatEffect(
                    icon: "⭐",
                    description: "Hero ability: +\(context.heroDamageBonus) damage",
                    type: .buff
                ))
            }

            damage = max(1, baseDamage)
        }

        return FateAttackResult(
            baseStrength: baseStrength,
            effortBonus: effortBonus,
            fateDrawResult: fateResult,
            totalAttack: totalAttack,
            defenseValue: monsterDefense,
            isHit: isHit,
            damage: damage,
            fateDrawEffects: fateResult?.drawEffects ?? [],
            specialEffects: specialEffects
        )
    }

    // MARK: - Engine-First Attack Calculation

    /// Calculate player attack without requiring Player model (Engine-First Architecture)
    /// Uses engine stats directly for full independence from legacy Player
    @available(*, deprecated, message: "Use calculateAttackWithFate(context:...) instead")
    public static func calculateAttackEngineFirst(
        engine: TwilightGameEngine,
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

        // Roll dice
        var totalDice = 1 + bonusDice

        // Hero ability: bonus dice (e.g., Tracker on first attack)
        let heroBonusDice = engine.player.getHeroBonusDice(isFirstAttack: isFirstAttack)
        if heroBonusDice > 0 {
            totalDice += heroBonusDice
            modifiers.append(CombatModifier(
                source: .heroAbility,
                value: 0,
                description: L10n.calcHeroAbilityDice.localized(with: heroBonusDice)
            ))
        }

        var diceRolls: [Int] = []
        for _ in 0..<totalDice {
            diceRolls.append(WorldRNG.shared.nextInt(in: 1...6))
        }

        // Create attack roll
        let attackRoll = AttackRoll(
            baseStrength: engine.player.strength,
            diceRolls: diceRolls,
            bonusDice: bonusDice,
            bonusDamage: bonusDamage,
            modifiers: modifiers
        )

        let isHit = attackRoll.total >= monsterDefense

        var damageCalculation: DamageCalculation? = nil

        if isHit {
            let baseDamage = max(1, attackRoll.total - monsterDefense + 2)

            // Curse damage modifiers
            if engine.player.hasCurse(.weakness) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: -1,
                    description: L10n.calcCurseWeakness.localized
                ))
            }

            if engine.player.hasCurse(.shadowOfNav) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: +3,
                    description: L10n.calcCurseShadowOfNav.localized
                ))
            }

            // Hero ability damage bonus
            let heroDamageBonus = engine.player.getHeroDamageBonus(targetFullHP: isTargetFullHP)
            if heroDamageBonus > 0 {
                damageModifiers.append(CombatModifier(
                    source: .heroAbility,
                    value: heroDamageBonus,
                    description: L10n.calcHeroAbility.localized
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

    // MARK: - Attack Calculation with CombatPlayerContext

    /// Calculate player attack using CombatPlayerContext (Engine-First Architecture)
    /// Replaces legacy calculatePlayerAttack that used Player model
    public static func calculatePlayerAttack(
        context: CombatPlayerContext,
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

        // Roll dice
        var totalDice = 1 + bonusDice

        // Hero ability: bonus dice (e.g., Tracker on first attack)
        let heroBonusDice = context.getHeroBonusDice(isFirstAttack: isFirstAttack)
        if heroBonusDice > 0 {
            totalDice += heroBonusDice
            modifiers.append(CombatModifier(
                source: .heroAbility,
                value: 0,  // Doesn't add to attack directly, only the dice roll
                description: L10n.calcHeroAbilityDice.localized(with: heroBonusDice)
            ))
        }

        var diceRolls: [Int] = []
        for _ in 0..<totalDice {
            diceRolls.append(WorldRNG.shared.nextInt(in: 1...6))
        }

        // Create attack roll
        let attackRoll = AttackRoll(
            baseStrength: context.strength,
            diceRolls: diceRolls,
            bonusDice: bonusDice,
            bonusDamage: bonusDamage,
            modifiers: modifiers
        )

        let isHit = attackRoll.total >= monsterDefense

        var damageCalculation: DamageCalculation? = nil

        if isHit {
            let baseDamage = max(1, attackRoll.total - monsterDefense + 2)

            // Curse damage modifiers
            if context.hasCurse(.weakness) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: -1,
                    description: L10n.calcCurseWeakness.localized
                ))
            }

            if context.hasCurse(.shadowOfNav) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: +3,
                    description: L10n.calcCurseShadowOfNav.localized
                ))
            }

            // Hero ability damage bonus (checks conditions like HP < 50% or target at full HP)
            let heroDamageBonus = context.getHeroDamageBonus(targetFullHP: isTargetFullHP)
            if heroDamageBonus > 0 {
                damageModifiers.append(CombatModifier(
                    source: .heroAbility,
                    value: heroDamageBonus,
                    description: L10n.calcHeroAbility.localized
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

    // MARK: - Spirit Attack (Pacify Path)

    /// Calculate spirit/will damage for the Pacify path (decoupled from engine).
    /// Uses player wisdom or intelligence from CombatPlayerContext.
    public static func calculateSpiritAttack(
        context: CombatPlayerContext,
        enemyCurrentWill: Int,
        fateDeck: FateDeckManager?,
        worldResonance: Float = 0.0
    ) -> SpiritAttackResult {
        let baseStat = max(context.wisdom, context.intelligence, 1)

        // Draw fate card for modifier (resonance-aware)
        let fateModifier: Int
        var fateDrawEffects: [FateDrawEffect] = []
        if let deck = fateDeck, let result = deck.drawAndResolve(worldResonance: worldResonance) {
            fateModifier = result.effectiveValue
            fateDrawEffects = result.drawEffects
        } else {
            fateModifier = WorldRNG.shared.nextInt(in: -1...2)
        }

        let damage = max(1, baseStat + fateModifier)
        let newWill = max(0, enemyCurrentWill - damage)

        return SpiritAttackResult(
            damage: damage,
            baseStat: baseStat,
            fateModifier: fateModifier,
            newWill: newWill,
            isPacified: newWill <= 0,
            fateDrawEffects: fateDrawEffects
        )
    }

    /// Calculate spirit/will damage for the Pacify path (engine-coupled, deprecated).
    @available(*, deprecated, message: "Use calculateSpiritAttack(context:...) instead")
    public static func calculateSpiritAttack(
        engine: TwilightGameEngine,
        enemyCurrentWill: Int,
        fateDeck: FateDeckManager?,
        worldResonance: Float = 0.0
    ) -> SpiritAttackResult {
        let context = CombatPlayerContext.from(engine: engine)
        return calculateSpiritAttack(
            context: context,
            enemyCurrentWill: enemyCurrentWill,
            fateDeck: fateDeck,
            worldResonance: worldResonance
        )
    }

}

/// Result of a spirit/will attack (Pacify path)
public struct SpiritAttackResult {
    public let damage: Int
    public let baseStat: Int
    public let fateModifier: Int
    public let newWill: Int
    public let isPacified: Bool
    public let fateDrawEffects: [FateDrawEffect]

    public init(damage: Int, baseStat: Int, fateModifier: Int, newWill: Int, isPacified: Bool, fateDrawEffects: [FateDrawEffect] = []) {
        self.damage = damage
        self.baseStat = baseStat
        self.fateModifier = fateModifier
        self.newWill = newWill
        self.isPacified = isPacified
        self.fateDrawEffects = fateDrawEffects
    }

    public var logDescription: String {
        var lines: [String] = []
        lines.append("✨ Spirit Attack")
        lines.append("   Base: \(baseStat) + Fate: \(fateModifier > 0 ? "+" : "")\(fateModifier) = \(damage) damage")
        if isPacified {
            lines.append("   🕊️ Enemy pacified!")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Combat Player Context

/// Context struct that replaces Player model for combat calculations
/// Used by CombatCalculator and CombatModule (Engine-First Architecture)
public struct CombatPlayerContext {
    public let health: Int
    public let maxHealth: Int
    public let faith: Int
    public let balance: Int
    public let strength: Int
    public let wisdom: Int
    public let intelligence: Int
    public let activeCurses: [CurseType]
    public let heroBonusDice: Int
    public let heroDamageBonus: Int

    public init(
        health: Int,
        maxHealth: Int,
        faith: Int,
        balance: Int,
        strength: Int,
        wisdom: Int = 0,
        intelligence: Int = 0,
        activeCurses: [CurseType],
        heroBonusDice: Int,
        heroDamageBonus: Int
    ) {
        self.health = health
        self.maxHealth = maxHealth
        self.faith = faith
        self.balance = balance
        self.strength = strength
        self.wisdom = wisdom
        self.intelligence = intelligence
        self.activeCurses = activeCurses
        self.heroBonusDice = heroBonusDice
        self.heroDamageBonus = heroDamageBonus
    }

    /// Check if player has a specific curse
    public func hasCurse(_ type: CurseType) -> Bool {
        return activeCurses.contains(type)
    }

    /// Get bonus dice from hero ability
    public func getHeroBonusDice(isFirstAttack: Bool) -> Int {
        // Hero ability logic would check conditions here
        // For now, return the stored value
        return heroBonusDice
    }

    /// Get bonus damage from hero ability
    public func getHeroDamageBonus(targetFullHP: Bool) -> Int {
        // Hero ability logic would check conditions here
        // For now, return the stored value
        return heroDamageBonus
    }

    /// Get damage reduction from hero ability (e.g., Priest vs dark sources)
    public func getHeroDamageReduction(fromDarkSource: Bool) -> Int {
        // Hero ability logic would check conditions here
        return 0
    }

    /// Create from TwilightGameEngine (Engine-First)
    public static func from(engine: TwilightGameEngine) -> CombatPlayerContext {
        CombatPlayerContext(
            health: engine.player.health,
            maxHealth: engine.player.maxHealth,
            faith: engine.player.faith,
            balance: engine.player.balance,
            strength: engine.player.strength,
            wisdom: engine.player.wisdom,
            intelligence: engine.player.intelligence,
            activeCurses: engine.player.activeCurses.map { $0.type },
            heroBonusDice: engine.player.getHeroBonusDice(isFirstAttack: true),
            heroDamageBonus: engine.player.getHeroDamageBonus(targetFullHP: false)
        )
    }
}
