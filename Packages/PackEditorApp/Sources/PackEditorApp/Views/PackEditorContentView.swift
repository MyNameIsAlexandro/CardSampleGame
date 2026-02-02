import SwiftUI

struct PackEditorContentView: View {
    @EnvironmentObject var tab: EditorTab

    var body: some View {
        VStack(spacing: 0) {
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

            if tab.showValidation {
                ValidationPanelView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tab.showValidation)
    }
}
