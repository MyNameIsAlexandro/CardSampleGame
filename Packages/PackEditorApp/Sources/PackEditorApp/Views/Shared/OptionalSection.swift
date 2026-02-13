/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/OptionalSection.swift
/// Назначение: Содержит реализацию файла OptionalSection.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI

struct OptionalSection<Content: View>: View {
    let label: String
    @Binding var isEnabled: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        Section {
            Toggle(label, isOn: $isEnabled)
            if isEnabled {
                content()
            }
        }
    }
}
