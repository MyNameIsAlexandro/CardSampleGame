import Foundation

// MARK: - Event Definition Adapter
// Converts EventDefinition (new data-driven) to GameEvent (legacy UI-compatible)
// This enables using content packs while maintaining compatibility with existing UI

extension EventDefinition {

    /// Convert EventDefinition to legacy GameEvent for UI compatibility
    /// - Parameter regionId: Optional region ID for context-specific conversion
    /// - Returns: GameEvent compatible with existing UI
    func toGameEvent(forRegion regionId: String? = nil) -> GameEvent {
        // Generate deterministic UUID from string ID for consistency
        let eventUUID = UUID(uuidString: id.md5UUID) ?? UUID()

        // Map event kind to legacy event type
        let eventType = mapEventKind(eventKind)

        // Map region states from availability
        let regionStates = mapRegionStates(availability.regionStates)

        // Map region types (infer from region IDs if needed)
        let regionTypes = mapRegionTypes(availability.regionIds)

        // Convert choices
        let eventChoices = choices.map { $0.toEventChoice() }

        // Create monster card for combat events
        let monsterCard = createMonsterCard(for: miniGameChallenge)

        return GameEvent(
            id: eventUUID,
            definitionId: id,  // Content Pack ID (e.g., "village_elder_request")
            eventType: eventType,
            title: title.localized,
            description: body.localized,
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

    private func mapRegionTypes(_ regionIds: [String]?) -> [RegionType] {
        guard let ids = regionIds else {
            return [] // Empty = any region type
        }

        // Look up region types from ContentRegistry (no hardcoded ID mapping)
        var types = Set<RegionType>()
        for regionId in ids {
            if let regionDef = ContentRegistry.shared.getRegion(id: regionId) {
                // Map regionType string from definition to RegionType enum
                let regionType = mapRegionTypeString(regionDef.regionType)
                types.insert(regionType)
            }
        }
        return Array(types)
    }

    private func mapRegionTypeString(_ typeString: String) -> RegionType {
        switch typeString.lowercased() {
        case "settlement": return .settlement
        case "forest": return .forest
        case "swamp": return .swamp
        case "wasteland": return .wasteland
        case "sacred": return .sacred
        case "mountain": return .mountain
        case "water": return .water
        default: return .forest
        }
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

    private func createMonsterCard(for challenge: MiniGameChallengeDefinition?) -> Card? {
        guard let challenge = challenge,
              let enemyId = challenge.enemyId else { return nil }

        // First, try to get enemy from ContentRegistry
        if let enemy = ContentRegistry.shared.getEnemy(id: enemyId) {
            return enemy.toCard()
        }

        // Fallback: Create from hardcoded stats
        let enemyStats = getEnemyStats(for: enemyId, difficulty: challenge.difficulty)

        return Card(
            id: UUID(),
            definitionId: enemyId,  // Content Pack ID for tracking
            name: enemyId.replacingOccurrences(of: "_", with: " ").capitalized,
            type: .monster,
            rarity: difficultyToRarity(challenge.difficulty),
            description: "Enemy: \(enemyId)",
            power: enemyStats.power,
            defense: enemyStats.defense,
            health: enemyStats.health
        )
    }

    private func getEnemyStats(for enemyId: String, difficulty: Int) -> (health: Int, power: Int, defense: Int) {
        // Base stats scaled by difficulty
        let baseHealth = 5 + (difficulty * 3)
        let basePower = 2 + difficulty
        let baseDefense = 1 + (difficulty / 2)

        // Enemy-specific adjustments
        switch enemyId {
        case "wild_beast":
            return (health: baseHealth, power: basePower + 1, defense: baseDefense)
        case "leshy":
            return (health: baseHealth + 2, power: basePower, defense: baseDefense + 1)
        case "mountain_spirit":
            return (health: baseHealth + 3, power: basePower + 1, defense: baseDefense + 2)
        case "leshy_guardian_boss":
            return (health: baseHealth + 10, power: basePower + 3, defense: baseDefense + 3)
        default:
            return (health: baseHealth, power: basePower, defense: baseDefense)
        }
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
    func toEventChoice() -> EventChoice {
        return EventChoice(
            id: id,
            text: label.localized,
            requirements: requirements?.toEventRequirements(),
            consequences: consequences.toEventConsequences()
        )
    }
}

// MARK: - Choice Requirements Conversion

extension ChoiceRequirements {

    /// Convert to legacy EventRequirements
    func toEventRequirements() -> EventRequirements {
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
    func toEventConsequences() -> EventConsequences {
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

// MARK: - String UUID Extension

private extension String {
    /// Generate a deterministic UUID-like string from this string
    var md5UUID: String {
        // Simple hash-based UUID generation for determinism
        var hash: UInt64 = 5381
        for char in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }

        // Format as UUID string (simplified)
        let hex = String(format: "%016llX", hash)
        let padded = hex.padding(toLength: 32, withPad: "0", startingAt: 0)

        // Insert dashes: 8-4-4-4-12
        let chars = Array(padded)
        return "\(String(chars[0..<8]))-\(String(chars[8..<12]))-\(String(chars[12..<16]))-\(String(chars[16..<20]))-\(String(chars[20..<32]))"
    }
}
