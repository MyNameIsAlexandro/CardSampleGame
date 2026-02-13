/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_REPLAY30_ReplayModels.swift
/// Назначение: Содержит реализацию файла INV_REPLAY30_ReplayModels.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation
@testable import TwilightEngine

struct ReplayTrace: Codable, Equatable {
    let schemaVersion: Int
    let traceId: String
    let steps: [ReplayStep]

    static let v1Smoke = ReplayTrace(
        schemaVersion: 1,
        traceId: "epic30_smoke_trace",
        steps: [
            ReplayStep(id: "s01", action: .explore),
            ReplayStep(id: "s02", action: .dismissCurrentEvent),
            ReplayStep(id: "s03", action: .rest),
            ReplayStep(id: "s04", action: .skipTurn),
            ReplayStep(id: "s05", action: .explore),
            ReplayStep(id: "s06", action: .dismissCurrentEvent),
            ReplayStep(id: "s07", action: .skipTurn),
            ReplayStep(id: "s08", action: .explore),
            ReplayStep(id: "s09", action: .dismissCurrentEvent),
            ReplayStep(id: "s10", action: .rest)
        ]
    )

    func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    func fingerprint() throws -> String {
        try canonicalData().base64EncodedString()
    }
}

struct ReplayStep: Codable, Equatable {
    let id: String
    let action: ReplayAction
}

enum ReplayAction: String, Codable, Equatable {
    case rest
    case explore
    case dismissCurrentEvent
    case skipTurn

    func toEngineAction() -> TwilightGameAction {
        switch self {
        case .rest: return .rest
        case .explore: return .explore
        case .dismissCurrentEvent: return .dismissCurrentEvent
        case .skipTurn: return .skipTurn
        }
    }
}

struct ReplayExecutionFingerprint: Codable, Equatable {
    let traceFingerprint: String
    let stepDigestFingerprint: String
    let finalStateFingerprint: String
}

struct ReplayExecutionReport: Equatable {
    let fingerprint: ReplayExecutionFingerprint
    let stepDigests: [StepDigest]
    let finalState: CanonicalEngineSnapshot
}

struct ReplayFixture: Codable, Equatable {
    let fixtureVersion: Int
    let fixtureId: String
    let seed: UInt64
    let checkpointSteps: [Int]
    let trace: ReplayTrace
    let expected: ReplayFixtureExpected
}

struct ReplayFixtureExpected: Codable, Equatable {
    let linear: ReplayFixtureExpectedRun
    let checkpointed: ReplayFixtureExpectedRun
}

struct ReplayFixtureExpectedRun: Codable, Equatable {
    let fingerprint: ReplayExecutionFingerprint?
    let stepDigests: [StepDigest]?
    let finalState: CanonicalEngineSnapshot?
}

struct StepDigest: Codable, Equatable {
    let step: Int
    let id: String
    let action: String
    let success: Bool
    let errorCode: String?
    let day: Int
    let tension: Int
    let currentRegionId: String?
    let currentEventId: String?
    let health: Int
    let faith: Int
    let rngState: UInt64
}

struct CanonicalEngineSnapshot: Codable, Equatable {
    struct Region: Codable, Equatable {
        let id: String
        let type: String
        let state: String
        let visited: Bool
        let reputation: Int
        let anchorId: String?
        let anchorAlignment: String?
        let anchorIntegrity: Int?
    }

    let day: Int
    let worldTension: Int
    let resonanceMilli: Int
    let currentRegionId: String?
    let playerHealth: Int
    let playerFaith: Int
    let playerBalance: Int
    let currentEventId: String?
    let isInCombat: Bool
    let isGameOver: Bool
    let gameResult: String?
    let pendingEncounterStatePresent: Bool
    let pendingExternalCombatSeed: UInt64?
    let deckCardIds: [String]
    let handCardIds: [String]
    let discardCardIds: [String]
    let activeQuestIds: [String]
    let completedQuestIds: [String]
    let completedEventIds: [String]
    let questStages: [String: Int]
    let worldFlags: [String: Bool]
    let regions: [Region]
    let rngSeed: UInt64
    let rngState: UInt64

    init(engine: TwilightGameEngine) {
        let save = engine.createEngineSave()
        self.day = save.currentDay
        self.worldTension = save.worldTension
        self.resonanceMilli = Int((save.resonance * 1000.0).rounded())
        self.currentRegionId = save.currentRegionId
        self.playerHealth = save.playerHealth
        self.playerFaith = save.playerFaith
        self.playerBalance = save.playerBalance
        self.currentEventId = engine.currentEventId
        self.isInCombat = engine.isInCombat
        self.isGameOver = engine.isGameOver
        self.gameResult = engine.gameResult.map { String(reflecting: $0) }
        self.pendingEncounterStatePresent = engine.pendingEncounterState != nil
        self.pendingExternalCombatSeed = engine.pendingExternalCombatSeed
        self.deckCardIds = save.deckCardIds
        self.handCardIds = save.handCardIds
        self.discardCardIds = save.discardCardIds
        self.activeQuestIds = save.activeQuestIds.sorted()
        self.completedQuestIds = save.completedQuestIds.sorted()
        self.completedEventIds = save.completedEventIds.sorted()
        self.questStages = save.questStages
        self.worldFlags = save.worldFlags
        self.regions = save.regions
            .map {
                Region(
                    id: $0.definitionId,
                    type: $0.type,
                    state: $0.state,
                    visited: $0.visited,
                    reputation: $0.reputation,
                    anchorId: $0.anchorDefinitionId,
                    anchorAlignment: $0.anchorAlignment,
                    anchorIntegrity: $0.anchorIntegrity
                )
            }
            .sorted { $0.id < $1.id }
        self.rngSeed = save.rngSeed
        self.rngState = save.rngState
    }
}
