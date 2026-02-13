/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/IntentComponent.swift
/// Назначение: Содержит реализацию файла IntentComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

public final class IntentComponent: Component {
    public var intent: EnemyIntent?

    public init(intent: EnemyIntent? = nil) {
        self.intent = intent
    }
}
