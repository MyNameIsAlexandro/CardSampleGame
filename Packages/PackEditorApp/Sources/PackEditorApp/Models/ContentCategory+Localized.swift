import Foundation
import PackEditorKit

extension ContentCategory {
    /// Returns the localized display name for this category.
    var localizedName: String {
        switch self {
        case .enemies: return String(localized: "sidebar.enemies", bundle: .module)
        case .cards: return String(localized: "sidebar.cards", bundle: .module)
        case .events: return String(localized: "sidebar.events", bundle: .module)
        case .regions: return String(localized: "sidebar.regions", bundle: .module)
        case .heroes: return String(localized: "sidebar.heroes", bundle: .module)
        case .fateCards: return String(localized: "sidebar.fateCards", bundle: .module)
        case .quests: return String(localized: "sidebar.quests", bundle: .module)
        case .behaviors: return String(localized: "sidebar.behaviors", bundle: .module)
        case .anchors: return String(localized: "sidebar.anchors", bundle: .module)
        case .balance: return String(localized: "sidebar.balance", bundle: .module)
        }
    }
}
