/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/AffinityMatrix.swift
/// Назначение: Data-driven lookup для стартовой disposition на основе heroWorld и enemyType.
/// Зона ответственности: AffinityMatrix[heroWorld][enemyType] + situationModifier (INV-DC-006, INV-DC-044).
/// Контекст: Disposition Combat Phase 3, Design doc §3. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.1

import Foundation

/// Data-driven starting disposition lookup.
/// Maps hero resonance zone × enemy type to a base disposition value.
public struct AffinityMatrix {

    // MARK: - Lookup

    /// Calculate the starting disposition for a combat encounter.
    ///
    /// - Parameters:
    ///   - heroWorld: The hero's resonance zone.
    ///   - enemyType: The enemy type identifier string.
    ///   - situationModifier: Additional modifier from world state / quest context.
    /// - Returns: Starting disposition value, clamped to [-100, +100].
    public static func startingDisposition(
        heroWorld: ResonanceZone,
        enemyType: String,
        situationModifier: Int = 0
    ) -> Int {
        let base = baseLookup(heroWorld: heroWorld, enemyType: enemyType)
        let result = base + situationModifier
        return min(100, max(-100, result))
    }

    // MARK: - Base Lookup Table

    /// Internal lookup of base disposition from the affinity matrix.
    /// Design doc §3 hardcoded initial data.
    static func baseLookup(heroWorld: ResonanceZone, enemyType: String) -> Int {
        let normalizedZone = normalizeZone(heroWorld)
        let normalizedType = enemyType.lowercased()

        guard let zoneTable = affinityTable[normalizedZone] else {
            return 0
        }

        return zoneTable[normalizedType] ?? 0
    }

    /// Normalize deep zones to their base zone for lookup.
    private static func normalizeZone(_ zone: ResonanceZone) -> ResonanceZone {
        switch zone {
        case .deepNav: return .nav
        case .deepPrav: return .prav
        default: return zone
        }
    }

    // MARK: - Affinity Table Data

    /// Hardcoded affinity table from design doc §3.
    /// heroWorld × enemyType → base disposition.
    ///
    /// Positive = leaning toward subjugation (hero has rapport).
    /// Negative = leaning toward destruction (hero is hostile).
    private static let affinityTable: [ResonanceZone: [String: Int]] = [
        .nav: [
            "нечисть": 30,
            "человек": -10,
            "зверь": -5,
            "дух": 15,
            "нежить": 20,
            "торговец": -15,
            "бандит": -10
        ],
        .yav: [
            "нечисть": 0,
            "человек": 20,
            "зверь": 10,
            "дух": 0,
            "нежить": -10,
            "торговец": 15,
            "бандит": -5
        ],
        .prav: [
            "нечисть": -40,
            "человек": 10,
            "зверь": 5,
            "дух": -15,
            "нежить": -30,
            "торговец": 10,
            "бандит": -20
        ]
    ]
}
