/// Файл: Packages/EchoEngine/Sources/EchoEngine/CombatSimulation+Queries.swift
/// Назначение: Содержит реализацию файла CombatSimulation+Queries.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

extension CombatSimulation {

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
            if let enemy = enemyEntity {
                let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
                if !health.isAlive { return .victory(.killed) }
                if health.willDepleted { return .victory(.pacified) }
            }
            return .victory(.killed)
        case .defeat:
            return .defeat
        default:
            return nil
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
}

