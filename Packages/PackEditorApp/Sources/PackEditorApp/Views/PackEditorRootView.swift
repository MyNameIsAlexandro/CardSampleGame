import SwiftUI

struct PackEditorRootView: View {
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
