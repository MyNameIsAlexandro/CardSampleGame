/// Файл: Utilities/Localization.swift
/// Назначение: Содержит реализацию файла Localization.swift.
/// Зона ответственности: Предоставляет вспомогательные утилиты и общие примитивы.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation

// MARK: - Localization Helper
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Localization Key Namespace
enum L10n {}
