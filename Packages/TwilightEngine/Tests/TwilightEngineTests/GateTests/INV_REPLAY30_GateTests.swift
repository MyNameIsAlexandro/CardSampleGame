/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_REPLAY30_GateTests.swift
/// Назначение: Содержит реализацию файла INV_REPLAY30_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation
import XCTest
@testable import TwilightEngine

/// INV-REPLAY30: Deterministic replay contract gates.
/// Verifies canonical action-trace replay and checkpoint restore determinism.
final class INV_REPLAY30_GateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = TestContentLoader.sharedLoadedRegistry()
    }

    func testCanonicalTraceFormat_roundTripAndStableFingerprint() throws {
        let trace = ReplayTrace.v1Smoke
        let encoded = try trace.canonicalData()
        let decoded = try JSONDecoder().decode(ReplayTrace.self, from: encoded)

        XCTAssertEqual(decoded, trace, "Canonical replay trace must be JSON round-trip stable")
        XCTAssertEqual(try trace.fingerprint(), try decoded.fingerprint(), "Canonical replay trace fingerprint must be stable")
    }

    func testReplayTrace_sameSeed_checkpointRestore_producesSameFingerprints() throws {
        let trace = ReplayTrace.v1Smoke
        let seed: UInt64 = 424242
        let checkpoints: Set<Int> = [2, 6, 9]

        let baseline = try runTrace(
            trace,
            seed: seed,
            checkpointSteps: checkpoints,
            restoreOnCheckpoints: true
        ).fingerprint

        for _ in 0..<2 {
            let run = try runTrace(
                trace,
                seed: seed,
                checkpointSteps: checkpoints,
                restoreOnCheckpoints: true
            ).fingerprint
            XCTAssertEqual(run, baseline, "Same seed + same trace + same checkpoints must be deterministic")
        }
    }

    func testReplayTrace_checkpointRestore_matchesLinearExecution() throws {
        let trace = ReplayTrace.v1Smoke
        let seed: UInt64 = 808080
        let checkpoints: Set<Int> = [3, 7]

        let linear = try runTrace(
            trace,
            seed: seed,
            checkpointSteps: checkpoints,
            restoreOnCheckpoints: false
        )
        let checkpointed = try runTrace(
            trace,
            seed: seed,
            checkpointSteps: checkpoints,
            restoreOnCheckpoints: true
        )

        XCTAssertEqual(
            linear.fingerprint.stepDigestFingerprint,
            checkpointed.fingerprint.stepDigestFingerprint,
            "Checkpoint restore path must preserve canonical step digest"
        )
        XCTAssertEqual(
            linear.fingerprint.finalStateFingerprint,
            checkpointed.fingerprint.finalStateFingerprint,
            "Checkpoint restore path must preserve final canonical state fingerprint"
        )
    }

    func testReplayTrace_differentSeeds_divergeFinalFingerprint() throws {
        let trace = ReplayTrace.v1Smoke
        let checkpoints: Set<Int> = [2, 6, 9]

        let runA = try runTrace(trace, seed: 111111, checkpointSteps: checkpoints, restoreOnCheckpoints: true)
        let runB = try runTrace(trace, seed: 222222, checkpointSteps: checkpoints, restoreOnCheckpoints: true)

        XCTAssertNotEqual(
            runA.fingerprint.finalStateFingerprint,
            runB.fingerprint.finalStateFingerprint,
            "Different seeds must produce different final replay fingerprint"
        )
    }

    func testReplayFixtureCorpus_matchesExpectedFingerprintsWithActionableDiff() throws {
        let updateFixtures = ProcessInfo.processInfo.environment["REPLAY_FIXTURE_UPDATE"] == "1"
        let fixtures = try loadReplayFixtures()
        XCTAssertFalse(fixtures.isEmpty, "Replay fixture corpus must not be empty")

        var driftMessages: [String] = []

        for (fixtureURL, fixture) in fixtures {
            XCTAssertEqual(fixture.fixtureVersion, 1, "Unsupported replay fixture version in \(fixtureURL.lastPathComponent)")

            let checkpoints = Set(fixture.checkpointSteps)
            let linear = try runTrace(
                fixture.trace,
                seed: fixture.seed,
                checkpointSteps: checkpoints,
                restoreOnCheckpoints: false
            )
            let checkpointed = try runTrace(
                fixture.trace,
                seed: fixture.seed,
                checkpointSteps: checkpoints,
                restoreOnCheckpoints: true
            )

            let drift = makeDriftMessages(
                fixtureName: fixtureURL.lastPathComponent,
                fixtureId: fixture.fixtureId,
                expected: fixture.expected,
                actualLinear: linear,
                actualCheckpointed: checkpointed
            )

            if !drift.isEmpty {
                if updateFixtures {
                    try writeUpdatedFixture(
                        at: fixtureURL,
                        fixture: fixture,
                        linear: linear,
                        checkpointed: checkpointed
                    )
                    continue
                }
                let replacement = makeExpectedFixtureBlock(
                    linear: linear,
                    checkpointed: checkpointed
                )
                driftMessages.append(
                    """
                    Fixture drift: \(fixtureURL.lastPathComponent) [\(fixture.fixtureId)]
                    \(drift.joined(separator: "\n"))

                    Suggested replacement for `expected`:
                    \(replacement)
                    """
                )
            }
        }

        if updateFixtures {
            XCTAssertTrue(
                driftMessages.isEmpty,
                "Fixture update mode should not retain drift diagnostics"
            )
            return
        }

        XCTAssertTrue(
            driftMessages.isEmpty,
            """
            Replay fixture drift detected.

            \(driftMessages.joined(separator: "\n\n"))
            """
        )
    }

    private func runTrace(
        _ trace: ReplayTrace,
        seed: UInt64,
        checkpointSteps: Set<Int>,
        restoreOnCheckpoints: Bool
    ) throws -> ReplayExecutionReport {
        var engine = makeEngine(seed: seed)
        var stepDigests: [StepDigest] = []

        for (zeroIndex, step) in trace.steps.enumerated() {
            let stepIndex = zeroIndex + 1
            let action = step.action.toEngineAction()
            let result = engine.performAction(action)

            stepDigests.append(
                StepDigest(
                    step: stepIndex,
                    id: step.id,
                    action: step.action.rawValue,
                    success: result.success,
                    errorCode: result.error.map { String(reflecting: $0) },
                    day: engine.currentDay,
                    tension: engine.worldTension,
                    currentRegionId: engine.currentRegionId,
                    currentEventId: engine.currentEventId,
                    health: engine.player.health,
                    faith: engine.player.faith,
                    rngState: engine.services.rng.currentState()
                )
            )

            if restoreOnCheckpoints, checkpointSteps.contains(stepIndex) {
                let save = engine.createEngineSave()
                engine = makeEngine(seed: seed)
                engine.restoreFromEngineSave(save)
            }
        }

        let finalState = CanonicalEngineSnapshot(engine: engine)
        let fingerprint = ReplayExecutionFingerprint(
            traceFingerprint: try trace.fingerprint(),
            stepDigestFingerprint: try fingerprint(of: stepDigests),
            finalStateFingerprint: try fingerprint(of: finalState)
        )
        return ReplayExecutionReport(
            fingerprint: fingerprint,
            stepDigests: stepDigests,
            finalState: finalState
        )
    }

    private func makeDriftMessages(
        fixtureName: String,
        fixtureId: String,
        expected: ReplayFixtureExpected,
        actualLinear: ReplayExecutionReport,
        actualCheckpointed: ReplayExecutionReport
    ) -> [String] {
        var messages: [String] = []

        compareFingerprint(
            label: "linear.traceFingerprint",
            expected: expected.linear.fingerprint?.traceFingerprint,
            actual: actualLinear.fingerprint.traceFingerprint,
            messages: &messages
        )
        compareFingerprint(
            label: "linear.stepDigestFingerprint",
            expected: expected.linear.fingerprint?.stepDigestFingerprint,
            actual: actualLinear.fingerprint.stepDigestFingerprint,
            messages: &messages
        )
        compareFingerprint(
            label: "linear.finalStateFingerprint",
            expected: expected.linear.fingerprint?.finalStateFingerprint,
            actual: actualLinear.fingerprint.finalStateFingerprint,
            messages: &messages
        )

        compareFingerprint(
            label: "checkpointed.traceFingerprint",
            expected: expected.checkpointed.fingerprint?.traceFingerprint,
            actual: actualCheckpointed.fingerprint.traceFingerprint,
            messages: &messages
        )
        compareFingerprint(
            label: "checkpointed.stepDigestFingerprint",
            expected: expected.checkpointed.fingerprint?.stepDigestFingerprint,
            actual: actualCheckpointed.fingerprint.stepDigestFingerprint,
            messages: &messages
        )
        compareFingerprint(
            label: "checkpointed.finalStateFingerprint",
            expected: expected.checkpointed.fingerprint?.finalStateFingerprint,
            actual: actualCheckpointed.fingerprint.finalStateFingerprint,
            messages: &messages
        )

        if let expectedLinearStepDigests = expected.linear.stepDigests {
            if expectedLinearStepDigests != actualLinear.stepDigests,
               let mismatch = firstStepMismatch(expected: expectedLinearStepDigests, actual: actualLinear.stepDigests) {
                messages.append("[\(fixtureId)] linear.stepDigests first mismatch at step=\(mismatch.stepIndex)")
                messages.append("  expected: \(mismatch.expected)")
                messages.append("  actual  : \(mismatch.actual)")
            }
        } else {
            messages.append("[\(fixtureName)] linear.stepDigests missing in fixture")
        }

        if let expectedCheckpointedStepDigests = expected.checkpointed.stepDigests {
            if expectedCheckpointedStepDigests != actualCheckpointed.stepDigests,
               let mismatch = firstStepMismatch(expected: expectedCheckpointedStepDigests, actual: actualCheckpointed.stepDigests) {
                messages.append("[\(fixtureId)] checkpointed.stepDigests first mismatch at step=\(mismatch.stepIndex)")
                messages.append("  expected: \(mismatch.expected)")
                messages.append("  actual  : \(mismatch.actual)")
            }
        } else {
            messages.append("[\(fixtureName)] checkpointed.stepDigests missing in fixture")
        }

        if let expectedLinearFinalState = expected.linear.finalState {
            if expectedLinearFinalState != actualLinear.finalState {
                messages.append("[\(fixtureId)] linear.finalState changed")
                messages.append("  expected day/tension/region/rng=\(expectedLinearFinalState.day)/\(expectedLinearFinalState.worldTension)/\(expectedLinearFinalState.currentRegionId ?? "nil")/\(expectedLinearFinalState.rngState)")
                messages.append("  actual   day/tension/region/rng=\(actualLinear.finalState.day)/\(actualLinear.finalState.worldTension)/\(actualLinear.finalState.currentRegionId ?? "nil")/\(actualLinear.finalState.rngState)")
            }
        } else {
            messages.append("[\(fixtureName)] linear.finalState missing in fixture")
        }

        if let expectedCheckpointedFinalState = expected.checkpointed.finalState {
            if expectedCheckpointedFinalState != actualCheckpointed.finalState {
                messages.append("[\(fixtureId)] checkpointed.finalState changed")
                messages.append("  expected day/tension/region/rng=\(expectedCheckpointedFinalState.day)/\(expectedCheckpointedFinalState.worldTension)/\(expectedCheckpointedFinalState.currentRegionId ?? "nil")/\(expectedCheckpointedFinalState.rngState)")
                messages.append("  actual   day/tension/region/rng=\(actualCheckpointed.finalState.day)/\(actualCheckpointed.finalState.worldTension)/\(actualCheckpointed.finalState.currentRegionId ?? "nil")/\(actualCheckpointed.finalState.rngState)")
            }
        } else {
            messages.append("[\(fixtureName)] checkpointed.finalState missing in fixture")
        }

        return messages
    }

    private func compareFingerprint(
        label: String,
        expected: String?,
        actual: String,
        messages: inout [String]
    ) {
        guard let expected else {
            messages.append("[\(label)] missing in fixture, actual=\(actual)")
            return
        }
        guard expected != actual else { return }
        messages.append("[\(label)] expected=\(expected) actual=\(actual)")
    }

    private func firstStepMismatch(
        expected: [StepDigest],
        actual: [StepDigest]
    ) -> (stepIndex: Int, expected: String, actual: String)? {
        let maxCount = max(expected.count, actual.count)
        for index in 0..<maxCount {
            let expectedValue = index < expected.count ? expected[index] : nil
            let actualValue = index < actual.count ? actual[index] : nil
            guard expectedValue != actualValue else { continue }
            let expectedDescription = expectedValue.map(stepDigestSummary) ?? "<missing>"
            let actualDescription = actualValue.map(stepDigestSummary) ?? "<missing>"
            return (index + 1, expectedDescription, actualDescription)
        }
        return nil
    }

    private func stepDigestSummary(_ step: StepDigest) -> String {
        "id=\(step.id), action=\(step.action), success=\(step.success), day=\(step.day), tension=\(step.tension), region=\(step.currentRegionId ?? "nil"), event=\(step.currentEventId ?? "nil"), hp=\(step.health), faith=\(step.faith), rng=\(step.rngState)"
    }

    private func loadReplayFixtures() throws -> [(URL, ReplayFixture)] {
        let fixturesDir = replayFixturesDirectory()
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fixturesDir.path) else {
            XCTFail("Replay fixtures directory not found: \(fixturesDir.path)")
            return []
        }

        let jsonFiles = try fileManager
            .contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let decoder = JSONDecoder()
        return try jsonFiles.map { url in
            let data = try Data(contentsOf: url)
            let fixture = try decoder.decode(ReplayFixture.self, from: data)
            return (url, fixture)
        }
    }

    private func replayFixturesDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // GateTests
            .deletingLastPathComponent() // TwilightEngineTests
            .appendingPathComponent("Fixtures/Replay")
    }

    private func makeExpectedFixtureBlock(
        linear: ReplayExecutionReport,
        checkpointed: ReplayExecutionReport
    ) -> String {
        let expected = ReplayFixtureExpected(
            linear: ReplayFixtureExpectedRun(
                fingerprint: linear.fingerprint,
                stepDigests: linear.stepDigests,
                finalState: linear.finalState
            ),
            checkpointed: ReplayFixtureExpectedRun(
                fingerprint: checkpointed.fingerprint,
                stepDigests: checkpointed.stepDigests,
                finalState: checkpointed.finalState
            )
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let data = try encoder.encode(expected)
            return String(data: data, encoding: .utf8) ?? "<encoding-error>"
        } catch {
            return "<encoding-error: \(error)>"
        }
    }

    private func writeUpdatedFixture(
        at url: URL,
        fixture: ReplayFixture,
        linear: ReplayExecutionReport,
        checkpointed: ReplayExecutionReport
    ) throws {
        let updatedFixture = ReplayFixture(
            fixtureVersion: fixture.fixtureVersion,
            fixtureId: fixture.fixtureId,
            seed: fixture.seed,
            checkpointSteps: fixture.checkpointSteps,
            trace: fixture.trace,
            expected: ReplayFixtureExpected(
                linear: ReplayFixtureExpectedRun(
                    fingerprint: linear.fingerprint,
                    stepDigests: linear.stepDigests,
                    finalState: linear.finalState
                ),
                checkpointed: ReplayFixtureExpectedRun(
                    fingerprint: checkpointed.fingerprint,
                    stepDigests: checkpointed.stepDigests,
                    finalState: checkpointed.finalState
                )
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(updatedFixture)
        try data.write(to: url, options: .atomic)
    }

    private func makeEngine(seed: UInt64) -> TwilightGameEngine {
        let engine = TestEngineFactory.makeEngine(seed: seed)
        engine.initializeNewGame(playerName: "Replay", heroId: nil)
        return engine
    }

    private func fingerprint<T: Encodable>(of value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return data.base64EncodedString()
    }
}
