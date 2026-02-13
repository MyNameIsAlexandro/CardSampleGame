/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ManagedPack+Equatable.swift
/// Назначение: Содержит реализацию файла ManagedPack+Equatable.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension ManagedPack: Equatable {
    /// Equatable conformance comparing pack identity and state.
    public static func == (lhs: ManagedPack, rhs: ManagedPack) -> Bool {
        lhs.id == rhs.id &&
        lhs.source == rhs.source &&
        lhs.state == rhs.state &&
        lhs.fileSize == rhs.fileSize &&
        lhs.modifiedAt == rhs.modifiedAt &&
        lhs.loadedAt == rhs.loadedAt
    }
}
