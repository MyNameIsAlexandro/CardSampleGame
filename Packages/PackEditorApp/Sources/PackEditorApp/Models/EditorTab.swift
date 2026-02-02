import SwiftUI
import TwilightEngine
import PackAuthoring
import PackEditorKit

/// Per-pack editing state. Each open pack gets its own EditorTab.
class EditorTab: ObservableObject, Identifiable {
    let id = UUID()
    let store = PackStore()

    // MARK: - UI Selection
    @Published var selectedCategory: ContentCategory? = nil
    @Published var selectedEntityId: String? = nil
    @Published var showValidation: Bool = false
    @Published var globalSearchText: String = ""

    var globalSearchResults: [(category: ContentCategory, id: String, name: String)] {
        guard !globalSearchText.isEmpty else { return [] }
        let query = globalSearchText.lowercased()
        var results: [(ContentCategory, String, String)] = []
        for category in ContentCategory.allCases {
            for id in store.entityIds(for: category) {
                let name = store.entityName(for: id, in: category)
                if id.lowercased().contains(query) || name.lowercased().contains(query) {
                    results.append((category, id, name))
                }
            }
        }
        return results
    }

    // MARK: - Forwarded Properties

    var loadedPack: LoadedPack? { store.loadedPack }
    var packURL: URL? { store.packURL }
    var isDirty: Bool {
        get { store.isDirty }
        set { store.isDirty = newValue }
    }
    var enemies: [String: EnemyDefinition] {
        get { store.enemies }
        set { store.enemies = newValue }
    }
    var cards: [String: StandardCardDefinition] {
        get { store.cards }
        set { store.cards = newValue }
    }
    var events: [String: EventDefinition] {
        get { store.events }
        set { store.events = newValue }
    }
    var regions: [String: RegionDefinition] {
        get { store.regions }
        set { store.regions = newValue }
    }
    var heroes: [String: StandardHeroDefinition] {
        get { store.heroes }
        set { store.heroes = newValue }
    }
    var fateCards: [String: FateCard] {
        get { store.fateCards }
        set { store.fateCards = newValue }
    }
    var quests: [String: QuestDefinition] {
        get { store.quests }
        set { store.quests = newValue }
    }
    var behaviors: [String: BehaviorDefinition] {
        get { store.behaviors }
        set { store.behaviors = newValue }
    }
    var anchors: [String: AnchorDefinition] {
        get { store.anchors }
        set { store.anchors = newValue }
    }
    var balanceConfig: BalanceConfiguration? {
        get { store.balanceConfig }
        set { store.balanceConfig = newValue }
    }
    var manifest: PackManifest? {
        get { store.manifest }
        set { store.manifest = newValue }
    }
    var validationSummary: PackValidator.ValidationSummary? { store.validationSummary }
    var packTitle: String { store.packTitle }

    func entityCount(for category: ContentCategory) -> Int {
        store.entityCount(for: category)
    }

    func entityIds(for category: ContentCategory) -> [String] {
        store.entityIds(for: category)
    }

    func entityName(for id: String, in category: ContentCategory) -> String {
        store.entityName(for: id, in: category)
    }

    // MARK: - Save Pack

    func savePack() {
        do {
            try store.savePack()
            objectWillChange.send()
        } catch {
            print("PackEditor: Failed to save: \(error)")
        }
    }

    // MARK: - Add / Delete Entity

    func addEntity(template: String? = nil) {
        guard let category = selectedCategory else { return }
        if let newId = store.addEntity(for: category, template: template) {
            selectedEntityId = newId
            objectWillChange.send()
        }
    }

    func duplicateSelectedEntity() {
        guard let category = selectedCategory, let id = selectedEntityId else { return }
        if let newId = store.duplicateEntity(id: id, for: category) {
            selectedEntityId = newId
            objectWillChange.send()
        }
    }

    func deleteSelectedEntity() {
        guard let category = selectedCategory, let id = selectedEntityId else { return }
        store.deleteEntity(id: id, for: category)
        selectedEntityId = nil
        objectWillChange.send()
    }

    // MARK: - Save Manifest

    func saveManifest() {
        do {
            try store.saveManifest()
            objectWillChange.send()
        } catch {
            print("PackEditor: Failed to save manifest: \(error)")
        }
    }

    // MARK: - Import / Export Entity

    @discardableResult
    func importEntityFromClipboard() -> String? {
        guard let category = selectedCategory,
              let string = NSPasteboard.general.string(forType: .string),
              let data = string.data(using: .utf8) else { return nil }
        do {
            let id = try store.importEntity(json: data, for: category)
            if let id { selectedEntityId = id }
            objectWillChange.send()
            return id
        } catch {
            print("PackEditor: Import failed: \(error)")
            return nil
        }
    }

    func exportSelectedEntityToClipboard() {
        guard let category = selectedCategory, let id = selectedEntityId else { return }
        guard let data = store.exportEntityJSON(id: id, for: category),
              let string = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    // MARK: - Entity Ordering

    func orderedEntityIds(for category: ContentCategory) -> [String] {
        store.orderedEntityIds(for: category)
    }

    func moveEntities(for category: ContentCategory, from source: IndexSet, to destination: Int) {
        var order = store.orderedEntityIds(for: category)
        order.move(fromOffsets: source, toOffset: destination)
        store.entityOrder[category] = order
        try? store.saveEntityOrder()
        objectWillChange.send()
    }

    // MARK: - Validate

    func validate() {
        store.validate()
        objectWillChange.send()
    }
}
