import Foundation

/// Encounter Engine — processes encounters as pure input→output
/// Reference: ENCOUNTER_SYSTEM_DESIGN.md
///
/// All methods are stubs (fatalError) until implementation.
/// Tests are RED TDD — they compile but fail at runtime.
public final class EncounterEngine {

    // MARK: - State (read-only externally)

    public private(set) var currentPhase: EncounterPhase
    public private(set) var currentRound: Int
    public private(set) var heroHP: Int
    public private(set) var enemies: [EncounterEnemyState]
    public private(set) var currentIntent: EnemyIntent?
    public private(set) var isFinished: Bool
    public private(set) var mulliganDone: Bool
    public private(set) var lastAttackTrack: AttackTrack?

    private let context: EncounterContext
    private let rng: WorldRNG
    private var fateDeck: FateDeckManager
    private var accumulatedResonanceDelta: Float = 0

    // MARK: - Init

    public init(context: EncounterContext) {
        self.context = context
        self.currentPhase = .intent
        self.currentRound = 1
        self.heroHP = context.hero.hp
        self.enemies = context.enemies.map { EncounterEnemyState(from: $0) }
        self.isFinished = false
        self.mulliganDone = false
        self.rng = WorldRNG(seed: context.rngSeed)
        if let state = context.rngState {
            self.rng.restoreState(state)
        }
        self.fateDeck = FateDeckManager(cards: [], rng: rng)
        self.fateDeck.restoreState(context.fateDeckSnapshot)
    }

    // MARK: - Actions

    public func performAction(_ action: PlayerAction) -> EncounterActionResult {
        switch action {
        case .attack(let targetId):
            return performPhysicalAttack(targetId: targetId)
        case .spiritAttack(let targetId):
            return performSpiritAttack(targetId: targetId)
        case .wait:
            return .ok([])
        case .mulligan:
            if mulliganDone { return .fail(.mulliganAlreadyDone) }
            mulliganDone = true
            return .ok([])
        case .defend, .flee, .useCard:
            return .ok([])
        }
    }

    public func advancePhase() -> EncounterPhase {
        switch currentPhase {
        case .intent:
            currentPhase = .playerAction
        case .playerAction:
            currentPhase = .enemyResolution
        case .enemyResolution:
            currentPhase = .roundEnd
        case .roundEnd:
            currentPhase = .intent
            currentRound += 1
        }
        return currentPhase
    }

    public func generateIntent(for enemyId: String) -> EnemyIntent {
        guard let idx = findEnemyIndex(id: enemyId) else {
            return .attack(damage: 1)
        }
        let enemy = enemies[idx]

        // Try behavior-driven intent first
        let encounterEnemy = context.enemies.first(where: { $0.id == enemyId })
        if let behaviorId = encounterEnemy?.behaviorId,
           let behavior = context.behaviors[behaviorId] {
            let behaviorCtx = BehaviorContext(
                healthPercent: Double(enemy.hp) / Double(max(1, enemy.maxHp)),
                turn: currentRound,
                power: enemy.power,
                defense: enemy.defense,
                health: enemy.hp,
                maxHealth: enemy.maxHp
            )
            if let intent = BehaviorEvaluator.evaluate(behavior: behavior, context: behaviorCtx) {
                currentIntent = intent
                return intent
            }
        }

        // Fallback to hardcoded generator
        let intent = EnemyIntentGenerator.generateIntent(
            enemyPower: enemy.power,
            enemyHealth: enemy.hp,
            enemyMaxHealth: enemy.maxHp,
            turnNumber: currentRound
        )
        currentIntent = intent
        return intent
    }

    public func resolveEnemyAction(enemyId: String) -> EncounterActionResult {
        guard let intent = currentIntent else {
            return .fail(.actionNotAllowed)
        }
        var changes: [EncounterStateChange] = []

        switch intent.type {
        case .attack:
            let fateCard = fateDeck.draw()
            var damage: Int
            if let card = fateCard {
                changes.append(.fateDraw(cardId: card.id, value: card.baseValue))
                if card.isCritical {
                    damage = 0
                } else {
                    var defenseBonus = 0
                    if let keyword = card.keyword {
                        let effect = KeywordInterpreter.resolveWithAlignment(
                            keyword: keyword,
                            context: .defense,
                            baseValue: card.baseValue,
                            isMatch: isSuitMatch(card.suit, for: .defense),
                            isMismatch: isSuitMismatch(card.suit, for: .defense)
                        )
                        defenseBonus = effect.bonusValue
                    }
                    damage = max(0, intent.value - card.baseValue - context.hero.armor - defenseBonus)
                }
            } else {
                damage = max(0, intent.value - context.hero.armor)
            }
            heroHP -= damage
            changes.append(.playerHPChanged(delta: -damage, newValue: heroHP))

        case .ritual:
            let delta = Float(intent.value) // negative = toward Nav
            accumulatedResonanceDelta += delta
            changes.append(.resonanceShifted(delta: delta, newValue: context.worldResonance + accumulatedResonanceDelta))

        case .block:
            if let idx = enemies.firstIndex(where: { $0.isAlive }) {
                enemies[idx].defense += intent.value
            }

        case .buff:
            if let idx = enemies.firstIndex(where: { $0.isAlive }) {
                enemies[idx].power += intent.value
            }

        case .heal:
            if let idx = enemies.firstIndex(where: { $0.isAlive }) {
                let healed = min(intent.value, enemies[idx].maxHp - enemies[idx].hp)
                enemies[idx].hp += healed
                changes.append(.enemyHPChanged(enemyId: enemies[idx].id, delta: healed, newValue: enemies[idx].hp))
            }

        case .summon:
            break // not yet implemented
        }

        currentIntent = nil
        return .ok(changes)
    }

    public func finishEncounter() -> EncounterResult {
        isFinished = true

        var perEntity: [String: EntityOutcome] = [:]
        for enemy in enemies {
            perEntity[enemy.id] = enemy.outcome ?? .alive
        }

        let outcome: EncounterOutcome
        let allDead = enemies.allSatisfy { !$0.isAlive }
        let allPacified = enemies.allSatisfy { $0.isPacified }
        let anyKilled = enemies.contains { $0.outcome == .killed }

        if allPacified && !anyKilled {
            outcome = .victory(.pacified)
        } else if allDead || anyKilled {
            outcome = .victory(.killed)
        } else if heroHP <= 0 {
            outcome = .defeat
        } else {
            outcome = .escaped
        }

        var worldFlags: [String: Bool] = [:]
        if allPacified && !anyKilled {
            worldFlags["nonviolent"] = true
        }

        let transaction = EncounterTransaction(
            hpDelta: heroHP - context.hero.hp,
            resonanceDelta: accumulatedResonanceDelta,
            worldFlags: worldFlags
        )

        return EncounterResult(
            outcome: outcome,
            perEntityOutcomes: perEntity,
            transaction: transaction,
            updatedFateDeck: fateDeck.getState(),
            rngState: rng.currentState()
        )
    }

    // MARK: - Private

    private func findEnemyIndex(id: String) -> Int? {
        enemies.firstIndex(where: { $0.id == id })
    }

    /// Suit alignment: nav ↔ physical/defense, prav ↔ spiritual, yav ↔ neutral (matches all)
    private func isSuitMatch(_ suit: FateCardSuit?, for context: ActionContext) -> Bool {
        guard let suit = suit else { return false }
        switch (suit, context) {
        case (.yav, _): return true
        case (.nav, .combatPhysical), (.nav, .defense): return true
        case (.prav, .combatSpiritual), (.prav, .dialogue): return true
        default: return false
        }
    }

    private func isSuitMismatch(_ suit: FateCardSuit?, for context: ActionContext) -> Bool {
        guard let suit = suit else { return false }
        switch (suit, context) {
        case (.yav, _): return false
        case (.nav, .combatSpiritual), (.nav, .dialogue): return true
        case (.prav, .combatPhysical), (.prav, .defense): return true
        default: return false
        }
    }

    private func performPhysicalAttack(targetId: String) -> EncounterActionResult {
        guard let idx = findEnemyIndex(id: targetId) else {
            return .fail(.invalidTarget)
        }
        var changes: [EncounterStateChange] = []
        var surpriseBonus = 0

        if lastAttackTrack == .spiritual {
            surpriseBonus = context.balanceConfig?.escalationSurpriseBonus ?? 3
            let delta: Float = context.balanceConfig?.escalationResonanceShift ?? -5.0
            accumulatedResonanceDelta += delta
            changes.append(.resonanceShifted(delta: delta, newValue: context.worldResonance + accumulatedResonanceDelta))
        }

        var keywordBonus = 0
        let fateCard = fateDeck.draw()
        if let card = fateCard {
            changes.append(.fateDraw(cardId: card.id, value: card.baseValue))
            if let keyword = card.keyword {
                let effect = KeywordInterpreter.resolveWithAlignment(
                    keyword: keyword,
                    context: .combatPhysical,
                    baseValue: card.baseValue,
                    isMatch: isSuitMatch(card.suit, for: .combatPhysical),
                    isMismatch: isSuitMismatch(card.suit, for: .combatPhysical)
                )
                keywordBonus = effect.bonusDamage
            }
        }

        let damage = max(1, context.hero.strength - enemies[idx].defense + surpriseBonus + keywordBonus)
        enemies[idx].hp = max(0, enemies[idx].hp - damage)
        lastAttackTrack = .physical

        changes.append(.enemyHPChanged(enemyId: targetId, delta: -damage, newValue: enemies[idx].hp))

        if enemies[idx].hp == 0 {
            enemies[idx].outcome = .killed
            changes.append(.enemyKilled(enemyId: targetId))
        }

        return .ok(changes)
    }

    private func performSpiritAttack(targetId: String) -> EncounterActionResult {
        guard let idx = findEnemyIndex(id: targetId) else {
            return .fail(.invalidTarget)
        }
        guard enemies[idx].hasSpiritTrack else {
            return .fail(.actionNotAllowed)
        }
        var changes: [EncounterStateChange] = []

        if lastAttackTrack == .physical {
            let shieldValue = context.balanceConfig?.deEscalationRageShield ?? 3
            enemies[idx].rageShield = shieldValue
            changes.append(.rageShieldApplied(enemyId: targetId, value: shieldValue))
        }

        var keywordBonus = 0
        let fateCard = fateDeck.draw()
        if let card = fateCard {
            changes.append(.fateDraw(cardId: card.id, value: card.baseValue))
            if let keyword = card.keyword {
                let effect = KeywordInterpreter.resolveWithAlignment(
                    keyword: keyword,
                    context: .combatSpiritual,
                    baseValue: card.baseValue,
                    isMatch: isSuitMatch(card.suit, for: .combatSpiritual),
                    isMismatch: isSuitMismatch(card.suit, for: .combatSpiritual)
                )
                keywordBonus = effect.bonusDamage
            }
        }

        let damage = max(1, context.hero.wisdom + keywordBonus)
        let currentWP = enemies[idx].wp!
        enemies[idx].wp = max(0, currentWP - damage)
        lastAttackTrack = .spiritual

        changes.append(.enemyWPChanged(enemyId: targetId, delta: -damage, newValue: enemies[idx].wp!))

        if enemies[idx].wp! == 0 && enemies[idx].hp > 0 {
            enemies[idx].outcome = .pacified
            changes.append(.enemyPacified(enemyId: targetId))
        }

        return .ok(changes)
    }
}

/// Mutable enemy state within an encounter
public struct EncounterEnemyState: Equatable {
    public let id: String
    public let name: String
    public var hp: Int
    public let maxHp: Int
    public var wp: Int?
    public let maxWp: Int?
    public var power: Int
    public var defense: Int
    public var rageShield: Int
    public var outcome: EntityOutcome?

    public var hasSpiritTrack: Bool { wp != nil }
    public var isAlive: Bool { hp > 0 }
    public var isPacified: Bool { wp != nil && wp! <= 0 && hp > 0 }

    public init(from enemy: EncounterEnemy) {
        self.id = enemy.id
        self.name = enemy.name
        self.hp = enemy.hp
        self.maxHp = enemy.maxHp
        self.wp = enemy.wp
        self.maxWp = enemy.maxWp
        self.power = enemy.power
        self.defense = enemy.defense
        self.rageShield = 0
        self.outcome = nil
    }
}

/// Which track was last attacked (for escalation/de-escalation)
public enum AttackTrack: Equatable {
    case physical
    case spiritual
}
