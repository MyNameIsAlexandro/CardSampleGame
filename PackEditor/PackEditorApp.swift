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

    var body: some View {
        ScrollView {
            switch state.selectedCategory {
            case .enemies:
                if let id = state.selectedEntityId, state.enemies[id] != nil {
                    EnemyEditor(enemy: Binding(
                        get: { state.enemies[id]! },
                        set: { state.enemies[id] = $0; state.isDirty = true }
                    ))
                }
            case .cards:
                if let id = state.selectedEntityId, state.cards[id] != nil {
                    CardEditor(card: Binding(
                        get: { state.cards[id]! },
                        set: { state.cards[id] = $0; state.isDirty = true }
                    ))
                }
            case .events:
                if let id = state.selectedEntityId, state.events[id] != nil {
                    EventEditor(event: Binding(
                        get: { state.events[id]! },
                        set: { state.events[id] = $0; state.isDirty = true }
                    ))
                }
            case .regions:
                if let id = state.selectedEntityId, state.regions[id] != nil {
                    RegionEditor(region: Binding(
                        get: { state.regions[id]! },
                        set: { state.regions[id] = $0; state.isDirty = true }
                    ))
                }
            case .heroes:
                if let id = state.selectedEntityId, state.heroes[id] != nil {
                    HeroEditor(hero: Binding(
                        get: { state.heroes[id]! },
                        set: { state.heroes[id] = $0; state.isDirty = true }
                    ))
                }
            case .fateCards:
                if let id = state.selectedEntityId, state.fateCards[id] != nil {
                    FateCardEditor(card: Binding(
                        get: { state.fateCards[id]! },
                        set: { state.fateCards[id] = $0; state.isDirty = true }
                    ))
                }
            case .quests:
                if let id = state.selectedEntityId, state.quests[id] != nil {
                    QuestEditor(quest: Binding(
                        get: { state.quests[id]! },
                        set: { state.quests[id] = $0; state.isDirty = true }
                    ))
                }
            case .balance:
                if state.balanceConfig != nil {
                    BalanceEditor(config: Binding(
                        get: { state.balanceConfig! },
                        set: { state.balanceConfig = $0; state.isDirty = true }
                    ))
                }
            case .none:
                Text("Select a category")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
