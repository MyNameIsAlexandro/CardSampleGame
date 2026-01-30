import SwiftUI
import TwilightEngine
import PackAuthoring

// MARK: - Content Category

enum ContentCategory: String, CaseIterable, Identifiable {
    case enemies = "Enemies"
    case cards = "Cards"
    case events = "Events"
    case regions = "Regions"
    case heroes = "Heroes"
    case fateCards = "Fate Cards"
    case quests = "Quests"
    case balance = "Balance"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .enemies: return "person.fill.xmark"
        case .cards: return "rectangle.portrait.fill"
        case .events: return "text.book.closed.fill"
        case .regions: return "map.fill"
        case .heroes: return "person.fill"
        case .fateCards: return "sparkles.rectangle.stack.fill"
        case .quests: return "flag.fill"
        case .balance: return "slider.horizontal.3"
        }
    }
}

// MARK: - Pack Editor State

class PackEditorState: ObservableObject {
    // MARK: - Pack Info
    @Published var loadedPack: LoadedPack?
    @Published var packURL: URL?
    @Published var isDirty: Bool = false

    // MARK: - Selection
    @Published var selectedCategory: ContentCategory? = nil
    @Published var selectedEntityId: String? = nil

    // MARK: - Content (mutable copies)
    @Published var enemies: [String: EnemyDefinition] = [:]
    @Published var cards: [String: StandardCardDefinition] = [:]
    @Published var events: [String: EventDefinition] = [:]
    @Published var regions: [String: RegionDefinition] = [:]
    @Published var heroes: [String: StandardHeroDefinition] = [:]
    @Published var fateCards: [String: FateCard] = [:]
    @Published var quests: [String: QuestDefinition] = [:]
    @Published var behaviors: [String: BehaviorDefinition] = [:]
    @Published var balanceConfig: BalanceConfiguration?

    // MARK: - Validation
    @Published var validationSummary: PackValidator.ValidationSummary?
    @Published var showValidation: Bool = false

    // MARK: - Computed

    var packTitle: String {
        if let pack = loadedPack {
            return "\(pack.manifest.packId) v\(pack.manifest.version)"
        }
        return "Pack Editor"
    }

    func entityCount(for category: ContentCategory) -> Int {
        switch category {
        case .enemies: return enemies.count
        case .cards: return cards.count
        case .events: return events.count
        case .regions: return regions.count
        case .heroes: return heroes.count
        case .fateCards: return fateCards.count
        case .quests: return quests.count
        case .balance: return balanceConfig != nil ? 1 : 0
        }
    }

    func entityIds(for category: ContentCategory) -> [String] {
        switch category {
        case .enemies: return enemies.keys.sorted()
        case .cards: return cards.keys.sorted()
        case .events: return events.keys.sorted()
        case .regions: return regions.keys.sorted()
        case .heroes: return heroes.keys.sorted()
        case .fateCards: return fateCards.keys.sorted()
        case .quests: return quests.keys.sorted()
        case .balance: return balanceConfig != nil ? ["balance"] : []
        }
    }

    func entityName(for id: String, in category: ContentCategory) -> String {
        switch category {
        case .enemies: return enemies[id]?.name.displayString ?? id
        case .cards: return cards[id]?.name.displayString ?? id
        case .events: return events[id]?.title.displayString ?? id
        case .regions: return regions[id]?.title.displayString ?? id
        case .heroes: return heroes[id]?.name.displayString ?? id
        case .fateCards: return fateCards[id]?.name ?? id
        case .quests: return quests[id]?.title.displayString ?? id
        case .balance: return "Balance Configuration"
        }
    }

    // MARK: - Open Pack

    func openPack() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a pack source folder (containing manifest.json)"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadPack(from: url)
    }

    func loadPack(from url: URL) {
        do {
            let manifest = try PackManifest.load(from: url)
            let pack = try PackLoader.load(manifest: manifest, from: url)

            self.loadedPack = pack
            self.packURL = url
            self.enemies = pack.enemies
            self.cards = pack.cards
            self.events = pack.events
            self.regions = pack.regions
            self.heroes = pack.heroes
            self.fateCards = pack.fateCards
            self.quests = pack.quests
            self.behaviors = pack.behaviors
            self.balanceConfig = pack.balanceConfig
            self.isDirty = false
            self.selectedCategory = nil
            self.selectedEntityId = nil
        } catch {
            print("PackEditor: Failed to load pack: \(error)")
        }
    }

    // MARK: - Save Pack

    func savePack() {
        guard let url = packURL, let manifest = loadedPack?.manifest else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            if let path = manifest.regionsPath {
                let data = try encoder.encode(Array(regions.values))
                try data.write(to: url.appendingPathComponent(path))
            }
            if let path = manifest.eventsPath {
                let data = try encoder.encode(Array(events.values))
                try data.write(to: url.appendingPathComponent(path))
            }
            if let path = manifest.questsPath {
                let data = try encoder.encode(Array(quests.values))
                try data.write(to: url.appendingPathComponent(path))
            }
            if let path = manifest.heroesPath {
                let data = try encoder.encode(Array(heroes.values))
                try data.write(to: url.appendingPathComponent(path))
            }
            if let path = manifest.cardsPath {
                let data = try encoder.encode(Array(cards.values))
                try data.write(to: url.appendingPathComponent(path))
            }
            if let path = manifest.enemiesPath {
                let data = try encoder.encode(Array(enemies.values))
                try data.write(to: url.appendingPathComponent(path))
            }
            if let path = manifest.fateDeckPath {
                let data = try encoder.encode(Array(fateCards.values))
                try data.write(to: url.appendingPathComponent(path))
            }
            if let path = manifest.balancePath, let config = balanceConfig {
                let data = try encoder.encode(config)
                try data.write(to: url.appendingPathComponent(path))
            }

            isDirty = false
            print("PackEditor: Saved pack to \(url.path)")
        } catch {
            print("PackEditor: Failed to save: \(error)")
        }
    }
}

// MARK: - LocalizableText Display Helper

extension LocalizableText {
    /// Returns the English text for inline strings, or the key string for key-based text.
    /// Used for display in the editor UI.
    var displayString: String {
        switch self {
        case .inline(let localized):
            return localized.en
        case .key(let key):
            return key.rawValue
        }
    }
}
