import Foundation

// MARK: - Twilight Marches Configuration
// Game-specific configuration for "Сумрачные Пределы" (Twilight Marches)
// Balance values come from BalanceConfiguration (balance.json) — single source of truth.
// This file contains domain types and game-specific logic only.

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Pressure Rules (WorldTension)
// ═══════════════════════════════════════════════════════════════════════════════

/// Twilight Marches pressure (WorldTension) rules
/// Reads from BalanceConfiguration (balance.json) as single source of truth
public struct TwilightPressureRules: PressureRuleSet {
    public let maxPressure: Int
    public let initialPressure: Int
    public let escalationInterval: Int
    public let escalationAmount: Int

    private let warningThreshold: Int
    private let criticalThreshold: Int
    private let catastrophicThreshold: Int
    private let warningDegradation: Double
    private let criticalDegradation: Double
    private let catastrophicDegradation: Double

    public init(from config: PressureBalanceConfig? = nil) {
        let c = config ?? .default
        maxPressure = c.maxPressure
        initialPressure = c.startingPressure
        escalationInterval = c.effectiveTickInterval
        escalationAmount = c.pressurePerTurn
        warningThreshold = c.thresholds.warning
        criticalThreshold = c.thresholds.critical
        catastrophicThreshold = c.thresholds.catastrophic
        warningDegradation = c.degradation.warningChance
        criticalDegradation = c.degradation.criticalChance
        catastrophicDegradation = c.degradation.catastrophicChance ?? 0.5
    }

    /// Thresholds and their effects (driven by balance.json)
    public var thresholds: [Int: [WorldEffect]] {
        return [
            warningThreshold: [.regionDegradation(probability: warningDegradation)],
            criticalThreshold: [.regionDegradation(probability: criticalDegradation), .globalEvent(eventId: "world_shift_warning")],
            catastrophicThreshold: [.regionDegradation(probability: catastrophicDegradation), .anchorWeakening(amount: 10)]
        ]
    }

    /// Canonical escalation formula: base + (daysPassed / 10)
    public func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        let escalationBonus = currentTime / 10
        return escalationAmount + escalationBonus
    }

    /// Static helper for use outside of PressureEngine context
    public static func calculateTensionIncrease(daysPassed: Int, base: Int = PressureBalanceConfig.default.pressurePerTurn) -> Int {
        let escalationBonus = daysPassed / 10
        return base + escalationBonus
    }

    public func checkThresholds(pressure: Int) -> [WorldEffect] {
        var effects: [WorldEffect] = []

        for (threshold, thresholdEffects) in thresholds {
            if pressure >= threshold {
                effects.append(contentsOf: thresholdEffects)
            }
        }

        return effects
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Region Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Region states in Twilight Marches
public enum TwilightRegionState: String, Codable, CaseIterable {
    case stable
    case borderland
    case breach

    /// Degradation weight (higher = degrades faster)
    public var degradationWeight: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Can player rest in this state?
    public var canRest: Bool {
        self == .stable
    }

    /// Can player trade in this state?
    public var canTrade: Bool {
        self == .stable
    }

    /// Combat modifier
    public var combatModifier: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Next degraded state
    public var degraded: TwilightRegionState? {
        switch self {
        case .stable: return .borderland
        case .borderland: return .breach
        case .breach: return nil
        }
    }

    /// Previous improved state
    public var improved: TwilightRegionState? {
        switch self {
        case .stable: return nil
        case .borderland: return .stable
        case .breach: return .borderland
        }
    }
}

/// Region type
public enum TwilightRegionType: String, Codable, CaseIterable {
    case village
    case forest
    case fortress
    case swamp
    case ruins
    case sanctuary
    case cursedLand
}

/// Region definition (static data)
public struct TwilightRegionDefinition: Codable {
    public let id: String
    public let name: String
    public let type: TwilightRegionType
    public let initialState: TwilightRegionState
    public let neighborIds: [String]
    public let hasAnchor: Bool
    public let anchorName: String?

    /// Initial anchor integrity (if has anchor)
    public var initialAnchorIntegrity: Int { hasAnchor ? 100 : 0 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Curse Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Curse types in Twilight Marches
public enum TwilightCurseType: String, Codable, CaseIterable {
    case weakness
    case fear
    case exhaustion
    case greed
    case shadowOfNav
    case bloodCurse
    case sealOfNav
}

/// Curse definition (static data)
public struct TwilightCurseDefinition {
    public let type: TwilightCurseType
    public let name: String
    public let description: String
    public let removalCost: Int
    public let damageModifier: Int      // Modifier to damage dealt
    public let damageTakenModifier: Int // Modifier to damage received
    public let actionModifier: Int      // Modifier to actions per turn
    public let specialEffect: String?   // ID of special effect

    public static let definitions: [TwilightCurseType: TwilightCurseDefinition] = [
        .weakness: TwilightCurseDefinition(
            type: .weakness,
            name: L10n.curseWeaknessName.localized,
            description: L10n.curseWeaknessDescription.localized,
            removalCost: 2,
            damageModifier: -1,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: nil
        ),
        .fear: TwilightCurseDefinition(
            type: .fear,
            name: L10n.curseFearName.localized,
            description: L10n.curseFearDescription.localized,
            removalCost: 2,
            damageModifier: 0,
            damageTakenModifier: 1,
            actionModifier: 0,
            specialEffect: nil
        ),
        .exhaustion: TwilightCurseDefinition(
            type: .exhaustion,
            name: L10n.curseExhaustionName.localized,
            description: L10n.curseExhaustionDescription.localized,
            removalCost: 3,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: -1,
            specialEffect: nil
        ),
        .greed: TwilightCurseDefinition(
            type: .greed,
            name: L10n.curseGreedName.localized,
            description: L10n.curseGreedDescription.localized,
            removalCost: 4,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "balance_shift_dark"
        ),
        .shadowOfNav: TwilightCurseDefinition(
            type: .shadowOfNav,
            name: L10n.curseShadowOfNavName.localized,
            description: L10n.curseShadowOfNavDescription.localized,
            removalCost: 5,
            damageModifier: 3,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "balance_shift_dark_on_combat"
        ),
        .bloodCurse: TwilightCurseDefinition(
            type: .bloodCurse,
            name: L10n.curseBloodCurseName.localized,
            description: L10n.curseBloodCurseDescription.localized,
            removalCost: 6,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "heal_on_kill_dark"
        ),
        .sealOfNav: TwilightCurseDefinition(
            type: .sealOfNav,
            name: L10n.curseSealOfNavName.localized,
            description: L10n.curseSealOfNavDescription.localized,
            removalCost: 8,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "block_sustain_cards"
        )
    ]

    public static func get(_ type: TwilightCurseType) -> TwilightCurseDefinition? {
        return definitions[type]
    }
}
