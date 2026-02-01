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
                    state.openPack()
                }
                .keyboardShortcut("o")

                Button("Save") {
                    state.savePack()
                }
                .keyboardShortcut("s")
                .disabled(!state.isDirty)

                Button("New Entity") {
                    state.addEntity()
                }
                .keyboardShortcut("n")
                .disabled(state.selectedCategory == nil || state.selectedCategory == .balance)

                Button("Duplicate Entity") {
                    state.duplicateSelectedEntity()
                }
                .keyboardShortcut("d")
                .disabled(state.selectedEntityId == nil || state.selectedCategory == .balance)
            }
        }
    }
}
