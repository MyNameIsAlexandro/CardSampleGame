/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/FieldValidation.swift
/// Назначение: Содержит реализацию файла FieldValidation.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI

/// A validation result for a single field.
struct FieldValidation {
    let level: ValidationBadge.Level
    let message: String

    static func error(_ message: String) -> FieldValidation {
        FieldValidation(level: .error, message: message)
    }

    static func warning(_ message: String) -> FieldValidation {
        FieldValidation(level: .warning, message: message)
    }
}

/// View modifier that appends a ValidationBadge when validation fails.
struct ValidatedModifier: ViewModifier {
    let validation: FieldValidation?

    func body(content: Content) -> some View {
        HStack {
            content
            if let v = validation {
                ValidationBadge(level: v.level, message: v.message)
            }
        }
    }
}

extension View {
    func validated(_ validation: FieldValidation?) -> some View {
        modifier(ValidatedModifier(validation: validation))
    }
}
