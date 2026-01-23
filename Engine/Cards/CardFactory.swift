import Foundation

// MARK: - Card Factory

/// Factory for creating runtime Card instances from Content Pack definitions
/// This is the ONLY authorized way to create Card instances at runtime.
///
/// The factory reads from ContentRegistry (which loads from JSON packs)
/// and converts definitions to runtime Card instances.
///
/// IMPORTANT: TwilightMarchesCards.swift must NOT be used at runtime.
/// All card creation must go through this factory.
final class CardFactory {

    // MARK: - Singleton

    static let shared = CardFactory()

    // MARK: - Dependencies

    private let contentRegistry: ContentRegistry
    private let cardRegistry: CardRegistry

    // MARK: - Initialization

    init(contentRegistry: ContentRegistry = .shared, cardRegistry: CardRegistry = .shared) {
        self.contentRegistry = contentRegistry
        self.cardRegistry = cardRegistry
    }

    // MARK: - Card Creation

    /// Get a runtime Card by ID
    /// - Parameter id: Card definition ID
    /// - Returns: Runtime Card instance or nil if not found
    func getCard(id: String) -> Card? {
        // First try ContentRegistry (from JSON packs)
        if let cardDef = contentRegistry.getCard(id: id) {
            return cardDef.toCard()
        }

        // Fallback to CardRegistry (built-in cards)
        if let cardDef = cardRegistry.card(id: id) as? StandardCardDefinition {
            return cardDef.toCard()
        }

        return nil
    }

    /// Get multiple cards by IDs
    /// - Parameter ids: Array of card IDs
    /// - Returns: Array of runtime Card instances (skipping not found)
    func getCards(ids: [String]) -> [Card] {
        return ids.compactMap { getCard(id: $0) }
    }

    /// Get all available cards
    /// - Returns: Array of all runtime Card instances
    func getAllCards() -> [Card] {
        var cards: [Card] = []

        // From ContentRegistry
        for cardDef in contentRegistry.getAllCards() {
            cards.append(cardDef.toCard())
        }

        // From CardRegistry (built-in)
        for cardDef in cardRegistry.allCards {
            if let stdDef = cardDef as? StandardCardDefinition {
                // Avoid duplicates
                if !cards.contains(where: { $0.name == stdDef.name }) {
                    cards.append(stdDef.toCard())
                }
            }
        }

        return cards
    }

    /// Get cards by type
    /// - Parameter type: Card type to filter
    /// - Returns: Array of runtime Card instances of that type
    func getCards(ofType type: CardType) -> [Card] {
        var cards: [Card] = []

        // From ContentRegistry
        for cardDef in contentRegistry.getCards(ofType: type) {
            cards.append(cardDef.toCard())
        }

        // From CardRegistry (built-in)
        for cardDef in cardRegistry.allCards where cardDef.cardType == type {
            if let stdDef = cardDef as? StandardCardDefinition {
                if !cards.contains(where: { $0.name == stdDef.name }) {
                    cards.append(stdDef.toCard())
                }
            }
        }

        return cards
    }

    // MARK: - Starting Decks

    /// Create starting deck for a hero
    /// - Parameter heroId: Hero definition ID
    /// - Returns: Array of runtime Card instances for starting deck
    func createStartingDeck(forHero heroId: String) -> [Card] {
        // Try ContentRegistry first (from Character Pack)
        let cards = contentRegistry.getStartingDeck(forHero: heroId)
        if !cards.isEmpty {
            return cards.map { $0.toCard() }
        }

        // Fallback to CardRegistry
        let registryDeck = cardRegistry.startingDeck(forHeroID: heroId)
        if !registryDeck.isEmpty {
            return registryDeck
        }

        // Final fallback: generic starter deck
        return createGenericStarterDeck()
    }

    /// Create starting deck for a hero by name (legacy compatibility)
    /// - Parameter heroName: Hero name
    /// - Returns: Array of runtime Card instances for starting deck
    func createStartingDeck(forHeroName heroName: String) -> [Card] {
        // Map name to hero ID
        let heroId = mapHeroNameToId(heroName)
        return createStartingDeck(forHero: heroId)
    }

    /// Create generic starter deck (fallback)
    private func createGenericStarterDeck() -> [Card] {
        var deck: [Card] = []

        // Add basic cards from registry
        let basicCardIds = ["strike_basic", "defend_basic", "heal_basic", "draw_basic"]
        for id in basicCardIds {
            if let card = getCard(id: id) {
                // Add 2 copies of each basic card
                deck.append(card)
                deck.append(getCard(id: id)!) // New instance
            }
        }

        return deck
    }

    // MARK: - Encounter Deck

    /// Create encounter deck from content packs
    /// - Returns: Array of monster cards for encounters
    func createEncounterDeck() -> [Card] {
        var deck: [Card] = []

        // Get all enemies from ContentRegistry
        for enemy in contentRegistry.getAllEnemies() {
            deck.append(enemy.toCard())
        }

        return deck
    }

    // MARK: - Market Cards

    /// Create market cards for purchasing
    /// - Parameter heroId: Optional hero ID for filtering
    /// - Returns: Array of purchasable cards
    func createMarketCards(forHeroId heroId: String? = nil) -> [Card] {
        var cards: [Card] = []

        // Get shop cards from CardRegistry
        let shopDefs = cardRegistry.shopCards(
            forHeroID: heroId,
            ownedExpansions: [],
            unlockedConditions: []
        )

        for cardDef in shopDefs {
            if let stdDef = cardDef as? StandardCardDefinition {
                cards.append(stdDef.toCard())
            }
        }

        return cards
    }

    // MARK: - Character Cards

    /// Create guardian characters for character selection
    /// - Returns: Array of hero cards for selection screen
    /// - Note: Requires ContentPacks to be loaded. Returns empty if no packs.
    func createGuardians() -> [Card] {
        var guardians: [Card] = []

        // Get heroes ONLY from ContentRegistry (no hardcoded fallback)
        for hero in contentRegistry.getAllHeroes() {
            guardians.append(heroToCard(hero))
        }

        if guardians.isEmpty {
            print("⚠️ CardFactory: No heroes loaded from ContentPacks. Ensure packs are loaded.")
        }

        return guardians
    }

    /// Convert hero definition to Card for UI display
    private func heroToCard(_ hero: StandardHeroDefinition) -> Card {
        return Card(
            id: UUID(),
            name: hero.name,
            type: .character,
            rarity: .legendary,
            description: hero.description,
            imageURL: nil,
            power: hero.baseStats.strength,
            defense: 0,
            health: hero.baseStats.health,
            abilities: [
                CardAbility(
                    name: hero.specialAbility.name,
                    description: hero.specialAbility.description,
                    effect: .custom(hero.specialAbility.description)
                )
            ],
            faithCost: 0
        )
    }

    // MARK: - Boss Creation

    /// Create boss card by enemy ID
    /// - Parameter enemyId: Enemy definition ID
    /// - Returns: Boss card or nil
    func createBoss(enemyId: String) -> Card? {
        if let enemy = contentRegistry.getEnemy(id: enemyId) {
            return enemy.toCard()
        }
        return nil
    }

    /// Create Leshy Guardian boss (Act I final boss)
    /// - Returns: Boss card from ContentPack or nil if not found
    /// - Note: Boss must be defined in enemies.json as "leshy_guardian_boss"
    func createLeshyGuardianBoss() -> Card? {
        // Get boss ONLY from ContentRegistry (no hardcoded fallback)
        if let boss = createBoss(enemyId: "leshy_guardian_boss") {
            return boss
        }

        print("⚠️ CardFactory: Boss 'leshy_guardian_boss' not found in ContentPacks")
        return nil
    }

    // MARK: - Helper Methods

    /// Map hero name to ID for legacy compatibility
    private func mapHeroNameToId(_ name: String) -> String {
        switch name.lowercased() {
        case "велеслава": return "veleslava"
        case "ратибор": return "ratibor"
        case "мирослав": return "miroslav"
        case "забава": return "zabava"
        default: return name.lowercased().replacingOccurrences(of: " ", with: "_")
        }
    }

}
