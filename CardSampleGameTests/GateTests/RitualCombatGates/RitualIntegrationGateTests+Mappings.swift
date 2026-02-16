/// Файл: CardSampleGameTests/GateTests/RitualCombatGates/RitualIntegrationGateTests+Mappings.swift
/// Назначение: Выносит mapping-контракт resume/snapshot из основного gate-файла.
/// Зона ответственности: Проверяет сохранность reward-полей в app-layer маппингах.
/// Контекст: Декомпозиция под hard line-limit ≤ 600 строк на файл.

import XCTest
@testable import CardSampleGame

@MainActor
final class RitualIntegrationMappingsGateTests: XCTestCase {

    // MARK: - INV-CONTRACT-004: Snapshot/resume mappings keep reward fields

    /// Static scan: app-layer mappings must preserve external combat payload fields.
    func testEventAndResumeMappingsPreserveRewardFields() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let eventFile = projectRoot.appendingPathComponent("Views/EventView.swift")
        let contentFile = projectRoot.appendingPathComponent("App/ContentView.swift")

        let eventCode = try String(contentsOf: eventFile, encoding: .utf8)
        let contentCode = try String(contentsOf: contentFile, encoding: .utf8)

        XCTAssertTrue(
            eventCode.contains("lootCardIds: snapshot.enemyDefinition.lootCardIds"),
            "EventView must map lootCardIds from external combat snapshot"
        )
        XCTAssertTrue(
            eventCode.contains("faithReward: snapshot.enemyDefinition.faithReward"),
            "EventView must map faithReward from external combat snapshot"
        )
        XCTAssertTrue(
            eventCode.contains("resonanceBehavior: snapshot.enemyDefinition.resonanceBehavior"),
            "EventView must map resonance behavior from external combat snapshot"
        )
        XCTAssertTrue(
            eventCode.contains("weaknesses: snapshot.enemyDefinition.weaknesses ?? []"),
            "EventView must map weaknesses from external combat snapshot"
        )
        XCTAssertTrue(
            eventCode.contains("strengths: snapshot.enemyDefinition.strengths ?? []"),
            "EventView must map strengths from external combat snapshot"
        )
        XCTAssertTrue(
            eventCode.contains("abilities: snapshot.enemyDefinition.abilities"),
            "EventView must map abilities from external combat snapshot"
        )
        XCTAssertTrue(
            contentCode.contains("lootCardIds: state.lootCardIds"),
            "Resume mapping must preserve lootCardIds from EncounterSaveState"
        )
        XCTAssertTrue(
            contentCode.contains("faithReward: state.faithReward"),
            "Resume mapping must preserve faithReward from EncounterSaveState"
        )
        XCTAssertTrue(
            contentCode.contains("resonanceBehavior: state.resonanceBehavior"),
            "Resume mapping must preserve resonanceBehavior from EncounterSaveState"
        )
        XCTAssertTrue(
            contentCode.contains("weaknesses: state.weaknesses"),
            "Resume mapping must preserve weaknesses from EncounterSaveState"
        )
        XCTAssertTrue(
            contentCode.contains("strengths: state.strengths"),
            "Resume mapping must preserve strengths from EncounterSaveState"
        )
        XCTAssertTrue(
            contentCode.contains("abilities: state.abilities"),
            "Resume mapping must preserve abilities from EncounterSaveState"
        )
    }
}
