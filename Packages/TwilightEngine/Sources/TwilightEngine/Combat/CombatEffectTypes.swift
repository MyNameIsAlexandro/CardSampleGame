/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatEffectTypes.swift
/// Назначение: Содержит реализацию файла CombatEffectTypes.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Combat effect (events in combat).
public struct CombatEffect {
    public let icon: String
    public let description: String
    public let type: CombatEffectType

    public init(icon: String, description: String, type: CombatEffectType) {
        self.icon = icon
        self.description = description
        self.type = type
    }
}

/// Combat effect type.
public enum CombatEffectType {
    case damage
    case heal
    case buff
    case debuff
    case summon
    case special
}
