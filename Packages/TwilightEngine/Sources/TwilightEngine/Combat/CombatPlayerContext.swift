/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatPlayerContext.swift
/// Назначение: Содержит реализацию файла CombatPlayerContext.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Context struct that replaces Player model for combat calculations.
/// Used by `CombatCalculator` and combat modules.
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

    /// Check if player has a specific curse.
    public func hasCurse(_ type: CurseType) -> Bool {
        activeCurses.contains(type)
    }

    /// Get bonus dice from hero ability.
    public func getHeroBonusDice(isFirstAttack: Bool) -> Int {
        heroBonusDice
    }

    /// Get bonus damage from hero ability.
    public func getHeroDamageBonus(targetFullHP: Bool) -> Int {
        heroDamageBonus
    }

    /// Get damage reduction from hero ability (e.g., Priest vs dark sources).
    public func getHeroDamageReduction(fromDarkSource: Bool) -> Int {
        0
    }

    /// Create from `TwilightGameEngine` state.
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
