/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols.swift
/// Назначение: Содержит реализацию файла EngineProtocols.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Game Engine v1.0 Core Protocols
// Setting-agnostic contracts for the game engine.
// The engine is the "processor", the game content is the "cartridge".

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Core Engine Types
// ═══════════════════════════════════════════════════════════════════════════════

/// Engine game phase enum
public enum EngineGamePhase: String, Codable {
    case setup
    case playing
    case paused
    case ended
}

/// Game end result
public enum GameEndDefeatReason: String, Codable, Equatable {
    case worldTensionMax
    case heroDied
}

/// Game end result
public enum GameEndResult: Equatable {
    case victory(endingId: String)
    case defeat(reason: GameEndDefeatReason)
    case abandoned
}
