import Foundation

/// Encounter Engine — processes encounters as pure input→output
/// Reference: ENCOUNTER_SYSTEM_DESIGN.md
///
/// Phases: intent → playerAction → enemyResolution → roundEnd.
/// State is public private(set); mutations only through performAction().
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
    public private(set) var lastFateDrawResult: FateDrawResult?
    public var fateDeckDrawCount: Int { fateDeck.drawPile.count }
    public var fateDeckDiscardCount: Int { fateDeck.discardPile.count }

    // MARK: - Card Hand State

    public private(set) var hand: [Card] = []
    public private(set) var cardDiscardPile: [Card] = []
    public private(set) var turnAttackBonus: Int = 0
    public private(set) var turnDefenseBonus: Int = 0
    public private(set) var turnInfluenceBonus: Int = 0
    public private(set) var heroFaith: Int = 0
    public private(set) var pendingFateChoice: FateCard?
    public var heroCardPoolCount: Int { cardPool().count }
    public var heroCardsTotal: Int { context.heroCards.count }
    private var finishActionUsed: Bool = false

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
        self.hand = Array(context.heroCards.prefix(3))
        self.cardDiscardPile = []
        self.heroFaith = context.heroFaith
    }

    // MARK: - Actions

    public func performAction(_ action: PlayerAction) -> EncounterActionResult {
        // Mulligan is allowed before combat loop starts (any phase)
        if case .mulligan(let cardIds) = action {
            if mulliganDone { return .fail(.mulliganAlreadyDone) }
            mulliganDone = true
            var changes: [EncounterStateChange] = []
            let toDiscard = hand.filter { cardIds.contains($0.id) }
            hand.removeAll { cardIds.contains($0.id) }
            cardDiscardPile.append(contentsOf: toDiscard)
            let available = cardPool()
            for card in available.prefix(toDiscard.count) {
                hand.append(card)
                changes.append(.cardDrawn(cardId: card.id))
            }
            return .ok(changes)
        }

        guard currentPhase == .playerAction else {
            return .fail(.actionNotAllowed)
        }
        switch action {
        case .attack(let targetId):
            if finishActionUsed { return .fail(.actionNotAllowed) }
            let result = performPhysicalAttack(targetId: targetId)
            if result.success { finishActionUsed = true }
            return result
        case .spiritAttack(let targetId):
            if finishActionUsed { return .fail(.actionNotAllowed) }
            let result = performSpiritAttack(targetId: targetId)
            if result.success { finishActionUsed = true }
            return result
        case .wait:
            if finishActionUsed { return .fail(.actionNotAllowed) }
            finishActionUsed = true
            return .ok([])
        case .useCard(let cardId, _):
            return playCard(cardId: cardId) // card play is NOT a finish action
        case .defend:
            if finishActionUsed { return .fail(.actionNotAllowed) }
            finishActionUsed = true
            return .ok([])
        case .flee:
            if finishActionUsed { return .fail(.actionNotAllowed) }
            finishActionUsed = true
            return .ok([])
        case .mulligan:
            return .fail(.actionNotAllowed)
        case .resolveFateChoice(let optionIndex):
            return resolveFateChoice(optionIndex: optionIndex)
        }
    }

    public func advancePhase() -> EncounterPhase {
        switch currentPhase {
        case .intent:
            currentPhase = .playerAction
        case .playerAction:
            currentPhase = .enemyResolution
        case .enemyResolution:
            turnAttackBonus = 0
            turnDefenseBonus = 0
            turnInfluenceBonus = 0
            finishActionUsed = false
            currentPhase = .roundEnd
        case .roundEnd:
            // Draw card at end of round (up to maxHandSize)
            let maxHand = context.balanceConfig?.maxHandSize ?? 7
            if hand.count < maxHand {
                let available = cardPool()
                if let card = available.first {
                    hand.append(card)
                }
            }
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
                maxHealth: enemy.maxHp,
                worldResonance: effectiveResonance,
                lastPlayerAction: lastAttackTrack.map { $0 == .physical ? "physical" : "spiritual" }
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
            turnNumber: currentRound,
            rng: rng
        )
        currentIntent = intent
        return intent
    }

    public func resolveEnemyAction(enemyId: String) -> EncounterActionResult {
        guard currentPhase == .enemyResolution else {
            return .fail(.actionNotAllowed)
        }
        guard let intent = currentIntent else {
            return .fail(.actionNotAllowed)
        }
        var changes: [EncounterStateChange] = []

        switch intent.type {
        case .attack:
            let fateResult = drawFate()
            var damage: Int
            if let fateResult = fateResult {
                let card = fateResult.card
                changes.append(.fateDraw(cardId: card.id, value: fateResult.effectiveValue))
                if fateResult.isCritical {
                    damage = 0
                } else {
                    var defenseBonus = 0
                    if let keyword = card.keyword {
                        let effect = KeywordInterpreter.resolveWithAlignment(
                            keyword: keyword,
                            context: .defense,
                            baseValue: card.baseValue,
                            isMatch: isSuitMatch(card.suit, for: .defense),
                            isMismatch: isSuitMismatch(card.suit, for: .defense),
                            matchMultiplier: matchMultiplier
                        )
                        defenseBonus = effect.bonusValue
                    }
                    damage = max(0, intent.value - fateResult.effectiveValue - context.hero.armor - turnDefenseBonus - defenseBonus)
                }
            } else {
                damage = max(0, intent.value - context.hero.armor - turnDefenseBonus)
            }
            heroHP -= damage
            changes.append(.playerHPChanged(delta: -damage, newValue: heroHP))

        case .ritual:
            let delta = Float(intent.value) // negative = toward Nav
            accumulatedResonanceDelta += delta
            changes.append(.resonanceShifted(delta: delta, newValue: context.worldResonance + accumulatedResonanceDelta))

        case .block:
            if let idx = findEnemyIndex(id: enemyId) {
                enemies[idx].defense += intent.value
            }

        case .buff:
            if let idx = findEnemyIndex(id: enemyId) {
                enemies[idx].power += intent.value
            }

        case .heal:
            if let idx = findEnemyIndex(id: enemyId) {
                let healed = min(intent.value, enemies[idx].maxHp - enemies[idx].hp)
                enemies[idx].hp += healed
                changes.append(.enemyHPChanged(enemyId: enemyId, delta: healed, newValue: enemies[idx].hp))
            }

        case .summon:
            break // not yet implemented

        case .prepare:
            break // stance — no immediate effect

        case .restoreWP:
            if let idx = findEnemyIndex(id: enemyId), let currentWP = enemies[idx].wp {
                let maxWP = enemies[idx].maxWp ?? currentWP
                let restored = min(intent.value, maxWP - currentWP)
                enemies[idx].wp = currentWP + restored
                changes.append(.enemyWPChanged(enemyId: enemyId, delta: restored, newValue: currentWP + restored))
            }

        case .debuff:
            // Reduce hero effective strength this round via negative attack bonus
            turnAttackBonus -= intent.value

        case .defend:
            if let idx = findEnemyIndex(id: enemyId) {
                enemies[idx].defense += intent.value
            }
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

    // MARK: - Card Play

    private func playCard(cardId: String) -> EncounterActionResult {
        guard let cardIndex = hand.firstIndex(where: { $0.id == cardId }) else {
            return .fail(.invalidTarget)
        }
        let card = hand[cardIndex]

        // Faith cost with resonance modifier
        let baseCost = card.faithCost
        var adjustedCost = baseCost
        if baseCost > 0 {
            let zone = ResonanceEngine.zone(for: effectiveResonance)
            if let realm = card.realm {
                switch (realm, zone) {
                case (.nav, .prav), (.nav, .deepPrav): adjustedCost += 1
                case (.prav, .nav), (.prav, .deepNav): adjustedCost += 1
                case (.nav, .nav), (.nav, .deepNav): adjustedCost = max(0, adjustedCost - 1)
                case (.prav, .prav), (.prav, .deepPrav): adjustedCost = max(0, adjustedCost - 1)
                default: break
                }
            }
            if adjustedCost > heroFaith {
                return .fail(.insufficientFaith)
            }
            heroFaith -= adjustedCost
        }

        hand.remove(at: cardIndex)
        cardDiscardPile.append(card)

        var changes: [EncounterStateChange] = []
        if adjustedCost > 0 {
            changes.append(.faithChanged(delta: -adjustedCost, newValue: heroFaith))
        }
        changes.append(.cardPlayed(cardId: card.id, name: card.name))

        for ability in card.abilities {
            switch ability.effect {
            case .damage(let amount, _):
                turnAttackBonus += amount
            case .heal(let amount):
                let healed = min(amount, context.hero.maxHp - heroHP)
                heroHP += healed
                changes.append(.playerHPChanged(delta: healed, newValue: heroHP))
            case .temporaryStat(let stat, let amount, _):
                switch stat {
                case "attack", "strength": turnAttackBonus += amount
                case "defense", "armor": turnDefenseBonus += amount
                case "influence", "wisdom": turnInfluenceBonus += amount
                default: break
                }
            case .drawCards(let count):
                let remaining = context.heroCards.filter { c in
                    !hand.contains(where: { $0.id == c.id }) &&
                    !cardDiscardPile.contains(where: { $0.id == c.id })
                }
                for drawn in remaining.prefix(count) {
                    hand.append(drawn)
                    changes.append(.cardDrawn(cardId: drawn.id))
                }
            case .gainFaith(let amount):
                heroFaith += amount
                changes.append(.faithChanged(delta: amount, newValue: heroFaith))
            default:
                break
            }
        }

        // Apply base stats as bonuses (cards have dual combat/diplomacy values)
        if let power = card.power, power > 0 {
            turnAttackBonus += power
        }
        if let def = card.defense, def > 0 {
            turnDefenseBonus += def
        }
        if let wis = card.wisdom, wis > 0 {
            turnInfluenceBonus += wis
        }

        return .ok(changes)
    }

    // MARK: - Private

    private var effectiveResonance: Float {
        context.worldResonance + accumulatedResonanceDelta
    }

    private var matchMultiplier: Double {
        context.balanceConfig?.matchMultiplier ?? 1.5
    }

    private func drawFate() -> FateDrawResult? {
        let result = fateDeck.drawAndResolve(worldResonance: effectiveResonance)
        lastFateDrawResult = result
        if let result = result, result.card.cardType == .choice {
            pendingFateChoice = result.card
        }
        return result
    }

    private func cardPool() -> [Card] {
        context.heroCards.filter { c in
            !hand.contains(where: { $0.id == c.id }) &&
            !cardDiscardPile.contains(where: { $0.id == c.id })
        }
    }

    private func resolveFateChoice(optionIndex: Int) -> EncounterActionResult {
        guard let choice = pendingFateChoice else {
            return .fail(.actionNotAllowed)
        }
        guard let options = choice.choiceOptions, optionIndex < options.count else {
            return .fail(.invalidTarget)
        }
        pendingFateChoice = nil
        // Apply the chosen option's effect as a value modifier
        // Safe option (index 0) typically has lower/no bonus
        // Risk option (index 1) typically has higher bonus but possible penalty
        let bonusValue = optionIndex == 0 ? 0 : choice.baseValue
        return .ok([.fateDraw(cardId: choice.id, value: bonusValue)])
    }

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
        let fateResult = drawFate()
        if let fateResult = fateResult {
            changes.append(.fateDraw(cardId: fateResult.card.id, value: fateResult.effectiveValue))
            if let keyword = fateResult.card.keyword {
                let effect = KeywordInterpreter.resolveWithAlignment(
                    keyword: keyword,
                    context: .combatPhysical,
                    baseValue: fateResult.effectiveValue,
                    isMatch: isSuitMatch(fateResult.card.suit, for: .combatPhysical),
                    isMismatch: isSuitMismatch(fateResult.card.suit, for: .combatPhysical),
                    matchMultiplier: matchMultiplier
                )
                keywordBonus = effect.bonusDamage
            }
        }

        let damage = max(1, context.hero.strength + turnAttackBonus - enemies[idx].defense + surpriseBonus + keywordBonus)
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
        let fateResult = drawFate()
        if let fateResult = fateResult {
            changes.append(.fateDraw(cardId: fateResult.card.id, value: fateResult.effectiveValue))
            if let keyword = fateResult.card.keyword {
                let effect = KeywordInterpreter.resolveWithAlignment(
                    keyword: keyword,
                    context: .combatSpiritual,
                    baseValue: fateResult.effectiveValue,
                    isMatch: isSuitMatch(fateResult.card.suit, for: .combatSpiritual),
                    isMismatch: isSuitMismatch(fateResult.card.suit, for: .combatSpiritual),
                    matchMultiplier: matchMultiplier
                )
                keywordBonus = effect.bonusDamage
            }
        }

        let damage = max(1, context.hero.wisdom + turnInfluenceBonus + keywordBonus - enemies[idx].rageShield - enemies[idx].spiritDefense)
        let currentWP = enemies[idx].wp ?? 0
        let newWP = max(0, currentWP - damage)
        enemies[idx].wp = newWP
        enemies[idx].rageShield = 0
        lastAttackTrack = .spiritual

        changes.append(.enemyWPChanged(enemyId: targetId, delta: -damage, newValue: newWP))

        if newWP == 0 && enemies[idx].hp > 0 {
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
    public var spiritDefense: Int
    public var rageShield: Int
    public var outcome: EntityOutcome?

    public var hasSpiritTrack: Bool { wp != nil }
    public var isAlive: Bool { hp > 0 }
    public var isPacified: Bool { wp.map { $0 <= 0 } ?? false && hp > 0 }

    public init(from enemy: EncounterEnemy) {
        self.id = enemy.id
        self.name = enemy.name
        self.hp = enemy.hp
        self.maxHp = enemy.maxHp
        self.wp = enemy.wp
        self.maxWp = enemy.maxWp
        self.power = enemy.power
        self.defense = enemy.defense
        self.spiritDefense = enemy.spiritDefense
        self.rageShield = 0
        self.outcome = nil
    }
}

/// Which track was last attacked (for escalation/de-escalation)
public enum AttackTrack: Equatable {
    case physical
    case spiritual
}
