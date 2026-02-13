/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Cards/CardFactory.swift
/// Назначение: Содержит реализацию файла CardFactory.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Card Factory

/// Factory for creating runtime Card instances from Content Pack definitions
/// This is the ONLY authorized way to create Card instances at runtime.
///
/// The factory reads ONLY from ContentRegistry (which loads from JSON packs)
/// and converts definitions to runtime Card instances.
///
/// IMPORTANT: No fallback to CardRegistry or any code-based content sources.
/// All card creation must go through ContentRegistry (pack-driven).
public final class CardFactory {
    // MARK: - Dependencies

    private let contentRegistry: ContentRegistry
    private let localizationManager: LocalizationManager

    // MARK: - Initialization

    /// Creates a CardFactory backed by the given content registry.
    public init(contentRegistry: ContentRegistry, localizationManager: LocalizationManager) {
        self.contentRegistry = contentRegistry
        self.localizationManager = localizationManager
    }

    // MARK: - Card Creation

    /// Get a runtime Card by ID
    /// - Parameter id: Card definition ID
    /// - Returns: Runtime Card instance or nil if not found
    public func getCard(id: String) -> Card? {
        // ContentRegistry is the ONLY source of cards (pack-driven)
        if let cardDef = contentRegistry.getCard(id: id) {
            return cardDef.toCard(localizationManager: localizationManager)
        }
        return nil
    }

    /// Get multiple cards by IDs
    /// - Parameter ids: Array of card IDs
    /// - Returns: Array of runtime Card instances (skipping not found)
    public func getCards(ids: [String]) -> [Card] {
        return ids.compactMap { getCard(id: $0) }
    }

    /// Get all available cards
    /// - Returns: Array of all runtime Card instances
    public func getAllCards() -> [Card] {
        // ContentRegistry is the ONLY source of cards (pack-driven)
        return contentRegistry.getAllCards().map { $0.toCard(localizationManager: localizationManager) }
    }

    /// Get cards by type
    /// - Parameter type: Card type to filter
    /// - Returns: Array of runtime Card instances of that type
    public func getCards(ofType type: CardType) -> [Card] {
        // ContentRegistry is the ONLY source of cards (pack-driven)
        return contentRegistry.getCards(ofType: type).map { $0.toCard(localizationManager: localizationManager) }
    }

    // MARK: - Starting Decks

    /// Create starting deck for a hero
    /// - Parameter heroId: Hero definition ID
    /// - Returns: Array of runtime Card instances for starting deck
    public func createStartingDeck(forHero heroId: String) -> [Card] {
        // ContentRegistry is the ONLY source of starting decks (pack-driven)
        let cards = contentRegistry.getStartingDeck(forHero: heroId)
        if !cards.isEmpty {
            return cards.map { $0.toCard(localizationManager: localizationManager) }
        }

        // Fallback: generic starter deck from ContentRegistry
        return createGenericStarterDeck()
    }


    /// Create generic starter deck (fallback)
    /// Returns empty if no starter deck defined in content packs.
    private func createGenericStarterDeck() -> [Card] {
        #if DEBUG
        print("⚠️ CardFactory: No starting deck found for hero. Ensure content pack defines starting_deck.")
        #endif
        return []
    }

    // MARK: - Encounter Deck

    /// Create encounter deck from content packs
    /// - Returns: Array of monster cards for encounters
    public func createEncounterDeck() -> [Card] {
        var deck: [Card] = []

        // Get all enemies from ContentRegistry
        for enemy in contentRegistry.getAllEnemies() {
            deck.append(enemy.toCard(localizationManager: localizationManager))
        }

        return deck
    }

    // MARK: - Market Cards

    /// Create market cards for purchasing
    /// - Parameter heroId: Optional hero ID for filtering
    /// - Returns: Array of purchasable cards
    public func createMarketCards(forHeroId heroId: String? = nil) -> [Card] {
        // ContentRegistry is the ONLY source of cards (pack-driven)
        // Filter for purchasable cards (exclude signature, legendary)
        return contentRegistry.getAllCards()
            .filter { card in
                // Exclude legendary cards (found only in dungeons)
                if card.rarity == .legendary { return false }
                return true
            }
            .map { $0.toCard(localizationManager: localizationManager) }
    }

    // MARK: - Character Cards

    /// Create guardian characters for character selection
    /// - Returns: Array of hero cards for selection screen
    /// - Note: Requires ContentPacks to be loaded. Returns empty if no packs.
    public func createGuardians() -> [Card] {
        var guardians: [Card] = []

        // Get heroes ONLY from ContentRegistry (no hardcoded fallback)
        for hero in contentRegistry.getAllHeroes() {
            guardians.append(heroToCard(hero))
        }

        if guardians.isEmpty {
            #if DEBUG
            print("⚠️ CardFactory: No heroes loaded from ContentPacks. Ensure packs are loaded.")
            #endif
        }

        return guardians
    }

    /// Convert hero definition to Card for UI display
    private func heroToCard(_ hero: StandardHeroDefinition) -> Card {
        return Card(
            id: hero.id,
            name: hero.name.localized,
            type: .character,
            rarity: .legendary,
            description: hero.description.localized,
            imageURL: nil,
            power: hero.baseStats.strength,
            defense: 0,
            health: hero.baseStats.health,
            abilities: [
                CardAbility(
                    id: "\(hero.id)_ability",
                    name: hero.specialAbility.name.localized,
                    description: hero.specialAbility.description.localized,
                    effect: .custom(hero.specialAbility.description.localized)
                )
            ],
            faithCost: 0
        )
    }

    // MARK: - Boss Creation

    /// Create boss card by enemy ID
    /// - Parameter enemyId: Enemy definition ID
    /// - Returns: Boss card or nil
    public func createBoss(enemyId: String) -> Card? {
        if let enemy = contentRegistry.getEnemy(id: enemyId) {
            return enemy.toCard(localizationManager: localizationManager)
        }
        return nil
    }

}
