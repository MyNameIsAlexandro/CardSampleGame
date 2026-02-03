import FirebladeECS
import TwilightEngine

/// Result of a completed combat encounter, containing all deltas to apply back to the game.
public struct EchoCombatResult: Sendable {
    public let outcome: CombatOutcome
    /// Resonance shift: negative for kill (Nav), positive for pacify (Prav)
    public let resonanceDelta: Int
    public let faithDelta: Int
    public let lootCardIds: [String]
    public let updatedFateDeckState: FateDeckState?
    /// Net HP change for the player (negative = damage taken)
    public let hpDelta: Int
    // Combat stats
    public let turnsPlayed: Int
    public let totalDamageDealt: Int
    public let totalDamageTaken: Int
    public let cardsPlayed: Int

    public init(
        outcome: CombatOutcome,
        resonanceDelta: Int = 0,
        faithDelta: Int = 0,
        lootCardIds: [String] = [],
        updatedFateDeckState: FateDeckState? = nil,
        hpDelta: Int = 0,
        turnsPlayed: Int = 0,
        totalDamageDealt: Int = 0,
        totalDamageTaken: Int = 0,
        cardsPlayed: Int = 0
    ) {
        self.outcome = outcome
        self.resonanceDelta = resonanceDelta
        self.faithDelta = faithDelta
        self.lootCardIds = lootCardIds
        self.updatedFateDeckState = updatedFateDeckState
        self.hpDelta = hpDelta
        self.turnsPlayed = turnsPlayed
        self.totalDamageDealt = totalDamageDealt
        self.totalDamageTaken = totalDamageTaken
        self.cardsPlayed = cardsPlayed
    }
}

/// High-level orchestrator for a complete combat encounter.
/// Owns the Nexus and all systems. Provides a simple API for tests and future UI.
public final class CombatSimulation {
    public let nexus: Nexus
    public let combatSystem: CombatSystem
    public let aiSystem: AISystem
    public let deckSystem: DeckSystem

    // Combat stats tracking
    public private(set) var statDamageDealt: Int = 0
    public private(set) var statDamageTaken: Int = 0
    public private(set) var statCardsPlayed: Int = 0

    // Card selection state (select-then-commit model)
    public private(set) var selectedCardIds: [String] = []
    public private(set) var reservedEnergy: Int = 0

    public init(nexus: Nexus, rng: WorldRNG) {
        self.nexus = nexus
        self.combatSystem = CombatSystem()
        self.aiSystem = AISystem(rng: rng)
        self.deckSystem = DeckSystem(rng: rng)
    }

    // MARK: - Convenience Builders

    /// Create a CombatSimulation from an enemy definition and player stats.
    public static func create(
        enemyDefinition: EnemyDefinition,
        playerName: String = "Hero",
        playerHealth: Int = 10,
        playerMaxHealth: Int = 10,
        playerStrength: Int = 5,
        playerDeck: [Card] = [],
        playerEnergy: Int = 3,
        fateCards: [FateCard] = [],
        resonance: Float = 0,
        seed: UInt64 = 42
    ) -> CombatSimulation {
        let rng = WorldRNG(seed: seed)
        let fateDeck = FateDeckManager(cards: fateCards, rng: rng)
        let nexus = CombatNexusBuilder.build(
            enemyDefinition: enemyDefinition,
            playerName: playerName,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth,
            playerStrength: playerStrength,
            playerDeck: playerDeck,
            playerEnergy: playerEnergy,
            fateDeck: fateDeck,
            resonance: resonance,
            rng: rng
        )
        return CombatSimulation(nexus: nexus, rng: rng)
    }

    // MARK: - Entity Access

    public var playerEntity: Entity? {
        nexus.family(requires: PlayerTagComponent.self).firstEntity
    }

    public var enemyEntity: Entity? {
        nexus.family(requires: EnemyTagComponent.self).firstEntity
    }

    // MARK: - State Queries

    public var phase: EchoCombatPhase {
        let family = nexus.family(requires: CombatStateComponent.self)
        return family.firstElement()?.phase ?? .setup
    }

    public var isOver: Bool {
        let family = nexus.family(requires: CombatStateComponent.self)
        guard let state = family.firstElement() else { return true }
        return !state.isActive
    }

    public var outcome: CombatOutcome? {
        switch phase {
        case .victory:
            // Determine victory type from enemy state
            if let enemy = enemyEntity {
                let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
                if !health.isAlive { return .victory(.killed) }
                if health.willDepleted { return .victory(.pacified) }
            }
            return .victory(.killed)
        case .defeat: return .defeat
        default: return nil
        }
    }

    public var playerHealth: Int {
        guard let player = playerEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: player.identifier)
        return health.current
    }

    public var playerMaxHealth: Int {
        guard let player = playerEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: player.identifier)
        return health.max
    }

    public var enemyHealth: Int {
        guard let enemy = enemyEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
        return health.current
    }

    public var enemyMaxHealth: Int {
        guard let enemy = enemyEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
        return health.max
    }

    public var enemyWill: Int {
        guard let enemy = enemyEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
        return health.will
    }

    public var enemyMaxWill: Int {
        guard let enemy = enemyEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
        return health.maxWill
    }

    public var hand: [Card] {
        guard let player = playerEntity else { return [] }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        return deck.hand
    }

    public var drawPileCount: Int {
        guard let player = playerEntity else { return 0 }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        return deck.drawPile.count
    }

    /// Draw one card from the draw pile into the hand. Returns the drawn card, or nil if empty.
    public func drawOneCard() -> Card? {
        guard let player = playerEntity else { return nil }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        let before = deck.hand.count
        deckSystem.drawCards(count: 1, for: player, nexus: nexus)
        guard deck.hand.count > before else { return nil }
        return deck.hand.last
    }

    public var discardPile: [Card] {
        guard let player = playerEntity else { return [] }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        return deck.discardPile
    }

    public var discardPileCount: Int {
        discardPile.count
    }

    public var exhaustPile: [Card] {
        guard let player = playerEntity else { return [] }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        return deck.exhaustPile
    }

    public var exhaustPileCount: Int {
        exhaustPile.count
    }

    public var energy: Int {
        guard let player = playerEntity else { return 0 }
        let e: EnergyComponent = nexus.get(unsafe: player.identifier)
        return e.current
    }

    public var maxEnergy: Int {
        guard let player = playerEntity else { return 0 }
        let e: EnergyComponent = nexus.get(unsafe: player.identifier)
        return e.max
    }

    public var fateDeckCount: Int {
        let family = nexus.family(requires: FateDeckComponent.self)
        for entity in family.entities {
            let comp: FateDeckComponent = nexus.get(unsafe: entity.identifier)
            return comp.fateDeck.drawPile.count
        }
        return 0
    }

    public var round: Int {
        let family = nexus.family(requires: CombatStateComponent.self)
        return family.firstElement()?.round ?? 1
    }

    public var resonance: Float {
        let family = nexus.family(requires: CombatStateComponent.self)
        for entity in family.entities {
            if entity.has(ResonanceComponent.self) {
                let res: ResonanceComponent = nexus.get(unsafe: entity.identifier)
                return res.value
            }
        }
        return 0
    }

    public func playerStatus(for stat: String) -> Int {
        guard let player = playerEntity else { return 0 }
        let s: StatusEffectComponent = nexus.get(unsafe: player.identifier)
        return s.total(for: stat)
    }

    public func enemyStatus(for stat: String) -> Int {
        guard let enemy = enemyEntity else { return 0 }
        let s: StatusEffectComponent = nexus.get(unsafe: enemy.identifier)
        return s.total(for: stat)
    }

    public var enemyIntent: EnemyIntent? {
        guard let enemy = enemyEntity else { return nil }
        let intent: IntentComponent = nexus.get(unsafe: enemy.identifier)
        return intent.intent
    }

    /// Build a EchoCombatResult from the current combat state. Call after combat ends.
    public var combatResult: EchoCombatResult? {
        guard let outcome = outcome else { return nil }
        guard let enemy = enemyEntity else { return nil }
        let enemyTag: EnemyTagComponent = nexus.get(unsafe: enemy.identifier)

        let resonanceDelta: Int
        let faithDelta: Int
        switch outcome {
        case .victory(.killed):
            resonanceDelta = -5  // Nav shift
            faithDelta = enemyTag.faithReward
        case .victory(.pacified):
            resonanceDelta = 5   // Prav shift
            faithDelta = enemyTag.faithReward
        case .defeat:
            resonanceDelta = 0
            faithDelta = 0
        }

        // Get fate deck state
        var fateDeckState: FateDeckState?
        let combatFamily = nexus.family(requires: CombatStateComponent.self)
        for combatEntity in combatFamily.entities {
            if combatEntity.has(FateDeckComponent.self) {
                let fateDeckComp: FateDeckComponent = nexus.get(unsafe: combatEntity.identifier)
                fateDeckState = fateDeckComp.fateDeck.getState()
                break
            }
        }

        return EchoCombatResult(
            outcome: outcome,
            resonanceDelta: resonanceDelta,
            faithDelta: faithDelta,
            lootCardIds: enemyTag.lootCardIds,
            updatedFateDeckState: fateDeckState,
            hpDelta: playerHealth - playerMaxHealth,
            turnsPlayed: round,
            totalDamageDealt: statDamageDealt,
            totalDamageTaken: statDamageTaken,
            cardsPlayed: statCardsPlayed
        )
    }

    // MARK: - Card Selection (Select-Then-Commit)

    /// Select a card from hand for the next commit action. Returns false if card can't be selected.
    public func selectCard(cardId: String) -> Bool {
        guard let player = playerEntity else { return false }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        guard let card = deck.hand.first(where: { $0.id == cardId }) else { return false }
        guard !selectedCardIds.contains(cardId) else { return false }

        let cost = card.cost ?? 1
        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        guard cost <= (energy.current - reservedEnergy) else { return false }

        selectedCardIds.append(cardId)
        reservedEnergy += cost
        return true
    }

    /// Deselect a previously selected card, refunding its energy reservation.
    public func deselectCard(cardId: String) {
        guard let idx = selectedCardIds.firstIndex(of: cardId) else { return }
        guard let player = playerEntity else { return }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        if let card = deck.hand.first(where: { $0.id == cardId }) {
            reservedEnergy -= (card.cost ?? 1)
        }
        selectedCardIds.remove(at: idx)
    }

    /// Deselect all cards and reset reserved energy.
    public func deselectAllCards() {
        selectedCardIds.removeAll()
        reservedEnergy = 0
    }

    /// Available energy after reservations.
    public var availableEnergy: Int {
        guard let player = playerEntity else { return 0 }
        let e: EnergyComponent = nexus.get(unsafe: player.identifier)
        return e.current - reservedEnergy
    }

    /// Commit selected cards + attack. Returns all combat events.
    /// Cards' damage abilities accumulate as bonusDamage; heal/draw/status apply immediately.
    /// One Fate draw for the whole action.
    @discardableResult
    public func commitAttack() -> [CombatEvent] {
        guard let player = playerEntity, let enemy = enemyEntity else { return [] }

        var events: [CombatEvent] = []

        // Resolve selected card effects, accumulate bonus damage
        let bonusDamage = resolveSelectedCardEffects(player: player, enemy: enemy, events: &events)

        // Spend reserved energy
        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        energy.current -= reservedEnergy

        // Perform attack with accumulated bonus
        let attackEvent = combatSystem.playerAttack(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        events.append(attackEvent)
        if case .playerAttacked(let dmg, _, _, _) = attackEvent { statDamageDealt += dmg }

        // Discard/exhaust selected cards
        discardSelectedCards(player: player)

        // Clear selection
        let cardCount = selectedCardIds.count
        selectedCardIds.removeAll()
        reservedEnergy = 0
        statCardsPlayed += cardCount

        // Transition to enemy phase
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)

        return events
    }

    /// Commit selected cards + influence. Same pattern as commitAttack but for spiritual track.
    @discardableResult
    public func commitInfluence() -> [CombatEvent] {
        guard let player = playerEntity, let enemy = enemyEntity else { return [] }

        var events: [CombatEvent] = []
        let bonusDamage = resolveSelectedCardEffects(player: player, enemy: enemy, events: &events)

        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        energy.current -= reservedEnergy

        let influenceEvent = combatSystem.playerInfluence(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        events.append(influenceEvent)

        discardSelectedCards(player: player)

        let cardCount = selectedCardIds.count
        selectedCardIds.removeAll()
        reservedEnergy = 0
        statCardsPlayed += cardCount

        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)

        return events
    }

    /// Resolve all selected card abilities. Damage is accumulated and returned as bonusDamage.
    /// Non-damage effects (heal, draw, status) apply immediately.
    private func resolveSelectedCardEffects(player: Entity, enemy: Entity, events: inout [CombatEvent]) -> Int {
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        let playerHealth: HealthComponent = nexus.get(unsafe: player.identifier)
        let enemyHealth: HealthComponent = nexus.get(unsafe: enemy.identifier)
        let playerStatus: StatusEffectComponent = nexus.get(unsafe: player.identifier)
        let enemyStatus: StatusEffectComponent = nexus.get(unsafe: enemy.identifier)

        var bonusDamage = 0

        for cardId in selectedCardIds {
            guard let card = deck.hand.first(where: { $0.id == cardId }) else { continue }

            var cardDamage = 0
            var cardHeal = 0
            var cardDrawn = 0
            var statusApplied: String? = nil

            if card.abilities.isEmpty {
                cardDamage += max(0, card.power ?? 0)
            }

            for ability in card.abilities {
                switch ability.effect {
                case .damage(let amount, _):
                    cardDamage += max(0, amount)

                case .heal(let amount):
                    let heal = min(amount, playerHealth.max - playerHealth.current)
                    playerHealth.current += heal
                    cardHeal += heal

                case .drawCards(let count):
                    let beforeCount = deck.hand.count
                    deckSystem.drawCards(count: count, for: player, nexus: nexus)
                    cardDrawn += deck.hand.count - beforeCount

                case .temporaryStat(let stat, let amount, let duration):
                    if stat == "poison" {
                        enemyStatus.apply(stat: stat, amount: amount, duration: duration)
                    } else {
                        playerStatus.apply(stat: stat, amount: amount, duration: duration)
                    }
                    statusApplied = stat

                case .gainFaith(let amount):
                    let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
                    energy.current = min(energy.max, energy.current + amount)
                    statusApplied = "energy"

                case .shiftBalance(let towards, let amount):
                    let combatFamily = nexus.family(requires: CombatStateComponent.self)
                    for combatEntity in combatFamily.entities {
                        if combatEntity.has(ResonanceComponent.self) {
                            let res: ResonanceComponent = nexus.get(unsafe: combatEntity.identifier)
                            let delta: Float
                            switch towards {
                            case .light: delta = Float(amount)
                            case .dark: delta = Float(-amount)
                            case .neutral: delta = res.value > 0 ? Float(-amount) : Float(amount)
                            }
                            res.value = max(-100, min(100, res.value + delta))
                            break
                        }
                    }
                    statusApplied = "resonance"

                case .applyCurse(let curseType, let duration):
                    enemyStatus.apply(stat: curseType.rawValue, amount: 1, duration: duration)
                    statusApplied = curseType.rawValue

                case .permanentStat(let stat, let amount):
                    if stat == "poison" {
                        enemyStatus.apply(stat: stat, amount: amount, duration: 99)
                    } else {
                        playerStatus.apply(stat: stat, amount: amount, duration: 99)
                    }
                    statusApplied = stat

                default:
                    break
                }
            }

            bonusDamage += cardDamage
            events.append(.cardPlayed(cardId: cardId, damage: cardDamage, heal: cardHeal, cardsDrawn: cardDrawn, statusApplied: statusApplied))
        }

        return bonusDamage
    }

    /// Discard or exhaust all selected cards.
    private func discardSelectedCards(player: Entity) {
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        for cardId in selectedCardIds {
            guard let card = deck.hand.first(where: { $0.id == cardId }) else { continue }
            if card.exhaust {
                deckSystem.exhaustCard(id: cardId, for: player, nexus: nexus)
            } else {
                deckSystem.discardCard(id: cardId, for: player, nexus: nexus)
            }
        }
    }

    // MARK: - Actions

    /// Begin combat: draw hand, generate enemy intent, set phase to playerTurn.
    public func beginCombat() {
        guard let player = playerEntity else { return }

        // Draw initial hand
        deckSystem.initializeCombatHand(for: player, nexus: nexus)

        // Generate enemy intent
        aiSystem.update(nexus: nexus)

        // Set phase
        combatSystem.setCombatPhase(.playerTurn, nexus: nexus)
    }

    /// Player attacks enemy.
    @discardableResult
    public func playerAttack(bonusDamage: Int = 0) -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .playerMissed(fateValue: 0, fateResolution: nil)
        }
        let event = combatSystem.playerAttack(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        if case .playerAttacked(let dmg, _, _, _) = event { statDamageDealt += dmg }
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
        return event
    }

    /// Play a card from hand. Resolves effect and discards card. Does NOT end the turn.
    @discardableResult
    public func playCard(cardId: String) -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .cardPlayed(cardId: cardId, damage: 0, heal: 0, cardsDrawn: 0, statusApplied: nil)
        }
        let event = combatSystem.playCard(cardId: cardId, player: player, enemy: enemy, deckSystem: deckSystem, nexus: nexus)
        statCardsPlayed += 1
        if case .cardPlayed(_, let dmg, _, _, _) = event { statDamageDealt += dmg }
        return event
    }

    /// Player uses spiritual influence on enemy.
    @discardableResult
    public func playerInfluence(bonusDamage: Int = 0) -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .influenceNotAvailable
        }
        let event = combatSystem.playerInfluence(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
        return event
    }

    /// Player skips (ends turn without acting).
    public func playerSkip() {
        endTurn()
    }

    /// End the player's turn: transitions phase to enemyResolve.
    /// Call resolveEnemyTurn() separately to execute the enemy action.
    public func endTurn() {
        deselectAllCards()
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
    }

    /// Resolve enemy turn, then advance round.
    @discardableResult
    public func resolveEnemyTurn() -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .enemyBlocked
        }
        let event = combatSystem.resolveEnemyIntent(enemy: enemy, player: player, nexus: nexus)
        if case .enemyAttacked(let dmg, _, _, _) = event { statDamageTaken += dmg }

        // Check for end conditions
        if let _ = combatSystem.checkVictoryOrDefeat(nexus: nexus) {
            return event
        }

        // Advance round
        combatSystem.advanceRound(nexus: nexus)

        // Reset energy and draw card for new turn
        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        energy.current = energy.max
        deckSystem.drawCards(count: 1, for: player, nexus: nexus)

        // Generate new enemy intent
        aiSystem.update(nexus: nexus)

        // Back to player turn
        combatSystem.setCombatPhase(.playerTurn, nexus: nexus)

        return event
    }

    /// Mulligan cards from hand.
    public func mulligan(cardIds: [String]) {
        guard let player = playerEntity else { return }
        deckSystem.mulligan(cardIds: cardIds, for: player, nexus: nexus)
    }
}
