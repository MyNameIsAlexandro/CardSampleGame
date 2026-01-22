import Foundation

// MARK: - Region State

enum RegionState: String, Codable, Hashable {
    case stable         // Стабильная Явь - безопасно
    case borderland     // Пограничье - повышенный риск
    case breach         // Прорыв Нави - опасно

    /// Initialize from Engine's RegionStateType
    /// Used by data-driven content loading
    init(from engineState: RegionStateType) {
        switch engineState {
        case .stable: self = .stable
        case .borderland: self = .borderland
        case .breach: self = .breach
        }
    }

    var displayName: String {
        switch self {
        case .stable: return L10n.regionStateStable.localized
        case .borderland: return L10n.regionStateBorderland.localized
        case .breach: return L10n.regionStateBreach.localized
        }
    }

    var emoji: String {
        switch self {
        case .stable: return "🟢"
        case .borderland: return "🟡"
        case .breach: return "🔴"
        }
    }

    // MARK: - Combat Modifiers

    /// Бонус к силе врага в этом регионе
    var enemyPowerBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Бонус к здоровью врага в этом регионе
    var enemyHealthBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 2
        case .breach: return 5
        }
    }

    /// Бонус к защите врага в этом регионе
    var enemyDefenseBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }
}

// MARK: - Combat Context

/// Контекст боя с учётом региона и проклятий
struct CombatContext {
    let regionState: RegionState
    let playerCurses: [CurseType]

    /// Рассчитать эффективную силу врага
    func adjustedEnemyPower(_ basePower: Int) -> Int {
        return basePower + regionState.enemyPowerBonus
    }

    /// Рассчитать эффективное здоровье врага
    func adjustedEnemyHealth(_ baseHealth: Int) -> Int {
        return baseHealth + regionState.enemyHealthBonus
    }

    /// Рассчитать эффективную защиту врага
    func adjustedEnemyDefense(_ baseDefense: Int) -> Int {
        return baseDefense + regionState.enemyDefenseBonus
    }

    /// Описание модификаторов региона для UI
    var regionModifierDescription: String? {
        switch regionState {
        case .stable:
            return nil
        case .borderland:
            return L10n.combatModifierBorderland.localized
        case .breach:
            return L10n.combatModifierBreach.localized
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
        case .forest: return L10n.regionTypeForest.localized
        case .swamp: return L10n.regionTypeSwamp.localized
        case .mountain: return L10n.regionTypeMountain.localized
        case .settlement: return L10n.regionTypeSettlement.localized
        case .water: return L10n.regionTypeWater.localized
        case .wasteland: return L10n.regionTypeWasteland.localized
        case .sacred: return L10n.regionTypeSacred.localized
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

    /// Initialize from JSON string (snake_case format)
    /// Used by data-driven content loading
    init?(fromJSON string: String) {
        switch string {
        case "shrine": self = .shrine
        case "barrow": self = .barrow
        case "sacred_tree": self = .sacredTree
        case "stone_idol": self = .stoneIdol
        case "spring": self = .spring
        case "chapel": self = .chapel
        case "temple": self = .temple
        case "cross": self = .cross
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .shrine: return L10n.anchorTypeShrine.localized
        case .barrow: return L10n.anchorTypeBarrow.localized
        case .sacredTree: return L10n.anchorTypeSacredTree.localized
        case .stoneIdol: return L10n.anchorTypeStoneIdol.localized
        case .spring: return L10n.anchorTypeSpring.localized
        case .chapel: return L10n.anchorTypeChapel.localized
        case .temple: return L10n.anchorTypeTemple.localized
        case .cross: return L10n.anchorTypeCross.localized
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

/// Legacy Region model used for world state persistence and direct UI binding.
///
/// ⚠️ МИГРАЦИЯ (Audit v1.1 Issue #9):
/// - Для нового кода предпочтительнее использовать Engine модели:
///   - `RegionDefinition` - статические данные региона (из ContentProvider)
///   - `RegionRuntimeState` - изменяемое состояние (Engine/Runtime/WorldRuntimeState.swift)
///   - `EngineRegionState` - объединённое состояние для UI (TwilightGameEngine.swift)
/// - Эта модель сохраняется для: сериализации сейвов, legacy UI, unit-тестов
/// - После полной миграции UI на Engine эта модель станет internal для persistence
struct Region: Identifiable, Codable {
    let id: UUID
    let definitionId: String        // Content Pack ID (e.g., "village", "sacred_oak")
    let name: String
    let type: RegionType
    var state: RegionState
    var anchor: Anchor?
    var availableEvents: [String]   // ID событий
    var activeQuests: [String]      // ID активных квестов
    var reputation: Int             // -100 to 100
    var visited: Bool               // Был ли игрок здесь
    var neighborIds: [UUID]         // ID соседних регионов (путешествие = 1 день)

    init(
        id: UUID = UUID(),
        definitionId: String = "",
        name: String,
        type: RegionType,
        state: RegionState = .stable,
        anchor: Anchor? = nil,
        availableEvents: [String] = [],
        activeQuests: [String] = [],
        reputation: Int = 0,
        visited: Bool = false,
        neighborIds: [UUID] = []
    ) {
        self.id = id
        self.definitionId = definitionId
        self.name = name
        self.type = type
        self.state = state
        self.anchor = anchor
        self.availableEvents = availableEvents
        self.activeQuests = activeQuests
        self.reputation = max(-100, min(100, reputation))
        self.visited = visited
        self.neighborIds = neighborIds
    }

    /// Проверить, является ли регион соседним
    func isNeighbor(_ regionId: UUID) -> Bool {
        return neighborIds.contains(regionId)
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
        case .combat: return L10n.eventTypeCombat.localized
        case .ritual: return L10n.eventTypeRitual.localized
        case .narrative: return L10n.eventTypeNarrative.localized
        case .exploration: return L10n.eventTypeExploration.localized
        case .worldShift: return L10n.eventTypeWorldShift.localized
        }
    }

    var icon: String {
        switch self {
        case .combat: return "bolt.fill"
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
    var balanceChange: Int?         // Изменение Light/Dark (дельта: +N сдвиг к Свету, -N к Тьме)
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
    let definitionId: String            // Content Pack ID (e.g., "village_elder_request")
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

    // Новые поля согласно документации
    let instant: Bool                   // true = не тратит день (короткие нарративные события)
    let weight: Int                     // Вес для взвешенного выбора (по умолчанию 1)
    let minTension: Int?                // Минимальный уровень напряжения (0-100)
    let maxTension: Int?                // Максимальный уровень напряжения (0-100)
    let requiredFlags: [String]?        // Флаги, которые должны быть установлены
    let forbiddenFlags: [String]?       // Флаги, которые НЕ должны быть установлены

    init(
        id: UUID = UUID(),
        definitionId: String = "",
        eventType: EventType,
        title: String,
        description: String,
        regionTypes: [RegionType] = [],
        regionStates: [RegionState] = [.stable, .borderland, .breach],
        choices: [EventChoice],
        questLinks: [String] = [],
        oneTime: Bool = false,
        completed: Bool = false,
        monsterCard: Card? = nil,
        instant: Bool = false,
        weight: Int = 1,
        minTension: Int? = nil,
        maxTension: Int? = nil,
        requiredFlags: [String]? = nil,
        forbiddenFlags: [String]? = nil
    ) {
        self.id = id
        self.definitionId = definitionId
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
        self.instant = instant
        self.weight = max(1, weight)  // Минимум 1
        self.minTension = minTension
        self.maxTension = maxTension
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
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

    /// Проверка с учётом напряжения и флагов мира
    func canOccur(in region: Region, worldTension: Int, worldFlags: [String: Bool]) -> Bool {
        // Базовые проверки
        guard canOccur(in: region) else { return false }

        // Проверка напряжения
        if let min = minTension, worldTension < min {
            return false
        }
        if let max = maxTension, worldTension > max {
            return false
        }

        // Проверка обязательных флагов
        if let required = requiredFlags {
            for flag in required {
                if worldFlags[flag] != true {
                    return false
                }
            }
        }

        // Проверка запрещённых флагов
        if let forbidden = forbiddenFlags {
            for flag in forbidden {
                if worldFlags[flag] == true {
                    return false
                }
            }
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

/// Квест в игре
/// Для side-квестов используйте theme для определения нарративной темы
/// См. EXPLORATION_CORE_DESIGN.md, раздел 30 (Side-квесты как "зеркала мира")
struct Quest: Identifiable, Codable {
    let id: UUID
    let definitionId: String?           // Content Pack ID (e.g., "quest_main_act1")
    let title: String
    let description: String
    let questType: QuestType
    var stage: Int                      // Текущая стадия квеста (0 = не начат)
    var objectives: [QuestObjective]
    let rewards: QuestRewards
    var completed: Bool

    // Narrative System properties (see EXPLORATION_CORE_DESIGN.md, section 30)
    var theme: SideQuestTheme?          // Тема квеста (для side-квестов): consequence/warning/temptation
    var mirrorFlag: String?             // Какой выбор игрока этот квест "отражает"

    init(
        id: UUID = UUID(),
        definitionId: String? = nil,
        title: String,
        description: String,
        questType: QuestType,
        stage: Int = 0,
        objectives: [QuestObjective],
        rewards: QuestRewards,
        completed: Bool = false,
        theme: SideQuestTheme? = nil,
        mirrorFlag: String? = nil
    ) {
        self.id = id
        self.definitionId = definitionId
        self.title = title
        self.description = description
        self.questType = questType
        self.stage = stage
        self.objectives = objectives
        self.rewards = rewards
        self.completed = completed
        self.theme = theme
        self.mirrorFlag = mirrorFlag
    }

    // Проверка, все ли цели выполнены
    var allObjectivesCompleted: Bool {
        return objectives.allSatisfy { $0.completed }
    }

    /// Проверяет, является ли квест "зеркалом" данного флага
    func mirrors(flag: String) -> Bool {
        return mirrorFlag == flag
    }
}

// MARK: - Deck Path (for Ending calculation)

/// Доминирующий путь колоды игрока
/// См. EXPLORATION_CORE_DESIGN.md, раздел 32.5
enum DeckPath: String, Codable {
    case light      // Преобладают Light-карты (>60%)
    case dark       // Преобладают Dark-карты (>60%)
    case balance    // Нет явного преобладания
}

// MARK: - Ending Profile

/// Профиль финала кампании
/// См. EXPLORATION_CORE_DESIGN.md, раздел 32.4
struct EndingProfile: Identifiable, Codable {
    let id: String
    let title: String
    let conditions: EndingConditions
    let summary: String
    let epilogue: EndingEpilogue
    let unlocksForNextRun: [String]?

    init(
        id: String,
        title: String,
        conditions: EndingConditions,
        summary: String,
        epilogue: EndingEpilogue,
        unlocksForNextRun: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.conditions = conditions
        self.summary = summary
        self.epilogue = epilogue
        self.unlocksForNextRun = unlocksForNextRun
    }
}

/// Условия для получения финала
/// См. EXPLORATION_CORE_DESIGN.md, раздел 32
struct EndingConditions: Codable {
    // WorldTension conditions
    let minTension: Int?                    // Минимальный WorldTension
    let maxTension: Int?                    // Максимальный WorldTension

    // Deck path condition
    let deckPath: DeckPath?                 // Требуемый путь колоды

    // Flag conditions
    let requiredFlags: [String]?            // Обязательные флаги
    let forbiddenFlags: [String]?           // Запрещённые флаги

    // Anchor conditions
    let minStableAnchors: Int?              // Минимум stable якорей
    let maxBreachAnchors: Int?              // Максимум breach регионов

    // Balance conditions
    let minBalance: Int?                    // Минимальный lightDarkBalance
    let maxBalance: Int?                    // Максимальный lightDarkBalance

    init(
        minTension: Int? = nil,
        maxTension: Int? = nil,
        deckPath: DeckPath? = nil,
        requiredFlags: [String]? = nil,
        forbiddenFlags: [String]? = nil,
        minStableAnchors: Int? = nil,
        maxBreachAnchors: Int? = nil,
        minBalance: Int? = nil,
        maxBalance: Int? = nil
    ) {
        self.minTension = minTension
        self.maxTension = maxTension
        self.deckPath = deckPath
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.minStableAnchors = minStableAnchors
        self.maxBreachAnchors = maxBreachAnchors
        self.minBalance = minBalance
        self.maxBalance = maxBalance
    }
}

/// Эпилог финала
struct EndingEpilogue: Codable {
    let anchors: String     // Судьба якорей
    let hero: String        // Судьба героя
    let world: String       // Судьба мира
}

// MARK: - Side Quest Theme

/// Тема побочного квеста (влияет на тон и последствия)
/// См. EXPLORATION_CORE_DESIGN.md, раздел 30.2
enum SideQuestTheme: String, Codable {
    case consequence    // Последствия — мир уже пострадал
    case warning        // Предупреждение — можно предотвратить деградацию
    case temptation     // Соблазн — быстрые выгоды за долгосрочный урон
}

// MARK: - Main Quest Step

/// Шаг основного квеста
/// См. EXPLORATION_CORE_DESIGN.md, раздел 29.3
struct MainQuestStep: Identifiable, Codable {
    let id: String
    let title: String
    let goal: String
    let unlockConditions: QuestConditions
    let completionConditions: QuestConditions
    let effects: QuestEffects?

    init(
        id: String,
        title: String,
        goal: String,
        unlockConditions: QuestConditions,
        completionConditions: QuestConditions,
        effects: QuestEffects? = nil
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.unlockConditions = unlockConditions
        self.completionConditions = completionConditions
        self.effects = effects
    }
}

/// Условия для квеста (разблокировки или завершения)
/// См. EXPLORATION_CORE_DESIGN.md, раздел 29
struct QuestConditions: Codable {
    var requiredFlags: [String]?    // Флаги, которые должны быть установлены
    var forbiddenFlags: [String]?   // Флаги, которых НЕ должно быть
    var minTension: Int?            // Минимальный WorldTension
    var maxTension: Int?            // Максимальный WorldTension
    var minBalance: Int?            // Минимальный lightDarkBalance
    var maxBalance: Int?            // Максимальный lightDarkBalance
    var visitedRegions: [String]?   // Посещённые регионы

    init(
        requiredFlags: [String]? = nil,
        forbiddenFlags: [String]? = nil,
        minTension: Int? = nil,
        maxTension: Int? = nil,
        minBalance: Int? = nil,
        maxBalance: Int? = nil,
        visitedRegions: [String]? = nil
    ) {
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.minTension = minTension
        self.maxTension = maxTension
        self.minBalance = minBalance
        self.maxBalance = maxBalance
        self.visitedRegions = visitedRegions
    }
}

/// Эффекты выполнения шага квеста
struct QuestEffects: Codable {
    var unlockRegions: [String]?    // Разблокировать регионы
    var setFlags: [String]?         // Установить флаги
    var tensionChange: Int?         // Изменение WorldTension
    var addCards: [String]?         // Добавить карты

    init(
        unlockRegions: [String]? = nil,
        setFlags: [String]? = nil,
        tensionChange: Int? = nil,
        addCards: [String]? = nil
    ) {
        self.unlockRegions = unlockRegions
        self.setFlags = setFlags
        self.tensionChange = tensionChange
        self.addCards = addCards
    }
}
