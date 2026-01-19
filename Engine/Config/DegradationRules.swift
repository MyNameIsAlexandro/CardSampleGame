import Foundation

// MARK: - Degradation Rules
// Правила деградации регионов, вынесенные из WorldState в Engine Config
// Позволяет настраивать поведение деградации без изменения кода

/// Протокол правил деградации для разных конфигураций игры
protocol DegradationRuleSet {
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

/// Правила деградации для "Сумрачных Пределов" (Twilight Marches)
struct TwilightDegradationRules: DegradationRuleSet {

    /// Веса выбора региона:
    /// - Stable (70-100%): 0 — не деградирует напрямую
    /// - Borderland (30-69%): 1 — умеренный приоритет
    /// - Breach (0-29%): 2 — высокий приоритет (уже слабые регионы ухудшаются быстрее)
    func selectionWeight(for regionState: RegionState) -> Int {
        switch regionState {
        case .stable:
            return 0
        case .borderland:
            return 1
        case .breach:
            return 2
        }
    }

    /// Вероятность сопротивления: чем выше integrity, тем больше шанс сопротивляться
    /// Формула: P(resist) = integrity / 100
    /// - integrity 100% → 100% сопротивление
    /// - integrity 50% → 50% сопротивление
    /// - integrity 0% → 0% сопротивление
    func resistanceProbability(anchorIntegrity: Int) -> Double {
        return Double(anchorIntegrity) / 100.0
    }

    /// Урон якорю при деградации: -20% integrity
    let degradationAmount: Int = 20

    /// Деградация происходит только при Tension >= 0 (всегда возможна)
    let minimumTensionForDegradation: Int = 0
}

// MARK: - Shared Instance

/// Глобальные правила деградации (по умолчанию TwilightDegradationRules)
enum DegradationRules {
    static var current: DegradationRuleSet = TwilightDegradationRules()

    /// Сбросить на дефолтные правила
    static func reset() {
        current = TwilightDegradationRules()
    }
}
