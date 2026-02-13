/// Файл: Packages/PackEditorKit/Tests/PackEditorKitTests/CombatSimulatorTests.swift
/// Назначение: Содержит реализацию файла CombatSimulatorTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import PackEditorKit

final class CombatSimulatorTests: XCTestCase {

    // MARK: - SimulationResult

    func testSimulationResult_winRate_zeroRuns() {
        let result = SimulationResult(
            totalRuns: 0, wins: 0, losses: 0,
            avgRounds: 0, avgHPRemaining: 0, avgResonanceDelta: 0,
            longestFight: 0, roundDistribution: [:]
        )
        XCTAssertEqual(result.winRate, 0)
    }

    func testSimulationResult_winRate_calculated() {
        let result = SimulationResult(
            totalRuns: 10, wins: 7, losses: 3,
            avgRounds: 5, avgHPRemaining: 10, avgResonanceDelta: 0.1,
            longestFight: 8, roundDistribution: [:]
        )
        XCTAssertEqual(result.winRate, 0.7, accuracy: 0.001)
    }

    func testSimulationResult_allWins() {
        let result = SimulationResult(
            totalRuns: 5, wins: 5, losses: 0,
            avgRounds: 3, avgHPRemaining: 20, avgResonanceDelta: 0,
            longestFight: 5, roundDistribution: [:]
        )
        XCTAssertEqual(result.winRate, 1.0, accuracy: 0.001)
    }

    func testSimulationResult_allLosses() {
        let result = SimulationResult(
            totalRuns: 5, wins: 0, losses: 5,
            avgRounds: 2, avgHPRemaining: 0, avgResonanceDelta: -0.5,
            longestFight: 3, roundDistribution: [:]
        )
        XCTAssertEqual(result.winRate, 0.0, accuracy: 0.001)
    }

    func testSimulationResult_roundDistribution() {
        let dist = [1: 3, 2: 5, 3: 2]
        let result = SimulationResult(
            totalRuns: 10, wins: 6, losses: 4,
            avgRounds: 2.0, avgHPRemaining: 15, avgResonanceDelta: 0,
            longestFight: 3, roundDistribution: dist
        )
        XCTAssertEqual(result.roundDistribution[1], 3)
        XCTAssertEqual(result.roundDistribution[2], 5)
        XCTAssertEqual(result.roundDistribution[3], 2)
    }
}
