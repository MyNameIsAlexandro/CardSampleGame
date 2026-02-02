import SwiftUI

/// Public entry point: the PackEditor scene (WindowGroup + Commands).
/// Usage from @main: `PackEditorScene()`
public struct PackEditorScene: Scene {
    @StateObject private var state = PackEditorState()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            PackEditorRootView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Open Pack Folder...") {
                    state.openPackDialog()
                }
                .keyboardShortcut("o")

                Button("Save") {
                    state.activeTab?.savePack()
                }
                .keyboardShortcut("s")
                .disabled(state.activeTab?.isDirty != true)

                Button("New Entity") {
                    state.activeTab?.addEntity()
                }
                .keyboardShortcut("n")
                .disabled(state.activeTab?.selectedCategory == nil || state.activeTab?.selectedCategory == .balance)

                Button("Duplicate Entity") {
                    state.activeTab?.duplicateSelectedEntity()
                }
                .keyboardShortcut("d")
                .disabled(state.activeTab?.selectedEntityId == nil || state.activeTab?.selectedCategory == .balance)
            }
        }
    }
}
