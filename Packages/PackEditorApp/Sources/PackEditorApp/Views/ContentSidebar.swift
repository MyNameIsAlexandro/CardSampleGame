import SwiftUI
import TwilightEngine
import PackEditorKit

struct ContentSidebar: View {
    @EnvironmentObject var state: PackEditorState

    var body: some View {
        Group {
            if state.globalSearchText.isEmpty {
                // Normal category list
                List(ContentCategory.allCases, selection: $state.selectedCategory) { category in
                    Label {
                        HStack {
                            Text(category.rawValue)
                            Spacer()
                            Text("\(state.entityCount(for: category))")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: category.icon)
                    }
                    .tag(category)
                }
            } else {
                // Search results
                let results = state.globalSearchResults
                if results.isEmpty {
                    List {
                        Text("No results")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(ContentCategory.allCases) { category in
                            let categoryResults = results.filter { $0.category == category }
                            if !categoryResults.isEmpty {
                                Section(category.rawValue) {
                                    ForEach(categoryResults, id: \.id) { result in
                                        Button {
                                            state.selectedCategory = result.category
                                            state.selectedEntityId = result.id
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.name).fontWeight(.medium)
                                                Text(result.id).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $state.globalSearchText, prompt: "Search all entities")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .onChange(of: state.selectedCategory) { _ in
            state.selectedEntityId = nil
        }
    }
}
