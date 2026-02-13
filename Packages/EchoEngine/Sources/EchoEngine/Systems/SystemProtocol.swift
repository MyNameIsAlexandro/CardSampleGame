/// Файл: Packages/EchoEngine/Sources/EchoEngine/Systems/SystemProtocol.swift
/// Назначение: Содержит реализацию файла SystemProtocol.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

/// Base protocol for all EchoEngine systems.
public protocol EchoSystem {
    func update(nexus: Nexus)
}
