import Foundation

/// Manages all combat state and logic for the engine.
/// Views access combat state via `engine.combat.X`.
public final class EngineCombatManager {

    // MARK: - Back-reference

    unowned let engine: TwilightGameEngine

    // MARK: - Combat State

    /// Current enemy card in combat
    public private(set) var combatEnemy: Card?

    /// Enemy current health
    public private(set) var combatEnemyHealth: Int = 0

    /// Enemy current will/resolve (Spirit track, 0 if enemy has no will)
    public private(set) var combatEnemyWill: Int = 0

    /// Enemy maximum will/resolve for UI progress bars
    public private(set) var combatEnemyMaxWill: Int = 0

    /// Combat actions remaining this turn
    public private(set) var combatActionsRemaining: Int = 3

    /// Combat turn number
    public private(set) var combatTurnNumber: Int = 1

    /// Whether mulligan has been done this combat
    public private(set) var combatMulliganDone: Bool = false

    /// Whether player has attacked this turn
    public private(set) var combatPlayerAttackedThisTurn: Bool = false

    /// Last attack fate card result (player attacking enemy)
    public private(set) var lastAttackFateResult: FateDrawResult?

    /// Last defense fate card result (player defending from enemy)
    public private(set) var lastDefenseFateResult: FateDrawResult?

    /// Current enemy intent for this turn (shown before player acts)
    public private(set) var currentEnemyIntent: EnemyIntent?

    /// Last fate attack result for UI display
    public private(set) var lastFateAttackResult: FateAttackResult?

    // MARK: - Private Combat State

    /// Bonus dice for next attack (from cards)
    var combatBonusDice: Int = 0

    /// Bonus damage for next attack (from cards)
    var combatBonusDamage: Int = 0

    /// Is this the first attack in this combat (for abilities)
    var combatIsFirstAttack: Bool = true

    // MARK: - Init

    init(engine: TwilightGameEngine) {
        self.engine = engine
    }

    // MARK: - Combat Setup

    /// Setup enemy for combat
    public func setupCombatEnemy(_ enemy: Card) {
        combatEnemy = enemy
        combatEnemyHealth = enemy.health ?? 10
        combatEnemyWill = enemy.will ?? 0
        combatEnemyMaxWill = enemy.will ?? 0
        combatTurnNumber = 1
        combatActionsRemaining = 3
        combatBonusDice = 0
        combatBonusDamage = 0
        combatIsFirstAttack = true
        engine.isInCombat = true
    }

    /// End combat mode so a new battle can be started
    public func endCombat() {
        engine.isInCombat = false
        combatEnemy = nil
    }

    /// Reset combat state (called from engine.resetGameState)
    func resetState() {
        combatEnemy = nil
        combatEnemyHealth = 0
        combatEnemyWill = 0
        combatEnemyMaxWill = 0
        combatTurnNumber = 0
        combatActionsRemaining = 3
        combatMulliganDone = false
        combatPlayerAttackedThisTurn = false
        lastAttackFateResult = nil
        lastDefenseFateResult = nil
        currentEnemyIntent = nil
        lastFateAttackResult = nil
        combatBonusDice = 0
        combatBonusDamage = 0
        combatIsFirstAttack = true
    }

    /// Get current combat state for UI
    public var combatState: CombatState? {
        guard engine.isInCombat, let enemy = combatEnemy else { return nil }
        return CombatState(
            enemy: enemy,
            enemyHealth: combatEnemyHealth,
            enemyWill: combatEnemyWill,
            enemyMaxWill: combatEnemyMaxWill,
            turnNumber: combatTurnNumber,
            actionsRemaining: combatActionsRemaining,
            bonusDice: combatBonusDice,
            bonusDamage: combatBonusDamage,
            isFirstAttack: combatIsFirstAttack,
            playerHand: engine.deck.playerHand
        )
    }

    // MARK: - Combat Action Handler

    /// Handle all combat-related actions
    func handleCombatAction(_ action: TwilightGameAction) -> (changes: [StateChange], combatStarted: Bool) {
        var stateChanges: [StateChange] = []
        var didStartCombat = false

        switch action {
        case .startCombat:
            didStartCombat = true
            engine.isInCombat = true
            combatTurnNumber = 1
            combatActionsRemaining = 3
            combatBonusDice = 0
            combatBonusDamage = 0
            combatIsFirstAttack = true
            combatMulliganDone = false
            combatPlayerAttackedThisTurn = false
            currentEnemyIntent = nil
            lastAttackFateResult = nil
            lastDefenseFateResult = nil

        case .combatMulligan(let cardIds):
            guard !combatMulliganDone else { break }
            engine.performCombatMulligan(cardIds: cardIds)
            combatMulliganDone = true

        case .combatGenerateIntent:
            guard let enemy = combatEnemy else { break }
            let enemyPower = enemy.power ?? 3
            currentEnemyIntent = EnemyIntentGenerator.generateIntent(
                enemyPower: enemyPower,
                enemyHealth: combatEnemyHealth,
                enemyMaxHealth: enemy.health ?? 10,
                turnNumber: combatTurnNumber
            )

        case .combatPlayerAttackWithFate(let bonusDamage):
            guard let enemy = combatEnemy else { break }
            combatPlayerAttackedThisTurn = true

            if let fateResult = engine.fateDeck?.drawAndResolve(worldResonance: engine.resonanceValue) {
                lastAttackFateResult = fateResult

                let baseDamage = engine.player.strength + combatBonusDamage + bonusDamage
                let fateBonus = fateResult.effectiveValue
                let totalAttack = baseDamage + fateBonus

                let enemyDefense = enemy.defense ?? 10
                if totalAttack >= enemyDefense {
                    let damage = max(1, totalAttack - enemyDefense + 1)
                    combatEnemyHealth = max(0, combatEnemyHealth - damage)
                    stateChanges.append(.enemyDamaged(
                        enemyId: enemy.id,
                        damage: damage,
                        newHealth: combatEnemyHealth
                    ))

                    if combatEnemyHealth <= 0 {
                        stateChanges.append(.enemyDefeated(enemyId: enemy.id))
                    }
                }

                let fateChanges = applyFateDrawEffects(fateResult.drawEffects)
                stateChanges.append(contentsOf: fateChanges)
            }

            combatBonusDice = 0
            combatBonusDamage = 0

        case .combatSkipAttack:
            combatPlayerAttackedThisTurn = false
            lastAttackFateResult = nil

        case .combatEnemyResolveWithFate:
            guard let intent = currentEnemyIntent else { break }

            switch intent.type {
            case .attack:
                if let fateResult = engine.fateDeck?.drawAndResolve(worldResonance: engine.resonanceValue) {
                    lastDefenseFateResult = fateResult

                    let fateBonus = fateResult.effectiveValue
                    let playerArmor = 0
                    let damageReduction = playerArmor + fateBonus
                    let actualDamage = max(0, intent.value - damageReduction)

                    if actualDamage > 0 {
                        engine.player.health = max(0, engine.player.health - actualDamage)
                        stateChanges.append(.healthChanged(
                            delta: -actualDamage,
                            newValue: engine.player.health
                        ))
                    }

                    let fateChanges = applyFateDrawEffects(fateResult.drawEffects)
                    stateChanges.append(contentsOf: fateChanges)
                } else {
                    engine.player.health = max(0, engine.player.health - intent.value)
                    stateChanges.append(.healthChanged(
                        delta: -intent.value,
                        newValue: engine.player.health
                    ))
                }

            case .ritual:
                let shift = Float(intent.secondaryValue ?? -5)
                engine.resonanceValue = max(-100, min(100, engine.resonanceValue + shift))
                stateChanges.append(.resonanceChanged(delta: shift, newValue: engine.resonanceValue))

            case .block, .buff:
                break

            case .heal:
                if let enemy = combatEnemy {
                    let maxHealth = enemy.health ?? 10
                    combatEnemyHealth = min(maxHealth, combatEnemyHealth + intent.value)
                }

            case .summon:
                break

            case .prepare, .restoreWP, .debuff, .defend:
                break
            }

            combatPlayerAttackedThisTurn = false
            currentEnemyIntent = nil

        case .combatInitialize:
            engine.performCombatInitialize()
            combatActionsRemaining = 3

        default:
            break
        }

        return (stateChanges, didStartCombat)
    }

    // MARK: - Fate Draw Effects

    /// Apply side effects from a fate card draw (resonance shift, tension shift)
    func applyFateDrawEffects(_ effects: [FateDrawEffect]) -> [StateChange] {
        var changes: [StateChange] = []
        for effect in effects {
            switch effect.type {
            case .shiftResonance:
                let delta = Float(effect.value)
                engine.resonanceValue = max(-100, min(100, engine.resonanceValue + delta))
                changes.append(.resonanceChanged(delta: delta, newValue: engine.resonanceValue))
            case .shiftTension:
                let oldTension = engine.worldTension
                engine.worldTension = max(0, min(100, engine.worldTension + effect.value))
                let actualDelta = engine.worldTension - oldTension
                if actualDelta != 0 {
                    changes.append(.tensionChanged(delta: actualDelta, newValue: engine.worldTension))
                }
            }
        }
        return changes
    }
}
