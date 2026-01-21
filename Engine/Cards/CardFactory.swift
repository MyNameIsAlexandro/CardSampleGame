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

        // Fallback to CardRegistry if hero matches
        if let heroClass = getHeroClass(forHeroId: heroId) {
            return cardRegistry.startingDeck(forHeroID: heroId, heroClass: heroClass)
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
    /// - Parameter heroClass: Optional hero class for filtering
    /// - Returns: Array of purchasable cards
    func createMarketCards(forHeroClass heroClass: HeroClass? = nil) -> [Card] {
        var cards: [Card] = []

        // Get shop cards from CardRegistry
        let shopDefs = cardRegistry.shopCards(
            forHeroID: nil,
            heroClass: heroClass,
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
    func createGuardians() -> [Card] {
        var guardians: [Card] = []

        // Get heroes from ContentRegistry
        for hero in contentRegistry.getAllHeroes() {
            guardians.append(heroToCard(hero))
        }

        // Fallback: if no heroes in packs, use hardcoded fallback
        if guardians.isEmpty {
            guardians = createFallbackGuardians()
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

    /// Fallback guardians when no packs loaded
    private func createFallbackGuardians() -> [Card] {
        // This provides minimal fallback when no packs are loaded
        // In production, packs should always be loaded
        return [
            Card(
                name: "Велеслава",
                type: .character,
                rarity: .legendary,
                description: "Жрица Света. Мастер исцеления и защиты.",
                defense: 2,
                health: 12,
                abilities: [],
                faithCost: 0
            ),
            Card(
                name: "Ратибор",
                type: .character,
                rarity: .legendary,
                description: "Воин. Сильный боец ближнего боя.",
                power: 4,
                health: 14,
                abilities: [],
                faithCost: 0
            ),
            Card(
                name: "Мирослав",
                type: .character,
                rarity: .legendary,
                description: "Следопыт. Быстрый и точный.",
                power: 3,
                health: 10,
                abilities: [],
                faithCost: 0
            ),
            Card(
                name: "Забава",
                type: .character,
                rarity: .legendary,
                description: "Ведьма. Мастер тёмных искусств.",
                power: 5,
                health: 8,
                abilities: [],
                faithCost: 0
            )
        ]
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
    func createLeshyGuardianBoss() -> Card? {
        // Try to get from ContentRegistry first
        if let boss = createBoss(enemyId: "leshy_guardian") {
            return boss
        }

        // Fallback boss
        return Card(
            name: "Леший-Хранитель",
            type: .monster,
            rarity: .legendary,
            description: "Древний страж Сумрачных Пределов. Босс Акта I.",
            power: 7,
            defense: 4,
            health: 25,
            abilities: [
                CardAbility(
                    name: "Гнев Природы",
                    description: "Регенерация 3 HP каждый ход",
                    effect: .heal(amount: 3)
                ),
                CardAbility(
                    name: "Древняя Броня",
                    description: "+2 к защите",
                    effect: .custom( "Дополнительная защита")
                )
            ],
            faithCost: 0
        )
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

    /// Get hero class for hero ID
    private func getHeroClass(forHeroId heroId: String) -> HeroClass? {
        if let hero = contentRegistry.getHero(id: heroId) {
            return hero.heroClass
        }

        // Fallback mapping
        switch heroId.lowercased() {
        case "veleslava": return .priest
        case "ratibor": return .warrior
        case "miroslav": return .ranger
        case "zabava": return .shadow
        default: return nil
        }
    }
}
