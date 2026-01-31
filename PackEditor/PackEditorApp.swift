import SwiftUI
import TwilightEngine
import PackAuthoring
import PackEditorKit

@main
struct PackEditorApp: App {
    @StateObject private var state = PackEditorState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Open Pack Folder...") {
                    state.openPack()
                }
                .keyboardShortcut("o")

                Button("Save") {
                    state.savePack()
                }
                .keyboardShortcut("s")
                .disabled(!state.isDirty)

                Button("New Entity") {
                    state.addEntity()
                }
                .keyboardShortcut("n")
                .disabled(state.selectedCategory == nil || state.selectedCategory == .balance)

                Button("Duplicate Entity") {
                    state.duplicateSelectedEntity()
                }
                .keyboardShortcut("d")
                .disabled(state.selectedEntityId == nil || state.selectedCategory == .balance)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: PackEditorState

    var body: some View {
        NavigationSplitView {
            ContentSidebar()
        } content: {
            if state.loadedPack != nil {
                EntityListView()
            } else {
                Text("Open a pack folder to begin")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            if state.loadedPack != nil {
                EditorDetailView()
            } else {
                Text("Select an entity to edit")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            EditorToolbar()
        }
        .navigationTitle(state.packTitle)
    }
}

struct EditorDetailView: View {
    @EnvironmentObject var state: PackEditorState
    @Environment(\.undoManager) var undoManager
    @State private var showJSONPreview = false

    var body: some View {
        ScrollView {
            switch state.selectedCategory {
            case .enemies:
                if let id = state.selectedEntityId, state.enemies[id] != nil {
                    EnemyEditor(enemy: undoBinding(
                        get: { state.enemies[id]! },
                        set: { state.enemies[id] = $0 },
                        label: "Edit Enemy"
                    ))
                }
            case .cards:
                if let id = state.selectedEntityId, state.cards[id] != nil {
                    CardEditor(card: undoBinding(
                        get: { state.cards[id]! },
                        set: { state.cards[id] = $0 },
                        label: "Edit Card"
                    ))
                }
            case .events:
                if let id = state.selectedEntityId, state.events[id] != nil {
                    EventEditor(event: undoBinding(
                        get: { state.events[id]! },
                        set: { state.events[id] = $0 },
                        label: "Edit Event"
                    ))
                }
            case .regions:
                if let id = state.selectedEntityId, state.regions[id] != nil {
                    RegionEditor(region: undoBinding(
                        get: { state.regions[id]! },
                        set: { state.regions[id] = $0 },
                        label: "Edit Region"
                    ))
                }
            case .heroes:
                if let id = state.selectedEntityId, state.heroes[id] != nil {
                    HeroEditor(hero: undoBinding(
                        get: { state.heroes[id]! },
                        set: { state.heroes[id] = $0 },
                        label: "Edit Hero"
                    ))
                }
            case .fateCards:
                if let id = state.selectedEntityId, state.fateCards[id] != nil {
                    FateCardEditor(card: undoBinding(
                        get: { state.fateCards[id]! },
                        set: { state.fateCards[id] = $0 },
                        label: "Edit Fate Card"
                    ))
                }
            case .quests:
                if let id = state.selectedEntityId, state.quests[id] != nil {
                    QuestEditor(quest: undoBinding(
                        get: { state.quests[id]! },
                        set: { state.quests[id] = $0 },
                        label: "Edit Quest"
                    ))
                }
            case .behaviors:
                if let id = state.selectedEntityId, state.behaviors[id] != nil {
                    BehaviorEditor(behavior: undoBinding(
                        get: { state.behaviors[id]! },
                        set: { state.behaviors[id] = $0 },
                        label: "Edit Behavior"
                    ))
                }
            case .anchors:
                if let id = state.selectedEntityId, state.anchors[id] != nil {
                    AnchorEditor(anchor: undoBinding(
                        get: { state.anchors[id]! },
                        set: { state.anchors[id] = $0 },
                        label: "Edit Anchor"
                    ))
                }
            case .balance:
                if state.balanceConfig != nil {
                    BalanceEditor(config: undoBinding(
                        get: { state.balanceConfig! },
                        set: { state.balanceConfig = $0 },
                        label: "Edit Balance"
                    ))
                }
            case .none:
                if state.manifest != nil {
                    ManifestEditor(manifest: Binding(
                        get: { state.manifest! },
                        set: {
                            state.manifest = $0
                            state.isDirty = true
                        }
                    ))
                } else {
                    Text("Select a category")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showJSONPreview = true
                } label: {
                    Image(systemName: "curlybraces")
                }
                .disabled(state.selectedEntityId == nil && state.selectedCategory != .balance)
                .help("View as JSON")
            }
        }
        .sheet(isPresented: $showJSONPreview) {
            jsonPreviewContent
        }
    }

    @ViewBuilder
    private var jsonPreviewContent: some View {
        if let id = state.selectedEntityId {
            switch state.selectedCategory {
            case .enemies:
                if let e = state.enemies[id] { JSONPreviewSheet(title: id, value: e) }
            case .cards:
                if let c = state.cards[id] { JSONPreviewSheet(title: id, value: c) }
            case .events:
                if let e = state.events[id] { JSONPreviewSheet(title: id, value: e) }
            case .regions:
                if let r = state.regions[id] { JSONPreviewSheet(title: id, value: r) }
            case .heroes:
                if let h = state.heroes[id] { JSONPreviewSheet(title: id, value: h) }
            case .fateCards:
                if let f = state.fateCards[id] { JSONPreviewSheet(title: id, value: f) }
            case .quests:
                if let q = state.quests[id] { JSONPreviewSheet(title: id, value: q) }
            case .behaviors:
                if let b = state.behaviors[id] { JSONPreviewSheet(title: id, value: b) }
            case .anchors:
                if let a = state.anchors[id] { JSONPreviewSheet(title: id, value: a) }
            case .balance:
                if let c = state.balanceConfig { JSONPreviewSheet(title: "Balance", value: c) }
            case .none:
                Text("No entity selected")
            }
        } else if state.selectedCategory == .balance, let c = state.balanceConfig {
            JSONPreviewSheet(title: "Balance", value: c)
        }
    }

    /// Creates a Binding that registers undo actions on every set.
    private func undoBinding<T>(
        get: @escaping () -> T,
        set: @escaping (T) -> Void,
        label: String
    ) -> Binding<T> {
        Binding(
            get: get,
            set: { newValue in
                let oldValue = get()
                set(newValue)
                state.isDirty = true
                undoManager?.registerUndo(withTarget: state) { state in
                    set(oldValue)
                    state.isDirty = true
                    state.objectWillChange.send()
                }
                undoManager?.setActionName(label)
            }
        )
    }
}
