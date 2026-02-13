/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/IntField.swift
/// Назначение: Содержит реализацию файла IntField.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI

struct IntField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int>? = nil

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Stepper("", value: $value, in: range ?? -999_999...999_999)
                .labelsHidden()
        }
    }
}
