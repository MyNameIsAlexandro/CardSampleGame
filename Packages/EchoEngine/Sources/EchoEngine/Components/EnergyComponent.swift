/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/EnergyComponent.swift
/// Назначение: Содержит реализацию файла EnergyComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

public final class EnergyComponent: Component {
    public var current: Int
    public var max: Int

    public init(current: Int = 3, max: Int = 3) {
        self.current = current
        self.max = max
    }
}
