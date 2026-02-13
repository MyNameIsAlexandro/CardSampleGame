/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+Quest.swift
/// Назначение: Содержит реализацию файла EngineProtocols+Quest.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 9. Quest System
// ═══════════════════════════════════════════════════════════════════════════════

/// Quest objective
public protocol QuestObjectiveProtocol {
    var id: String { get }
    var description: String { get }
    var isCompleted: Bool { get }

    /// Check if objective is complete based on flags
    func checkCompletion(flags: [String: Bool]) -> Bool
}

/// Quest definition
public protocol QuestDefinitionProtocol {
    associatedtype Objective: QuestObjectiveProtocol

    var id: String { get }
    var title: String { get }
    var isMain: Bool { get }
    var objectives: [Objective] { get }
    var isCompleted: Bool { get }

    /// Rewards on completion
    var rewardTransaction: Transaction { get }
}

/// Quest manager protocol
public protocol QuestManagerProtocol {
    associatedtype Quest: QuestDefinitionProtocol

    var activeQuests: [Quest] { get }
    var completedQuests: [String] { get }

    /// Check quest progress based on flags
    func checkProgress(flags: [String: Bool])

    /// Complete a quest
    func completeQuest(_ questId: String) -> Transaction?
}
