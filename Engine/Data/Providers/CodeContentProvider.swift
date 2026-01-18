import Foundation

// MARK: - Code Content Provider
// Reference: Docs/MIGRATION_PLAN.md, Feature A3
// Adapter for existing TwilightMarchesConfig content

/// Content provider that loads definitions from Swift code.
/// This is an adapter for the existing TwilightMarchesConfig.swift content.
/// Will be replaced/augmented by JSONContentProvider in Phase 5.
class CodeContentProvider: ContentProvider {
    // MARK: - Cached Definitions

    private var regions: [String: RegionDefinition] = [:]
    private var anchors: [String: AnchorDefinition] = [:]
    private var events: [String: EventDefinition] = [:]
    private var quests: [String: QuestDefinition] = [:]
    private var miniGameChallenges: [String: MiniGameChallengeDefinition] = [:]

    // MARK: - Event Pool Index

    private var eventsByPool: [String: [EventDefinition]] = [:]
    private var eventsByRegion: [String: [EventDefinition]] = [:]

    // MARK: - Initialization

    init() {
        loadContent()
    }

    /// Load all content from code definitions
    private func loadContent() {
        loadRegions()
        loadAnchors()
        loadEvents()
        loadQuests()
        loadMiniGameChallenges()
        buildEventIndices()
    }

    // MARK: - Content Loading (Override in subclass for actual content)

    /// Load region definitions
    /// Subclass should override to provide actual regions
    func loadRegions() {
        // Default implementation - subclass overrides with actual content
        // Example region for testing:
        let forest = RegionDefinition(
            id: "forest",
            titleKey: "region.forest.title",
            descriptionKey: "region.forest.description",
            neighborIds: ["village", "crossroads"],
            initiallyDiscovered: true,
            anchorId: "anchor_forest",
            eventPoolIds: ["pool_forest", "pool_common"],
            initialState: .stable
        )
        regions[forest.id] = forest
    }

    /// Load anchor definitions
    func loadAnchors() {
        // Default implementation - subclass overrides
        let forestAnchor = AnchorDefinition(
            id: "anchor_forest",
            titleKey: "anchor.forest.title",
            descriptionKey: "anchor.forest.description",
            regionId: "forest"
        )
        anchors[forestAnchor.id] = forestAnchor
    }

    /// Load event definitions
    func loadEvents() {
        // Default implementation - subclass overrides
        let testEvent = EventDefinition(
            id: "event_test",
            titleKey: "event.test.title",
            bodyKey: "event.test.body",
            eventType: .inline,
            poolIds: ["pool_common"],
            choices: [
                ChoiceDefinition(
                    id: "choice_a",
                    labelKey: "event.test.choice_a",
                    consequences: ChoiceConsequences(resourceChanges: ["faith": -2])
                ),
                ChoiceDefinition(
                    id: "choice_b",
                    labelKey: "event.test.choice_b",
                    consequences: ChoiceConsequences(resourceChanges: ["health": -3])
                )
            ]
        )
        events[testEvent.id] = testEvent
    }

    /// Load quest definitions
    func loadQuests() {
        // Default implementation - subclass overrides
        let testQuest = QuestDefinition(
            id: "quest_test",
            titleKey: "quest.test.title",
            descriptionKey: "quest.test.description",
            objectives: [
                ObjectiveDefinition(
                    id: "obj_1",
                    descriptionKey: "quest.test.obj1",
                    completionCondition: .manual,
                    nextObjectiveId: "obj_2"
                ),
                ObjectiveDefinition(
                    id: "obj_2",
                    descriptionKey: "quest.test.obj2",
                    completionCondition: .manual
                )
            ]
        )
        quests[testQuest.id] = testQuest
    }

    /// Load mini-game challenge definitions
    func loadMiniGameChallenges() {
        // Default implementation - subclass overrides
        let testCombat = MiniGameChallengeDefinition(
            id: "combat_test",
            challengeType: .combat,
            difficulty: 5
        )
        miniGameChallenges[testCombat.id] = testCombat
    }

    /// Build event indices for fast lookup
    private func buildEventIndices() {
        eventsByPool.removeAll()
        eventsByRegion.removeAll()

        for event in events.values {
            // Index by pool
            for poolId in event.poolIds {
                eventsByPool[poolId, default: []].append(event)
            }

            // Index by region (from availability)
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds {
                    eventsByRegion[regionId, default: []].append(event)
                }
            }
        }
    }

    // MARK: - Registration (for building content)

    func registerRegion(_ region: RegionDefinition) {
        regions[region.id] = region
    }

    func registerAnchor(_ anchor: AnchorDefinition) {
        anchors[anchor.id] = anchor
    }

    func registerEvent(_ event: EventDefinition) {
        events[event.id] = event
    }

    func registerQuest(_ quest: QuestDefinition) {
        quests[quest.id] = quest
    }

    func registerMiniGameChallenge(_ challenge: MiniGameChallengeDefinition) {
        miniGameChallenges[challenge.id] = challenge
    }

    func rebuildIndices() {
        buildEventIndices()
    }

    // MARK: - ContentProvider Implementation

    func getAllRegionDefinitions() -> [RegionDefinition] {
        return Array(regions.values)
    }

    func getRegionDefinition(id: String) -> RegionDefinition? {
        return regions[id]
    }

    func getAllAnchorDefinitions() -> [AnchorDefinition] {
        return Array(anchors.values)
    }

    func getAnchorDefinition(id: String) -> AnchorDefinition? {
        return anchors[id]
    }

    func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition? {
        return anchors.values.first { $0.regionId == regionId }
    }

    func getAllEventDefinitions() -> [EventDefinition] {
        return Array(events.values)
    }

    func getEventDefinition(id: String) -> EventDefinition? {
        return events[id]
    }

    func getEventDefinitions(forRegion regionId: String) -> [EventDefinition] {
        // Get events from region's pools
        guard let region = regions[regionId] else { return [] }

        var result: [EventDefinition] = []
        for poolId in region.eventPoolIds {
            result.append(contentsOf: eventsByPool[poolId] ?? [])
        }

        // Add events specifically for this region
        result.append(contentsOf: eventsByRegion[regionId] ?? [])

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }
    }

    func getEventDefinitions(forPool poolId: String) -> [EventDefinition] {
        return eventsByPool[poolId] ?? []
    }

    func getAllQuestDefinitions() -> [QuestDefinition] {
        return Array(quests.values)
    }

    func getQuestDefinition(id: String) -> QuestDefinition? {
        return quests[id]
    }

    func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition] {
        return Array(miniGameChallenges.values)
    }

    func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition? {
        return miniGameChallenges[id]
    }

    func validate() -> [ContentValidationError] {
        let validator = ContentValidator(provider: self)
        return validator.validate()
    }
}
