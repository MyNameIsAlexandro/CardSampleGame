import SwiftUI

struct PackEditorRootView: View {
    @EnvironmentObject var state: PackEditorState

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()

            if state.showBrowser {
                PackBrowserView()
            } else if let tab = state.activeTab {
                PackEditorContentView()
                    .environmentObject(tab)
                    .id(tab.id) // force view recreation on tab switch
            }
        }
        .navigationTitle(state.packTitle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    state.openPackDialog()
                } label: {
                    Label(String(localized: "toolbar.open", bundle: .module), systemImage: "folder")
                }
            }
        }
    }
}
