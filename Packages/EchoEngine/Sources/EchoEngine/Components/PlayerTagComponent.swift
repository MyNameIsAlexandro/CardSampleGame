/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/PlayerTagComponent.swift
/// Назначение: Содержит реализацию файла PlayerTagComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

public final class PlayerTagComponent: Component {
    public var name: String
    public var strength: Int

    public init(name: String = "Hero", strength: Int = 5) {
        self.name = name
        self.strength = strength
    }
}
