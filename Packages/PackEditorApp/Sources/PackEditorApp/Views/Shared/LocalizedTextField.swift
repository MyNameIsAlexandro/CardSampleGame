/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/LocalizedTextField.swift
/// Назначение: Содержит реализацию файла LocalizedTextField.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import TwilightEngine

/// Edits a `LocalizableText` value.
/// For inline strings: shows EN/RU text fields side by side.
/// For key-based strings: shows the key as read-only.
struct LocalizedTextField: View {
    let label: String
    @Binding var text: LocalizableText
    var multiline: Bool = false

    var body: some View {
        switch text {
        case .inline:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EN").font(.caption2).foregroundStyle(.secondary)
                        if multiline {
                            TextEditor(text: enBinding)
                                .font(.body)
                                .frame(minHeight: 60)
                        } else {
                            TextField(label, text: enBinding)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RU").font(.caption2).foregroundStyle(.secondary)
                        if multiline {
                            TextEditor(text: ruBinding)
                                .font(.body)
                                .frame(minHeight: 60)
                        } else {
                            TextField(label, text: ruBinding)
                        }
                    }
                }
            }
        case .key:
            LabeledContent(label, value: text.displayString)
        }
    }

    private var enBinding: Binding<String> {
        Binding(
            get: { text.inlineString?.en ?? "" },
            set: { newValue in
                if let ls = text.inlineString {
                    text = .inline(LocalizedString(en: newValue, ru: ls.ru))
                }
            }
        )
    }

    private var ruBinding: Binding<String> {
        Binding(
            get: { text.inlineString?.ru ?? "" },
            set: { newValue in
                if let ls = text.inlineString {
                    text = .inline(LocalizedString(en: ls.en, ru: newValue))
                }
            }
        )
    }
}
