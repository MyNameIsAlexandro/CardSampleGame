/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_RESUME47_GateTests.swift
/// Назначение: Содержит реализацию файла INV_RESUME47_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation
import XCTest
@testable import TwilightEngine

/// INV-RESUME47: save/resume fault-injection matrix.
/// Covers interrupted write recovery, partial snapshot resume, and repeated recovery determinism.
final class INV_RESUME47_GateTests: XCTestCase {

    private enum FaultMode {
        case interruptedWrite
        case partialSnapshot
    }

    private enum HarnessError: Error, CustomStringConvertible {
        case actionFailed(step: Int, actionDescription: String, error: ActionError?)
        case decodeDidNotFailForInterruptedPayload(step: Int)
        case missingRecoveryCheckpoint(step: Int)
        case recoveryDrift(step: Int, expected: String, actual: String)

        var description: String {
            switch self {
            case let .actionFailed(step, actionDescription, error):
                return "Step \(step) failed for action \(actionDescription) error=\(String(describing: error))"
            case let .decodeDidNotFailForInterruptedPayload(step):
                return "Step \(step): interrupted payload unexpectedly decoded"
            case let .missingRecoveryCheckpoint(step):
                return "Step \(step): interrupted recovery has no previous valid checkpoint"
            case let .recoveryDrift(step, expected, actual):
                return "Step \(step): recovery drift expected=\(expected) actual=\(actual)"
            }
        }
    }

    private struct StepDigest: Codable, Equatable {
        let step: Int
        let day: Int
        let worldTension: Int
        let currentEventId: String?
        let pendingEncounterStatePresent: Bool
        let pendingExternalCombatSeed: UInt64?
        let isInCombat: Bool
        let playerHealth: Int
        let playerFaith: Int
        let rngState: UInt64
    }

    private struct CanonicalSnapshot: Codable, Equatable {
        let day: Int
        let worldTension: Int
        let resonanceMilli: Int
        let currentRegionId: String?
        let currentEventId: String?
        let pendingEncounterStatePresent: Bool
        let pendingExternalCombatSeed: UInt64?
        let isInCombat: Bool
        let playerHealth: Int
        let playerFaith: Int
        let playerBalance: Int
        let worldFlags: [String]
        let completedEventIds: [String]
        let rngSeed: UInt64
        let rngState: UInt64
    }

    private struct ScenarioReport: Equatable {
        let snapshot: CanonicalSnapshot
        let finalFingerprint: String
        let stepFingerprint: String
    }

    private let scriptedStepCount = 14

    override func setUp() {
        super.setUp()
        _ = TestContentLoader.sharedLoadedRegistry()
    }

    func testInterruptedSaveWriteRecovery_matchesBaselineFingerprint() throws {
        let checkpoints: Set<Int> = [2, 5, 8, 11]
        let faultPlan: [Int: FaultMode] = [
            5: .interruptedWrite,
            11: .interruptedWrite
        ]

        let baseline = try runScenario(seed: 470001, checkpoints: checkpoints, faultPlan: [:])
        let recovered = try runScenario(seed: 470001, checkpoints: checkpoints, faultPlan: faultPlan)

        assertNoDrift(baseline: baseline, recovered: recovered)
    }

    func testPartialSnapshotResume_matchesBaselineFingerprint() throws {
        let checkpoints: Set<Int> = [2, 5, 8, 11]
        let faultPlan: [Int: FaultMode] = [
            8: .partialSnapshot
        ]

        let baseline = try runScenario(seed: 470002, checkpoints: checkpoints, faultPlan: [:])
        let resumed = try runScenario(seed: 470002, checkpoints: checkpoints, faultPlan: faultPlan)

        assertNoDrift(baseline: baseline, recovered: resumed)
    }

    func testRepeatedRecoveries_areDeterministicAcrossRuns() throws {
        let checkpoints: Set<Int> = [2, 5, 8, 11]
        let faultPlan: [Int: FaultMode] = [
            5: .interruptedWrite,
            8: .partialSnapshot,
            11: .interruptedWrite
        ]

        for seed in [470003 as UInt64, 470004 as UInt64] {
            let baseline = try runScenario(seed: seed, checkpoints: checkpoints, faultPlan: [:])
            let runA = try runScenario(seed: seed, checkpoints: checkpoints, faultPlan: faultPlan)
            let runB = try runScenario(seed: seed, checkpoints: checkpoints, faultPlan: faultPlan)

            assertNoDrift(baseline: baseline, recovered: runA)
            XCTAssertEqual(runA.finalFingerprint, runB.finalFingerprint, "Repeated recovery run must keep final fingerprint stable for seed=\(seed)")
            XCTAssertEqual(runA.stepFingerprint, runB.stepFingerprint, "Repeated recovery run must keep step fingerprint stable for seed=\(seed)")
        }
    }

    private func runScenario(
        seed: UInt64,
        checkpoints: Set<Int>,
        faultPlan: [Int: FaultMode]
    ) throws -> ScenarioReport {
        var engine = makeEngine(seed: seed)
        var stepDigests: [StepDigest] = []

        var lastValidCheckpoint: EngineSave?
        var lastValidCheckpointStep = -1

        for step in 0..<scriptedStepCount {
            try performScriptStep(step, on: &engine)

            if checkpoints.contains(step) {
                let preCheckpointSnapshot = canonicalSnapshot(of: engine)
                let checkpointSave = engine.createEngineSave()

                switch faultPlan[step] {
                case .interruptedWrite?:
                    if (try? JSONDecoder().decode(EngineSave.self, from: interruptedPayload(from: checkpointSave))) != nil {
                        throw HarnessError.decodeDidNotFailForInterruptedPayload(step: step)
                    }

                    guard let lastValidCheckpoint else {
                        throw HarnessError.missingRecoveryCheckpoint(step: step)
                    }

                    var recovered = restoreEngine(from: lastValidCheckpoint)
                    if lastValidCheckpointStep + 1 <= step {
                        for replayStep in (lastValidCheckpointStep + 1)...step {
                            try performScriptStep(replayStep, on: &recovered)
                        }
                    }
                    engine = recovered

                    let recoveredSnapshot = canonicalSnapshot(of: engine)
                    guard recoveredSnapshot == preCheckpointSnapshot else {
                        throw HarnessError.recoveryDrift(
                            step: step,
                            expected: try fingerprint(of: preCheckpointSnapshot),
                            actual: try fingerprint(of: recoveredSnapshot)
                        )
                    }

                case .partialSnapshot?:
                    let partialSave = try partialSnapshot(from: checkpointSave)
                    engine = restoreEngine(from: partialSave)

                    let resumedSnapshot = canonicalSnapshot(of: engine)
                    guard resumedSnapshot == preCheckpointSnapshot else {
                        throw HarnessError.recoveryDrift(
                            step: step,
                            expected: try fingerprint(of: preCheckpointSnapshot),
                            actual: try fingerprint(of: resumedSnapshot)
                        )
                    }

                    lastValidCheckpoint = partialSave
                    lastValidCheckpointStep = step

                case nil:
                    engine = restoreEngine(from: checkpointSave)
                    lastValidCheckpoint = checkpointSave
                    lastValidCheckpointStep = step
                }
            }

            stepDigests.append(stepDigest(step: step + 1, engine: engine))
        }

        let snapshot = canonicalSnapshot(of: engine)
        return ScenarioReport(
            snapshot: snapshot,
            finalFingerprint: try fingerprint(of: snapshot),
            stepFingerprint: try fingerprint(of: stepDigests)
        )
    }

    private func makeEngine(seed: UInt64) -> TwilightGameEngine {
        let engine = TestEngineFactory.makeEngine(seed: seed)
        engine.initializeNewGame(playerName: "Resume47", heroId: nil)
        return engine
    }

    private func restoreEngine(from save: EngineSave) -> TwilightGameEngine {
        let engine = TestEngineFactory.makeEngine(seed: save.rngSeed)
        engine.restoreFromEngineSave(save)
        return engine
    }

    private func performScriptStep(_ step: Int, on engine: inout TwilightGameEngine) throws {
        if engine.currentEventId != nil {
            let dismissResult = engine.performAction(.dismissCurrentEvent)
            guard dismissResult.success else {
                throw HarnessError.actionFailed(
                    step: step,
                    actionDescription: String(describing: TwilightGameAction.dismissCurrentEvent),
                    error: dismissResult.error
                )
            }
        }

        let action: TwilightGameAction = (step % 3 == 0) ? .rest : .skipTurn
        let result = engine.performAction(action)
        guard result.success else {
            throw HarnessError.actionFailed(
                step: step,
                actionDescription: String(describing: action),
                error: result.error
            )
        }

        if engine.currentEventId != nil {
            let dismissResult = engine.performAction(.dismissCurrentEvent)
            guard dismissResult.success else {
                throw HarnessError.actionFailed(
                    step: step,
                    actionDescription: String(describing: TwilightGameAction.dismissCurrentEvent),
                    error: dismissResult.error
                )
            }
        }
    }

    private func interruptedPayload(from save: EngineSave) throws -> Data {
        let data = try JSONEncoder().encode(save)
        let cut = max(1, data.count / 3)
        return Data(data.prefix(cut))
    }

    private func partialSnapshot(from save: EngineSave) throws -> EngineSave {
        let data = try JSONEncoder().encode(save)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HarnessError.recoveryDrift(step: -1, expected: "jsonObject", actual: "invalid")
        }

        object.removeValue(forKey: "savedAt")
        object.removeValue(forKey: "gameDuration")
        object.removeValue(forKey: "coreVersion")
        object.removeValue(forKey: "activePackSet")
        object.removeValue(forKey: "formatVersion")
        object.removeValue(forKey: "primaryCampaignPackId")

        let partialData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try JSONDecoder().decode(EngineSave.self, from: partialData)
    }

    private func canonicalSnapshot(of engine: TwilightGameEngine) -> CanonicalSnapshot {
        let save = engine.createEngineSave()

        let flags = save.worldFlags
            .map { "\($0.key)=\($0.value)" }
            .sorted()

        return CanonicalSnapshot(
            day: save.currentDay,
            worldTension: save.worldTension,
            resonanceMilli: Int((save.resonance * 1000.0).rounded()),
            currentRegionId: save.currentRegionId,
            currentEventId: engine.currentEventId,
            pendingEncounterStatePresent: engine.pendingEncounterState != nil,
            pendingExternalCombatSeed: engine.pendingExternalCombatSeed,
            isInCombat: engine.isInCombat,
            playerHealth: save.playerHealth,
            playerFaith: save.playerFaith,
            playerBalance: save.playerBalance,
            worldFlags: flags,
            completedEventIds: save.completedEventIds.sorted(),
            rngSeed: save.rngSeed,
            rngState: save.rngState
        )
    }

    private func stepDigest(step: Int, engine: TwilightGameEngine) -> StepDigest {
        let save = engine.createEngineSave()
        return StepDigest(
            step: step,
            day: save.currentDay,
            worldTension: save.worldTension,
            currentEventId: engine.currentEventId,
            pendingEncounterStatePresent: engine.pendingEncounterState != nil,
            pendingExternalCombatSeed: engine.pendingExternalCombatSeed,
            isInCombat: engine.isInCombat,
            playerHealth: save.playerHealth,
            playerFaith: save.playerFaith,
            rngState: save.rngState
        )
    }

    private func fingerprint<T: Encodable>(of value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value).base64EncodedString()
    }

    private func assertNoDrift(baseline: ScenarioReport, recovered: ScenarioReport) {
        XCTAssertEqual(recovered.finalFingerprint, baseline.finalFingerprint, "Final fingerprint drifted after fault-injection recovery")
        XCTAssertEqual(recovered.stepFingerprint, baseline.stepFingerprint, "Step fingerprint drifted after fault-injection recovery")
        XCTAssertEqual(recovered.snapshot.rngState, baseline.snapshot.rngState, "RNG state drifted versus baseline")
        XCTAssertEqual(recovered.snapshot.currentEventId, baseline.snapshot.currentEventId, "currentEventId drifted versus baseline")
        XCTAssertEqual(
            recovered.snapshot.pendingEncounterStatePresent,
            baseline.snapshot.pendingEncounterStatePresent,
            "pendingEncounterState drifted versus baseline"
        )
        XCTAssertEqual(
            recovered.snapshot.pendingExternalCombatSeed,
            baseline.snapshot.pendingExternalCombatSeed,
            "pendingExternalCombatSeed drifted versus baseline"
        )
    }
}
