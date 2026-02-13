/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentAccessError.swift
/// Назначение: Содержит реализацию файла ContentAccessError.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Error when accessing content fails
public enum ContentAccessError: Error, LocalizedError {
    case notFound(type: String, id: String)
    case incompleteContent(type: String, id: String, missing: [String])
    case insufficientContent(type: String, required: Int, found: Int)
    case noPlayableContent(reason: String)
    case validationFailed(errors: [ContentValidationError])

    public var errorDescription: String? {
        switch self {
        case .notFound(let type, let id):
            return "\(type) '\(id)' not found in loaded content"
        case .incompleteContent(let type, let id, let missing):
            return "\(type) '\(id)' is incomplete, missing: \(missing.joined(separator: ", "))"
        case .insufficientContent(let type, let required, let found):
            return "Insufficient \(type): required \(required), found \(found)"
        case .noPlayableContent(let reason):
            return "No playable content: \(reason)"
        case .validationFailed(let errors):
            return "Content validation failed with \(errors.count) errors"
        }
    }
}
