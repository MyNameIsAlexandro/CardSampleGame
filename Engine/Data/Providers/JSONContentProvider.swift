import Foundation

// MARK: - JSON Content Provider
// Reference: Docs/MIGRATION_PLAN.md, Feature A3 / EPIC D
// Placeholder for Phase 5 - Real cartridge-data-driven

/// Content provider that loads definitions from JSON files.
/// This is the "cartridge" approach - content as external data.
///
/// **Phase 5 Implementation:**
/// - Load JSON from Resources/Content/
/// - Validate on load
/// - Support hot-reload for development
class JSONContentProvider: ContentProvider {
    // MARK: - Configuration

    /// Base path for content JSON files
    let contentPath: String

    /// Bundle containing content (nil = main bundle)
    let bundle: Bundle?

    // MARK: - Cached Definitions

    private var regions: [String: RegionDefinition] = [:]
    private var anchors: [String: AnchorDefinition] = [:]
    private var events: [String: EventDefinition] = [:]
    private var quests: [String: QuestDefinition] = [:]
    private var miniGameChallenges: [String: MiniGameChallengeDefinition] = [:]

    // MARK: - Event Indices

    private var eventsByPool: [String: [EventDefinition]] = [:]
    private var eventsByRegion: [String: [EventDefinition]] = [:]

    // MARK: - Initialization

    init(contentPath: String = "Content", bundle: Bundle? = nil) {
        self.contentPath = contentPath
        self.bundle = bundle

        // TODO: Phase 5 - Load from JSON
        // loadAllContent()
    }

    // MARK: - Loading (Phase 5)

    /// Load all content from JSON files
    /// TODO: Implement in Phase 5
    func loadAllContent() throws {
        // Expected structure:
        // Resources/Content/
        //   regions.json
        //   anchors.json
        //   events/
        //     pool_common.json
        //     pool_forest.json
        //   quests.json
        //   challenges.json

        fatalError("JSONContentProvider not yet implemented - Phase 5")
    }

    /// Reload content (for development hot-reload)
    func reloadContent() throws {
        regions.removeAll()
        anchors.removeAll()
        events.removeAll()
        quests.removeAll()
        miniGameChallenges.removeAll()
        eventsByPool.removeAll()
        eventsByRegion.removeAll()

        try loadAllContent()
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
        guard let region = regions[regionId] else { return [] }

        var result: [EventDefinition] = []
        for poolId in region.eventPoolIds {
            result.append(contentsOf: eventsByPool[poolId] ?? [])
        }
        result.append(contentsOf: eventsByRegion[regionId] ?? [])

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

// MARK: - JSON Schemas (Phase 5)

/*
Expected JSON format for regions.json:

{
  "regions": [
    {
      "id": "forest",
      "titleKey": "region.forest.title",
      "descriptionKey": "region.forest.description",
      "neighborIds": ["village", "crossroads"],
      "initiallyDiscovered": true,
      "anchorId": "anchor_forest",
      "eventPoolIds": ["pool_forest", "pool_common"],
      "initialState": "stable",
      "degradationWeight": 1
    }
  ]
}

Expected JSON format for events:

{
  "events": [
    {
      "id": "event_forest_whispers",
      "titleKey": "event.forest_whispers.title",
      "bodyKey": "event.forest_whispers.body",
      "eventType": "inline",
      "availability": {
        "regionStates": ["stable", "borderland"],
        "minPressure": 0,
        "maxPressure": 60
      },
      "poolIds": ["pool_forest"],
      "weight": 10,
      "isOneTime": false,
      "choices": [
        {
          "id": "listen",
          "labelKey": "event.forest_whispers.listen",
          "consequences": {
            "resourceChanges": {"faith": -2},
            "setFlags": ["heard_whispers"]
          }
        },
        {
          "id": "ignore",
          "labelKey": "event.forest_whispers.ignore",
          "consequences": {
            "resourceChanges": {"health": -1}
          }
        }
      ]
    }
  ]
}
*/
