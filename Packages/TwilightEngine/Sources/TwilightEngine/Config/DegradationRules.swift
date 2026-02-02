import Foundation

// MARK: - Degradation Rules
// Правила деградации регионов, вынесенные из WorldState в Engine Config
// Позволяет настраивать поведение деградации без изменения кода

/// Протокол правил деградации для разных конфигураций игры
public protocol DegradationRuleSet {
    /// Вес региона для выбора кандидата на деградацию
    func selectionWeight(for regionState: RegionState) -> Int

    /// Вероятность сопротивления якоря (0.0 - 1.0)
    /// Возвращает вероятность того, что якорь сопротивляется деградации
    func resistanceProbability(anchorIntegrity: Int) -> Double

    /// Урон якорю при деградации
    var degradationAmount: Int { get }

    /// Минимальный Tension для запуска деградации
    var minimumTensionForDegradation: Int { get }
}

/// Default degradation rules for world region state changes
/// Reads degradationAmount from AnchorBalanceConfig when provided
public struct TwilightDegradationRules: DegradationRuleSet {

    /// Урон якорю при деградации
    public let degradationAmount: Int

    /// Деградация происходит только при Tension >= минимум
    public let minimumTensionForDegradation: Int

    public init(anchorConfig: AnchorBalanceConfig? = nil) {
        let c = anchorConfig ?? .default
        degradationAmount = c.degradationAmount ?? 20
        minimumTensionForDegradation = 0
    }

    /// Веса выбора региона:
    /// - Stable (70-100%): 0 — не деградирует напрямую
    /// - Borderland (30-69%): 1 — умеренный приоритет
    /// - Breach (0-29%): 2 — высокий приоритет
    public func selectionWeight(for regionState: RegionState) -> Int {
        switch regionState {
        case .stable:
            return 0
        case .borderland:
            return 1
        case .breach:
            return 2
        }
    }

    /// Вероятность сопротивления: P(resist) = integrity / 100
    public func resistanceProbability(anchorIntegrity: Int) -> Double {
        return Double(anchorIntegrity) / 100.0
    }
}

