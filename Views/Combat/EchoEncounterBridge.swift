/// Файл: Views/Combat/EchoEncounterBridge.swift
/// Назначение: Содержит реализацию файла EchoEncounterBridge.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import TwilightEngine

// MARK: - Echo Combat Configuration

/// Конфигурация запуска внешнего боя через EchoEngine.
struct EchoCombatConfig {
    let enemyDefinition: EnemyDefinition
    let playerName: String
    let playerHealth: Int
    let playerMaxHealth: Int
    let playerStrength: Int
    let playerDeck: [Card]
    let fateCards: [FateCard]
    let resonance: Float
    let seed: UInt64
}

// MARK: - EchoEncounterBridge

/// Мост между состоянием encounter в движке и конфигурацией внешнего Echo-боя.
enum EchoEncounterBridge {

    /// Build an EchoCombatConfig from a saved encounter state (for mid-combat resume).
    /// Restarts combat from the saved HP/deck state (turn-level resume not supported in SpriteKit).
    static func makeCombatConfig(
        from saved: EncounterSaveState,
        engine: TwilightGameEngine,
        registry: ContentRegistry
    ) -> EchoCombatConfig? {
        guard let firstEnemy = saved.context.enemies.first else { return nil }
        let localizationManager = engine.services.localizationManager

        let enemyDef = registry.getEnemy(id: firstEnemy.id)
            ?? EnemyDefinition(
                id: firstEnemy.id,
                name: .inline(LocalizedString(en: firstEnemy.name, ru: firstEnemy.name)),
                description: .inline(LocalizedString(en: "", ru: "")),
                health: firstEnemy.hp,
                power: firstEnemy.power,
                defense: firstEnemy.defense,
                will: firstEnemy.wp
            )

        let fateCards = saved.fateDeckState.drawPile + saved.fateDeckState.discardPile
        let localizedDeck = localizedCards(
            saved.context.heroCards,
            registry: registry,
            localizationManager: localizationManager
        )
        let localizedFateCards = localizedFateCards(fateCards, localizationManager: localizationManager)

        return EchoCombatConfig(
            enemyDefinition: enemyDef,
            playerName: engine.player.name,
            playerHealth: saved.heroHP,
            playerMaxHealth: saved.context.hero.maxHp,
            playerStrength: saved.context.hero.strength,
            playerDeck: localizedDeck,
            fateCards: localizedFateCards,
            resonance: saved.context.worldResonance,
            seed: saved.rngState
        )
    }

    /// Build an EchoCombatConfig from current engine state for SpriteKit combat.
    /// Uses engine-owned external combat snapshot and deterministic seed.
    static func makeCombatConfig(engine: TwilightGameEngine) -> EchoCombatConfig? {
        let difficultyRaw = UserDefaults.standard.string(forKey: "gameDifficulty") ?? "normal"
        let difficulty = DifficultyLevel(rawValue: difficultyRaw) ?? .normal
        guard let snapshot = engine.makeExternalCombatSnapshot(difficulty: difficulty) else { return nil }
        let registry = engine.services.contentRegistry
        let localizationManager = engine.services.localizationManager

        return EchoCombatConfig(
            enemyDefinition: snapshot.enemyDefinition,
            playerName: engine.player.name,
            playerHealth: snapshot.hero.hp,
            playerMaxHealth: snapshot.hero.maxHp,
            playerStrength: snapshot.hero.strength,
            playerDeck: localizedCards(
                snapshot.echoHeroCards,
                registry: registry,
                localizationManager: localizationManager
            ),
            fateCards: localizedFateCards(snapshot.echoFateCards, localizationManager: localizationManager),
            resonance: snapshot.resonance,
            seed: snapshot.seed
        )
    }

    private static func localizedCards(
        _ cards: [Card],
        registry: ContentRegistry,
        localizationManager: LocalizationManager
    ) -> [Card] {
        cards.map { card in
            guard let definitionId = canonicalCardDefinitionId(for: card.id, registry: registry),
                  let definition = registry.getCard(id: definitionId) else {
                return card
            }

            let localizedCard = definition.toCard(localizationManager: localizationManager)
            return card.replacingLocalizedText(name: localizedCard.name, description: localizedCard.description)
        }
    }

    private static func canonicalCardDefinitionId(
        for runtimeCardId: String,
        registry: ContentRegistry
    ) -> String? {
        if registry.getCard(id: runtimeCardId) != nil {
            return runtimeCardId
        }

        guard let suffixSeparator = runtimeCardId.lastIndex(of: "_") else {
            return nil
        }

        let suffixStart = runtimeCardId.index(after: suffixSeparator)
        let suffix = runtimeCardId[suffixStart...]
        guard !suffix.isEmpty, suffix.allSatisfy(\.isNumber) else {
            return nil
        }

        let candidate = String(runtimeCardId[..<suffixSeparator])
        return registry.getCard(id: candidate) == nil ? nil : candidate
    }

    private static func localizedFateCards(
        _ cards: [FateCard],
        localizationManager: LocalizationManager
    ) -> [FateCard] {
        cards.map { card in
            guard let key = card.nameKey else {
                return card
            }

            let localizedName = localizationManager.resolve(StringKey(key)) ?? card.name
            guard localizedName != card.name else {
                return card
            }

            return FateCard(
                id: card.id,
                modifier: card.baseValue,
                isCritical: card.isCritical,
                isSticky: card.isSticky,
                name: localizedName,
                nameKey: card.nameKey,
                suit: card.suit,
                resonanceRules: card.resonanceRules,
                onDrawEffects: card.onDrawEffects,
                keyword: card.keyword,
                cardType: card.cardType,
                choiceOptions: card.choiceOptions
            )
        }
    }
}

private extension Card {
    func replacingLocalizedText(name: String, description: String) -> Card {
        Card(
            id: id,
            name: name,
            type: type,
            rarity: rarity,
            description: description,
            imageURL: imageURL,
            power: power,
            defense: defense,
            health: health,
            will: will,
            wisdom: wisdom,
            cost: cost,
            abilities: abilities,
            traits: traits,
            damageType: damageType,
            range: range,
            balance: balance,
            realm: realm,
            curseType: curseType,
            expansionSet: expansionSet,
            role: role,
            regionRequirement: regionRequirement,
            exhaust: exhaust,
            faithCost: faithCost
        )
    }
}
