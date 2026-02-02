import Foundation
import TwilightEngine

/// Content categories available in the pack editor.
public enum ContentCategory: String, CaseIterable, Identifiable, Sendable {
    case enemies = "Enemies"
    case cards = "Cards"
    case events = "Events"
    case regions = "Regions"
    case heroes = "Heroes"
    case fateCards = "Fate Cards"
    case quests = "Quests"
    case behaviors = "Behaviors"
    case anchors = "Anchors"
    case balance = "Balance"

    public var id: String { rawValue }

    /// Returns the content categories relevant to a given pack type.
    public static func categories(for packType: PackType) -> [ContentCategory] {
        switch packType {
        case .character:
            return [.heroes, .cards]
        case .campaign:
            return [.enemies, .cards, .events, .regions, .fateCards, .quests, .behaviors, .anchors, .balance]
        default:
            return Array(allCases)
        }
    }

    public var icon: String {
        switch self {
        case .enemies: return "person.fill.xmark"
        case .cards: return "rectangle.portrait.fill"
        case .events: return "text.book.closed.fill"
        case .regions: return "map.fill"
        case .heroes: return "person.fill"
        case .fateCards: return "sparkles.rectangle.stack.fill"
        case .quests: return "flag.fill"
        case .behaviors: return "brain"
        case .anchors: return "mappin.and.ellipse"
        case .balance: return "slider.horizontal.3"
        }
    }
}
