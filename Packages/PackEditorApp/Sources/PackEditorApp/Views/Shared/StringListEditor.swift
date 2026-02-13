/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/StringListEditor.swift
/// Назначение: Содержит реализацию файла StringListEditor.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI

struct StringListEditor: View {
    let label: String
    @Binding var items: [String]

    // Use a stable ID that includes the label to differentiate multiple editors
    private var stableId: String { label }

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
            HStack {
                TextField("Item", text: itemBinding(at: index))
                Button(role: .destructive) {
                    guard index < items.count else { return }
                    items.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .id("\(stableId)-\(index)") // Unique ID for each row
        }
        Button {
            items.append("")
        } label: {
            Label("Add \(label)", systemImage: "plus.circle")
        }
    }

    private func itemBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < items.count else { return "" }
                return items[index]
            },
            set: { newValue in
                guard index < items.count else { return }
                items[index] = newValue
            }
        )
    }
}
