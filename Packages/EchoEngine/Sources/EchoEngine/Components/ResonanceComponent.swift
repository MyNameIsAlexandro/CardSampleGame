/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/ResonanceComponent.swift
/// Назначение: Содержит реализацию файла ResonanceComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

public final class ResonanceComponent: Component {
    public var value: Float

    public init(value: Float = 0) {
        self.value = value
    }
}
