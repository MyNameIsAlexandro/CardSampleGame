import Foundation

// MARK: - Resonance Zone

/// Zones of world resonance, from deep Nav to deep Prav
public enum ResonanceZone: String, Codable, Hashable, CaseIterable {
    case deepNav   // -100..-61
    case nav       // -60..-21
    case yav       // -20..20
    case prav      //  21..60
    case deepPrav  //  61..100
}

// MARK: - Resonance Shift

/// Record of a resonance change (for logging/analytics)
public struct ResonanceShift: Codable, Equatable {
    public let amount: Float
    public let source: String
    public let resultingValue: Float

    public init(amount: Float, source: String, resultingValue: Float) {
        self.amount = amount
        self.source = source
        self.resultingValue = resultingValue
    }
}

// MARK: - Resonance Engine

/// Manages the global world resonance state (-100..+100).
/// Resonance represents the balance between Nav (chaos/death) and Prav (order/divine).
/// Separate from PlayerRuntimeState.balance which tracks the player's personal alignment.
public final class ResonanceEngine {

    /// Current resonance value, clamped to -100...100
    public private(set) var value: Float = 0.0

    // MARK: - Initialization

    public init(value: Float = 0.0) {
        self.value = Self.clamped(value)
    }

    // MARK: - Mutation

    /// Shift resonance by a given amount. Returns a record of the change.
    /// This is the only way to change resonance during gameplay.
    @discardableResult
    public func shift(amount: Float, source: String) -> ResonanceShift {
        value = Self.clamped(value + amount)
        return ResonanceShift(amount: amount, source: source, resultingValue: value)
    }

    // MARK: - Query

    /// Get the active resonance zone based on current value
    public func getActiveZone() -> ResonanceZone {
        Self.zone(for: value)
    }

    // MARK: - Save/Load

    /// Set value directly (for restoring from save)
    public func setValue(_ v: Float) {
        value = Self.clamped(v)
    }

    // MARK: - Static Helpers

    /// Determine zone for a given resonance value
    public static func zone(for value: Float) -> ResonanceZone {
        switch value {
        case ...(-61):
            return .deepNav
        case (-60)...(-21):
            return .nav
        case (-20)...20:
            return .yav
        case 21...60:
            return .prav
        default:
            return .deepPrav
        }
    }

    private static func clamped(_ v: Float) -> Float {
        min(100, max(-100, v))
    }
}
