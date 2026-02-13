/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaQuestResourceThresholdCondition.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaQuestResourceThresholdCondition.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Условие порога по ресурсу.
struct JSONResourceThresholdCondition: Codable {
    public let resourceId: String?
    public let minValue: Int?

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case minValue = "min_value"
    }
}
