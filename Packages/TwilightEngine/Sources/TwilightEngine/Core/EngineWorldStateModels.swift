/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineWorldStateModels.swift
/// Назначение: Содержит реализацию файла EngineWorldStateModels.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

// MARK: - Event Trigger

/// Trigger type that causes an event to fire
public enum EventTrigger {
    case arrival
    case exploration
    case combat
    case quest
    case time
}

// MARK: - Engine Region State (Bridge from Legacy)

/// Объединённое состояние региона для UI (Audit v1.1 Issue #9)
///
/// Это ПРЕДПОЧТИТЕЛЬНАЯ модель для UI:
/// - Создаётся из legacy Region через TwilightGameEngine.syncFromLegacy()
/// - Публикуется через engine.publishedRegions
/// - UI должен использовать engine.regionsArray или engine.currentRegion
///
/// Архитектура моделей:
/// - `RegionDefinition` - статические данные (ContentProvider)
/// - `RegionRuntimeState` - изменяемое состояние (WorldRuntimeState)
/// - `EngineRegionState` - объединённое для UI (этот struct)
/// - `Region` (legacy) - persistence и совместимость
public struct EngineRegionState: Identifiable {
    /// Stable definition ID (serves as both identity and definition reference)
    public let id: String
    /// Localized display name
    public let name: String
    /// Region type (settlement, sacred, etc.)
    public let type: RegionType
    /// Current state (stable, borderland, breach)
    public var state: RegionState
    /// Anchor protecting this region, if any
    public var anchor: EngineAnchorState?
    /// Definition IDs of neighboring regions
    public let neighborIds: [String]
    /// Whether trading is available in this region
    public var canTrade: Bool
    /// Whether the player has visited this region
    public var visited: Bool = false
    /// Player reputation in this region
    public var reputation: Int = 0

    /// Create directly (Engine-First) - id is the definition ID
    public init(
        id: String,
        name: String,
        type: RegionType,
        state: RegionState,
        anchor: EngineAnchorState? = nil,
        neighborIds: [String] = [],
        canTrade: Bool = false,
        visited: Bool = false,
        reputation: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.state = state
        self.anchor = anchor
        self.neighborIds = neighborIds
        self.canTrade = canTrade
        self.visited = visited
        self.reputation = reputation
    }

    /// Can rest in this region
    public var canRest: Bool {
        state == .stable && (type == .settlement || type == .sacred)
    }

    /// Region alignment derived from anchor (neutral if no anchor)
    public var alignment: AnchorAlignment {
        anchor?.alignment ?? .neutral
    }
}

// MARK: - Engine Anchor State (Bridge from Legacy)

/// Internal state for engine anchor tracking (REQUIRED definitionId - Audit A1)
public struct EngineAnchorState {
    /// Stable definition ID (serves as both identity and definition reference)
    public let id: String
    /// Localized display name
    public let name: String
    /// Current integrity level (0-100)
    public var integrity: Int
    /// Anchor alignment (light/neutral/dark)
    public var alignment: AnchorAlignment

    /// Create directly (Engine-First) - id is the definition ID
    public init(id: String, name: String, integrity: Int, alignment: AnchorAlignment = .neutral) {
        self.id = id
        self.name = name
        self.integrity = max(0, min(100, integrity))
        self.alignment = alignment
    }
}

// MARK: - Combat State (for UI)

/// Read-only combat state for UI binding
public struct CombatState {
    /// The enemy card being fought
    public let enemy: Card
    /// Enemy's current health points
    public let enemyHealth: Int
    /// Enemy's current will/resolve (Spirit track)
    public let enemyWill: Int
    /// Enemy's maximum will/resolve
    public let enemyMaxWill: Int
    /// Current combat turn number
    public let turnNumber: Int
    /// Actions remaining this turn
    public let actionsRemaining: Int
    /// Bonus dice accumulated for next attack
    public let bonusDice: Int
    /// Bonus damage accumulated for next attack
    public let bonusDamage: Int
    /// Whether the next attack is the first in this combat
    public let isFirstAttack: Bool
    /// Cards currently in the player's hand
    public let playerHand: [Card]

    /// Whether this enemy has a Spirit track (will > 0)
    public var hasSpiritTrack: Bool {
        enemyMaxWill > 0
    }

    /// Enemy's maximum health from card definition
    public var enemyMaxHealth: Int {
        enemy.health ?? 10
    }

    /// Enemy's defense value from card definition
    public var enemyDefense: Int {
        enemy.defense ?? 10
    }

    /// Enemy's attack power from card definition
    public var enemyPower: Int {
        enemy.power ?? 3
    }

    /// Initialize combat state with all required fields
    public init(
        enemy: Card,
        enemyHealth: Int,
        enemyWill: Int = 0,
        enemyMaxWill: Int = 0,
        turnNumber: Int,
        actionsRemaining: Int,
        bonusDice: Int,
        bonusDamage: Int,
        isFirstAttack: Bool,
        playerHand: [Card]
    ) {
        self.enemy = enemy
        self.enemyHealth = enemyHealth
        self.enemyWill = enemyWill
        self.enemyMaxWill = enemyMaxWill
        self.turnNumber = turnNumber
        self.actionsRemaining = actionsRemaining
        self.bonusDice = bonusDice
        self.bonusDamage = bonusDamage
        self.isFirstAttack = isFirstAttack
        self.playerHand = playerHand
    }
}
