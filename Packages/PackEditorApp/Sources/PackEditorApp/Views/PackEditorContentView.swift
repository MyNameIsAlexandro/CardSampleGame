import SwiftUI

struct PackEditorContentView: View {
    @EnvironmentObject var tab: EditorTab

    var body: some View {
        NavigationSplitView {
            ContentSidebar()
        } content: {
            EntityListView()
        } detail: {
            EditorDetailView()
        }
        .toolbar {
            EditorToolbar()
        }
    }
}
