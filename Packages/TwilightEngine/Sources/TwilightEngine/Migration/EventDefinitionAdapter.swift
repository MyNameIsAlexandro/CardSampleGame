/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Migration/EventDefinitionAdapter.swift
/// Назначение: Содержит реализацию файла EventDefinitionAdapter.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Event Definition Adapter
// Converts EventDefinition (new data-driven) to GameEvent (legacy UI-compatible)
// This enables using content packs while maintaining compatibility with existing UI

extension EventDefinition {

    /// Convert EventDefinition to legacy GameEvent for UI compatibility
    /// - Parameter regionId: Optional region ID for context-specific conversion
    /// - Returns: GameEvent compatible with existing UI
    public func toGameEvent(
        forRegion regionId: String? = nil,
        registry: ContentRegistry,
        localizationManager: LocalizationManager
    ) -> GameEvent {
        // Map event kind to legacy event type
        let eventType = mapEventKind(eventKind)

        // Map region states from availability
        let regionStates = mapRegionStates(availability.regionStates)

        // Map region types (infer from region IDs if needed)
        let regionTypes = mapRegionTypes(availability.regionIds, registry: registry)

        // Convert choices
        let eventChoices = choices.map { $0.toEventChoice(localizationManager: localizationManager) }

        // Create monster card for combat events
        let monsterCard = createMonsterCard(for: miniGameChallenge, registry: registry, localizationManager: localizationManager)

        return GameEvent(
            id: id,
            eventType: eventType,
            title: title.resolve(using: localizationManager),
            description: body.resolve(using: localizationManager),
            regionTypes: regionTypes,
            regionStates: regionStates,
            choices: eventChoices,
            questLinks: extractQuestLinks(),
            oneTime: isOneTime,
            completed: false,
            monsterCard: monsterCard,
            instant: isInstant,
            weight: weight,
            minTension: availability.minPressure,
            maxTension: availability.maxPressure,
            requiredFlags: availability.requiredFlags.isEmpty ? nil : availability.requiredFlags,
            forbiddenFlags: availability.forbiddenFlags.isEmpty ? nil : availability.forbiddenFlags
        )
    }

    // MARK: - Private Mapping Helpers

    private func mapEventKind(_ kind: EventKind) -> EventType {
        switch kind {
        case .inline:
            return .narrative
        case .miniGame(let miniGameKind):
            switch miniGameKind {
            case .combat:
                return .combat
            case .ritual:
                return .ritual
            case .exploration:
                return .exploration
            case .dialogue:
                return .narrative
            case .puzzle:
                return .ritual
            }
        }
    }

    private func mapRegionStates(_ stateStrings: [String]?) -> [RegionState] {
        guard let states = stateStrings else {
            return [.stable, .borderland, .breach] // Default: all states
        }

        return states.compactMap { stateString in
            switch stateString.lowercased() {
            case "stable": return .stable
            case "borderland": return .borderland
            case "breach": return .breach
            default: return nil
            }
        }
    }

    private func mapRegionTypes(_ regionIds: [String]?, registry: ContentRegistry) -> [RegionType] {
        guard let ids = regionIds else {
            return [] // Empty = any region type
        }

        // Look up region types from ContentRegistry (no hardcoded ID mapping)
        var types = Set<RegionType>()
        for regionId in ids {
            if let regionDef = registry.getRegion(id: regionId) {
                // Map regionType string from definition to RegionType enum
                let regionType = mapRegionTypeString(regionDef.regionType)
                types.insert(regionType)
            }
        }
        return Array(types)
    }

    private func mapRegionTypeString(_ typeString: String) -> RegionType {
        RegionType(rawValue: typeString.lowercased()) ?? .settlement
    }

    private func extractQuestLinks() -> [String] {
        // Extract quest links from choice consequences
        var links: [String] = []
        for choice in choices {
            if let questProgress = choice.consequences.questProgress {
                links.append(questProgress.questId)
            }
        }
        return links
    }

    private func createMonsterCard(
        for challenge: MiniGameChallengeDefinition?,
        registry: ContentRegistry,
        localizationManager: LocalizationManager
    ) -> Card? {
        guard let challenge = challenge,
              let enemyId = challenge.enemyId else { return nil }

        // First, try to get enemy from ContentRegistry
        if let enemy = registry.getEnemy(id: enemyId) {
            return enemy.toCard(localizationManager: localizationManager)
        }

        // Fallback: Create from hardcoded stats
        let enemyStats = getEnemyStats(for: enemyId, difficulty: challenge.difficulty, registry: registry)

        return Card(
            id: enemyId,
            name: enemyId.replacingOccurrences(of: "_", with: " ").capitalized,
            type: .monster,
            rarity: difficultyToRarity(challenge.difficulty),
            description: "Enemy: \(enemyId)",
            power: enemyStats.power,
            defense: enemyStats.defense,
            health: enemyStats.health
        )
    }

    private func getEnemyStats(for enemyId: String, difficulty: Int, registry: ContentRegistry) -> (health: Int, power: Int, defense: Int) {
        // Try to get stats from ContentRegistry (data-driven)
        if let enemyDef = registry.getEnemy(id: enemyId) {
            return (health: enemyDef.health, power: enemyDef.power, defense: enemyDef.defense)
        }

        // Fallback: base stats scaled by difficulty (no game-specific IDs)
        let baseHealth = 5 + (difficulty * 3)
        let basePower = 2 + difficulty
        let baseDefense = 1 + (difficulty / 2)
        return (health: baseHealth, power: basePower, defense: baseDefense)
    }

    private func difficultyToRarity(_ difficulty: Int) -> CardRarity {
        switch difficulty {
        case 1: return .common
        case 2: return .uncommon
        case 3: return .rare
        case 4...5: return .epic
        default: return .legendary
        }
    }
}

// MARK: - Choice Definition to Event Choice

extension ChoiceDefinition {

    /// Convert ChoiceDefinition to legacy EventChoice
    public func toEventChoice(localizationManager: LocalizationManager) -> EventChoice {
        return EventChoice(
            id: id,
            text: label.resolve(using: localizationManager),
            requirements: requirements?.toEventRequirements(),
            consequences: consequences.toEventConsequences()
        )
    }
}

// MARK: - Choice Requirements Conversion

extension ChoiceRequirements {

    /// Convert to legacy EventRequirements
    public func toEventRequirements() -> EventRequirements {
        var requirements = EventRequirements()

        // Map resource requirements
        if let faith = minResources["faith"] {
            requirements.minimumFaith = faith
        }
        if let health = minResources["health"] {
            requirements.minimumHealth = health
        }

        // Map balance requirements
        if let minBal = minBalance {
            if minBal >= 70 {
                requirements.requiredBalance = .light
            } else if let maxBal = maxBalance, maxBal <= 30 {
                requirements.requiredBalance = .dark
            }
        }

        // Map flag requirements
        if !requiredFlags.isEmpty {
            requirements.requiredFlags = requiredFlags
        }

        return requirements
    }
}

// MARK: - Choice Consequences Conversion

extension ChoiceConsequences {

    /// Convert to legacy EventConsequences
    public func toEventConsequences() -> EventConsequences {
        var consequences = EventConsequences()

        // Map resource changes
        if let faith = resourceChanges["faith"] {
            consequences.faithChange = faith
        }
        if let health = resourceChanges["health"] {
            consequences.healthChange = health
        }

        // Map balance change
        if balanceDelta != 0 {
            consequences.balanceChange = balanceDelta
        }

        // Map flags
        if !setFlags.isEmpty {
            var flagDict: [String: Bool] = [:]
            for flag in setFlags {
                flagDict[flag] = true
            }
            for flag in clearFlags {
                flagDict[flag] = false
            }
            consequences.setFlags = flagDict
        }

        // Map region state change to anchor integrity
        if let stateChange = regionStateChange,
           let transition = stateChange.transition {
            switch transition {
            case .restore:
                consequences.anchorIntegrityChange = 20
            case .degrade:
                consequences.anchorIntegrityChange = -20
            }
        }

        // Result message from result key
        if let resultKey = resultKey {
            consequences.message = resultKey.replacingOccurrences(of: "_", with: " ").capitalized
        }

        return consequences
    }
}
