import Foundation

/// Протокол определения карты (Data Layer)
/// Описывает статические данные карты, которые не меняются во время игры
protocol CardDefinition {
    /// Уникальный идентификатор карты
    var id: String { get }

    /// Локализованное название
    var name: String { get }

    /// Тип карты
    var cardType: CardType { get }

    /// Редкость
    var rarity: CardRarity { get }

    /// Описание для UI
    var description: String { get }

    /// Иконка карты (SF Symbol или emoji)
    var icon: String { get }

    /// Набор/дополнение
    var expansionSet: ExpansionSet { get }

    /// Принадлежность карты (кому доступна)
    var ownership: CardOwnership { get }

    /// Эффекты карты
    var abilities: [CardAbility] { get }

    /// Стоимость веры для покупки
    var faithCost: Int { get }

    /// Баланс Свет/Тьма
    var balance: CardBalance? { get }

    /// Роль карты в кампании
    var role: CardRole? { get }
}

/// Принадлежность карты - определяет кто может использовать карту
/// Аналог системы сигнатурных карт из Arkham Horror LCG
enum CardOwnership: Codable, Equatable {
    /// Базовая карта - доступна всем
    case universal

    /// Карта класса - доступна только герою определённого класса
    case classSpecific(heroClass: HeroClass)

    /// Сигнатурная карта героя - привязана к конкретному герою
    /// Как в Arkham Horror LCG, где у каждого следователя есть свои уникальные карты
    case heroSignature(heroID: String)

    /// Карта набора/дополнения - требует владения DLC
    case expansion(setID: String)

    /// Карта с требованием разблокировки
    case requiresUnlock(condition: String)

    /// Карта с несколькими условиями (все должны выполняться)
    case composite([CardOwnership])
}

/// Стандартная реализация определения карты
struct StandardCardDefinition: CardDefinition {
    let id: String
    let name: String
    let cardType: CardType
    let rarity: CardRarity
    let description: String
    let icon: String
    let expansionSet: ExpansionSet
    let ownership: CardOwnership
    let abilities: [CardAbility]
    let faithCost: Int
    let balance: CardBalance?
    let role: CardRole?

    // Дополнительные параметры
    let power: Int?
    let defense: Int?
    let health: Int?
    let realm: Realm?
    let curseType: CurseType?

    init(
        id: String,
        name: String,
        cardType: CardType,
        rarity: CardRarity = .common,
        description: String,
        icon: String = "🃏",
        expansionSet: ExpansionSet = .baseSet,
        ownership: CardOwnership = .universal,
        abilities: [CardAbility] = [],
        faithCost: Int = 3,
        balance: CardBalance? = nil,
        role: CardRole? = nil,
        power: Int? = nil,
        defense: Int? = nil,
        health: Int? = nil,
        realm: Realm? = nil,
        curseType: CurseType? = nil
    ) {
        self.id = id
        self.name = name
        self.cardType = cardType
        self.rarity = rarity
        self.description = description
        self.icon = icon
        self.expansionSet = expansionSet
        self.ownership = ownership
        self.abilities = abilities
        self.faithCost = faithCost
        self.balance = balance
        self.role = role
        self.power = power
        self.defense = defense
        self.health = health
        self.realm = realm
        self.curseType = curseType
    }

    /// Конвертация в игровую Card
    func toCard() -> Card {
        return Card(
            id: UUID(),
            name: name,
            type: cardType,
            rarity: rarity,
            description: description,
            power: power,
            defense: defense,
            health: health,
            abilities: abilities,
            balance: balance,
            realm: realm,
            curseType: curseType,
            expansionSet: expansionSet.rawValue,
            role: role,
            faithCost: faithCost
        )
    }
}

// MARK: - Card Ownership Extensions

extension CardOwnership {
    /// Проверить, доступна ли карта для героя
    func isAvailable(
        forHeroID heroID: String?,
        heroClass: HeroClass?,
        ownedExpansions: Set<String> = [],
        unlockedConditions: Set<String> = []
    ) -> Bool {
        switch self {
        case .universal:
            return true

        case .classSpecific(let requiredClass):
            return heroClass == requiredClass

        case .heroSignature(let requiredHeroID):
            return heroID == requiredHeroID

        case .expansion(let setID):
            return ownedExpansions.contains(setID)

        case .requiresUnlock(let condition):
            return unlockedConditions.contains(condition)

        case .composite(let requirements):
            return requirements.allSatisfy { requirement in
                requirement.isAvailable(
                    forHeroID: heroID,
                    heroClass: heroClass,
                    ownedExpansions: ownedExpansions,
                    unlockedConditions: unlockedConditions
                )
            }
        }
    }

    /// Описание условий доступа для UI
    var accessDescription: String {
        switch self {
        case .universal:
            return "Доступна всем"

        case .classSpecific(let heroClass):
            return "Только для класса: \(heroClass.rawValue)"

        case .heroSignature(let heroID):
            return "Сигнатурная карта героя: \(heroID)"

        case .expansion(let setID):
            return "Требуется дополнение: \(setID)"

        case .requiresUnlock(let condition):
            return "Требуется: \(condition)"

        case .composite(let requirements):
            let descriptions = requirements.map { $0.accessDescription }
            return descriptions.joined(separator: " + ")
        }
    }
}

// MARK: - Signature Card Set

/// Набор сигнатурных карт героя
/// Каждый герой может иметь уникальные карты, которые начинают в его колоде
/// или могут быть добавлены только этому герою
struct HeroSignatureCards {
    /// ID героя
    let heroID: String

    /// Обязательные сигнатурные карты (начинают в колоде)
    let requiredCards: [CardDefinition]

    /// Опциональные сигнатурные карты (можно добавить во время кампании)
    let optionalCards: [CardDefinition]

    /// Слабость героя (негативная сигнатурная карта)
    /// Как в Arkham Horror LCG, где у каждого следователя есть своя слабость
    let weakness: CardDefinition?

    /// Все карты ID
    var allCardIDs: [String] {
        var ids = requiredCards.map { $0.id }
        ids.append(contentsOf: optionalCards.map { $0.id })
        if let weakness = weakness {
            ids.append(weakness.id)
        }
        return ids
    }
}

// MARK: - Class Card Pool

/// Пул карт класса героя
/// Карты, доступные всем героям определённого класса
struct ClassCardPool {
    /// Класс героя
    let heroClass: HeroClass

    /// Стартовые карты класса (добавляются в начальную колоду)
    let startingCards: [CardDefinition]

    /// Карты для покупки (доступны в магазине только этому классу)
    let purchasableCards: [CardDefinition]

    /// Карты улучшения (замена базовых карт на улучшенные)
    let upgradeCards: [CardDefinition]

    /// Все карты ID
    var allCardIDs: [String] {
        var ids = startingCards.map { $0.id }
        ids.append(contentsOf: purchasableCards.map { $0.id })
        ids.append(contentsOf: upgradeCards.map { $0.id })
        return ids
    }
}
