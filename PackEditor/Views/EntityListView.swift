import SwiftUI
import TwilightEngine
import PackEditorKit

struct EntityListView: View {
    @EnvironmentObject var state: PackEditorState
    @State private var searchText = ""

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
