import SwiftUI

struct PackEditorRootView: View {
    @EnvironmentObject var state: PackEditorState

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()

            if state.showBrowser {
                // Placeholder for Phase 3 PackBrowserView
                VStack {
                    Text("Pack Browser")
                        .font(.largeTitle)
                    Text("Coming soon — use Open button in toolbar")
                        .foregroundStyle(.secondary)
                    Button("Open Pack...") {
                        state.openPackDialog()
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Label("Open", systemImage: "folder")
                }
            }
        }
    }
}
