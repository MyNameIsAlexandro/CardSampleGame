/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/EditorDetailView.swift
/// Назначение: Содержит реализацию файла EditorDetailView.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import TwilightEngine
import PackEditorKit

struct EditorDetailView: View {
    @EnvironmentObject var tab: EditorTab
    @Environment(\.undoManager) var undoManager
    @State private var showJSONPreview = false

    var body: some View {
        ScrollView {
            switch tab.selectedCategory {
            case .enemies:
                if let id = tab.selectedEntityId, let snapshot = tab.enemies[id] {
                    EnemyEditor(enemy: undoBinding(
                        get: { tab.enemies[id] ?? snapshot },
                        set: { tab.enemies[id] = $0 },
                        label: "Edit Enemy"
                    ))
                }
            case .cards:
                if let id = tab.selectedEntityId, let snapshot = tab.cards[id] {
                    CardEditor(card: undoBinding(
                        get: { tab.cards[id] ?? snapshot },
                        set: { tab.cards[id] = $0 },
                        label: "Edit Card"
                    ))
                }
            case .events:
                if let id = tab.selectedEntityId, let snapshot = tab.events[id] {
                    EventEditor(event: undoBinding(
                        get: { tab.events[id] ?? snapshot },
                        set: { tab.events[id] = $0 },
                        label: "Edit Event"
                    ))
                }
            case .regions:
                if let id = tab.selectedEntityId, let snapshot = tab.regions[id] {
                    RegionEditor(region: undoBinding(
                        get: { tab.regions[id] ?? snapshot },
                        set: { tab.regions[id] = $0 },
                        label: "Edit Region"
                    ))
                }
            case .heroes:
                if let id = tab.selectedEntityId, let snapshot = tab.heroes[id] {
                    HeroEditor(hero: undoBinding(
                        get: { tab.heroes[id] ?? snapshot },
                        set: { tab.heroes[id] = $0 },
                        label: "Edit Hero"
                    ))
                }
            case .fateCards:
                if let id = tab.selectedEntityId, let snapshot = tab.fateCards[id] {
                    FateCardEditor(card: undoBinding(
                        get: { tab.fateCards[id] ?? snapshot },
                        set: { tab.fateCards[id] = $0 },
                        label: "Edit Fate Card"
                    ))
                }
            case .quests:
                if let id = tab.selectedEntityId, let snapshot = tab.quests[id] {
                    QuestEditor(quest: undoBinding(
                        get: { tab.quests[id] ?? snapshot },
                        set: { tab.quests[id] = $0 },
                        label: "Edit Quest"
                    ))
                }
            case .behaviors:
                if let id = tab.selectedEntityId, let snapshot = tab.behaviors[id] {
                    BehaviorEditor(behavior: undoBinding(
                        get: { tab.behaviors[id] ?? snapshot },
                        set: { tab.behaviors[id] = $0 },
                        label: "Edit Behavior"
                    ))
                }
            case .anchors:
                if let id = tab.selectedEntityId, let snapshot = tab.anchors[id] {
                    AnchorEditor(anchor: undoBinding(
                        get: { tab.anchors[id] ?? snapshot },
                        set: { tab.anchors[id] = $0 },
                        label: "Edit Anchor"
                    ))
                }
            case .balance:
                if let snapshot = tab.balanceConfig {
                    BalanceEditor(config: undoBinding(
                        get: { tab.balanceConfig ?? snapshot },
                        set: { tab.balanceConfig = $0 },
                        label: "Edit Balance"
                    ))
                }
            case .none:
                if let snapshot = tab.manifest {
                    ManifestEditor(manifest: Binding(
                        get: { tab.manifest ?? snapshot },
                        set: { [weak tab] newValue in
                            tab?.manifest = newValue
                            // Defer isDirty change to avoid "Publishing changes from within view updates"
                            Task { @MainActor in
                                tab?.isDirty = true
                            }
                        }
                    ))
                } else {
                    Text("placeholder.selectCategory", bundle: .module)
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
                .disabled(tab.selectedEntityId == nil && tab.selectedCategory != .balance)
                .help(String(localized: "editor.viewJSON", bundle: .module))
            }
        }
        .sheet(isPresented: $showJSONPreview) {
            jsonPreviewContent
        }
    }

    @ViewBuilder
    private var jsonPreviewContent: some View {
        if let id = tab.selectedEntityId {
            switch tab.selectedCategory {
            case .enemies:
                if let e = tab.enemies[id] { JSONPreviewSheet(title: id, value: e) }
            case .cards:
                if let c = tab.cards[id] { JSONPreviewSheet(title: id, value: c) }
            case .events:
                if let e = tab.events[id] { JSONPreviewSheet(title: id, value: e) }
            case .regions:
                if let r = tab.regions[id] { JSONPreviewSheet(title: id, value: r) }
            case .heroes:
                if let h = tab.heroes[id] { JSONPreviewSheet(title: id, value: h) }
            case .fateCards:
                if let f = tab.fateCards[id] { JSONPreviewSheet(title: id, value: f) }
            case .quests:
                if let q = tab.quests[id] { JSONPreviewSheet(title: id, value: q) }
            case .behaviors:
                if let b = tab.behaviors[id] { JSONPreviewSheet(title: id, value: b) }
            case .anchors:
                if let a = tab.anchors[id] { JSONPreviewSheet(title: id, value: a) }
            case .balance:
                if let c = tab.balanceConfig { JSONPreviewSheet(title: "Balance", value: c) }
            case .none:
                Text("placeholder.noEntitySelected", bundle: .module)
            }
        } else if tab.selectedCategory == .balance, let c = tab.balanceConfig {
            JSONPreviewSheet(title: "Balance", value: c)
        }
    }

    private func undoBinding<T>(
        get: @escaping () -> T,
        set: @escaping (T) -> Void,
        label: String
    ) -> Binding<T> {
        Binding(
            get: get,
            set: { [weak tab, weak undoManager] newValue in
                let oldValue = get()
                set(newValue)
                // Defer state changes to avoid "Publishing changes from within view updates"
                Task { @MainActor in
                    tab?.isDirty = true
                    undoManager?.registerUndo(withTarget: tab!) { tab in
                        set(oldValue)
                        tab.isDirty = true
                        tab.objectWillChange.send()
                    }
                    undoManager?.setActionName(label)
                }
            }
        )
    }
}
