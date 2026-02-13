/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+ActionPipeline.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+ActionPipeline.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    // MARK: - Action Execution

    func executeTravel(to regionId: String) -> ([StateChange], [String]) {
        var changes: [StateChange] = []
        let events: [String] = []

        clearCurrentEventSelection()

        currentRegionId = regionId
        changes.append(.regionChanged(regionId: regionId))

        return (changes, events)
    }

    func executeRest() -> [StateChange] {
        var changes: [StateChange] = []

        let healAmount = restHealAmount
        let newHealth = min(player.maxHealth, player.health + healAmount)
        let delta = newHealth - player.health
        player.health = newHealth
        changes.append(.healthChanged(delta: delta, newValue: newHealth))

        return changes
    }

    func executeExplore() -> ([StateChange], [String]) {
        let changes: [StateChange] = []
        var events: [String] = []

        guard let regionId = currentRegionId else {
            return (changes, events)
        }

        if let event = generateEvent(for: regionId, trigger: .exploration) {
            events.append(event)
            assignCurrentEventId(event)
        } else if let encounter = generateRandomEncounter(regionId: regionId) {
            events.append(encounter)
            assignCurrentEventId(encounter)
        }

        return (changes, events)
    }

    func executeTrade() -> [StateChange] {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return []
        }

        rebuildPublishedMarketCards(for: region.id)
        return []
    }

    func executeMarketBuy(cardId: String) -> [StateChange] {
        guard let cardDef = services.contentRegistry.getCard(id: cardId) else {
            return []
        }

        let card = cardDef.toCard(localizationManager: services.localizationManager)
        let cost = card.adjustedFaithCost(playerBalance: player.balance)
        guard player.faith >= cost else { return [] }

        player.faith -= cost
        deck.addToDeck(card)
        removeCardFromMarket(cardId: cardId)

        return [
            .faithChanged(delta: -cost, newValue: player.faith),
            .cardAdded(cardId: card.id, zone: "deck")
        ]
    }

    func executeDrawFateCard() -> [StateChange] {
        guard let result = fateDeck?.drawAndResolve(worldResonance: resonanceValue) else {
            return []
        }

        var changes: [StateChange] = []
        for effect in result.drawEffects {
            switch effect.type {
            case .shiftResonance:
                let oldValue = resonanceValue
                setWorldResonance(resonanceValue + Float(effect.value))
                changes.append(.resonanceChanged(delta: resonanceValue - oldValue, newValue: resonanceValue))
            case .shiftTension:
                let oldValue = worldTension
                worldTension = max(0, min(100, worldTension + effect.value))
                changes.append(.tensionChanged(delta: worldTension - oldValue, newValue: worldTension))
            }
        }

        return changes
    }

    func executeCombatFinish(
        outcome: CombatEndOutcome,
        transaction: EncounterTransaction,
        updatedFateDeck: FateDeckState?
    ) -> [StateChange] {
        var changes: [StateChange] = []

        if transaction.hpDelta != 0 {
            let previous = player.health
            player.health = max(0, min(player.maxHealth, player.health + transaction.hpDelta))
            changes.append(.healthChanged(delta: player.health - previous, newValue: player.health))
        }

        if transaction.faithDelta != 0 {
            let previous = player.faith
            player.faith = max(0, min(player.maxFaith, player.faith + transaction.faithDelta))
            changes.append(.faithChanged(delta: player.faith - previous, newValue: player.faith))
        }

        if transaction.resonanceDelta != 0 {
            let previous = resonanceValue
            setWorldResonance(resonanceValue + transaction.resonanceDelta)
            changes.append(.resonanceChanged(delta: resonanceValue - previous, newValue: resonanceValue))
        }

        for (key, value) in transaction.worldFlags {
            worldFlags[key] = value
            changes.append(.flagSet(key: key, value: value))
        }

        for lootCardId in transaction.lootCardIds {
            if let cardDef = services.contentRegistry.getCard(id: lootCardId) {
                let card = cardDef.toCard(localizationManager: services.localizationManager)
                deck.addToDeck(card)
                changes.append(.cardAdded(cardId: card.id, zone: "deck"))
            }
        }

        if let updatedFateDeck {
            if let deckManager = fateDeck {
                deckManager.restoreState(updatedFateDeck)
            } else {
                let manager = FateDeckManager(cards: [], rng: services.rng)
                manager.restoreState(updatedFateDeck)
                fateDeck = manager
            }
        }

        clearPendingExternalCombatPersistence()
        combat.endCombat()

        switch outcome {
        case .victory:
            if let enemyId = combat.combatEnemy?.id {
                changes.append(.enemyDefeated(enemyId: enemyId))
            }
            changes.append(.combatEnded(victory: true))
        case .defeat, .escaped:
            changes.append(.combatEnded(victory: false))
        }

        return changes
    }

    func rebuildPublishedMarketCards(for regionDefinitionId: String) {
        let allCards = services.contentRegistry.getAllCards()
        guard !allCards.isEmpty else {
            publishedMarketCards = []
            return
        }

        if marketState.global?.day != currentDay {
            let globalCards = allCards
                .sorted { $0.id < $1.id }
                .prefix(12)
                .map(\.id)
            marketState.global = GlobalMarketState(day: currentDay, cardIds: Array(globalCards))
        }

        if marketState.regions[regionDefinitionId]?.day != currentDay {
            let occupied = Set(marketState.global?.cardIds ?? [])
            let regionalCards = allCards
                .sorted { $0.id < $1.id }
                .filter { !occupied.contains($0.id) }
                .prefix(8)
                .map(\.id)
            marketState.regions[regionDefinitionId] = RegionalMarketState(
                day: currentDay,
                cardIds: Array(regionalCards),
                storyCardId: nil
            )
        }

        guard let global = marketState.global,
              let regional = marketState.regions[regionDefinitionId] else {
            publishedMarketCards = []
            return
        }

        var ids = global.cardIds + regional.cardIds
        if let storyId = regional.storyCardId {
            ids.append(storyId)
        }

        let cards = ids
            .compactMap { services.contentRegistry.getCard(id: $0)?.toCard(localizationManager: services.localizationManager) }
            .sorted { lhs, rhs in
                lhs.adjustedFaithCost(playerBalance: player.balance) < rhs.adjustedFaithCost(playerBalance: player.balance)
            }
        publishedMarketCards = cards
    }

    func removeCardFromMarket(cardId: String) {
        if var global = marketState.global {
            global.cardIds.removeAll { $0 == cardId }
            marketState.global = global
        }

        for (regionId, var regional) in marketState.regions {
            regional.cardIds.removeAll { $0 == cardId }
            if regional.storyCardId == cardId {
                regional.storyCardId = nil
            }
            marketState.regions[regionId] = regional
        }

        publishedMarketCards.removeAll { $0.id == cardId }
    }

    /// Generate a random combat encounter when no scripted event fires.
    /// Chance scales with worldTension (0–100). At tension 30 → ~15%, at 80 → ~40%.
    func generateRandomEncounter(regionId: String) -> String? {
        let encounterChance = max(5, worldTension / 2)
        let roll = services.rng.nextInt(in: 0...99)
        guard roll < encounterChance else { return nil }

        let allEnemies = services.contentRegistry.getAllEnemies()
        guard !allEnemies.isEmpty else { return nil }

        let enemy = allEnemies[services.rng.nextInt(in: 0...(allEnemies.count - 1))]

        let monsterCard = enemy.toCard(localizationManager: services.localizationManager)
        let combatEvent = GameEvent(
            id: "random_encounter_\(currentDay)_\(regionId)",
            eventType: .combat,
            title: enemy.name.resolved,
            description: enemy.description.resolved,
            choices: [
                EventChoice(
                    id: "fight",
                    text: NSLocalizedString("encounter.action.attack", comment: ""),
                    consequences: EventConsequences(message: "")
                ),
                EventChoice(
                    id: "flee",
                    text: NSLocalizedString("encounter.action.flee", comment: ""),
                    consequences: EventConsequences(healthChange: -2, message: "")
                )
            ],
            monsterCard: monsterCard
        )

        currentEvent = combatEvent
        return combatEvent.id
    }

    func executeStrengthenAnchor() -> [StateChange] {
        var changes: [StateChange] = []

        guard let regionId = currentRegionId,
              var region = regions[regionId],
              var anchor = region.anchor else {
            return changes
        }

        if playerAlignment == .nav {
            let cost = anchorDarkStrengthenCostHP
            player.health -= cost
            changes.append(.healthChanged(delta: -cost, newValue: player.health))

            if anchor.alignment != .dark {
                let oldAlignment = anchor.alignment
                anchor.alignment = (oldAlignment == .light) ? .neutral : .dark
                changes.append(.anchorAlignmentChanged(anchorId: anchor.id, newAlignment: anchor.alignment.rawValue))
            }
        } else {
            let cost = anchorStrengthenCost
            player.faith -= cost
            changes.append(.faithChanged(delta: -cost, newValue: player.faith))
        }

        let strengthAmount = anchorStrengthenAmount
        let newIntegrity = min(100, anchor.integrity + strengthAmount)
        let delta = newIntegrity - anchor.integrity
        anchor.integrity = newIntegrity
        region.anchor = anchor
        regions[regionId] = region

        changes.append(.anchorIntegrityChanged(anchorId: anchor.id, delta: delta, newValue: newIntegrity))

        return changes
    }

    func executeDefileAnchor() -> [StateChange] {
        var changes: [StateChange] = []

        guard let regionId = currentRegionId,
              var region = regions[regionId],
              var anchor = region.anchor else {
            return changes
        }

        let cost = anchorDefileCostHP
        player.health -= cost
        changes.append(.healthChanged(delta: -cost, newValue: player.health))

        anchor.alignment = .dark
        region.anchor = anchor
        regions[regionId] = region

        changes.append(.anchorAlignmentChanged(anchorId: anchor.id, newAlignment: AnchorAlignment.dark.rawValue))

        return changes
    }

    func executeEventChoice(eventId: String, choiceIndex: Int) -> [StateChange] {
        var changes: [StateChange] = []

        if let event = currentEvent,
           choiceIndex < event.choices.count {
            let choice = event.choices[choiceIndex]
            changes.append(contentsOf: applyConsequences(choice.consequences))
        }

        if let completedEventId = currentEvent?.id {
            completedEventIds.insert(completedEventId)
        }
        changes.append(.eventCompleted(eventId: eventId))

        assignCurrentEventId(nil)

        return changes
    }

    func executeMiniGameInput(_ input: MiniGameInput) -> [StateChange] {
        var changes: [StateChange] = []

        for (resource, amount) in input.bonusRewards {
            switch resource {
            case "health":
                let newHealth = min(player.maxHealth, player.health + amount)
                player.health = newHealth
                changes.append(.healthChanged(delta: amount, newValue: newHealth))
            case "faith":
                let newFaith = player.faith + amount
                player.faith = newFaith
                changes.append(.faithChanged(delta: amount, newValue: newFaith))
            default:
                break
            }
        }

        return changes
    }

    // MARK: - Consequences

    func applyConsequences(_ consequences: EventConsequences) -> [StateChange] {
        var changes: [StateChange] = []

        if let healthDelta = consequences.healthChange, healthDelta != 0 {
            let newHealth = max(0, min(player.maxHealth, player.health + healthDelta))
            player.health = newHealth
            changes.append(.healthChanged(delta: healthDelta, newValue: newHealth))
        }

        if let faithDelta = consequences.faithChange, faithDelta != 0 {
            let newFaith = max(0, player.faith + faithDelta)
            player.faith = newFaith
            changes.append(.faithChanged(delta: faithDelta, newValue: newFaith))
        }

        if let balanceDelta = consequences.balanceChange, balanceDelta != 0 {
            let newBalance = max(0, min(100, player.balance + balanceDelta))
            player.balance = newBalance
            changes.append(.balanceChanged(delta: balanceDelta, newValue: newBalance))
        }

        if let tensionDelta = consequences.tensionChange, tensionDelta != 0 {
            worldTension = max(0, min(100, worldTension + tensionDelta))
            changes.append(.tensionChanged(delta: tensionDelta, newValue: worldTension))
        }

        if let flagsToSet = consequences.setFlags {
            for (flag, value) in flagsToSet {
                worldFlags[flag] = value
                changes.append(.flagSet(key: flag, value: value))
            }
        }

        return changes
    }

    // MARK: - Event Generation

    func generateEvent(for regionId: String, trigger: EventTrigger) -> String? {
        #if DEBUG
        if _blockScriptedEvents { return nil }
        #endif

        guard let region = publishedRegions[regionId] else {
            return nil
        }
        let regionDefId = region.id

        let regionStateString = mapRegionStateToString(region.state)

        let availableDefinitions = contentRegistry.getAvailableEvents(
            forRegion: regionDefId,
            pressure: worldTension,
            regionState: regionStateString
        )

        let activeFlags = Set(worldFlags.filter { $0.value }.map { $0.key })
        let currentBalance = Int(resonanceValue)

        let filteredDefinitions = availableDefinitions.filter { eventDef in
            if eventDef.isOneTime && completedEventIds.contains(eventDef.id) {
                return false
            }

            let avail = eventDef.availability
            for flag in avail.requiredFlags {
                if !activeFlags.contains(flag) { return false }
            }
            for flag in avail.forbiddenFlags {
                if activeFlags.contains(flag) { return false }
            }
            if let min = avail.minBalance, currentBalance < min { return false }
            if let max = avail.maxBalance, currentBalance > max { return false }
            return true
        }

        guard !filteredDefinitions.isEmpty else { return nil }

        let totalWeight = filteredDefinitions.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            let selectedDef = filteredDefinitions[services.rng.nextInt(in: 0...(filteredDefinitions.count - 1))]
            let gameEvent = selectedDef.toGameEvent(
                forRegion: regionDefId,
                registry: services.contentRegistry,
                localizationManager: services.localizationManager
            )
            currentEvent = gameEvent
            return gameEvent.id
        }

        let roll = services.rng.nextInt(in: 0...(totalWeight - 1))
        var cumulative = 0
        for eventDef in filteredDefinitions {
            cumulative += eventDef.weight
            if roll < cumulative {
                let gameEvent = eventDef.toGameEvent(
                    forRegion: regionDefId,
                    registry: services.contentRegistry,
                    localizationManager: services.localizationManager
                )
                currentEvent = gameEvent
                return gameEvent.id
            }
        }

        let selectedDef = filteredDefinitions[services.rng.nextInt(in: 0...(filteredDefinitions.count - 1))]
        let gameEvent = selectedDef.toGameEvent(
            forRegion: regionDefId,
            registry: services.contentRegistry,
            localizationManager: services.localizationManager
        )
        currentEvent = gameEvent
        return gameEvent.id
    }
}
