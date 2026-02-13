/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/Render/ParticleComponent.swift
/// Назначение: Содержит реализацию файла ParticleComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

public final class ParticleComponent: Component {
    public var emitterName: String?
    public var isActive: Bool
    public var removeWhenDone: Bool

    public init(emitterName: String? = nil, isActive: Bool = false, removeWhenDone: Bool = true) {
        self.emitterName = emitterName
        self.isActive = isActive
        self.removeWhenDone = removeWhenDone
    }
}
