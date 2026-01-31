import SwiftUI
import TwilightEngine
import PackEditorKit

struct EntityListView: View {
    @EnvironmentObject var state: PackEditorState
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        if let category = state.selectedCategory {
            let ids = filteredIds(for: category)
            List(ids, id: \.self, selection: $state.selectedEntityId) { id in
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.entityName(for: id, in: category))
                        .fontWeight(.medium)
                    Text(id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(id)
            }
            .searchable(text: $searchText, prompt: "Filter \(category.rawValue.lowercased())")
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        state.addEntity()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(category == .balance)
                    .help("Add new \(category.rawValue.lowercased().dropLast())")

                    Button {
                        state.duplicateSelectedEntity()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(state.selectedEntityId == nil || category == .balance)
                    .help("Duplicate selected entity")

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(state.selectedEntityId == nil || category == .balance)
                    .help("Delete selected entity")
                }
            }
            .alert("Delete Entity?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    state.deleteSelectedEntity()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let id = state.selectedEntityId {
                    Text("Are you sure you want to delete \"\(id)\"? This cannot be undone.")
                }
            }
        } else {
            Text("Select a category")
                .foregroundStyle(.secondary)
        }
    }

    private func filteredIds(for category: ContentCategory) -> [String] {
        let allIds = state.entityIds(for: category)
        guard !searchText.isEmpty else { return allIds }
        return allIds.filter { id in
            id.localizedCaseInsensitiveContains(searchText) ||
            state.entityName(for: id, in: category).localizedCaseInsensitiveContains(searchText)
        }
    }
}
