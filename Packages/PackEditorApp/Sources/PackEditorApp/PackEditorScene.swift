/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/PackEditorScene.swift
/// Назначение: Содержит реализацию файла PackEditorScene.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    state.autosaveAll()
                }
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
