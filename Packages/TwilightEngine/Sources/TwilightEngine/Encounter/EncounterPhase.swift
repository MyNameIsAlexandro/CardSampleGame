import Foundation

/// Named phases of an encounter turn loop
/// Reference: ENCOUNTER_SYSTEM_DESIGN.md §2
public enum EncounterPhase: String, Codable, Equatable {
    case intent          // Enemy declares intent
    case playerAction    // Player chooses action
    case enemyResolution // Enemy executes declared intent
    case roundEnd        // Cleanup, victory check, advance round
}
