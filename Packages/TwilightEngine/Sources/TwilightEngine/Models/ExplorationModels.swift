/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/ExplorationModels.swift
/// Назначение: Содержит реализацию файла ExplorationModels.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Region State

public enum RegionState: String, Codable, Hashable, CaseIterable {
    case stable         // Стабильная Явь - безопасно
    case borderland     // Пограничье - повышенный риск
    case breach         // Прорыв Нави - опасно

    /// Initialize from Engine's RegionStateType
    /// Used by data-driven content loading
    public init(from engineState: RegionStateType) {
        switch engineState {
        case .stable: self = .stable
        case .borderland: self = .borderland
        case .breach: self = .breach
        }
    }

    public var displayName: String {
        switch self {
        case .stable: return L10n.regionStateStable.localized
        case .borderland: return L10n.regionStateBorderland.localized
        case .breach: return L10n.regionStateBreach.localized
        }
    }

    public var emoji: String {
        switch self {
        case .stable: return "🟢"
        case .borderland: return "🟡"
        case .breach: return "🔴"
        }
    }

    // MARK: - Combat Modifiers

    /// Бонус к силе врага в этом регионе
    public var enemyPowerBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Бонус к здоровью врага в этом регионе
    public var enemyHealthBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 2
        case .breach: return 5
        }
    }

    /// Бонус к защите врага в этом регионе
    public var enemyDefenseBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }
}

// MARK: - Combat Context

/// Контекст боя с учётом региона и проклятий
public struct CombatContext {
    public let regionState: RegionState
    public let playerCurses: [CurseType]

    public init(regionState: RegionState, playerCurses: [CurseType]) {
        self.regionState = regionState
        self.playerCurses = playerCurses
    }

    /// Рассчитать эффективную силу врага
    public func adjustedEnemyPower(_ basePower: Int) -> Int {
        return basePower + regionState.enemyPowerBonus
    }

    /// Рассчитать эффективное здоровье врага
    public func adjustedEnemyHealth(_ baseHealth: Int) -> Int {
        return baseHealth + regionState.enemyHealthBonus
    }

    /// Рассчитать эффективную защиту врага
    public func adjustedEnemyDefense(_ baseDefense: Int) -> Int {
        return baseDefense + regionState.enemyDefenseBonus
    }

    /// Описание модификаторов региона для UI
    public var regionModifierDescription: String? {
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

public enum RegionType: String, Codable, Hashable {
    case forest         // Лес
    case swamp          // Болото
    case mountain       // Горы
    case settlement     // Поселение
    case water          // Водная зона
    case wasteland      // Пустошь
    case sacred         // Священное место

    public var displayName: String {
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

    public var icon: String {
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

public enum AnchorType: String, Codable {
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
    public init?(fromJSON string: String) {
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

    public var displayName: String {
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

    public var icon: String {
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

public struct Anchor: Identifiable, Codable {
    public let id: String
    public let name: String
    public let type: AnchorType
    public var integrity: Int          // 0-100%
    public var influence: CardBalance  // .light, .neutral, .dark
    public let power: Int              // Сила влияния (1-10)

    public init(
        id: String,
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
    public var determinedRegionState: RegionState {
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
    public var isDefiled: Bool {
        return influence == .dark
    }
}
