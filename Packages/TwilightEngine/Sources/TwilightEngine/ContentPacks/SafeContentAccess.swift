import Foundation

// MARK: - Safe Content Access

/// Provides safe, validated access to content with comprehensive error handling.
/// Use this instead of direct ContentRegistry access in production code.
public final class SafeContentAccess {

    // MARK: - Singleton

    /// Shared instance wrapping ContentRegistry.shared
    public static let shared = SafeContentAccess(registry: ContentRegistry.shared)

    // MARK: - Properties

    private let registry: ContentRegistry
    private var validationPerformed = false
    private var cachedValidationErrors: [ContentValidationError] = []

    // MARK: - Initialization

    public init(registry: ContentRegistry) {
        self.registry = registry
    }

    // MARK: - Validation

    /// Result of content validation
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [ContentValidationError]
        public let warnings: [ContentValidationWarning]
        public let contentSummary: ContentSummary

        public var hasErrors: Bool { !errors.isEmpty }
        public var hasWarnings: Bool { !warnings.isEmpty }
    }

    /// Warning about content issues (non-fatal)
    public struct ContentValidationWarning: CustomStringConvertible {
        public let type: WarningType
        public let contentId: String
        public let message: String

        public var description: String {
            "[\(type.rawValue)] \(contentId): \(message)"
        }

        public enum WarningType: String {
            case partialContent = "PARTIAL"
            case missingOptional = "MISSING_OPTIONAL"
            case deprecatedField = "DEPRECATED"
            case crossPackReference = "CROSS_PACK"
        }
    }

    /// Summary of loaded content
    public struct ContentSummary {
        public let heroCount: Int
        public let cardCount: Int
        public let enemyCount: Int
        public let eventCount: Int
        public let regionCount: Int
        public let questCount: Int
        public let anchorCount: Int
        public let fateCardCount: Int
        public let behaviorCount: Int
        public let hasBalanceConfig: Bool

        public var isEmpty: Bool {
            heroCount == 0 && cardCount == 0 && enemyCount == 0
        }

        public var isMinimallyPlayable: Bool {
            heroCount > 0 && fateCardCount > 0
        }
    }

    /// Perform comprehensive validation of all loaded content.
    /// Call this after loading packs and before starting gameplay.
    @discardableResult
    public func validateAllContent() -> ValidationResult {
        var errors: [ContentValidationError] = []
        var warnings: [ContentValidationWarning] = []

        // 1. Basic validation from registry
        errors.append(contentsOf: registry.validateAllContent())
        errors.append(contentsOf: registry.validateContentRequirements())

        // 2. Validate all heroes have complete starting decks
        validateHeroStartingDecks(errors: &errors, warnings: &warnings)

        // 3. Validate enemy references
        validateEnemyReferences(errors: &errors, warnings: &warnings)

        // 4. Validate event chain integrity
        validateEventChains(errors: &errors, warnings: &warnings)

        // 5. Validate fate cards exist
        validateFateCards(errors: &errors, warnings: &warnings)

        // 6. Validate quest objective references
        validateQuestObjectives(errors: &errors, warnings: &warnings)

        // Cache results
        cachedValidationErrors = errors
        validationPerformed = true

        let summary = buildContentSummary()

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            contentSummary: summary
        )
    }

    // MARK: - Safe Accessors

    /// Safely get hero with validation
    public func getHero(id: String) -> Result<StandardHeroDefinition, ContentAccessError> {
        guard let hero = registry.getHero(id: id) else {
            return .failure(.notFound(type: "Hero", id: id))
        }
        return .success(hero)
    }

    /// Safely get hero's starting deck with complete validation
    public func getStartingDeck(forHero heroId: String) -> Result<[StandardCardDefinition], ContentAccessError> {
        guard let hero = registry.getHero(id: heroId) else {
            return .failure(.notFound(type: "Hero", id: heroId))
        }

        var cards: [StandardCardDefinition] = []
        var missingIds: [String] = []

        for cardId in hero.startingDeckCardIDs {
            if let card = registry.getCard(id: cardId) {
                cards.append(card)
            } else {
                missingIds.append(cardId)
            }
        }

        if !missingIds.isEmpty {
            return .failure(.incompleteContent(
                type: "StartingDeck",
                id: heroId,
                missing: missingIds
            ))
        }

        return .success(cards)
    }

    /// Safely get enemy definition
    public func getEnemy(id: String) -> Result<EnemyDefinition, ContentAccessError> {
        guard let enemy = registry.getEnemy(id: id) else {
            return .failure(.notFound(type: "Enemy", id: id))
        }
        return .success(enemy)
    }

    /// Safely get card definition
    public func getCard(id: String) -> Result<StandardCardDefinition, ContentAccessError> {
        guard let card = registry.getCard(id: id) else {
            return .failure(.notFound(type: "Card", id: id))
        }
        return .success(card)
    }

    /// Safely get event definition
    public func getEvent(id: String) -> Result<EventDefinition, ContentAccessError> {
        guard let event = registry.getEvent(id: id) else {
            return .failure(.notFound(type: "Event", id: id))
        }
        return .success(event)
    }

    /// Safely get region definition
    public func getRegion(id: String) -> Result<RegionDefinition, ContentAccessError> {
        guard let region = registry.getRegion(id: id) else {
            return .failure(.notFound(type: "Region", id: id))
        }
        return .success(region)
    }

    /// Safely get fate cards with minimum count validation
    public func getFateCards(minimumCount: Int = 1) -> Result<[FateCard], ContentAccessError> {
        let fateCards = registry.getAllFateCards()

        if fateCards.count < minimumCount {
            return .failure(.insufficientContent(
                type: "FateCards",
                required: minimumCount,
                found: fateCards.count
            ))
        }

        return .success(fateCards)
    }

    /// Get all heroes that have complete, valid starting decks
    public func getPlayableHeroes() -> [StandardHeroDefinition] {
        return registry.getAllHeroes().filter { hero in
            let deck = registry.getStartingDeck(forHero: hero.id)
            return deck.count == hero.startingDeckCardIDs.count
        }
    }

    /// Check if content is ready for gameplay with specific requirements
    public func isReadyForGameplay(
        requireHeroes: Bool = true,
        requireFateCards: Bool = true,
        requireEnemies: Bool = false
    ) -> Result<Void, ContentAccessError> {

        if requireHeroes && registry.getAllHeroes().isEmpty {
            return .failure(.insufficientContent(type: "Heroes", required: 1, found: 0))
        }

        if requireFateCards && registry.getAllFateCards().isEmpty {
            return .failure(.insufficientContent(type: "FateCards", required: 1, found: 0))
        }

        if requireEnemies && registry.getAllEnemies().isEmpty {
            return .failure(.insufficientContent(type: "Enemies", required: 1, found: 0))
        }

        // Check that at least one hero has a complete deck
        let playableHeroes = getPlayableHeroes()
        if requireHeroes && playableHeroes.isEmpty {
            return .failure(.noPlayableContent(reason: "No heroes have complete starting decks"))
        }

        return .success(())
    }

    // MARK: - Private Validation Methods

    private func validateHeroStartingDecks(
        errors: inout [ContentValidationError],
        warnings: inout [ContentValidationWarning]
    ) {
        for hero in registry.getAllHeroes() {
            var missingCards: [String] = []

            for cardId in hero.startingDeckCardIDs {
                if registry.getCard(id: cardId) == nil {
                    missingCards.append(cardId)
                }
            }

            if !missingCards.isEmpty {
                errors.append(ContentValidationError(
                    type: .brokenReference,
                    definitionId: hero.id,
                    message: "Hero starting deck missing cards: \(missingCards.joined(separator: ", "))"
                ))
            }

            // Warn if deck is empty
            if hero.startingDeckCardIDs.isEmpty {
                warnings.append(ContentValidationWarning(
                    type: .missingOptional,
                    contentId: hero.id,
                    message: "Hero has no starting deck cards defined"
                ))
            }
        }
    }

    private func validateEnemyReferences(
        errors: inout [ContentValidationError],
        warnings: inout [ContentValidationWarning]
    ) {
        for enemy in registry.getAllEnemies() {
            // Validate loot card references
            for lootCardId in enemy.lootCardIds {
                if registry.getCard(id: lootCardId) == nil {
                    warnings.append(ContentValidationWarning(
                        type: .crossPackReference,
                        contentId: enemy.id,
                        message: "Enemy loot references card '\(lootCardId)' not in loaded packs"
                    ))
                }
            }

            // Validate health is positive
            if enemy.health <= 0 {
                errors.append(ContentValidationError(
                    type: .invalidRange,
                    definitionId: enemy.id,
                    message: "Enemy has non-positive health: \(enemy.health)"
                ))
            }

            // Validate difficulty range
            if enemy.difficulty < 1 || enemy.difficulty > 10 {
                warnings.append(ContentValidationWarning(
                    type: .missingOptional,
                    contentId: enemy.id,
                    message: "Enemy difficulty \(enemy.difficulty) outside expected range 1-10"
                ))
            }
        }
    }

    private func validateEventChains(
        errors: inout [ContentValidationError],
        warnings: inout [ContentValidationWarning]
    ) {
        let allEventIds = Set(registry.getAllEvents().map { $0.id })

        for event in registry.getAllEvents() {
            for choice in event.choices {
                // Check trigger event exists
                if let triggerId = choice.consequences.triggerEventId {
                    if !allEventIds.contains(triggerId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: event.id,
                            message: "Choice '\(choice.id)' triggers non-existent event '\(triggerId)'"
                        ))
                    }
                }

                // Note: Combat encounters are triggered via event kind, not choice consequences
                // Enemy references are validated separately in validateEnemyReferences
            }
        }
    }

    private func validateFateCards(
        errors: inout [ContentValidationError],
        warnings: inout [ContentValidationWarning]
    ) {
        let fateCards = registry.getAllFateCards()

        if fateCards.isEmpty {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "fate-deck",
                message: "No fate cards loaded - combat system requires fate deck"
            ))
        } else if fateCards.count < 10 {
            warnings.append(ContentValidationWarning(
                type: .partialContent,
                contentId: "fate-deck",
                message: "Only \(fateCards.count) fate cards loaded - recommend at least 10"
            ))
        }

        // Validate fate card values are in expected range
        for card in fateCards {
            if card.baseValue < -2 || card.baseValue > 3 {
                warnings.append(ContentValidationWarning(
                    type: .missingOptional,
                    contentId: card.id,
                    message: "Fate card value \(card.baseValue) outside typical range -2 to +3"
                ))
            }
        }
    }

    private func validateQuestObjectives(
        errors: inout [ContentValidationError],
        warnings: inout [ContentValidationWarning]
    ) {
        let allEventIds = Set(registry.getAllEvents().map { $0.id })
        let allRegionIds = Set(registry.getAllRegions().map { $0.id })

        for quest in registry.getAllQuests() {
            let objectiveIds = Set(quest.objectives.map { $0.id })
            var visitedObjectives: Set<String> = []

            for objective in quest.objectives {
                // Check for circular references
                if let nextId = objective.nextObjectiveId {
                    if !objectiveIds.contains(nextId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: quest.id,
                            message: "Objective '\(objective.id)' references non-existent next '\(nextId)'"
                        ))
                    }

                    // Simple circular reference check
                    if visitedObjectives.contains(nextId) {
                        warnings.append(ContentValidationWarning(
                            type: .crossPackReference,
                            contentId: quest.id,
                            message: "Possible circular reference in objective chain at '\(objective.id)'"
                        ))
                    }
                }
                visitedObjectives.insert(objective.id)

                // Validate completion condition references
                switch objective.completionCondition {
                case .eventCompleted(let eventId):
                    if !allEventIds.contains(eventId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: quest.id,
                            message: "Objective '\(objective.id)' requires non-existent event '\(eventId)'"
                        ))
                    }
                case .visitRegion(let regionId):
                    if !allRegionIds.contains(regionId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: quest.id,
                            message: "Objective '\(objective.id)' requires non-existent region '\(regionId)'"
                        ))
                    }
                case .choiceMade(let eventId, _):
                    if !allEventIds.contains(eventId) {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: quest.id,
                            message: "Objective '\(objective.id)' requires choice in non-existent event '\(eventId)'"
                        ))
                    }
                default:
                    break
                }
            }
        }
    }

    private func buildContentSummary() -> ContentSummary {
        ContentSummary(
            heroCount: registry.getAllHeroes().count,
            cardCount: registry.getAllCards().count,
            enemyCount: registry.getAllEnemies().count,
            eventCount: registry.getAllEvents().count,
            regionCount: registry.getAllRegions().count,
            questCount: registry.getAllQuests().count,
            anchorCount: registry.getAllAnchors().count,
            fateCardCount: registry.getAllFateCards().count,
            behaviorCount: registry.allBehaviors.count,
            hasBalanceConfig: registry.getBalanceConfig() != nil
        )
    }

    // MARK: - Reset (Testing)

    /// Reset validation state (for testing)
    public func resetValidation() {
        validationPerformed = false
        cachedValidationErrors = []
    }
}

// MARK: - Content Access Error

/// Error when accessing content fails
public enum ContentAccessError: Error, LocalizedError {
    case notFound(type: String, id: String)
    case incompleteContent(type: String, id: String, missing: [String])
    case insufficientContent(type: String, required: Int, found: Int)
    case noPlayableContent(reason: String)
    case validationFailed(errors: [ContentValidationError])

    public var errorDescription: String? {
        switch self {
        case .notFound(let type, let id):
            return "\(type) '\(id)' not found in loaded content"
        case .incompleteContent(let type, let id, let missing):
            return "\(type) '\(id)' is incomplete, missing: \(missing.joined(separator: ", "))"
        case .insufficientContent(let type, let required, let found):
            return "Insufficient \(type): required \(required), found \(found)"
        case .noPlayableContent(let reason):
            return "No playable content: \(reason)"
        case .validationFailed(let errors):
            return "Content validation failed with \(errors.count) errors"
        }
    }
}
