/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/PackEditorContentView.swift
/// Назначение: Содержит реализацию файла PackEditorContentView.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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
