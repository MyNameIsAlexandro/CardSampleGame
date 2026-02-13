/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+GameEngine.swift
/// Назначение: Содержит реализацию файла EngineProtocols+GameEngine.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 10. Core Engine Protocol
// ═══════════════════════════════════════════════════════════════════════════════

/// Main game engine orchestrator protocol
public protocol GameEngineProtocol {
    associatedtype PlayerState
    associatedtype WorldManager: WorldStateManagerProtocol
    associatedtype EventSystem: EventSystemProtocol
    associatedtype Resolver: ConflictResolverProtocol
    associatedtype QuestManager: QuestManagerProtocol
    associatedtype EndChecker: EndGameCheckerProtocol

    // Subsystems
    var timeEngine: any TimeEngineProtocol { get }
    var pressureEngine: any PressureEngineProtocol { get }
    var worldManager: WorldManager { get }
    var eventSystem: EventSystem { get }
    var resolver: Resolver { get }
    var questManager: QuestManager { get }
    var endChecker: EndChecker { get }
    var economyManager: any EconomyManagerProtocol { get }

    // State
    var playerState: PlayerState { get }
    var isGameOver: Bool { get }
    var isVictory: Bool { get }

    // Core Loop
    func performAction(_ action: any TimedAction) async
    func worldTick()
    func checkEndConditions()
    func save()
}
