import Foundation

/// Result of a completed encounter
public struct EncounterResult: Equatable {
    public let outcome: EncounterOutcome
    public let perEntityOutcomes: [String: EntityOutcome]
    public let transaction: EncounterTransaction
    public let updatedFateDeck: FateDeckState
    public let rngState: UInt64

    public init(outcome: EncounterOutcome, perEntityOutcomes: [String: EntityOutcome], transaction: EncounterTransaction, updatedFateDeck: FateDeckState, rngState: UInt64) {
        self.outcome = outcome
        self.perEntityOutcomes = perEntityOutcomes
        self.transaction = transaction
        self.updatedFateDeck = updatedFateDeck
        self.rngState = rngState
    }
}

/// Overall encounter outcome
public enum EncounterOutcome: Equatable {
    case victory(VictoryType)
    case defeat
    case escaped
}

/// How victory was achieved
public enum VictoryType: Equatable, Codable {
    case killed
    case pacified
    case custom(String)

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "killed": self = .killed
        case "pacified": self = .pacified
        case "custom":
            let value = try container.decode(String.self, forKey: .value)
            self = .custom(value)
        default: self = .killed
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .killed:
            try container.encode("killed", forKey: .type)
        case .pacified:
            try container.encode("pacified", forKey: .type)
        case .custom(let value):
            try container.encode("custom", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

/// Per-entity outcome in multi-enemy encounters
public enum EntityOutcome: String, Codable, Equatable {
    case killed
    case pacified
    case escaped
    case alive
}

/// Transaction: all world state changes from the encounter
public struct EncounterTransaction: Equatable {
    public let hpDelta: Int
    public let faithDelta: Int
    public let resonanceDelta: Float
    public let worldFlags: [String: Bool]
    public let lootCardIds: [String]

    public init(hpDelta: Int = 0, faithDelta: Int = 0, resonanceDelta: Float = 0, worldFlags: [String: Bool] = [:], lootCardIds: [String] = []) {
        self.hpDelta = hpDelta
        self.faithDelta = faithDelta
        self.resonanceDelta = resonanceDelta
        self.worldFlags = worldFlags
        self.lootCardIds = lootCardIds
    }

    public static let empty = EncounterTransaction()
}
