import Foundation

/// Реестр карт - централизованное хранилище всех определений карт
/// Поддерживает:
/// - Универсальные карты (доступны всем)
/// - Сигнатурные карты героя (уникальные карты конкретного персонажа по heroID)
/// - DLC/Expansion карты
final class CardRegistry {

    // MARK: - Singleton

    static let shared = CardRegistry()

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

    private init() {
        // No hardcoded cards - all content comes from ContentPacks
        // Cards are loaded via PackLoader -> ContentRegistry
    }

    // MARK: - Registration

    /// Зарегистрировать определение карты
    func register(_ definition: CardDefinition) {
        definitions[definition.id] = definition
    }

    /// Зарегистрировать несколько карт
    func registerAll(_ definitions: [CardDefinition]) {
        for definition in definitions {
            register(definition)
        }
    }

    /// Зарегистрировать пул карт героя
    func registerHeroPool(_ pool: HeroCardPool) {
        heroPools[pool.heroID] = pool
        registerAll(pool.startingCards)
        registerAll(pool.purchasableCards)
        registerAll(pool.upgradeCards)
    }

    /// Зарегистрировать сигнатурные карты героя
    func registerSignatureCards(_ cards: HeroSignatureCards) {
        signatureCards[cards.heroID] = cards
        registerAll(cards.requiredCards)
        registerAll(cards.optionalCards)
        if let weakness = cards.weakness {
            register(weakness)
        }
    }

    /// Удалить карту из реестра
    func unregister(id: String) {
        definitions.removeValue(forKey: id)
    }

    /// Очистить реестр
    func clear() {
        definitions.removeAll()
        heroPools.removeAll()
        signatureCards.removeAll()
    }

    /// Перезагрузить реестр
    func reload() {
        clear()
        // Load cards from data sources (ContentPacks)
        for source in dataSources {
            registerAll(source.loadCards())
        }
    }

    // MARK: - Data Sources

    /// Добавить источник данных
    func addDataSource(_ source: CardDataSource) {
        dataSources.append(source)
        registerAll(source.loadCards())
    }

    /// Удалить источник данных
    func removeDataSource(_ source: CardDataSource) {
        if let index = dataSources.firstIndex(where: { $0.id == source.id }) {
            let source = dataSources.remove(at: index)
            for card in source.loadCards() {
                unregister(id: card.id)
            }
        }
    }

    // MARK: - Queries

    /// Получить карту по ID
    func card(id: String) -> CardDefinition? {
        return definitions[id]
    }

    /// Все карты
    var allCards: [CardDefinition] {
        return Array(definitions.values)
    }

    /// Карты доступные для героя
    func availableCards(
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

    /// Универсальные карты (доступны всем)
    var universalCards: [CardDefinition] {
        return allCards.filter { card in
            if case .universal = card.ownership { return true }
            return false
        }
    }

    /// Сигнатурные карты героя
    func signatureCards(forHeroID heroID: String) -> HeroSignatureCards? {
        return signatureCards[heroID]
    }

    /// Пул карт героя
    func heroPool(for heroID: String) -> HeroCardPool? {
        return heroPools[heroID]
    }

    /// Стартовая колода для героя
    func startingDeck(forHeroID heroID: String) -> [Card] {
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

    /// Карты для магазина (с учётом доступности)
    func shopCards(
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
            // Исключаем сигнатурные карты из магазина
            if case .heroSignature = card.ownership { return false }
            // Исключаем легендарные (добываются только из данжей)
            if card.rarity == .legendary { return false }
            return card.rarity.order <= maxRarity.order
        }
    }

    /// Количество карт в реестре
    var count: Int {
        return definitions.count
    }

    // MARK: - Content Pack Integration
    // All cards are now loaded from ContentPacks via PackLoader.
    // No hardcoded cards in CardRegistry.
    // See: ContentPacks/TwilightMarches/Cards/cards.json
}

// MARK: - Card Data Source Protocol

/// Протокол источника данных карт
protocol CardDataSource {
    var id: String { get }
    var name: String { get }
    func loadCards() -> [CardDefinition]
}

// MARK: - JSON Data Source

/// Загрузчик карт из JSON
struct JSONCardDataSource: CardDataSource {
    let id: String
    let name: String
    let fileURL: URL

    func loadCards() -> [CardDefinition] {
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
struct JSONCardDefinition: Codable {
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
            name: name,
            cardType: cardType,
            rarity: rarity,
            description: description,
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
