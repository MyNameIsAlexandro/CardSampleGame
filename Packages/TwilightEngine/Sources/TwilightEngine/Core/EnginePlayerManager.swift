import Foundation
import Combine

/// Manages player stats, hero abilities, and curses.
/// Views access player state via `engine.player.X`.
public final class EnginePlayerManager: ObservableObject {

    // MARK: - Back-reference

    unowned let engine: TwilightGameEngine

    // MARK: - Published State

    @Published public internal(set) var health: Int = 10
    @Published public internal(set) var maxHealth: Int = 10
    @Published public internal(set) var faith: Int = 3
    @Published public internal(set) var maxFaith: Int = 10
    @Published public internal(set) var balance: Int = 50
    @Published public internal(set) var name: String = "Герой"
    @Published public internal(set) var heroId: String?

    /// Character stats
    @Published public internal(set) var strength: Int = 5
    @Published public internal(set) var dexterity: Int = 0
    @Published public internal(set) var constitution: Int = 0
    @Published public internal(set) var intelligence: Int = 0
    @Published public internal(set) var wisdom: Int = 0
    @Published public internal(set) var charisma: Int = 0

    /// Active curses
    @Published public internal(set) var activeCurses: [ActiveCurse] = []

    // MARK: - Init

    init(engine: TwilightGameEngine) {
        self.engine = engine
    }

    // MARK: - Hero Abilities

    /// Get hero definition from registry
    public var heroDefinition: HeroDefinition? {
        guard let heroId = heroId else { return nil }
        return HeroRegistry.shared.hero(id: heroId)
    }

    /// Get hero's special ability
    var heroAbility: HeroAbility? {
        return heroDefinition?.specialAbility
    }

    /// Check if player has a specific curse
    public func hasCurse(_ type: CurseType) -> Bool {
        return activeCurses.contains { $0.type == type }
    }

    /// Get damage modifier from curses (weakness: -1, shadowOfNav: +3)
    public func getCurseDamageDealtModifier() -> Int {
        var modifier = 0
        if hasCurse(.weakness) { modifier -= 1 }
        if hasCurse(.shadowOfNav) { modifier += 3 }
        return modifier
    }

    /// Get damage taken modifier from curses (fear: +1)
    public func getCurseDamageTakenModifier() -> Int {
        var modifier = 0
        if hasCurse(.fear) { modifier += 1 }
        return modifier
    }

    /// Get bonus dice from hero ability (e.g., Tracker on first attack)
    public func getHeroBonusDice(isFirstAttack: Bool) -> Int {
        guard let ability = heroAbility,
              ability.trigger == .onAttack else { return 0 }

        if let condition = ability.condition {
            switch condition.type {
            case .firstAttack:
                guard isFirstAttack else { return 0 }
            default:
                break
            }
        }

        return ability.effects.first { $0.type == .bonusDice }?.value ?? 0
    }

    /// Get bonus damage from hero ability (e.g., Berserker when HP < 50%)
    public func getHeroDamageBonus(targetFullHP: Bool = false) -> Int {
        guard let ability = heroAbility,
              ability.trigger == .onDamageDealt else { return 0 }

        if let condition = ability.condition {
            switch condition.type {
            case .hpBelowPercent:
                let threshold = condition.value ?? 50
                guard health < maxHealth * threshold / 100 else { return 0 }
            case .targetFullHP:
                guard targetFullHP else { return 0 }
            default:
                break
            }
        }

        return ability.effects.first { $0.type == .bonusDamage }?.value ?? 0
    }

    /// Get damage reduction from hero ability (e.g., Priest vs dark sources)
    public func getHeroDamageReduction(fromDarkSource: Bool = false) -> Int {
        guard let ability = heroAbility,
              ability.trigger == .onDamageReceived else { return 0 }

        if let condition = ability.condition {
            switch condition.type {
            case .damageSourceDark:
                guard fromDarkSource else { return 0 }
            default:
                break
            }
        }

        return ability.effects.first { $0.type == .damageReduction }?.value ?? 0
    }

    /// Check if hero gains faith at end of turn (e.g., Mage meditation)
    public var shouldGainFaithEndOfTurn: Bool {
        guard let ability = heroAbility,
              ability.trigger == .turnEnd else { return false }
        return ability.effects.contains { $0.type == .gainFaith }
    }

    // MARK: - Damage Calculation

    /// Calculate total damage dealt with curses and hero abilities
    public func calculateDamageDealt(_ baseDamage: Int, targetFullHP: Bool = false) -> Int {
        let curseModifier = getCurseDamageDealtModifier()
        let heroBonus = getHeroDamageBonus(targetFullHP: targetFullHP)
        return max(0, baseDamage + curseModifier + heroBonus)
    }

    /// Take damage with curse modifiers and hero abilities
    public func takeDamageWithModifiers(_ baseDamage: Int, fromDarkSource: Bool = false) {
        let curseModifier = getCurseDamageTakenModifier()
        let heroReduction = getHeroDamageReduction(fromDarkSource: fromDarkSource)
        let actualDamage = max(0, baseDamage + curseModifier - heroReduction)
        health = max(0, health - actualDamage)
    }

    // MARK: - Curse Management

    /// Apply curse to player
    public func applyCurse(type: CurseType, duration: Int, sourceCard: String? = nil) {
        let curse = ActiveCurse(type: type, duration: duration, sourceCard: sourceCard)
        activeCurses.append(curse)
    }

    /// Remove curse from player
    public func removeCurse(type: CurseType? = nil) {
        if let specificType = type {
            activeCurses.removeAll { $0.type == specificType }
        } else if !activeCurses.isEmpty {
            activeCurses.removeFirst()
        }
    }

    /// Tick curses at end of turn (reduce duration, remove expired)
    public func tickCurses() {
        for i in (0..<activeCurses.count).reversed() {
            activeCurses[i].duration -= 1
            if activeCurses[i].duration <= 0 {
                activeCurses.remove(at: i)
            }
        }
    }

    // MARK: - Setup

    /// Initialize player from hero definition or balance config defaults
    func initializeFromHero(_ heroId: String?, name playerName: String, balanceConfig: BalanceConfiguration) {
        self.name = playerName
        self.heroId = heroId

        if let heroId = heroId,
           let heroDef = HeroRegistry.shared.hero(id: heroId) {
            let stats = heroDef.baseStats
            health = stats.health
            maxHealth = stats.maxHealth
            faith = stats.faith
            maxFaith = stats.maxFaith
            balance = stats.startingBalance
            strength = stats.strength
            dexterity = stats.dexterity
            constitution = stats.constitution
            intelligence = stats.intelligence
            wisdom = stats.wisdom
            charisma = stats.charisma
        } else {
            health = balanceConfig.resources.startingHealth
            maxHealth = balanceConfig.resources.maxHealth
            faith = balanceConfig.resources.startingFaith
            maxFaith = balanceConfig.resources.maxFaith
            balance = 50
            strength = 5
            dexterity = 0
            constitution = 0
            intelligence = 0
            wisdom = 0
            charisma = 0
        }

        activeCurses = []
    }

    /// Restore hero stats from save
    func restoreFromSave(_ save: EngineSave) {
        name = save.playerName
        heroId = save.heroId
        health = save.playerHealth
        maxHealth = save.playerMaxHealth
        faith = save.playerFaith
        maxFaith = save.playerMaxFaith
        balance = save.playerBalance

        if let heroId = save.heroId,
           let heroDef = HeroRegistry.shared.hero(id: heroId) {
            let stats = heroDef.baseStats
            strength = stats.strength
            dexterity = stats.dexterity
            constitution = stats.constitution
            intelligence = stats.intelligence
            wisdom = stats.wisdom
            charisma = stats.charisma
        }
    }

    /// Reset state
    func resetState() {
        activeCurses = []
    }

    // MARK: - Setters (for engine/test access)

    public func setHealth(_ value: Int) { health = min(max(0, value), maxHealth) }
    public func setMaxHealth(_ value: Int) {
        maxHealth = max(1, value)
        health = min(health, maxHealth)
    }
    public func canAffordFaith(_ cost: Int) -> Bool { faith >= cost }
    public func setFaith(_ value: Int) { faith = min(maxFaith, max(0, value)) }
    public func applyFaithDelta(_ delta: Int) { faith = min(maxFaith, max(0, faith + delta)) }
    public func setBalance(_ value: Int) { balance = min(100, max(0, value)) }
    public func setName(_ value: String) { name = value }
    public func setHeroId(_ value: String) { heroId = value }
}
