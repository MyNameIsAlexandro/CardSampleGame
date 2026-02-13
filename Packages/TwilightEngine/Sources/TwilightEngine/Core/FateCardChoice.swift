/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/FateCardChoice.swift
/// Назначение: Содержит реализацию файла FateCardChoice.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Fate Card Type

/// Type of fate card
public enum FateCardType: String, Codable, Hashable, Sendable {
    case standard
    case choice
}

// MARK: - Fate Choice Option

/// Option for choice-type fate cards
public struct FateChoiceOption: Codable, Equatable, Hashable, Sendable {
    public var label: String
    public var effect: String

    public init(label: String, effect: String) {
        self.label = label
        self.effect = effect
    }
}
