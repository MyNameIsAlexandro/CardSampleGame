/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/ExternalCombatSnapshot.swift
/// Назначение: Содержит реализацию файла ExternalCombatSnapshot.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

public struct ExternalCombatEnemySnapshot: Equatable, Sendable {
    public let id: String
    public let name: String
    public let hp: Int
    public let maxHp: Int
    public let wp: Int?
    public let maxWp: Int?
    public let power: Int
    public let defense: Int

    public init(
        id: String,
        name: String,
        hp: Int,
        maxHp: Int,
        wp: Int?,
        maxWp: Int?,
        power: Int,
        defense: Int
    ) {
        self.id = id
        self.name = name
        self.hp = hp
        self.maxHp = maxHp
        self.wp = wp
        self.maxWp = maxWp
        self.power = power
        self.defense = defense
    }
}

public struct ExternalCombatSnapshot {
    public let seed: UInt64
    public let hero: EncounterHero
    public let enemyDefinition: EnemyDefinition
    public let enemy: ExternalCombatEnemySnapshot
    public let playerDeckCards: [Card]
    public let playerHandCards: [Card]
    public let playerDiscardCards: [Card]
    public let fateDeckState: FateDeckState
    public let resonance: Float
    public let heroFaith: Int
    public let behaviors: [String: BehaviorDefinition]
    public let balanceConfig: CombatBalanceConfig?

    public init(
        seed: UInt64,
        hero: EncounterHero,
        enemyDefinition: EnemyDefinition,
        enemy: ExternalCombatEnemySnapshot,
        playerDeckCards: [Card],
        playerHandCards: [Card],
        playerDiscardCards: [Card],
        fateDeckState: FateDeckState,
        resonance: Float,
        heroFaith: Int,
        behaviors: [String: BehaviorDefinition],
        balanceConfig: CombatBalanceConfig?
    ) {
        self.seed = seed
        self.hero = hero
        self.enemyDefinition = enemyDefinition
        self.enemy = enemy
        self.playerDeckCards = playerDeckCards
        self.playerHandCards = playerHandCards
        self.playerDiscardCards = playerDiscardCards
        self.fateDeckState = fateDeckState
        self.resonance = resonance
        self.heroFaith = heroFaith
        self.behaviors = behaviors
        self.balanceConfig = balanceConfig
    }

    public var encounterHeroCards: [Card] {
        Self.withUniqueCardIds(playerHandCards + playerDeckCards + playerDiscardCards)
    }

    public var echoHeroCards: [Card] {
        playerDeckCards + playerHandCards + playerDiscardCards
    }

    public var echoFateCards: [FateCard] {
        fateDeckState.drawPile + fateDeckState.discardPile
    }

    private static func withUniqueCardIds(_ cards: [Card]) -> [Card] {
        var seenCounts: [String: Int] = [:]
        return cards.map { card in
            let count = (seenCounts[card.id] ?? 0) + 1
            seenCounts[card.id] = count
            if count == 1 {
                return card
            }
            return card.withInstanceId("\(card.id)_\(count)")
        }
    }
}

extension TwilightGameEngine {

    public func makeExternalCombatSnapshot(difficulty: DifficultyLevel) -> ExternalCombatSnapshot? {
        guard let state = combat.combatState else { return nil }
        return buildExternalCombatSnapshot(enemyCard: state.enemy, combatState: state, difficulty: difficulty)
    }

    public func makeExternalCombatSnapshot(for monsterCard: Card, difficulty: DifficultyLevel) -> ExternalCombatSnapshot? {
        buildExternalCombatSnapshot(enemyCard: monsterCard, combatState: nil, difficulty: difficulty)
    }

    private func buildExternalCombatSnapshot(
        enemyCard: Card,
        combatState: CombatState?,
        difficulty: DifficultyLevel
    ) -> ExternalCombatSnapshot? {
        guard let seed = pendingExternalCombatSeed else { return nil }

        let enemyPayload = resolveExternalCombatEnemy(
            enemyCard: enemyCard,
            combatState: combatState,
            difficulty: difficulty
        )
        let encounterHero = EncounterHero(
            id: player.heroId ?? "hero",
            hp: player.health,
            maxHp: player.maxHealth,
            strength: player.strength,
            armor: 0,
            wisdom: player.wisdom,
            willDefense: 0
        )
        let fateDeckSnapshot = fateDeckStateSnapshot() ?? FateDeckState(drawPile: [], discardPile: [])

        return ExternalCombatSnapshot(
            seed: seed,
            hero: encounterHero,
            enemyDefinition: enemyPayload.definition,
            enemy: enemyPayload.snapshot,
            playerDeckCards: deck.playerDeck,
            playerHandCards: deck.playerHand,
            playerDiscardCards: deck.playerDiscard,
            fateDeckState: fateDeckSnapshot,
            resonance: resonanceValue,
            heroFaith: player.faith,
            behaviors: buildBehaviorMap(),
            balanceConfig: services.contentRegistry.getBalanceConfig()?.combat
        )
    }

    private func resolveExternalCombatEnemy(
        enemyCard: Card,
        combatState: CombatState?,
        difficulty: DifficultyLevel
    ) -> (definition: EnemyDefinition, snapshot: ExternalCombatEnemySnapshot) {
        var enemyDef = services.contentRegistry.getEnemy(id: enemyCard.id) ?? synthesizedEnemyDefinition(from: enemyCard)
        if let health = enemyCard.health { enemyDef.health = health }
        if let power = enemyCard.power { enemyDef.power = power }
        if let defense = enemyCard.defense { enemyDef.defense = defense }
        if let will = enemyCard.will { enemyDef.will = will }

        let baseHealth: Int
        let baseCurrentHealth: Int
        let basePower: Int
        let baseDefense: Int
        let baseWill: Int?
        let baseMaxWill: Int?

        if let combatState {
            baseHealth = combatState.enemyMaxHealth
            baseCurrentHealth = combatState.enemyHealth
            basePower = combatState.enemyPower
            baseDefense = combatState.enemyDefense
            baseWill = combatState.hasSpiritTrack ? combatState.enemyWill : nil
            baseMaxWill = combatState.hasSpiritTrack ? combatState.enemyMaxWill : nil
        } else {
            let combatContext = CombatContext(
                regionState: currentRegion?.state ?? .stable,
                playerCurses: player.activeCurses.map(\.type)
            )
            let rawHealth = enemyCard.health ?? enemyDef.health
            let rawPower = enemyCard.power ?? enemyDef.power
            let rawDefense = enemyCard.defense ?? enemyDef.defense
            let rawWill = enemyCard.will ?? enemyDef.will

            baseHealth = max(1, combatContext.adjustedEnemyHealth(rawHealth))
            baseCurrentHealth = baseHealth
            basePower = max(0, combatContext.adjustedEnemyPower(rawPower))
            baseDefense = max(0, combatContext.adjustedEnemyDefense(rawDefense))
            baseWill = rawWill
            baseMaxWill = rawWill
        }

        let scaledMaxHealth = max(1, Int(Double(baseHealth) * difficulty.hpMultiplier))
        let scaledCurrentHealth = min(
            scaledMaxHealth,
            max(0, Int(Double(baseCurrentHealth) * difficulty.hpMultiplier))
        )
        let scaledPower = max(0, Int(Double(basePower) * difficulty.powerMultiplier))

        enemyDef.health = scaledMaxHealth
        enemyDef.power = scaledPower
        enemyDef.defense = baseDefense
        enemyDef.will = baseMaxWill

        let enemySnapshot = ExternalCombatEnemySnapshot(
            id: enemyCard.id,
            name: enemyCard.name,
            hp: scaledCurrentHealth,
            maxHp: scaledMaxHealth,
            wp: baseWill,
            maxWp: baseMaxWill,
            power: scaledPower,
            defense: baseDefense
        )

        return (enemyDef, enemySnapshot)
    }

    private func synthesizedEnemyDefinition(from card: Card) -> EnemyDefinition {
        EnemyDefinition(
            id: card.id,
            name: .inline(LocalizedString(en: card.name, ru: card.name)),
            description: .inline(LocalizedString(en: card.description, ru: card.description)),
            health: card.health ?? 10,
            power: card.power ?? 5,
            defense: card.defense ?? 0,
            difficulty: 1,
            enemyType: .beast,
            rarity: card.rarity,
            will: card.will
        )
    }

    private func buildBehaviorMap() -> [String: BehaviorDefinition] {
        var map: [String: BehaviorDefinition] = [:]
        for behavior in services.contentRegistry.allBehaviors {
            map[behavior.id] = behavior
        }
        return map
    }

}
