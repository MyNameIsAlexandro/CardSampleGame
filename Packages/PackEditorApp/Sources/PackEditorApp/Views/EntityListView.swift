import SwiftUI
import TwilightEngine
import PackEditorKit

struct EntityListView: View {
    @EnvironmentObject var tab: EditorTab
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        if let category = tab.selectedCategory {
            let ids = filteredIds(for: category)
            List(selection: $tab.selectedEntityId) {
                ForEach(ids, id: \.self) { id in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.entityName(for: id, in: category))
                            .fontWeight(.medium)
                        Text(id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(id)
                }
                .onMove { from, to in
                    guard searchText.isEmpty else { return }
                    tab.moveEntities(for: category, from: from, to: to)
                }
            }
            .searchable(text: $searchText, prompt: "Filter \(category.rawValue.lowercased())")
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        if let templates = templateOptions(for: category) {
                            ForEach(templates, id: \.0) { (key, label) in
                                Button(label) {
                                    tab.addEntity(template: key)
                                }
                            }
                        } else {
                            Button("New") {
                                tab.addEntity()
                            }
                        }

                        Divider()

                        Button("Import from Clipboard") {
                            _ = tab.importEntityFromClipboard()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(category == .balance)
                    .help("Add new \(category.rawValue.lowercased().dropLast())")

                    Button {
                        tab.duplicateSelectedEntity()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(tab.selectedEntityId == nil || category == .balance)
                    .help("Duplicate selected entity")

                    Button {
                        tab.exportSelectedEntityToClipboard()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(tab.selectedEntityId == nil)
                    .help("Export selected entity to clipboard")

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(tab.selectedEntityId == nil || category == .balance)
                    .help("Delete selected entity")
                }
            }
            .alert("Delete Entity?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    tab.deleteSelectedEntity()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let id = tab.selectedEntityId {
                    Text("Are you sure you want to delete \"\(id)\"? This cannot be undone.")
                }
            }
        } else {
            Text("Select a category")
                .foregroundStyle(.secondary)
        }
    }

    private func templateOptions(for category: ContentCategory) -> [(String, String)]? {
        switch category {
        case .enemies: return [("beast", "Beast"), ("undead", "Undead"), ("boss", "Boss")]
        case .cards: return [("attack", "Attack"), ("defense", "Defense"), ("spell", "Spell"), ("item", "Item")]
        case .regions: return [("settlement", "Settlement"), ("wilderness", "Wilderness"), ("dungeon", "Dungeon")]
        default: return nil
        }
    }

    private func filteredIds(for category: ContentCategory) -> [String] {
        let allIds = tab.orderedEntityIds(for: category)
        guard !searchText.isEmpty else { return allIds }
        return allIds.filter { id in
            id.localizedCaseInsensitiveContains(searchText) ||
            tab.entityName(for: id, in: category).localizedCaseInsensitiveContains(searchText)
        }
    }
}
