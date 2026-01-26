import XCTest
@testable import TwilightEngine

/// Content Validation Tests - validates cross-references in JSON content
/// Prevents "silent failures" where typos cause conditions to never match
///
/// **Risk Mitigation:**
/// - Typo in flag name → condition never triggers
/// - Typo in region ID → event never appears in that region
/// - Typo in quest ID → quest progress never registers
/// - Typo in resource ID → requirement check fails silently
final class ContentValidationTests: XCTestCase {

    // MARK: - Test Data

    private var loadedPack: LoadedPack?
    private var allRegionIds: Set<String> = []
    private var allEventIds: Set<String> = []
    private var allQuestIds: Set<String> = []
    private var allCardIds: Set<String> = []
    private var allHeroIds: Set<String> = []
    private var allEnemyIds: Set<String> = []
    private var allAnchorIds: Set<String> = []

    // Known valid flags (defined by game logic, not JSON)
    private let systemFlags: Set<String> = [
        // Quest state flags (set by game engine)
        "main_quest_started",
        "act1_complete",
        "act1_failed",
        "act5_completed",

        // Combat/event outcome flags
        "leshy_guardian_defeated",
        "child_found",
        "child_saved",
        "child_saved_reward",
        "oak_strengthened",
        "critical_anchor_destroyed",

        // Player choice flags
        "helped_village",
        "mercenary_path",
        "refused_main_quest",
    ]

    // Known valid resources
    private let knownResources: Set<String> = [
        "health",
        "faith",
        "supplies",
        "gold",
        "balance"
    ]

    // Known valid region states
    private let knownRegionStates: Set<String> = [
        "stable",
        "borderland",
        "breach",
        "corrupted",
        "lost"
    ]

    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Load content pack using TestContentLoader
        TestContentLoader.loadContentPacksIfNeeded()

        // Get loaded pack from registry
        guard let packId = ContentRegistry.shared.loadedPackIds.first(where: { $0.contains("twilight") || $0.contains("act") }),
              let pack = ContentRegistry.shared.loadedPacks[packId] else {
            XCTFail("CONTENT VALIDATION FAILURE: TwilightMarchesActI pack not loaded - check TestContentLoader"); return
        }

        self.loadedPack = pack
        collectKnownIds()
    }

    private func collectKnownIds() {
        guard let pack = loadedPack else { return }

        // Regions (dictionary keys are IDs)
        allRegionIds = Set(pack.regions.keys)

        // Events
        allEventIds = Set(pack.events.keys)

        // Quests
        allQuestIds = Set(pack.quests.keys)

        // Cards
        allCardIds = Set(pack.cards.keys)

        // Heroes
        allHeroIds = Set(pack.heroes.keys)

        // Enemies
        allEnemyIds = Set(pack.enemies.keys)

        // Anchors
        allAnchorIds = Set(pack.anchors.keys)
    }

    // MARK: - Flag Validation

    func testAllReferencedFlagsAreKnown() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        var referencedFlags: Set<String> = []
        var setFlags: Set<String> = []

        // Collect flags from events
        for (_, event) in pack.events {
            // Availability flags
            referencedFlags.formUnion(event.availability.requiredFlags)
            referencedFlags.formUnion(event.availability.forbiddenFlags)

            // Choice flags
            for choice in event.choices {
                if let req = choice.requirements {
                    referencedFlags.formUnion(req.requiredFlags)
                    referencedFlags.formUnion(req.forbiddenFlags)
                }
                setFlags.formUnion(choice.consequences.setFlags)
                setFlags.formUnion(choice.consequences.clearFlags)
            }
        }

        // Collect flags from quests
        for (_, quest) in pack.quests {
            referencedFlags.formUnion(quest.availability.requiredFlags)
            referencedFlags.formUnion(quest.availability.forbiddenFlags)

            setFlags.formUnion(quest.completionRewards.setFlags)
            setFlags.formUnion(quest.failurePenalties.setFlags)
        }

        // All set flags become valid referenced flags
        let allKnownFlags = systemFlags.union(setFlags)

        // Find unknown flags
        let unknownFlags = referencedFlags.subtracting(allKnownFlags)

        if !unknownFlags.isEmpty {
            XCTFail("""
                Found \(unknownFlags.count) unknown flags referenced in conditions:
                \(unknownFlags.sorted().map { "  - \($0)" }.joined(separator: "\n"))

                These flags are checked but never set. Possible causes:
                1. Typo in flag name
                2. Flag is set elsewhere (add to systemFlags in test)
                3. Missing set_flags in consequences
                """)
        }
    }

    // MARK: - Region ID Validation

    func testAllReferencedRegionIdsExist() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        var referencedRegionIds: Set<String> = []

        // From event availability
        for (_, event) in pack.events {
            if let regionIds = event.availability.regionIds {
                referencedRegionIds.formUnion(regionIds)
            }
        }

        // From quest availability
        for (_, quest) in pack.quests {
            if let regionIds = quest.availability.regionIds {
                referencedRegionIds.formUnion(regionIds)
            }
        }

        // From region connections (neighborIds)
        for (_, region) in pack.regions {
            referencedRegionIds.formUnion(region.neighborIds)
        }

        // Find unknown regions
        let unknownRegions = referencedRegionIds.subtracting(allRegionIds)

        if !unknownRegions.isEmpty {
            XCTFail("""
                Found \(unknownRegions.count) unknown region IDs:
                \(unknownRegions.sorted().map { "  - \($0)" }.joined(separator: "\n"))

                Known regions: \(allRegionIds.sorted().joined(separator: ", "))
                """)
        }
    }

    // MARK: - Quest ID Validation

    func testAllReferencedQuestIdsExist() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        var referencedQuestIds: Set<String> = []

        // From event consequences
        for (_, event) in pack.events {
            for choice in event.choices {
                if let questProgress = choice.consequences.questProgress {
                    referencedQuestIds.insert(questProgress.questId)
                }
            }
        }

        // Find unknown quests
        let unknownQuests = referencedQuestIds.subtracting(allQuestIds)

        if !unknownQuests.isEmpty {
            XCTFail("""
                Found \(unknownQuests.count) unknown quest IDs in event consequences:
                \(unknownQuests.sorted().map { "  - \($0)" }.joined(separator: "\n"))

                Known quests: \(allQuestIds.sorted().joined(separator: ", "))
                """)
        }
    }

    // MARK: - Event ID Validation

    func testAllReferencedEventIdsExist() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        var referencedEventIds: Set<String> = []

        // From choice consequences (trigger_event_id)
        for (_, event) in pack.events {
            for choice in event.choices {
                if let triggerId = choice.consequences.triggerEventId {
                    referencedEventIds.insert(triggerId)
                }
            }
        }

        // Find unknown events
        let unknownEvents = referencedEventIds.subtracting(allEventIds)

        if !unknownEvents.isEmpty {
            XCTFail("""
                Found \(unknownEvents.count) unknown event IDs in trigger_event_id:
                \(unknownEvents.sorted().map { "  - \($0)" }.joined(separator: "\n"))

                Known events: \(allEventIds.sorted().joined(separator: ", "))
                """)
        }
    }

    // MARK: - Resource ID Validation

    func testAllReferencedResourceIdsAreKnown() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        var referencedResources: Set<String> = []

        // From event choice requirements and consequences
        for (_, event) in pack.events {
            for choice in event.choices {
                if let req = choice.requirements {
                    referencedResources.formUnion(req.minResources.keys)
                }
                referencedResources.formUnion(choice.consequences.resourceChanges.keys)
            }
        }

        // From quest rewards/penalties
        for (_, quest) in pack.quests {
            referencedResources.formUnion(quest.completionRewards.resourceChanges.keys)
            referencedResources.formUnion(quest.failurePenalties.resourceChanges.keys)
        }

        // Find unknown resources
        let unknownResources = referencedResources.subtracting(knownResources)

        if !unknownResources.isEmpty {
            XCTFail("""
                Found \(unknownResources.count) unknown resource IDs:
                \(unknownResources.sorted().map { "  - \($0)" }.joined(separator: "\n"))

                Known resources: \(knownResources.sorted().joined(separator: ", "))
                """)
        }
    }

    // MARK: - Region State Validation

    func testAllReferencedRegionStatesAreKnown() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        var referencedStates: Set<String> = []

        // From event availability
        for (_, event) in pack.events {
            if let states = event.availability.regionStates {
                referencedStates.formUnion(states)
            }
        }

        // From quest availability
        for (_, quest) in pack.quests {
            if let states = quest.availability.regionStates {
                referencedStates.formUnion(states)
            }
        }

        // Find unknown states
        let unknownStates = referencedStates.subtracting(knownRegionStates)

        if !unknownStates.isEmpty {
            XCTFail("""
                Found \(unknownStates.count) unknown region states:
                \(unknownStates.sorted().map { "  - \($0)" }.joined(separator: "\n"))

                Known states: \(knownRegionStates.sorted().joined(separator: ", "))
                """)
        }
    }

    // MARK: - Card ID Validation

    func testAllReferencedCardIdsExist() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        var referencedCardIds: Set<String> = []

        // From quest rewards
        for (_, quest) in pack.quests {
            referencedCardIds.formUnion(quest.completionRewards.cardIds)
        }

        // From hero starting decks (if heroes are loaded)
        for (_, hero) in pack.heroes {
            referencedCardIds.formUnion(hero.startingDeckCardIDs)
        }

        // Find unknown cards - need to check global CardRegistry too
        let allKnownCards = allCardIds.union(Set(CardRegistry.shared.allCards.map { $0.id }))
        let unknownCards = referencedCardIds.subtracting(allKnownCards)

        if !unknownCards.isEmpty {
            XCTFail("""
                Found \(unknownCards.count) unknown card IDs:
                \(unknownCards.sorted().map { "  - \($0)" }.joined(separator: "\n"))

                Known cards in pack: \(allCardIds.sorted().joined(separator: ", "))
                """)
        }
    }

    // MARK: - Comprehensive Summary

    func testContentIntegrityReport() throws {
        guard let pack = loadedPack else {
            XCTFail("CONTENT VALIDATION FAILURE: Pack not loaded"); return
        }

        print("""

            === Content Integrity Report ===

            Pack: \(pack.manifest.packId) v\(pack.manifest.version)

            Content Counts:
            - Regions: \(pack.regions.count)
            - Events: \(pack.events.count)
            - Quests: \(pack.quests.count)
            - Cards: \(pack.cards.count)
            - Heroes: \(pack.heroes.count)
            - Enemies: \(pack.enemies.count)
            - Anchors: \(pack.anchors.count)

            Region IDs: \(allRegionIds.sorted().joined(separator: ", "))
            Quest IDs: \(allQuestIds.sorted().joined(separator: ", "))

            ================================

            """)

        // This test always passes - it's for diagnostics
        XCTAssertTrue(true)
    }
}
