/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/HealthComponent.swift
/// Назначение: Содержит реализацию файла HealthComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

public final class HealthComponent: Component {
    public var current: Int
    public var max: Int
    public var will: Int
    public var maxWill: Int

    public init(current: Int, max: Int, will: Int = 0, maxWill: Int = 0) {
        self.current = current
        self.max = max
        self.will = will
        self.maxWill = maxWill
    }

    public var isAlive: Bool { current > 0 }
    public var willDepleted: Bool { maxWill > 0 && will <= 0 }
}
