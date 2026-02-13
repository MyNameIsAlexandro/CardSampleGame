/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_SCHEMA28_GateTests.swift
/// Назначение: Содержит реализацию файла INV_SCHEMA28_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// INV-SCHEMA28: Save schema compatibility and migration contract gates.
/// Ensures legacy payloads remain loadable and schema changes are explicit.
final class INV_SCHEMA28_GateTests: XCTestCase {

    private let knownEngineSaveKeysByFormatVersion: [Int: Set<String>] = [
        1: [
            "version", "savedAt", "gameDuration",
            "coreVersion", "activePackSet", "formatVersion", "primaryCampaignPackId",
            "playerName", "heroId", "playerHealth", "playerMaxHealth", "playerFaith", "playerMaxFaith", "playerBalance",
            "deckCardIds", "handCardIds", "discardCardIds",
            "currentDay", "worldTension", "lightDarkBalance", "resonance", "currentRegionId",
            "regions",
            "mainQuestStage", "activeQuestIds", "completedQuestIds", "questStages",
            "completedEventIds", "eventLog",
            "worldFlags",
            "fateDeckState", "encounterState",
            "rngSeed", "rngState"
        ]
    ]
    private let requiredEncodedEngineSaveKeysByFormatVersion: [Int: Set<String>] = [
        1: [
            "version", "savedAt", "gameDuration",
            "coreVersion", "activePackSet", "formatVersion",
            "playerName", "playerHealth", "playerMaxHealth", "playerFaith", "playerMaxFaith", "playerBalance",
            "deckCardIds", "handCardIds", "discardCardIds",
            "currentDay", "worldTension", "lightDarkBalance", "resonance",
            "regions",
            "mainQuestStage", "activeQuestIds", "completedQuestIds", "questStages",
            "completedEventIds", "eventLog",
            "worldFlags",
            "rngSeed", "rngState"
        ]
    ]

    func test_engineSaveSchemaKeySet_isStableForCurrentFormatVersion() throws {
        let save = EngineSave(rngSeed: 1, rngState: 1)
        let data = try JSONEncoder().encode(save)
        let jsonObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let actualKeys = Set(jsonObject.keys)

        guard let knownKeys = knownEngineSaveKeysByFormatVersion[EngineSave.currentFormatVersion],
              let requiredEncodedKeys = requiredEncodedEngineSaveKeysByFormatVersion[EngineSave.currentFormatVersion] else {
            XCTFail(
                """
                Missing schema contract for formatVersion=\(EngineSave.currentFormatVersion).
                Add expected key-set for this format and migration fixtures before merging schema changes.
                """
            )
            return
        }

        XCTAssertTrue(
            actualKeys.isSubset(of: knownKeys),
            """
            EngineSave produced unknown keys for formatVersion=\(EngineSave.currentFormatVersion).
            If this is intentional, add migration coverage + update expected schema key-set.
            """
        )
        XCTAssertTrue(
            requiredEncodedKeys.isSubset(of: actualKeys),
            """
            EngineSave is missing required encoded keys for formatVersion=\(EngineSave.currentFormatVersion).
            If this is intentional, add migration coverage + update expected schema key-set.
            """
        )
    }

    func test_engineSaveDecodesLegacyPayload_missingCompatibilityAndRuntimeFields() throws {
        let legacyPayload: [String: Any] = [
            "playerName": "Legacy Hero",
            "playerHealth": 17,
            "playerMaxHealth": 21,
            "playerFaith": 8,
            "playerMaxFaith": 12,
            "playerBalance": 44,
            "deckCardIds": [],
            "handCardIds": [],
            "discardCardIds": [],
            "currentDay": 9,
            "worldTension": 33,
            "lightDarkBalance": 62,
            "regions": [],
            "mainQuestStage": 2,
            "activeQuestIds": [],
            "completedQuestIds": [],
            "completedEventIds": [],
            "eventLog": [],
            "worldFlags": ["legacy_flag": true],
            "market": ["legacy": true], // legacy key from older schema should be ignored
            "rngSeed": 1234
        ]

        let decoded = try JSONDecoder().decode(EngineSave.self, from: makeJSONData(from: legacyPayload))

        XCTAssertEqual(decoded.playerName, "Legacy Hero")
        XCTAssertEqual(decoded.coreVersion, EngineSave.currentCoreVersion)
        XCTAssertEqual(decoded.activePackSet, [:])
        XCTAssertEqual(decoded.formatVersion, EngineSave.currentFormatVersion)
        XCTAssertNil(decoded.primaryCampaignPackId)
        XCTAssertEqual(decoded.rngSeed, 1234)
        XCTAssertEqual(decoded.rngState, 1234)
        XCTAssertEqual(decoded.resonance, 0)
        XCTAssertNil(decoded.fateDeckState)
        XCTAssertNil(decoded.encounterState)
    }

    func test_engineSaveDecodesForwardPayload_withUnknownFields() throws {
        var payload = baselinePayload()
        payload["future_field"] = "ignored"
        payload["future_nested"] = ["sub_flag": true, "sub_value": 42]

        let decoded = try JSONDecoder().decode(EngineSave.self, from: makeJSONData(from: payload))

        XCTAssertEqual(decoded.playerName, "Forward Save")
        XCTAssertEqual(decoded.playerHealth, 19)
        XCTAssertEqual(decoded.currentDay, 4)
        XCTAssertEqual(decoded.worldTension, 22)
        XCTAssertEqual(decoded.rngSeed, 7)
        XCTAssertEqual(decoded.rngState, 9)
    }

    func test_engineSaveFormatVersionContract_isKnown() {
        XCTAssertNotNil(
            knownEngineSaveKeysByFormatVersion[EngineSave.currentFormatVersion],
            "Current formatVersion must have an explicit schema contract."
        )
        XCTAssertNotNil(
            requiredEncodedEngineSaveKeysByFormatVersion[EngineSave.currentFormatVersion],
            "Current formatVersion must have an explicit schema contract."
        )
    }

    private func baselinePayload() -> [String: Any] {
        [
            "version": 1,
            "savedAt": 0,
            "gameDuration": 10,
            "coreVersion": EngineSave.currentCoreVersion,
            "activePackSet": ["core-heroes": "1.0.0"],
            "formatVersion": EngineSave.currentFormatVersion,
            "playerName": "Forward Save",
            "playerHealth": 19,
            "playerMaxHealth": 20,
            "playerFaith": 6,
            "playerMaxFaith": 10,
            "playerBalance": 31,
            "deckCardIds": [],
            "handCardIds": [],
            "discardCardIds": [],
            "currentDay": 4,
            "worldTension": 22,
            "lightDarkBalance": 55,
            "resonance": 10.0,
            "regions": [],
            "mainQuestStage": 1,
            "activeQuestIds": [],
            "completedQuestIds": [],
            "questStages": [:],
            "completedEventIds": [],
            "eventLog": [],
            "worldFlags": [:],
            "rngSeed": 7,
            "rngState": 9
        ]
    }

    private func makeJSONData(from payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }
}
