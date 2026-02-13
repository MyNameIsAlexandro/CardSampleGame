/// Файл: Packages/EchoEngine/Sources/EchoEngine/FamilyHelpers.swift
/// Назначение: Содержит реализацию файла FamilyHelpers.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

/// Helper to get the first element from a Family iterator (LazySequence).
/// FirebladeECS Family conforms to LazySequenceProtocol, not RandomAccessCollection,
/// so `.first` doesn't work as expected. This provides a safe accessor.
extension Sequence {
    func firstElement() -> Element? {
        var iterator = makeIterator()
        return iterator.next()
    }
}

/// Helper to get the first Entity from a Family's entity iterator.
extension Family {
    var firstEntity: Entity? {
        entities.firstElement()
    }
}
