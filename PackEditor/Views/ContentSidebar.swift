import SwiftUI
import TwilightEngine
import PackEditorKit

struct ContentSidebar: View {
    @EnvironmentObject var state: PackEditorState

    var body: some View {
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
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .onChange(of: state.selectedCategory) { _ in
            state.selectedEntityId = nil
        }
    }
}
