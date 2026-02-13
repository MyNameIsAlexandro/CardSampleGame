/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaQuestChoiceCondition.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaQuestChoiceCondition.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Условие "сделан конкретный выбор в событии".
struct JSONChoiceMadeCondition: Codable {
    public let eventId: String?
    public let choiceId: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case choiceId = "choice_id"
    }
}
