/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+ActionValidation.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+ActionValidation.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    // MARK: - Validation

    func validateAction(_ action: TwilightGameAction) -> ActionError? {
        switch action {
        case .travel(let toRegionId):
            return validateTravel(to: toRegionId)

        case .rest:
            return validateRest()

        case .explore:
            if isInCombat { return .combatInProgress }
            return nil

        case .trade:
            return validateTrade()

        case .marketBuy(let cardId):
            return validateMarketBuy(cardId: cardId)

        case .strengthenAnchor:
            return validateStrengthenAnchor()

        case .defileAnchor:
            return validateDefileAnchor()

        case .drawFateCard:
            return validateDrawFateCard()

        case .chooseEventOption(let eventId, let choiceIndex):
            return validateEventChoice(eventId: eventId, choiceIndex: choiceIndex)

        case .startCombat(let encounterId):
            if isInCombat { return .combatInProgress }
            if let currentEventId, currentEventId != encounterId {
                return .eventNotFound(eventId: encounterId)
            }
            return nil

        case .combatFinish:
            return nil

        case .combatStoreEncounterState:
            return nil

        default:
            return nil
        }
    }

    func validateTravel(to regionId: String) -> ActionError? {
        guard let currentId = currentRegionId,
              let currentRegion = regions[currentId] else {
            return .invalidAction(reason: .noCurrentRegion)
        }

        if !currentRegion.neighborIds.contains(regionId) {
            return .regionNotNeighbor(regionId: regionId)
        }

        if player.health <= 0 {
            return .healthTooLow
        }

        return nil
    }

    func validateRest() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: .noCurrentRegion)
        }

        if region.state == .breach {
            return .actionNotAvailableInRegion(action: "rest", regionType: "breach")
        }

        return nil
    }

    func validateTrade() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: .noCurrentRegion)
        }

        if !region.canTrade {
            return .actionNotAvailableInRegion(action: "trade", regionType: region.type.rawValue)
        }

        return nil
    }

    func validateMarketBuy(cardId: String) -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: .noCurrentRegion)
        }

        if !region.canTrade {
            return .actionNotAvailableInRegion(action: "trade", regionType: region.type.rawValue)
        }

        guard let global = marketState.global, global.day == currentDay,
              let regional = marketState.regions[region.id], regional.day == currentDay else {
            return .invalidAction(reason: .marketNotInitialized)
        }

        var availableCardIds = Set(global.cardIds)
        availableCardIds.formUnion(regional.cardIds)
        if let storyId = regional.storyCardId {
            availableCardIds.insert(storyId)
        }

        guard availableCardIds.contains(cardId) else {
            return .invalidAction(reason: .cardNotInMarket)
        }

        guard let cardDef = services.contentRegistry.getCard(id: cardId) else {
            return .invalidAction(reason: .unknownCard(cardId: cardId))
        }

        let cost = cardDef.toCard(localizationManager: services.localizationManager)
            .adjustedFaithCost(playerBalance: player.balance)
        if player.faith < cost {
            return .insufficientResources(resource: "faith", required: cost, available: player.faith)
        }

        return nil
    }

    func validateStrengthenAnchor() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: .noCurrentRegion)
        }

        if region.anchor == nil {
            return .actionNotAvailableInRegion(action: "strengthen anchor", regionType: "no anchor")
        }

        if playerAlignment == .nav {
            let cost = anchorDarkStrengthenCostHP
            if player.health <= cost {
                return .insufficientResources(resource: "health", required: cost, available: player.health)
            }
        } else {
            let cost = anchorStrengthenCost
            if player.faith < cost {
                return .insufficientResources(resource: "faith", required: cost, available: player.faith)
            }
        }

        return nil
    }

    func validateDefileAnchor() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: .noCurrentRegion)
        }

        guard let anchor = region.anchor else {
            return .actionNotAvailableInRegion(action: "defile anchor", regionType: "no anchor")
        }

        if playerAlignment != .nav {
            return .invalidAction(reason: .defileRequiresDarkAlignment)
        }

        if anchor.alignment == .dark {
            return .invalidAction(reason: .anchorAlreadyDark)
        }

        let cost = anchorDefileCostHP
        if player.health <= cost {
            return .insufficientResources(resource: "health", required: cost, available: player.health)
        }

        return nil
    }
}
