import Foundation

/// Класс героя определяет начальные характеристики и стиль игры
/// Документация: GAME_DESIGN_DOCUMENT.md
enum HeroClass: String, CaseIterable, Codable {
    case warrior = "Воин"           // Высокая сила, много HP
    case mage = "Маг"               // Высокий интеллект, много веры
    case ranger = "Следопыт"        // Высокая ловкость, сбалансирован
    case priest = "Жрец"            // Высокая мудрость, исцеление
    case shadow = "Тень"            // Скрытность, тёмная магия

    /// Описание класса для UI
    var description: String {
        switch self {
        case .warrior:
            return "Мастер ближнего боя. Высокая сила и живучесть."
        case .mage:
            return "Владеет магией. Сильные заклинания, но хрупок."
        case .ranger:
            return "Следопыт и охотник. Сбалансированные характеристики."
        case .priest:
            return "Служитель Света. Исцеление и защита от тьмы."
        case .shadow:
            return "Агент Нави. Тёмная магия и скрытность."
        }
    }

    /// Иконка класса
    var icon: String {
        switch self {
        case .warrior: return "⚔️"
        case .mage: return "🔮"
        case .ranger: return "🏹"
        case .priest: return "✝️"
        case .shadow: return "🗡️"
        }
    }

    /// Начальные характеристики
    var baseStats: HeroStats {
        switch self {
        case .warrior:
            return HeroStats(
                health: 12,
                maxHealth: 12,
                strength: 7,
                dexterity: 3,
                constitution: 5,
                intelligence: 1,
                wisdom: 2,
                charisma: 2,
                faith: 2,
                maxFaith: 8,
                startingBalance: 50
            )
        case .mage:
            return HeroStats(
                health: 7,
                maxHealth: 7,
                strength: 2,
                dexterity: 3,
                constitution: 2,
                intelligence: 7,
                wisdom: 4,
                charisma: 2,
                faith: 5,
                maxFaith: 15,
                startingBalance: 50
            )
        case .ranger:
            return HeroStats(
                health: 10,
                maxHealth: 10,
                strength: 4,
                dexterity: 6,
                constitution: 4,
                intelligence: 3,
                wisdom: 3,
                charisma: 2,
                faith: 3,
                maxFaith: 10,
                startingBalance: 50
            )
        case .priest:
            return HeroStats(
                health: 9,
                maxHealth: 9,
                strength: 3,
                dexterity: 2,
                constitution: 3,
                intelligence: 4,
                wisdom: 6,
                charisma: 4,
                faith: 5,
                maxFaith: 12,
                startingBalance: 70  // Склонен к Свету
            )
        case .shadow:
            return HeroStats(
                health: 8,
                maxHealth: 8,
                strength: 4,
                dexterity: 5,
                constitution: 3,
                intelligence: 5,
                wisdom: 2,
                charisma: 1,
                faith: 4,
                maxFaith: 10,
                startingBalance: 30  // Склонен к Тьме
            )
        }
    }

    /// Особая способность класса
    var specialAbility: String {
        switch self {
        case .warrior:
            return "Ярость: +2 к урону при HP ниже 50%"
        case .mage:
            return "Медитация: +1 вера в конце хода"
        case .ranger:
            return "Выслеживание: +1 кубик при первой атаке"
        case .priest:
            return "Благословение: -1 урон от тьмы"
        case .shadow:
            return "Засада: +3 урона по полным HP"
        }
    }

    /// Стартовая колода зависит от класса
    var startingDeckType: DeckPath {
        switch self {
        case .warrior: return .balance
        case .mage: return .balance
        case .ranger: return .balance
        case .priest: return .light
        case .shadow: return .dark
        }
    }
}

/// Структура с характеристиками героя
struct HeroStats: Codable {
    let health: Int
    let maxHealth: Int
    let strength: Int
    let dexterity: Int
    let constitution: Int
    let intelligence: Int
    let wisdom: Int
    let charisma: Int
    let faith: Int
    let maxFaith: Int
    let startingBalance: Int
}
