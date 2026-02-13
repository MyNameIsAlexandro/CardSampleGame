/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/DifficultyLevel.swift
/// Назначение: Содержит реализацию файла DifficultyLevel.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Game difficulty level with enemy stat multipliers
public enum DifficultyLevel: String, CaseIterable, Codable {
    case easy, normal, hard

    /// Enemy HP multiplier
    public var hpMultiplier: Double {
        switch self {
        case .easy: return 0.75
        case .normal: return 1.0
        case .hard: return 1.5
        }
    }

    /// Enemy power multiplier
    public var powerMultiplier: Double {
        switch self {
        case .easy: return 0.75
        case .normal: return 1.0
        case .hard: return 1.25
        }
    }
}
