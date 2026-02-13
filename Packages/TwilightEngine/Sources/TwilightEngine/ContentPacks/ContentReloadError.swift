/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentReloadError.swift
/// Назначение: Содержит реализацию файла ContentReloadError.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Errors during content reload.
public enum ContentReloadError: Error, LocalizedError {
    case packNotFound(packId: String)
    case notReloadable(reason: String)
    case validationFailed(summary: ValidationSummary)
    case loadFailed(underlying: Error)

    /// Localized description of the reload error.
    public var errorDescription: String? {
        switch self {
        case .packNotFound(let id): return "Pack '\(id)' not found"
        case .notReloadable(let reason): return "Cannot reload: \(reason)"
        case .validationFailed(let summary): return "Validation failed with \(summary.errorCount) errors"
        case .loadFailed(let error): return "Load failed: \(error.localizedDescription)"
        }
    }
}
