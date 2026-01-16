import Foundation

// MARK: - Region State

enum RegionState: String, Codable, Hashable {
    case stable         // Стабильная Явь - безопасно
    case borderland     // Пограничье - повышенный риск
    case breach         // Прорыв Нави - опасно

    var displayName: String {
        switch self {
        case .stable: return "Стабильная"
        case .borderland: return "Пограничье"
        case .breach: return "Прорыв Нави"
        }
    }

    var emoji: String {
        switch self {
        case .stable: return "🟢"
        case .borderland: return "🟡"
        case .breach: return "🔴"
        }
    }
}

// MARK: - Region Type

enum RegionType: String, Codable, Hashable {
    case forest         // Лес
    case swamp          // Болото
    case mountain       // Горы
    case settlement     // Поселение
    case water          // Водная зона
    case wasteland      // Пустошь
    case sacred         // Священное место

    var displayName: String {
        switch self {
        case .forest: return "Лес"
        case .swamp: return "Болото"
        case .mountain: return "Горы"
        case .settlement: return "Поселение"
        case .water: return "Водная зона"
        case .wasteland: return "Пустошь"
        case .sacred: return "Священное место"
        }
    }

    var icon: String {
        switch self {
        case .forest: return "tree.fill"
        case .swamp: return "cloud.fog.fill"
        case .mountain: return "mountain.2.fill"
        case .settlement: return "house.fill"
        case .water: return "drop.fill"
        case .wasteland: return "wind"
        case .sacred: return "star.fill"
        }
    }
}

// MARK: - Anchor Type

enum AnchorType: String, Codable {
    case shrine         // Капище
    case barrow         // Курган
    case sacredTree     // Священный дуб
    case stoneIdol      // Каменная баба
    case spring         // Родник
    case chapel         // Часовня
    case temple         // Храм
    case cross          // Обетный крест

    var displayName: String {
        switch self {
        case .shrine: return "Капище"
        case .barrow: return "Курган"
        case .sacredTree: return "Священный Дуб"
        case .stoneIdol: return "Каменная Баба"
        case .spring: return "Родник"
        case .chapel: return "Часовня"
        case .temple: return "Храм"
        case .cross: return "Обетный Крест"
        }
    }

    var icon: String {
        switch self {
        case .shrine: return "flame.fill"
        case .barrow: return "mountain.2"
        case .sacredTree: return "leaf.fill"
        case .stoneIdol: return "figure.stand"
        case .spring: return "drop.circle.fill"
        case .chapel: return "building.columns.fill"
        case .temple: return "building.2.fill"
        case .cross: return "cross.fill"
        }
    }
}

// MARK: - Anchor

struct Anchor: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: AnchorType
    var integrity: Int          // 0-100%
    var influence: CardBalance  // .light, .neutral, .dark
    let power: Int              // Сила влияния (1-10)

    init(
        id: UUID = UUID(),
        name: String,
        type: AnchorType,
        integrity: Int = 100,
        influence: CardBalance = .light,
        power: Int = 5
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.integrity = max(0, min(100, integrity))
        self.influence = influence
        self.power = power
    }

    // Определяет состояние региона на основе целостности якоря
    var determinedRegionState: RegionState {
        switch integrity {
        case 70...100:
            return .stable
        case 30..<70:
            return .borderland
        default:
            return .breach
        }
    }

    // Проверка, осквернен ли якорь
    var isDefiled: Bool {
        return influence == .dark
    }
}

// MARK: - Region

struct Region: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: RegionType
    var state: RegionState
    var anchor: Anchor?
    var availableEvents: [String]   // ID событий
    var activeQuests: [String]      // ID активных квестов
    var reputation: Int             // -100 to 100
    var visited: Bool               // Был ли игрок здесь

    init(
        id: UUID = UUID(),
        name: String,
        type: RegionType,
        state: RegionState = .stable,
        anchor: Anchor? = nil,
        availableEvents: [String] = [],
        activeQuests: [String] = [],
        reputation: Int = 0,
        visited: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.state = state
        self.anchor = anchor
        self.availableEvents = availableEvents
        self.activeQuests = activeQuests
        self.reputation = max(-100, min(100, reputation))
        self.visited = visited
    }

    // Обновить состояние региона на основе якоря
    mutating func updateStateFromAnchor() {
        if let anchor = anchor {
            self.state = anchor.determinedRegionState
        } else {
            // Без якоря регион всегда в Breach
            self.state = .breach
        }
    }

    // Можно ли торговать в регионе
    var canTrade: Bool {
        return state == .stable && type == .settlement && reputation >= 0
    }

    // Можно ли отдохнуть в регионе
    var canRest: Bool {
        return state == .stable && (type == .settlement || type == .sacred)
    }
}

// MARK: - Event Type

enum EventType: String, Codable, Hashable {
    case combat         // Бой
    case ritual         // Ритуал/Выбор
    case narrative      // Нарративное событие
    case exploration    // Исследование
    case worldShift     // Сдвиг мира

    var displayName: String {
        switch self {
        case .combat: return "Бой"
        case .ritual: return "Ритуал"
        case .narrative: return "Встреча"
        case .exploration: return "Исследование"
        case .worldShift: return "Сдвиг Мира"
        }
    }

    var icon: String {
        switch self {
        case .combat: return "sword.fill"
        case .ritual: return "sparkles"
        case .narrative: return "text.bubble.fill"
        case .exploration: return "magnifyingglass"
        case .worldShift: return "globe"
        }
    }
}

// MARK: - Event Choice

struct EventChoice: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let requirements: EventRequirements?
    let consequences: EventConsequences

    init(
        id: String = UUID().uuidString,
        text: String,
        requirements: EventRequirements? = nil,
        consequences: EventConsequences
    ) {
        self.id = id
        self.text = text
        self.requirements = requirements
        self.consequences = consequences
    }
}

// MARK: - Event Requirements

struct EventRequirements: Codable, Hashable {
    var minimumFaith: Int?
    var minimumHealth: Int?
    var requiredBalance: CardBalance?    // Требуется определенный баланс
    var requiredFlags: [String]?         // Требуются флаги мира

    func canMeet(with player: Player, worldState: WorldState) -> Bool {
        if let minFaith = minimumFaith, player.faith < minFaith {
            return false
        }
        if let minHealth = minimumHealth, player.health < minHealth {
            return false
        }
        if let reqBalance = requiredBalance {
            // Проверка баланса игрока (0-100 scale)
            let playerBalanceEnum: CardBalance
            if player.balance >= 70 {
                playerBalanceEnum = .light
            } else if player.balance <= 30 {
                playerBalanceEnum = .dark
            } else {
                playerBalanceEnum = .neutral
            }

            if playerBalanceEnum != reqBalance {
                return false
            }
        }
        if let reqFlags = requiredFlags {
            for flag in reqFlags {
                if worldState.worldFlags[flag] != true {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - Event Consequences

struct EventConsequences: Codable, Hashable {
    var faithChange: Int?
    var healthChange: Int?
    var balanceChange: Int?         // Изменение Light/Dark (-100 to +100)
    var tensionChange: Int?
    var reputationChange: Int?
    var addCards: [String]?         // ID карт для добавления
    var addCurse: String?           // ID проклятия
    var giveArtifact: String?       // ID артефакта
    var setFlags: [String: Bool]?   // Установить флаги
    var anchorIntegrityChange: Int? // Изменение целостности якоря
    var message: String?            // Сообщение игроку
}

// MARK: - Game Event

struct GameEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let eventType: EventType
    let title: String
    let description: String
    let regionTypes: [RegionType]       // В каких типах регионов может произойти
    let regionStates: [RegionState]     // В каких состояниях может произойти
    let choices: [EventChoice]
    let questLinks: [String]            // Связь с квестами
    var oneTime: Bool                   // Происходит только один раз
    var completed: Bool                 // Уже произошло
    let monsterCard: Card?              // Карта монстра для боевых событий

    init(
        id: UUID = UUID(),
        eventType: EventType,
        title: String,
        description: String,
        regionTypes: [RegionType] = [],
        regionStates: [RegionState] = [.stable, .borderland, .breach],
        choices: [EventChoice],
        questLinks: [String] = [],
        oneTime: Bool = false,
        completed: Bool = false,
        monsterCard: Card? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.title = title
        self.description = description
        self.regionTypes = regionTypes
        self.regionStates = regionStates
        self.choices = choices
        self.questLinks = questLinks
        self.oneTime = oneTime
        self.completed = completed
        self.monsterCard = monsterCard
    }

    // Проверка, может ли событие произойти в регионе
    func canOccur(in region: Region) -> Bool {
        if completed && oneTime {
            return false
        }

        if !regionTypes.isEmpty && !regionTypes.contains(region.type) {
            return false
        }

        if !regionStates.contains(region.state) {
            return false
        }

        return true
    }
}

// MARK: - Quest Type

enum QuestType: String, Codable {
    case main       // Основной квест
    case side       // Побочный квест
}

// MARK: - Quest Objective

struct QuestObjective: Identifiable, Codable {
    let id: UUID
    let description: String
    var completed: Bool
    var requiredFlags: [String]?  // Флаги, необходимые для выполнения цели

    init(id: UUID = UUID(), description: String, completed: Bool = false, requiredFlags: [String]? = nil) {
        self.id = id
        self.description = description
        self.completed = completed
        self.requiredFlags = requiredFlags
    }
}

// MARK: - Quest Rewards

struct QuestRewards: Codable {
    var faith: Int?
    var cards: [String]?
    var artifact: String?
    var experience: Int?
}

// MARK: - Quest

struct Quest: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let questType: QuestType
    var stage: Int                      // Текущая стадия квеста (0 = не начат)
    var objectives: [QuestObjective]
    let rewards: QuestRewards
    var completed: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        questType: QuestType,
        stage: Int = 0,
        objectives: [QuestObjective],
        rewards: QuestRewards,
        completed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.questType = questType
        self.stage = stage
        self.objectives = objectives
        self.rewards = rewards
        self.completed = completed
    }

    // Проверка, все ли цели выполнены
    var allObjectivesCompleted: Bool {
        return objectives.allSatisfy { $0.completed }
    }
}
