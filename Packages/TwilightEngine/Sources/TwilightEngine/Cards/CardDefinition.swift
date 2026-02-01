import Foundation

/// Протокол определения карты (Data Layer)
/// Описывает статические данные карты, которые не меняются во время игры
public protocol CardDefinition {
    /// Уникальный идентификатор карты
    var id: String { get }

    /// Локализованное название (supports inline LocalizedString or StringKey)
    var name: LocalizableText { get }

    /// Тип карты
    var cardType: CardType { get }

    /// Редкость
    var rarity: CardRarity { get }

    /// Описание для UI (supports inline LocalizedString or StringKey)
    var description: LocalizableText { get }

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

    /// Если true, карта удаляется из колоды после розыгрыша
    var exhaust: Bool { get }

    /// Стоимость энергии за ход (nil = используется default 1)
    var cost: Int? { get }
}

/// Принадлежность карты - определяет кто может использовать карту
/// Аналог системы сигнатурных карт из Arkham Horror LCG
public enum CardOwnership: Equatable {
    /// Базовая карта - доступна всем
    case universal

    /// Сигнатурная карта героя - привязана к конкретному герою по ID
    /// Как в Arkham Horror LCG, где у каждого следователя есть свои уникальные карты
    case heroSignature(heroID: String)

    /// Карта класса - доступна героям определённого класса
    case classSpecific(className: String)

    /// Карта набора/дополнения - требует владения DLC
    case expansion(setID: String)

    /// Карта с требованием разблокировки
    case requiresUnlock(condition: String)

    /// Карта с несколькими условиями (все должны выполняться)
    case composite([CardOwnership])
}

// MARK: - CardOwnership Codable

extension CardOwnership: Codable {
    private enum CodingKeys: String, CodingKey {
        case universal
        case heroSignature = "hero_signature"
        case classSpecific = "class_specific"
        case expansion
        case requiresUnlock = "requires_unlock"
        case composite
    }

    public init(from decoder: Decoder) throws {
        // Try string first (for "universal")
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            if stringValue == "universal" {
                self = .universal
                return
            }
        }

        // Try keyed container for complex types
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let heroID = try container.decodeIfPresent(String.self, forKey: .heroSignature) {
            self = .heroSignature(heroID: heroID)
        } else if let className = try container.decodeIfPresent(String.self, forKey: .classSpecific) {
            self = .classSpecific(className: className)
        } else if let setID = try container.decodeIfPresent(String.self, forKey: .expansion) {
            self = .expansion(setID: setID)
        } else if let condition = try container.decodeIfPresent(String.self, forKey: .requiresUnlock) {
            self = .requiresUnlock(condition: condition)
        } else if let items = try container.decodeIfPresent([CardOwnership].self, forKey: .composite) {
            self = .composite(items)
        } else {
            self = .universal
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .universal:
            var container = encoder.singleValueContainer()
            try container.encode("universal")

        case .heroSignature(let heroID):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(heroID, forKey: .heroSignature)

        case .classSpecific(let className):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(className, forKey: .classSpecific)

        case .expansion(let setID):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(setID, forKey: .expansion)

        case .requiresUnlock(let condition):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(condition, forKey: .requiresUnlock)

        case .composite(let items):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(items, forKey: .composite)
        }
    }
}

/// Стандартная реализация определения карты
public struct StandardCardDefinition: CardDefinition, Codable {
    public var id: String
    public var name: LocalizableText
    public var cardType: CardType
    public var rarity: CardRarity
    public var description: LocalizableText
    public var icon: String
    public var expansionSet: ExpansionSet
    public var ownership: CardOwnership
    public var abilities: [CardAbility]
    public var faithCost: Int
    public var balance: CardBalance?
    public var role: CardRole?

    // Дополнительные параметры
    public var power: Int?
    public var defense: Int?
    public var health: Int?
    public var wisdom: Int?
    public var realm: Realm?
    public var curseType: CurseType?
    public var exhaust: Bool
    public var cost: Int?

    public init(
        id: String,
        name: LocalizableText,
        cardType: CardType,
        rarity: CardRarity = .common,
        description: LocalizableText,
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
        wisdom: Int? = nil,
        realm: Realm? = nil,
        curseType: CurseType? = nil,
        exhaust: Bool = false,
        cost: Int? = nil
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
        self.wisdom = wisdom
        self.realm = realm
        self.curseType = curseType
        self.exhaust = exhaust
        self.cost = cost
    }

    // MARK: - Custom Codable (backward compatibility)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(LocalizableText.self, forKey: .name)
        cardType = try container.decode(CardType.self, forKey: .cardType)
        rarity = try container.decodeIfPresent(CardRarity.self, forKey: .rarity) ?? .common
        description = try container.decode(LocalizableText.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "🃏"
        expansionSet = try container.decodeIfPresent(ExpansionSet.self, forKey: .expansionSet) ?? .baseSet
        ownership = try container.decodeIfPresent(CardOwnership.self, forKey: .ownership) ?? .universal
        abilities = try container.decodeIfPresent([CardAbility].self, forKey: .abilities) ?? []
        faithCost = try container.decodeIfPresent(Int.self, forKey: .faithCost) ?? 3
        balance = try container.decodeIfPresent(CardBalance.self, forKey: .balance)
        role = try container.decodeIfPresent(CardRole.self, forKey: .role)
        power = try container.decodeIfPresent(Int.self, forKey: .power)
        defense = try container.decodeIfPresent(Int.self, forKey: .defense)
        health = try container.decodeIfPresent(Int.self, forKey: .health)
        wisdom = try container.decodeIfPresent(Int.self, forKey: .wisdom)
        realm = try container.decodeIfPresent(Realm.self, forKey: .realm)
        curseType = try container.decodeIfPresent(CurseType.self, forKey: .curseType)
        exhaust = try container.decodeIfPresent(Bool.self, forKey: .exhaust) ?? false
        cost = try container.decodeIfPresent(Int.self, forKey: .cost)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, cardType, rarity, description, icon, expansionSet, ownership
        case abilities, faithCost, balance, role, power, defense, health, wisdom
        case realm, curseType, exhaust, cost
    }

    /// Конвертация в игровую Card
    public func toCard() -> Card {
        return Card(
            id: id,
            name: name.resolved,
            type: cardType,
            rarity: rarity,
            description: description.resolved,
            power: power,
            defense: defense,
            health: health,
            wisdom: wisdom,
            cost: cost,
            abilities: abilities,
            balance: balance,
            realm: realm,
            curseType: curseType,
            expansionSet: expansionSet.rawValue,
            role: role,
            exhaust: exhaust,
            faithCost: faithCost
        )
    }
}

// MARK: - Card Ownership Extensions

extension CardOwnership {
    /// Проверить, доступна ли карта для героя
    func isAvailable(
        forHeroID heroID: String?,
        heroClass: String? = nil,
        ownedExpansions: Set<String> = [],
        unlockedConditions: Set<String> = []
    ) -> Bool {
        switch self {
        case .universal:
            return true

        case .heroSignature(let requiredHeroID):
            return heroID == requiredHeroID

        case .classSpecific(let className):
            return heroClass == className

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

        case .heroSignature(let heroID):
            return "Сигнатурная карта героя: \(heroID)"

        case .classSpecific(let className):
            return "Карта класса: \(className)"

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
public struct HeroSignatureCards {
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

// MARK: - Hero Card Pool

/// Пул карт героя
/// Карты, доступные конкретному герою
public struct HeroCardPool {
    /// ID героя
    let heroID: String

    /// Стартовые карты (добавляются в начальную колоду)
    let startingCards: [CardDefinition]

    /// Карты для покупки (доступны в магазине только этому герою)
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
