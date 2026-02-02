import SwiftUI
import TwilightEngine
import PackEditorKit

struct ContentSidebar: View {
    @EnvironmentObject var tab: EditorTab

    var body: some View {
        Group {
            if tab.globalSearchText.isEmpty {
                // Normal category list
                List(ContentCategory.allCases, selection: $tab.selectedCategory) { category in
                    Label {
                        HStack {
                            Text(category.localizedName)
                            Spacer()
                            Text("\(tab.entityCount(for: category))")
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
                let results = tab.globalSearchResults
                if results.isEmpty {
                    List {
                        Text("placeholder.noResults", bundle: .module)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(ContentCategory.allCases) { category in
                            let categoryResults = results.filter { $0.category == category }
                            if !categoryResults.isEmpty {
                                Section(category.localizedName) {
                                    ForEach(categoryResults, id: \.id) { result in
                                        Button {
                                            tab.selectedCategory = result.category
                                            tab.selectedEntityId = result.id
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
        .searchable(text: $tab.globalSearchText, prompt: Text("placeholder.searchAll", bundle: .module))
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .onChange(of: tab.selectedCategory) { _ in
            tab.selectedEntityId = nil
        }
    }
}
