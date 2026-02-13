/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+Journal.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+Journal.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    // MARK: - Action Journal (Engine-First)

    /// Auto-log user-visible actions to the engine journal.
    /// Internal to the TwilightEngine module; UI should not write journal entries directly.
    func appendActionLogEntryIfNeeded(action: TwilightGameAction, triggeredEvents: [String]) {
        let regionName = resolveRegionName(forRegionId: currentRegionId)

        switch action {
        case .travel(let toRegionId):
            let destinationName = resolveRegionName(forRegionId: toRegionId)
            guard !destinationName.isEmpty else { return }
            appendEventLogEntry(
                dayNumber: currentDay,
                regionName: destinationName,
                eventTitle: L10n.journalEntryTravel.localized,
                choiceMade: L10n.journalEntryTravelChoice.localized,
                outcome: L10n.journalEntryTravelOutcome.localized(with: destinationName),
                type: .travel
            )

        case .rest:
            appendEventLogEntry(
                dayNumber: currentDay,
                regionName: regionName,
                eventTitle: L10n.journalRestTitle.localized,
                choiceMade: L10n.journalRestChoice.localized,
                outcome: L10n.journalRestOutcome.localized,
                type: .exploration
            )

        case .strengthenAnchor:
            appendEventLogEntry(
                dayNumber: currentDay,
                regionName: regionName,
                eventTitle: L10n.journalAnchorTitle.localized,
                choiceMade: L10n.journalAnchorChoice.localized,
                outcome: L10n.journalAnchorOutcome.localized,
                type: .worldChange
            )

        case .explore:
            // Only log "nothing found" to mirror existing UX.
            guard triggeredEvents.isEmpty else { return }
            appendEventLogEntry(
                dayNumber: currentDay,
                regionName: regionName,
                eventTitle: L10n.journalEntryExplore.localized,
                choiceMade: L10n.journalEntryExploreChoice.localized,
                outcome: L10n.journalEntryExploreNothing.localized,
                type: .exploration
            )

        case .chooseEventOption(let eventId, let choiceIndex):
            guard let event = currentEvent,
                  event.id == eventId,
                  event.choices.indices.contains(choiceIndex) else { return }
            let choice = event.choices[choiceIndex]

            let logType: EventLogType = (event.eventType == .combat) ? .combat : .exploration
            let outcomeMessage = choice.consequences.message ?? L10n.journalChoiceMade.localized

            appendEventLogEntry(
                dayNumber: currentDay,
                regionName: regionName,
                eventTitle: event.title,
                choiceMade: choice.text,
                outcome: outcomeMessage,
                type: logType
            )

        default:
            break
        }
    }

    /// Shared helper for journal append operations.
    func appendEventLogEntry(
        dayNumber: Int,
        regionName: String,
        eventTitle: String,
        choiceMade: String,
        outcome: String,
        type: EventLogType
    ) {
        let entry = EventLogEntry(
            dayNumber: dayNumber,
            regionName: regionName,
            eventTitle: eventTitle,
            choiceMade: choiceMade,
            outcome: outcome,
            type: type
        )

        eventLog.append(entry)
        if eventLog.count > 100 {
            eventLog.removeFirst(eventLog.count - 100)
        }
        refreshPublishedEventLog()
    }

    /// Resolve region display name from current world snapshot.
    func resolveRegionName(forRegionId regionId: String?) -> String {
        guard let regionId else { return "" }
        return regions[regionId]?.name ?? regionId
    }
}
