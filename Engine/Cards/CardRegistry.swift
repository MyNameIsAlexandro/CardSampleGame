import Foundation

/// Реестр карт - централизованное хранилище всех определений карт
/// Поддерживает:
/// - Универсальные карты (доступны всем)
/// - Класс-специфичные карты (только для определённого класса героя)
/// - Сигнатурные карты героя (уникальные карты конкретного персонажа)
/// - DLC/Expansion карты
final class CardRegistry {

    // MARK: - Singleton

    static let shared = CardRegistry()

    // MARK: - Storage

    /// Все зарегистрированные карты
    private var definitions: [String: CardDefinition] = [:]

    /// Пулы карт классов
    private var classPools: [HeroClass: ClassCardPool] = [:]

    /// Сигнатурные карты героев
    private var signatureCards: [String: HeroSignatureCards] = [:]

    /// Источники данных карт
    private var dataSources: [CardDataSource] = []

    // MARK: - Init

    private init() {
        registerBuiltInCards()
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

    /// Зарегистрировать пул карт класса
    func registerClassPool(_ pool: ClassCardPool) {
        classPools[pool.heroClass] = pool
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
        classPools.removeAll()
        signatureCards.removeAll()
    }

    /// Перезагрузить реестр
    func reload() {
        clear()
        registerBuiltInCards()
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
        heroClass: HeroClass?,
        ownedExpansions: Set<String> = [],
        unlockedConditions: Set<String> = []
    ) -> [CardDefinition] {
        return allCards.filter { card in
            card.ownership.isAvailable(
                forHeroID: heroID,
                heroClass: heroClass,
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

    /// Карты определённого класса
    func cards(forClass heroClass: HeroClass) -> [CardDefinition] {
        return allCards.filter { card in
            if case .classSpecific(let requiredClass) = card.ownership {
                return requiredClass == heroClass
            }
            return false
        }
    }

    /// Сигнатурные карты героя
    func cards(forHeroID heroID: String) -> HeroSignatureCards? {
        return signatureCards[heroID]
    }

    /// Пул карт класса
    func classPool(for heroClass: HeroClass) -> ClassCardPool? {
        return classPools[heroClass]
    }

    /// Стартовая колода для героя
    func startingDeck(forHeroID heroID: String, heroClass: HeroClass) -> [Card] {
        var deck: [Card] = []

        // 1. Базовые универсальные карты
        let basicCards = universalCards.filter { $0.rarity == .common }
        for cardDef in basicCards.prefix(5) {
            if let def = cardDef as? StandardCardDefinition {
                deck.append(def.toCard())
            }
        }

        // 2. Карты класса
        if let pool = classPools[heroClass] {
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
        heroClass: HeroClass?,
        ownedExpansions: Set<String> = [],
        unlockedConditions: Set<String> = [],
        maxRarity: CardRarity = .epic
    ) -> [CardDefinition] {
        return availableCards(
            forHeroID: heroID,
            heroClass: heroClass,
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

    // MARK: - Built-in Cards

    private func registerBuiltInCards() {
        // Базовые универсальные карты
        registerBaseCards()

        // Карты классов
        registerWarriorCards()
        registerMageCards()
        registerRangerCards()
        registerPriestCards()
        registerShadowCards()

        // Сигнатурные карты героев
        registerSignatureCardsForBuiltInHeroes()
    }

    private func registerBaseCards() {
        // Базовый удар
        register(StandardCardDefinition(
            id: "strike_basic",
            name: "Удар",
            cardType: .attack,
            rarity: .common,
            description: "Нанести 3 урона",
            icon: "⚔️",
            abilities: [CardAbility(
                name: "Удар",
                description: "Нанести 3 урона",
                effect: .damage(amount: 3, type: .physical)
            )],
            faithCost: 1,
            balance: .neutral
        ))

        // Базовая защита
        register(StandardCardDefinition(
            id: "defend_basic",
            name: "Защита",
            cardType: .defense,
            rarity: .common,
            description: "Получить 3 защиты",
            icon: "🛡️",
            abilities: [],
            faithCost: 1,
            balance: .neutral,
            defense: 3
        ))

        // Восстановление
        register(StandardCardDefinition(
            id: "heal_basic",
            name: "Лечение",
            cardType: .spell,
            rarity: .common,
            description: "Восстановить 2 HP",
            icon: "💚",
            abilities: [CardAbility(
                name: "Исцеление",
                description: "Восстановить 2 HP",
                effect: .heal(amount: 2)
            )],
            faithCost: 2,
            balance: .light,
            role: .sustain
        ))

        // Взять карты
        register(StandardCardDefinition(
            id: "draw_basic",
            name: "Подготовка",
            cardType: .special,
            rarity: .common,
            description: "Взять 2 карты",
            icon: "📜",
            abilities: [CardAbility(
                name: "Подготовка",
                description: "Взять 2 карты",
                effect: .drawCards(count: 2)
            )],
            faithCost: 2,
            balance: .neutral,
            role: .utility
        ))
    }

    private func registerWarriorCards() {
        let classCards: [CardDefinition] = [
            StandardCardDefinition(
                id: "warrior_rage_strike",
                name: "Яростный удар",
                cardType: .attack,
                rarity: .uncommon,
                description: "Нанести 5 урона. +2 если HP < 50%",
                icon: "🔥",
                ownership: .classSpecific(heroClass: .warrior),
                abilities: [CardAbility(
                    name: "Ярость",
                    description: "Нанести 5 урона. +2 если HP < 50%",
                    effect: .damage(amount: 5, type: .physical)
                )],
                faithCost: 3,
                balance: .neutral,
                power: 5
            ),
            StandardCardDefinition(
                id: "warrior_battlecry",
                name: "Боевой клич",
                cardType: .special,
                rarity: .rare,
                description: "+1 кубик атаки на 2 хода",
                icon: "📢",
                ownership: .classSpecific(heroClass: .warrior),
                abilities: [CardAbility(
                    name: "Боевой клич",
                    description: "+1 кубик атаки",
                    effect: .addDice(count: 1)
                )],
                faithCost: 4,
                balance: .neutral,
                role: .power
            )
        ]

        registerClassPool(ClassCardPool(
            heroClass: .warrior,
            startingCards: [classCards[0]],
            purchasableCards: classCards,
            upgradeCards: []
        ))
    }

    private func registerMageCards() {
        let classCards: [CardDefinition] = [
            StandardCardDefinition(
                id: "mage_arcane_bolt",
                name: "Арканный снаряд",
                cardType: .spell,
                rarity: .common,
                description: "Нанести 4 магического урона",
                icon: "✨",
                ownership: .classSpecific(heroClass: .mage),
                abilities: [CardAbility(
                    name: "Арканный снаряд",
                    description: "Нанести 4 магического урона",
                    effect: .damage(amount: 4, type: .arcane)
                )],
                faithCost: 2,
                balance: .neutral,
                power: 4
            ),
            StandardCardDefinition(
                id: "mage_meditation",
                name: "Глубокая медитация",
                cardType: .special,
                rarity: .uncommon,
                description: "Получить 3 веры",
                icon: "🧘",
                ownership: .classSpecific(heroClass: .mage),
                abilities: [CardAbility(
                    name: "Медитация",
                    description: "Получить 3 веры",
                    effect: .gainFaith(amount: 3)
                )],
                faithCost: 2,
                balance: .neutral,
                role: .utility
            )
        ]

        registerClassPool(ClassCardPool(
            heroClass: .mage,
            startingCards: [classCards[0]],
            purchasableCards: classCards,
            upgradeCards: []
        ))
    }

    private func registerRangerCards() {
        let classCards: [CardDefinition] = [
            StandardCardDefinition(
                id: "ranger_precise_shot",
                name: "Точный выстрел",
                cardType: .attack,
                rarity: .common,
                description: "Нанести 3 урона. Можно перебросить 1 кубик",
                icon: "🎯",
                ownership: .classSpecific(heroClass: .ranger),
                abilities: [CardAbility(
                    name: "Точный выстрел",
                    description: "Нанести урон с перебросом",
                    effect: .reroll
                )],
                faithCost: 2,
                balance: .neutral,
                power: 3
            ),
            StandardCardDefinition(
                id: "ranger_trap",
                name: "Ловушка",
                cardType: .special,
                rarity: .uncommon,
                description: "Следующий враг получает -2 к защите",
                icon: "🪤",
                ownership: .classSpecific(heroClass: .ranger),
                abilities: [],
                faithCost: 3,
                balance: .neutral,
                role: .control
            )
        ]

        registerClassPool(ClassCardPool(
            heroClass: .ranger,
            startingCards: [classCards[0]],
            purchasableCards: classCards,
            upgradeCards: []
        ))
    }

    private func registerPriestCards() {
        let classCards: [CardDefinition] = [
            StandardCardDefinition(
                id: "priest_holy_light",
                name: "Святой свет",
                cardType: .spell,
                rarity: .common,
                description: "Восстановить 4 HP или нанести 4 урона нежити",
                icon: "☀️",
                ownership: .classSpecific(heroClass: .priest),
                abilities: [CardAbility(
                    name: "Святой свет",
                    description: "Исцеление или урон нежити",
                    effect: .heal(amount: 4)
                )],
                faithCost: 3,
                balance: .light,
                role: .sustain
            ),
            StandardCardDefinition(
                id: "priest_blessing",
                name: "Благословение",
                cardType: .spell,
                rarity: .uncommon,
                description: "Снять проклятие или +2 к защите",
                icon: "🙏",
                ownership: .classSpecific(heroClass: .priest),
                abilities: [CardAbility(
                    name: "Благословение",
                    description: "Снять проклятие",
                    effect: .removeCurse(type: nil)
                )],
                faithCost: 4,
                balance: .light,
                role: .sustain
            )
        ]

        registerClassPool(ClassCardPool(
            heroClass: .priest,
            startingCards: [classCards[0]],
            purchasableCards: classCards,
            upgradeCards: []
        ))
    }

    private func registerShadowCards() {
        let classCards: [CardDefinition] = [
            StandardCardDefinition(
                id: "shadow_backstab",
                name: "Удар в спину",
                cardType: .attack,
                rarity: .common,
                description: "Нанести 2 урона. +4 если цель на полном HP",
                icon: "🗡️",
                ownership: .classSpecific(heroClass: .shadow),
                abilities: [CardAbility(
                    name: "Засада",
                    description: "Урон с бонусом по полному HP",
                    effect: .damage(amount: 2, type: .physical)
                )],
                faithCost: 2,
                balance: .dark,
                power: 2
            ),
            StandardCardDefinition(
                id: "shadow_poison_blade",
                name: "Отравленный клинок",
                cardType: .attack,
                rarity: .uncommon,
                description: "Нанести 3 урона. Наложить Слабость",
                icon: "🐍",
                ownership: .classSpecific(heroClass: .shadow),
                abilities: [CardAbility(
                    name: "Яд",
                    description: "Наложить Слабость",
                    effect: .applyCurse(type: .weakness, duration: 2)
                )],
                faithCost: 4,
                balance: .dark,
                power: 3,
                role: .control
            )
        ]

        registerClassPool(ClassCardPool(
            heroClass: .shadow,
            startingCards: [classCards[0]],
            purchasableCards: classCards,
            upgradeCards: []
        ))
    }

    private func registerSignatureCardsForBuiltInHeroes() {
        // Рагнар - Воин
        registerSignatureCards(HeroSignatureCards(
            heroID: "warrior_ragnar",
            requiredCards: [
                StandardCardDefinition(
                    id: "ragnar_ancestral_axe",
                    name: "Топор предков",
                    cardType: .weapon,
                    rarity: .rare,
                    description: "Легендарное оружие Рагнара. +2 к урону, +1 кубик",
                    icon: "🪓",
                    ownership: .heroSignature(heroID: "warrior_ragnar"),
                    abilities: [CardAbility(
                        name: "Наследие",
                        description: "+1 кубик атаки",
                        effect: .addDice(count: 1)
                    )],
                    faithCost: 0,
                    balance: .neutral,
                    power: 2
                )
            ],
            optionalCards: [],
            weakness: StandardCardDefinition(
                id: "ragnar_blood_rage",
                name: "Кровавая ярость",
                cardType: .curse,
                rarity: .rare,
                description: "Слабость Рагнара. При HP < 25% атакует ближайшую цель",
                icon: "💢",
                ownership: .heroSignature(heroID: "warrior_ragnar"),
                abilities: [],
                faithCost: 0,
                balance: .dark,
                curseType: .bloodCurse
            )
        ))

        // Умбра - Тень
        registerSignatureCards(HeroSignatureCards(
            heroID: "shadow_umbra",
            requiredCards: [
                StandardCardDefinition(
                    id: "umbra_shadow_cloak",
                    name: "Плащ теней",
                    cardType: .armor,
                    rarity: .rare,
                    description: "Артефакт Умбры. Невидимость на 1 ход после убийства",
                    icon: "🌑",
                    ownership: .heroSignature(heroID: "shadow_umbra"),
                    abilities: [],
                    faithCost: 0,
                    balance: .dark,
                    defense: 1
                )
            ],
            optionalCards: [],
            weakness: StandardCardDefinition(
                id: "umbra_dark_pact",
                name: "Тёмный договор",
                cardType: .curse,
                rarity: .rare,
                description: "Слабость Умбры. Каждые 3 убийства: баланс -10 к Тьме",
                icon: "📜",
                ownership: .heroSignature(heroID: "shadow_umbra"),
                abilities: [CardAbility(
                    name: "Договор",
                    description: "Сдвиг к Тьме",
                    effect: .shiftBalance(towards: .dark, amount: 10)
                )],
                faithCost: 0,
                balance: .dark
            )
        ))
    }
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
            print("CardRegistry: Failed to load JSON from \(fileURL)")
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([JSONCardDefinition].self, from: data)
            return decoded.map { $0.toStandard() }
        } catch {
            print("CardRegistry: Failed to decode cards: \(error)")
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
    let ownershipType: String?  // "universal", "class:warrior", "hero:warrior_ragnar"

    func toStandard() -> StandardCardDefinition {
        let ownership: CardOwnership
        if let ownershipType = ownershipType {
            if ownershipType == "universal" {
                ownership = .universal
            } else if ownershipType.hasPrefix("class:") {
                let className = String(ownershipType.dropFirst(6))
                if let heroClass = HeroClass(rawValue: className) {
                    ownership = .classSpecific(heroClass: heroClass)
                } else {
                    ownership = .universal
                }
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
