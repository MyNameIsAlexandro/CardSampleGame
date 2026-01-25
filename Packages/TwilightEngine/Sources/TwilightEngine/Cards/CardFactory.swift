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

    // MARK: - Singleton

    public static let shared = CardFactory()

    // MARK: - Dependencies

    private let contentRegistry: ContentRegistry

    // MARK: - Initialization

    public init(contentRegistry: ContentRegistry = .shared) {
        self.contentRegistry = contentRegistry
    }

    // MARK: - Card Creation

    /// Get a runtime Card by ID
    /// - Parameter id: Card definition ID
    /// - Returns: Runtime Card instance or nil if not found
    public func getCard(id: String) -> Card? {
        // ContentRegistry is the ONLY source of cards (pack-driven)
        if let cardDef = contentRegistry.getCard(id: id) {
            return cardDef.toCard()
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
        return contentRegistry.getAllCards().map { $0.toCard() }
    }

    /// Get cards by type
    /// - Parameter type: Card type to filter
    /// - Returns: Array of runtime Card instances of that type
    public func getCards(ofType type: CardType) -> [Card] {
        // ContentRegistry is the ONLY source of cards (pack-driven)
        return contentRegistry.getCards(ofType: type).map { $0.toCard() }
    }

    // MARK: - Starting Decks

    /// Create starting deck for a hero
    /// - Parameter heroId: Hero definition ID
    /// - Returns: Array of runtime Card instances for starting deck
    public func createStartingDeck(forHero heroId: String) -> [Card] {
        // ContentRegistry is the ONLY source of starting decks (pack-driven)
        let cards = contentRegistry.getStartingDeck(forHero: heroId)
        if !cards.isEmpty {
            return cards.map { $0.toCard() }
        }

        // Fallback: generic starter deck from ContentRegistry
        return createGenericStarterDeck()
    }

    /// Create starting deck for a hero by name (legacy compatibility)
    /// - Parameter heroName: Hero name
    /// - Returns: Array of runtime Card instances for starting deck
    public func createStartingDeck(forHeroName heroName: String) -> [Card] {
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
    public func createEncounterDeck() -> [Card] {
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
    public func createMarketCards(forHeroId heroId: String? = nil) -> [Card] {
        // ContentRegistry is the ONLY source of cards (pack-driven)
        // Filter for purchasable cards (exclude signature, legendary)
        return contentRegistry.getAllCards()
            .filter { card in
                // Exclude legendary cards (found only in dungeons)
                if card.rarity == .legendary { return false }
                return true
            }
            .map { $0.toCard() }
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
            id: UUID(),
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
            return enemy.toCard()
        }
        return nil
    }

    /// Create Leshy Guardian boss (Act I final boss)
    /// - Returns: Boss card from ContentPack or nil if not found
    /// - Note: Boss must be defined in enemies.json as "leshy_guardian_boss"
    public func createLeshyGuardianBoss() -> Card? {
        // Get boss ONLY from ContentRegistry (no hardcoded fallback)
        if let boss = createBoss(enemyId: "leshy_guardian_boss") {
            return boss
        }

        #if DEBUG
        print("⚠️ CardFactory: Boss 'leshy_guardian_boss' not found in ContentPacks")
        #endif
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
