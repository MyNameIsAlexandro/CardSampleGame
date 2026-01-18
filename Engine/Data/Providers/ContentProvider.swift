import Foundation

// MARK: - Content Provider Protocol
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.3
// Reference: Docs/MIGRATION_PLAN.md, Feature A3

/// Protocol for loading game content definitions.
/// Abstracts the source of content (code, JSON, database, etc.)
protocol ContentProvider {
    // MARK: - Regions

    /// Get all region definitions
    func getAllRegionDefinitions() -> [RegionDefinition]

    /// Get a specific region by ID
    func getRegionDefinition(id: String) -> RegionDefinition?

    // MARK: - Anchors

    /// Get all anchor definitions
    func getAllAnchorDefinitions() -> [AnchorDefinition]

    /// Get a specific anchor by ID
    func getAnchorDefinition(id: String) -> AnchorDefinition?

    /// Get anchor for a region
    func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition?

    // MARK: - Events

    /// Get all event definitions
    func getAllEventDefinitions() -> [EventDefinition]

    /// Get a specific event by ID
    func getEventDefinition(id: String) -> EventDefinition?

    /// Get events for a specific region
    func getEventDefinitions(forRegion regionId: String) -> [EventDefinition]

    /// Get events for a specific pool
    func getEventDefinitions(forPool poolId: String) -> [EventDefinition]

    // MARK: - Quests

    /// Get all quest definitions
    func getAllQuestDefinitions() -> [QuestDefinition]

    /// Get a specific quest by ID
    func getQuestDefinition(id: String) -> QuestDefinition?

    // MARK: - Mini-Game Challenges

    /// Get all mini-game challenge definitions
    func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition]

    /// Get a specific challenge by ID
    func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition?

    // MARK: - Validation

    /// Validate all content for consistency
    func validate() -> [ContentValidationError]
}

// MARK: - Content Validation Error

/// Error found during content validation
struct ContentValidationError: Equatable, CustomStringConvertible {
    /// Type of validation error
    let type: ErrorType

    /// Affected definition ID
    let definitionId: String

    /// Detailed error message
    let message: String

    var description: String {
        return "[\(type.rawValue)] \(definitionId): \(message)"
    }

    enum ErrorType: String, Equatable {
        case duplicateId = "DUPLICATE_ID"
        case brokenReference = "BROKEN_REFERENCE"
        case invalidRange = "INVALID_RANGE"
        case missingRequired = "MISSING_REQUIRED"
        case emptyChoices = "EMPTY_CHOICES"
        case invalidLocalizationKey = "INVALID_KEY"
        case circularReference = "CIRCULAR_REF"
    }
}

// MARK: - Content Validator

/// Validates content from a provider
struct ContentValidator {
    let provider: ContentProvider

    init(provider: ContentProvider) {
        self.provider = provider
    }

    /// Run all validation checks
    func validate() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        errors.append(contentsOf: validateUniqueIds())
        errors.append(contentsOf: validateRegionReferences())
        errors.append(contentsOf: validateAnchorReferences())
        errors.append(contentsOf: validateEventReferences())
        errors.append(contentsOf: validateQuestReferences())
        errors.append(contentsOf: validateEventChoices())
        errors.append(contentsOf: validateRanges())

        return errors
    }

    // MARK: - Validation Checks

    /// Check for duplicate IDs within each type
    private func validateUniqueIds() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        // Regions
        let regionIds = provider.getAllRegionDefinitions().map { $0.id }
        for (id, count) in Dictionary(grouping: regionIds, by: { $0 }).filter({ $0.value.count > 1 }) {
            errors.append(ContentValidationError(
                type: .duplicateId,
                definitionId: id,
                message: "Region ID appears \(count.count) times"
            ))
        }

        // Events
        let eventIds = provider.getAllEventDefinitions().map { $0.id }
        for (id, count) in Dictionary(grouping: eventIds, by: { $0 }).filter({ $0.value.count > 1 }) {
            errors.append(ContentValidationError(
                type: .duplicateId,
                definitionId: id,
                message: "Event ID appears \(count.count) times"
            ))
        }

        // Quests
        let questIds = provider.getAllQuestDefinitions().map { $0.id }
        for (id, count) in Dictionary(grouping: questIds, by: { $0 }).filter({ $0.value.count > 1 }) {
            errors.append(ContentValidationError(
                type: .duplicateId,
                definitionId: id,
                message: "Quest ID appears \(count.count) times"
            ))
        }

        return errors
    }

    /// Check that region neighbor references exist
    private func validateRegionReferences() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []
        let allRegionIds = Set(provider.getAllRegionDefinitions().map { $0.id })

        for region in provider.getAllRegionDefinitions() {
            for neighborId in region.neighborIds {
                if !allRegionIds.contains(neighborId) {
                    errors.append(ContentValidationError(
                        type: .brokenReference,
                        definitionId: region.id,
                        message: "Neighbor '\(neighborId)' does not exist"
                    ))
                }
            }
        }

        return errors
    }

    /// Check that anchor region references exist
    private func validateAnchorReferences() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []
        let allRegionIds = Set(provider.getAllRegionDefinitions().map { $0.id })

        for anchor in provider.getAllAnchorDefinitions() {
            if !allRegionIds.contains(anchor.regionId) {
                errors.append(ContentValidationError(
                    type: .brokenReference,
                    definitionId: anchor.id,
                    message: "Region '\(anchor.regionId)' does not exist"
                ))
            }
        }

        return errors
    }

    /// Check event references
    private func validateEventReferences() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []
        let allEventIds = Set(provider.getAllEventDefinitions().map { $0.id })
        let allRegionIds = Set(provider.getAllRegionDefinitions().map { $0.id })

        for event in provider.getAllEventDefinitions() {
            // Check region references in availability
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds {
                    if !allRegionIds.contains(regionId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: event.id,
                            message: "Region '\(regionId)' in availability does not exist"
                        ))
                    }
                }
            }

            // Check trigger event references
            for choice in event.choices {
                if let triggerId = choice.consequences.triggerEventId {
                    if !allEventIds.contains(triggerId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: event.id,
                            message: "Trigger event '\(triggerId)' in choice '\(choice.id)' does not exist"
                        ))
                    }
                }
            }
        }

        return errors
    }

    /// Check quest references
    private func validateQuestReferences() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []
        let allEventIds = Set(provider.getAllEventDefinitions().map { $0.id })
        let allRegionIds = Set(provider.getAllRegionDefinitions().map { $0.id })

        for quest in provider.getAllQuestDefinitions() {
            let objectiveIds = Set(quest.objectives.map { $0.id })

            for objective in quest.objectives {
                // Check next objective reference
                if let nextId = objective.nextObjectiveId, !objectiveIds.contains(nextId) {
                    errors.append(ContentValidationError(
                        type: .brokenReference,
                        definitionId: quest.id,
                        message: "Objective '\(objective.id)' references non-existent next '\(nextId)'"
                    ))
                }

                // Check completion condition references
                switch objective.completionCondition {
                case .eventCompleted(let eventId):
                    if !allEventIds.contains(eventId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: quest.id,
                            message: "Objective '\(objective.id)' references non-existent event '\(eventId)'"
                        ))
                    }
                case .visitRegion(let regionId):
                    if !allRegionIds.contains(regionId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: quest.id,
                            message: "Objective '\(objective.id)' references non-existent region '\(regionId)'"
                        ))
                    }
                case .choiceMade(let eventId, _):
                    if !allEventIds.contains(eventId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: quest.id,
                            message: "Objective '\(objective.id)' references non-existent event '\(eventId)'"
                        ))
                    }
                default:
                    break
                }
            }
        }

        return errors
    }

    /// Check that events have valid choices
    private func validateEventChoices() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        for event in provider.getAllEventDefinitions() {
            // Inline events should have at least 2 choices
            if case .inline = event.eventKind {
                if event.choices.isEmpty {
                    errors.append(ContentValidationError(
                        type: .emptyChoices,
                        definitionId: event.id,
                        message: "Inline event has no choices"
                    ))
                } else if event.choices.count < 2 {
                    errors.append(ContentValidationError(
                        type: .emptyChoices,
                        definitionId: event.id,
                        message: "Inline event should have at least 2 choices"
                    ))
                }
            }

            // Check for duplicate choice IDs within event
            let choiceIds = event.choices.map { $0.id }
            for (id, count) in Dictionary(grouping: choiceIds, by: { $0 }).filter({ $0.value.count > 1 }) {
                errors.append(ContentValidationError(
                    type: .duplicateId,
                    definitionId: event.id,
                    message: "Choice ID '\(id)' appears \(count.count) times"
                ))
            }
        }

        return errors
    }

    /// Check pressure/balance ranges are valid
    private func validateRanges() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        for event in provider.getAllEventDefinitions() {
            // Check pressure range
            if let min = event.availability.minPressure, let max = event.availability.maxPressure {
                if min > max {
                    errors.append(ContentValidationError(
                        type: .invalidRange,
                        definitionId: event.id,
                        message: "minPressure (\(min)) > maxPressure (\(max))"
                    ))
                }
            }

            // Check balance range
            if let min = event.availability.minBalance, let max = event.availability.maxBalance {
                if min > max {
                    errors.append(ContentValidationError(
                        type: .invalidRange,
                        definitionId: event.id,
                        message: "minBalance (\(min)) > maxBalance (\(max))"
                    ))
                }
            }

            // Check choice requirements
            for choice in event.choices {
                if let range = choice.requirements?.balanceRange {
                    if range.lowerBound < -100 || range.upperBound > 100 {
                        errors.append(ContentValidationError(
                            type: .invalidRange,
                            definitionId: event.id,
                            message: "Choice '\(choice.id)' has balance range outside -100...100"
                        ))
                    }
                }
            }
        }

        return errors
    }
}
