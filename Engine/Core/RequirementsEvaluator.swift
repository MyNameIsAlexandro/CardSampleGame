import Foundation

// MARK: - Requirements Evaluator
// Логика проверки требований, вынесенная из Definitions в Engine Core
// Definitions остаются "тупыми данными", а логика живёт здесь

/// Протокол для оценки требований
protocol RequirementsEvaluating {
    /// Проверяет, выполнены ли требования выбора
    func canMeet(
        requirements: ChoiceRequirements,
        resources: [String: Int],
        flags: Set<String>,
        balance: Int
    ) -> Bool

    /// Проверяет, доступен ли выбор в текущем контексте
    func isChoiceAvailable(
        choice: ChoiceDefinition,
        resources: [String: Int],
        flags: Set<String>,
        balance: Int
    ) -> Bool
}

/// Стандартный evaluator для проверки требований
struct RequirementsEvaluator: RequirementsEvaluating {

    /// Проверяет, выполнены ли требования
    func canMeet(
        requirements: ChoiceRequirements,
        resources: [String: Int],
        flags: Set<String>,
        balance: Int
    ) -> Bool {
        // Check resources
        for (resourceId, minValue) in requirements.minResources {
            if (resources[resourceId] ?? 0) < minValue {
                return false
            }
        }

        // Check required flags
        for flag in requirements.requiredFlags {
            if !flags.contains(flag) {
                return false
            }
        }

        // Check forbidden flags
        for flag in requirements.forbiddenFlags {
            if flags.contains(flag) {
                return false
            }
        }

        // Check balance range
        if let min = requirements.minBalance, balance < min {
            return false
        }
        if let max = requirements.maxBalance, balance > max {
            return false
        }

        return true
    }

    /// Проверяет, доступен ли выбор (если есть requirements - проверяет их)
    func isChoiceAvailable(
        choice: ChoiceDefinition,
        resources: [String: Int],
        flags: Set<String>,
        balance: Int
    ) -> Bool {
        guard let requirements = choice.requirements else {
            return true  // Нет требований = всегда доступен
        }
        return canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )
    }
}

// MARK: - Shared Instance

/// Глобальный evaluator для проверки требований
enum Requirements {
    static var evaluator: RequirementsEvaluating = RequirementsEvaluator()
}
