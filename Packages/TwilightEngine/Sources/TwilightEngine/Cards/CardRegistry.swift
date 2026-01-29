import Foundation

/// Реестр карт - централизованное хранилище всех определений карт
/// Поддерживает:
/// - Универсальные карты (доступны всем)
/// - Сигнатурные карты героя (уникальные карты конкретного персонажа по heroID)
/// - DLC/Expansion карты
@available(*, deprecated, message: "Use ContentRegistry")
public final class CardRegistry {

    // MARK: - Singleton

    public static let shared = CardRegistry()

    // MARK: - Storage

    /// Все зарегистрированные карты
    private var definitions: [String: CardDefinition] = [:]

    /// Пулы карт героев (по heroID)
    private var heroPools: [String: HeroCardPool] = [:]

    /// Сигнатурные карты героев
    private var signatureCards: [String: HeroSignatureCards] = [:]

    /// Источники данных карт
    private var dataSources: [CardDataSource] = []

    // MARK: - Init

    public init() {
        // No hardcoded cards - all content comes from ContentPacks
    }

    // MARK: - Registration

    /// Register a card definition in the registry.
    /// - Parameter definition: The card definition to register.
    /// - Note: If a card with the same ID already exists, it will be replaced.
    public func register(_ definition: CardDefinition) {
        definitions[definition.id] = definition
    }

    /// Register multiple card definitions at once.
    /// - Parameter definitions: Array of card definitions to register.
    public func registerAll(_ definitions: [CardDefinition]) {
        for definition in definitions {
            register(definition)
        }
    }

    /// Register a hero's card pool (starting, purchasable, and upgrade cards).
    /// - Parameter pool: The hero card pool containing all cards for a specific hero.
    public func registerHeroPool(_ pool: HeroCardPool) {
        heroPools[pool.heroID] = pool
        registerAll(pool.startingCards)
        registerAll(pool.purchasableCards)
        registerAll(pool.upgradeCards)
    }

    /// Register signature cards for a hero.
    /// - Parameter cards: The signature cards collection for a hero.
    public func registerSignatureCards(_ cards: HeroSignatureCards) {
        signatureCards[cards.heroID] = cards
        registerAll(cards.requiredCards)
        registerAll(cards.optionalCards)
        if let weakness = cards.weakness {
            register(weakness)
        }
    }

    /// Remove a card from the registry.
    /// - Parameter id: The unique identifier of the card to remove.
    public func unregister(id: String) {
        definitions.removeValue(forKey: id)
    }

    /// Clear all registered cards, hero pools, and signature cards.
    /// - Note: This does not remove data sources; call `reload()` to repopulate.
    public func clear() {
        definitions.removeAll()
        heroPools.removeAll()
        signatureCards.removeAll()
    }

    /// Reload all cards from registered data sources.
    /// - Note: Clears existing registrations before reloading.
    public func reload() {
        clear()
        // Load cards from data sources (ContentPacks)
        for source in dataSources {
            registerAll(source.loadCards())
        }
    }

    // MARK: - Data Sources

    /// Add a data source and immediately load its cards.
    /// - Parameter source: The card data source to add.
    public func addDataSource(_ source: CardDataSource) {
        dataSources.append(source)
        registerAll(source.loadCards())
    }

    /// Remove a data source and unregister all its cards.
    /// - Parameter source: The card data source to remove.
    public func removeDataSource(_ source: CardDataSource) {
        if let index = dataSources.firstIndex(where: { $0.id == source.id }) {
            let source = dataSources.remove(at: index)
            for card in source.loadCards() {
                unregister(id: card.id)
            }
        }
    }

    // MARK: - Queries

    /// Get a card definition by its unique identifier.
    /// - Parameter id: The card's unique identifier.
    /// - Returns: The card definition, or `nil` if not found.
    public func card(id: String) -> CardDefinition? {
        return definitions[id]
    }

    /// All registered card definitions.
    public var allCards: [CardDefinition] {
        return Array(definitions.values)
    }

    /// Get cards available for a specific hero considering ownership rules.
    /// - Parameters:
    ///   - heroID: The hero's unique identifier (for signature cards).
    ///   - ownedExpansions: Set of owned expansion/DLC identifiers.
    ///   - unlockedConditions: Set of unlocked condition flags.
    /// - Returns: Array of card definitions available to the hero.
    public func availableCards(
        forHeroID heroID: String?,
        ownedExpansions: Set<String> = [],
        unlockedConditions: Set<String> = []
    ) -> [CardDefinition] {
        return allCards.filter { card in
            card.ownership.isAvailable(
                forHeroID: heroID,
                ownedExpansions: ownedExpansions,
                unlockedConditions: unlockedConditions
            )
        }
    }

    /// All universal cards (available to all heroes).
    public var universalCards: [CardDefinition] {
        return allCards.filter { card in
            if case .universal = card.ownership { return true }
            return false
        }
    }

    /// Get signature cards for a specific hero.
    /// - Parameter heroID: The hero's unique identifier.
    /// - Returns: The hero's signature cards, or `nil` if none registered.
    public func signatureCards(forHeroID heroID: String) -> HeroSignatureCards? {
        return signatureCards[heroID]
    }

    /// Get the card pool for a specific hero.
    /// - Parameter heroID: The hero's unique identifier.
    /// - Returns: The hero's card pool, or `nil` if none registered.
    public func heroPool(for heroID: String) -> HeroCardPool? {
        return heroPools[heroID]
    }

    /// Build the starting deck for a hero.
    /// - Parameter heroID: The hero's unique identifier.
    /// - Returns: Array of Card instances for the hero's starting deck.
    /// - Note: Includes basic universal cards, hero pool cards, and signature cards.
    public func startingDeck(forHeroID heroID: String) -> [Card] {
        var deck: [Card] = []

        // 1. Базовые универсальные карты
        let basicCards = universalCards.filter { $0.rarity == .common }
        for cardDef in basicCards.prefix(5) {
            if let def = cardDef as? StandardCardDefinition {
                deck.append(def.toCard())
            }
        }

        // 2. Карты героя (из пула)
        if let pool = heroPools[heroID] {
            for cardDef in pool.startingCards {
                if let def = cardDef as? StandardCardDefinition {
                    deck.append(def.toCard())
                }
            }
        }

        // 3. Сигнатурные карты героя
        if let signature = signatureCards[heroID] {
            for cardDef in signature.requiredCards {
                if let def = cardDef as? StandardCardDefinition {
                    deck.append(def.toCard())
                }
            }
            // Добавляем слабость
            if let weakness = signature.weakness as? StandardCardDefinition {
                deck.append(weakness.toCard())
            }
        }

        return deck
    }

    /// Get cards available for purchase in the shop.
    /// - Parameters:
    ///   - heroID: The hero's unique identifier.
    ///   - ownedExpansions: Set of owned expansion/DLC identifiers.
    ///   - unlockedConditions: Set of unlocked condition flags.
    ///   - maxRarity: Maximum rarity to include (default: epic).
    /// - Returns: Array of purchasable card definitions.
    /// - Note: Excludes signature cards and legendary cards (dungeon rewards only).
    public func shopCards(
        forHeroID heroID: String?,
        ownedExpansions: Set<String> = [],
        unlockedConditions: Set<String> = [],
        maxRarity: CardRarity = .epic
    ) -> [CardDefinition] {
        return availableCards(
            forHeroID: heroID,
            ownedExpansions: ownedExpansions,
            unlockedConditions: unlockedConditions
        ).filter { card in
            // Exclude signature cards from shop
            if case .heroSignature = card.ownership { return false }
            // Exclude legendary (dungeon rewards only)
            if card.rarity == .legendary { return false }
            return card.rarity.order <= maxRarity.order
        }
    }

    /// Number of registered cards.
    public var count: Int {
        return definitions.count
    }

    // MARK: - Content Pack Integration
    // All cards are loaded from ContentPacks via ContentRegistry.
}

// MARK: - Card Data Source Protocol

/// Protocol for card data sources.
/// Allows loading cards from different sources (JSON files, server, DLC).
public protocol CardDataSource {
    /// Unique identifier for this data source.
    var id: String { get }

    /// Human-readable name (for debugging).
    var name: String { get }

    /// Load all cards from this data source.
    /// - Returns: Array of card definitions.
    func loadCards() -> [CardDefinition]
}

// MARK: - JSON Data Source

/// Card data source that loads from a JSON file.
public struct JSONCardDataSource: CardDataSource {
    /// Unique identifier for this data source.
    public let id: String

    /// Human-readable name (for debugging).
    public let name: String

    /// URL to the JSON file containing card definitions.
    public let fileURL: URL

    /// Load cards from the JSON file.
    /// - Returns: Array of card definitions, or empty array on error.
    public func loadCards() -> [CardDefinition] {
        guard let data = try? Data(contentsOf: fileURL) else {
            #if DEBUG
            print("CardRegistry: Failed to load JSON from \(fileURL)")
            #endif
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([JSONCardDefinition].self, from: data)
            return decoded.map { $0.toStandard() }
        } catch {
            #if DEBUG
            print("CardRegistry: Failed to decode cards: \(error)")
            #endif
            return []
        }
    }
}

/// JSON-совместимое определение карты
public struct JSONCardDefinition: Codable {
    let id: String
    let name: String
    let cardType: CardType
    let rarity: CardRarity
    let description: String
    let icon: String?
    let expansionSet: ExpansionSet?
    let faithCost: Int
    let balance: CardBalance?
    let role: CardRole?
    let power: Int?
    let defense: Int?
    let health: Int?
    // Simplified ownership for JSON
    let ownershipType: String?  // "universal", "hero:warrior_ragnar"

    func toStandard() -> StandardCardDefinition {
        let ownership: CardOwnership
        if let ownershipType = ownershipType {
            if ownershipType == "universal" {
                ownership = .universal
            } else if ownershipType.hasPrefix("hero:") {
                let heroID = String(ownershipType.dropFirst(5))
                ownership = .heroSignature(heroID: heroID)
            } else {
                ownership = .universal
            }
        } else {
            ownership = .universal
        }

        return StandardCardDefinition(
            id: id,
            name: .text(name),
            cardType: cardType,
            rarity: rarity,
            description: .text(description),
            icon: icon ?? "🃏",
            expansionSet: expansionSet ?? .baseSet,
            ownership: ownership,
            faithCost: faithCost,
            balance: balance,
            role: role,
            power: power,
            defense: defense,
            health: health
        )
    }
}

// MARK: - CardRarity Extension

extension CardRarity {
    /// Порядок редкости для сравнения
    var order: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
}
