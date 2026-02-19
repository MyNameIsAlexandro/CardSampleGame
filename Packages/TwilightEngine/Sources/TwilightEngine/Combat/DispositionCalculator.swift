/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCalculator.swift
/// Назначение: Static calculator для effective_power в Disposition Combat.
/// Зона ответственности: Формула effective_power, streak bonus, switch penalty, threat bonus, surge, hard cap.
/// Контекст: INV-DC-002 (hard cap 25), INV-DC-009..011 (momentum), INV-DC-017 (surge). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.1

import Foundation

/// Static calculator for disposition combat power resolution.
/// All methods are pure functions — no state, no RNG.
public struct DispositionCalculator {

    /// Hard cap for effective_power (INV-DC-002).
    public static let hardCap: Int = 25

    // MARK: - Effective Power

    /// Calculate the effective power of a card play.
    ///
    /// Formula:
    /// ```
    /// effective_power = min(25,
    ///     surged_base + streak_bonus + threat_bonus + fate_modifier
    ///     + resonance_bonus - switch_penalty - defend_reduction - adapt_penalty
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - basePower: Base power of the card.
    ///   - streakCount: Current streak count (after this action).
    ///   - lastActionType: The previous action type (for threat bonus).
    ///   - currentActionType: The action being performed.
    ///   - fateKeyword: Active fate keyword (optional).
    ///   - fateModifier: Numeric modifier from drawn fate card.
    ///   - resonanceZone: Current resonance zone.
    ///   - defendReduction: Enemy defend reduction applied to strikes.
    ///   - adaptPenalty: Enemy adapt penalty applied to streak-matching actions.
    /// - Returns: Effective power, capped at 25, minimum 0.
    public static func effectivePower(
        basePower: Int,
        streakCount: Int,
        lastActionType: DispositionActionType?,
        currentActionType: DispositionActionType,
        fateKeyword: FateKeyword? = nil,
        fateModifier: Int = 0,
        resonanceZone: ResonanceZone = .yav,
        defendReduction: Int = 0,
        adaptPenalty: Int = 0
    ) -> Int {
        let surgedBase = surgedBasePower(basePower: basePower, fateKeyword: fateKeyword)
        let streak = streakBonus(streakCount: streakCount)
        let threat = threatBonus(lastActionType: lastActionType, currentActionType: currentActionType)
        let resonance = resonanceBonus(zone: resonanceZone, actionType: currentActionType)
        let switchPen: Int
        if lastActionType != nil && lastActionType != currentActionType {
            switchPen = switchPenalty(streakCount: streakCount)
        } else {
            switchPen = 0
        }

        let raw = surgedBase + streak + threat + fateModifier + resonance
            - switchPen - defendReduction - adaptPenalty

        return min(hardCap, max(0, raw))
    }

    // MARK: - Component Calculations

    /// Streak bonus: `max(0, streakCount - 1)` (INV-DC-009).
    public static func streakBonus(streakCount: Int) -> Int {
        return max(0, streakCount - 1)
    }

    /// Switch penalty: applied when switching action type with streak >= 3 (INV-DC-011).
    /// `max(0, streakCount - 2)` when streak >= 3, else 0.
    public static func switchPenalty(streakCount: Int) -> Int {
        guard streakCount >= 3 else { return 0 }
        return max(0, streakCount - 2)
    }

    /// Threat bonus: +2 when switching from strike to influence (INV-DC-010).
    public static func threatBonus(
        lastActionType: DispositionActionType?,
        currentActionType: DispositionActionType
    ) -> Int {
        if lastActionType == .strike && currentActionType == .influence {
            return 2
        }
        return 0
    }

    /// Surge modifier: base_power * 3/2 (integer math). Surge only multiplies base (INV-DC-017).
    public static func surgedBasePower(basePower: Int, fateKeyword: FateKeyword?) -> Int {
        guard fateKeyword == .surge else { return basePower }
        return basePower * 3 / 2
    }

    /// Resonance bonus for the current zone and action type.
    /// Nav: strike +2. Prav: influence +2.
    public static func resonanceBonus(zone: ResonanceZone, actionType: DispositionActionType) -> Int {
        switch (zone, actionType) {
        case (.nav, .strike), (.deepNav, .strike):
            return 2
        case (.prav, .influence), (.deepPrav, .influence):
            return 2
        default:
            return 0
        }
    }
}
