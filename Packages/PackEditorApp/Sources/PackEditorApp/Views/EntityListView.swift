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
            .searchable(text: $searchText, prompt: Text(String(localized: "entityList.filterPrompt \(category.localizedName.lowercased())", bundle: .module)))
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
                            Button(String(localized: "entityList.new", bundle: .module)) {
                                tab.addEntity()
                            }
                        }

                        Divider()

                        Button(String(localized: "entityList.importClipboard", bundle: .module)) {
                            _ = tab.importEntityFromClipboard()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(category == .balance)
                    .help(String(localized: "entityList.addHelp \(category.localizedName.lowercased())", bundle: .module))

                    Button {
                        tab.duplicateSelectedEntity()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(tab.selectedEntityId == nil || category == .balance)
                    .help(String(localized: "entityList.duplicateHelp", bundle: .module))

                    Button {
                        tab.exportSelectedEntityToClipboard()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(tab.selectedEntityId == nil)
                    .help(String(localized: "entityList.exportHelp", bundle: .module))

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(tab.selectedEntityId == nil || category == .balance)
                    .help(String(localized: "entityList.deleteHelp", bundle: .module))
                }
            }
            .alert(String(localized: "entityList.deleteTitle", bundle: .module), isPresented: $showDeleteConfirmation) {
                Button(String(localized: "entityList.delete", bundle: .module), role: .destructive) {
                    tab.deleteSelectedEntity()
                }
                Button(String(localized: "entityList.cancel", bundle: .module), role: .cancel) {}
            } message: {
                if let id = tab.selectedEntityId {
                    Text(String(localized: "entityList.deleteMessage \(id)", bundle: .module))
                }
            }
        } else {
            Text("placeholder.selectCategory", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }

    private func templateOptions(for category: ContentCategory) -> [(String, String)]? {
        switch category {
        case .enemies: return [
            ("beast", String(localized: "template.beast", bundle: .module)),
            ("undead", String(localized: "template.undead", bundle: .module)),
            ("boss", String(localized: "template.boss", bundle: .module))
        ]
        case .cards: return [
            ("attack", String(localized: "template.attack", bundle: .module)),
            ("defense", String(localized: "template.defense", bundle: .module)),
            ("spell", String(localized: "template.spell", bundle: .module)),
            ("item", String(localized: "template.item", bundle: .module))
        ]
        case .regions: return [
            ("settlement", String(localized: "template.settlement", bundle: .module)),
            ("wilderness", String(localized: "template.wilderness", bundle: .module)),
            ("dungeon", String(localized: "template.dungeon", bundle: .module))
        ]
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
