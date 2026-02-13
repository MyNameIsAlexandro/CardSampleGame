/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaQuestConditions.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaQuestConditions.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Условия выполнения objective в JSON-схеме квестов.
/// Поддерживает как текущий плоский формат, так и legacy object-формат.
struct JSONCompletionCondition: Codable {
    public let flagSet: String?
    public let visitRegion: String?
    public let eventCompleted: String?
    public let defeatEnemy: String?
    public let collectItem: String?
    public let choiceMade: JSONChoiceMadeCondition?
    public let resourceThreshold: JSONResourceThresholdCondition?
    public let type: String?
    public let regionId: String?
    public let eventId: String?
    public let flag: String?
    public let threshold: Int?

    enum CodingKeys: String, CodingKey {
        case flagSet = "flag_set"
        case visitRegion = "visit_region"
        case eventCompleted = "event_completed"
        case defeatEnemy = "defeat_enemy"
        case collectItem = "collect_item"
        case choiceMade = "choice_made"
        case resourceThreshold = "resource_threshold"
        case type, regionId, eventId, flag, threshold
    }

    public func toCondition() -> CompletionCondition {
        if let flag = flagSet {
            return .flagSet(flag)
        }
        if let region = visitRegion {
            return .visitRegion(region)
        }
        if let event = eventCompleted {
            return .eventCompleted(event)
        }
        if let enemy = defeatEnemy {
            return .defeatEnemy(enemy)
        }
        if let item = collectItem {
            return .collectItem(item)
        }
        if let choice = choiceMade {
            return .choiceMade(eventId: choice.eventId ?? "", choiceId: choice.choiceId ?? "")
        }
        if let resource = resourceThreshold {
            return .resourceThreshold(resourceId: resource.resourceId ?? "", minValue: resource.minValue ?? 0)
        }

        switch type?.lowercased() {
        case "visitregion", "visit_region":
            return .visitRegion(regionId ?? "")
        case "eventcompleted", "event_completed":
            return .eventCompleted(eventId ?? "")
        case "flagset", "flag_set":
            return .flagSet(flag ?? "")
        case "defeatenemy", "defeat_enemy":
            return .defeatEnemy(eventId ?? "")
        default:
            return .manual
        }
    }
}
