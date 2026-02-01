import FirebladeECS
import TwilightEngine

/// High-level orchestrator for a complete combat encounter.
/// Owns the Nexus and all systems. Provides a simple API for tests and future UI.
public final class CombatSimulation {
    public let nexus: Nexus
    public let combatSystem: CombatSystem
    public let aiSystem: AISystem
    public let deckSystem: DeckSystem

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
        case .victory: return .victory
        case .defeat: return .defeat
        default: return nil
        }
    }

    public var playerHealth: Int {
        guard let player = playerEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: player.identifier)
        return health.current
    }

    public var enemyHealth: Int {
        guard let enemy = enemyEntity else { return 0 }
        let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
        return health.current
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

    public var discardPileCount: Int {
        guard let player = playerEntity else { return 0 }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        return deck.discardPile.count
    }

    public var round: Int {
        let family = nexus.family(requires: CombatStateComponent.self)
        return family.firstElement()?.round ?? 1
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
            return .playerMissed(fateValue: 0)
        }
        let event = combatSystem.playerAttack(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
        return event
    }

    /// Play a card from hand. Resolves effect and discards card. Does NOT end the turn.
    @discardableResult
    public func playCard(cardId: String) -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .cardPlayed(cardId: cardId, damage: 0, heal: 0, cardsDrawn: 0)
        }
        return combatSystem.playCard(cardId: cardId, player: player, enemy: enemy, deckSystem: deckSystem, nexus: nexus)
    }

    /// Player skips (ends turn without acting).
    public func playerSkip() {
        endTurn()
    }

    /// End the player's turn: transitions phase to enemyResolve.
    /// Call resolveEnemyTurn() separately to execute the enemy action.
    public func endTurn() {
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
    }

    /// Resolve enemy turn, then advance round.
    @discardableResult
    public func resolveEnemyTurn() -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .enemyBlocked
        }
        let event = combatSystem.resolveEnemyIntent(enemy: enemy, player: player, nexus: nexus)

        // Check for end conditions
        if let _ = combatSystem.checkVictoryOrDefeat(nexus: nexus) {
            return event
        }

        // Advance round
        combatSystem.advanceRound(nexus: nexus)

        // Draw card for new turn
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
