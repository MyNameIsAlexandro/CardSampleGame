/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/DiplomacyComponent.swift
/// Назначение: Содержит реализацию файла DiplomacyComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

/// Tracks the player's current attack track and escalation/deescalation state.
public enum AttackTrack: String, Codable {
    case physical
    case spiritual
}

public final class DiplomacyComponent: Component {
    /// Current attack track (physical or spiritual).
    public var currentTrack: AttackTrack
    /// Rage shield turns remaining — extra enemy defense after switching spiritual→physical.
    public var rageShield: Int
    /// Surprise bonus turns remaining — extra spirit damage after switching physical→spiritual.
    public var surpriseBonus: Int

    public init(
        currentTrack: AttackTrack = .physical,
        rageShield: Int = 0,
        surpriseBonus: Int = 0
    ) {
        self.currentTrack = currentTrack
        self.rageShield = rageShield
        self.surpriseBonus = surpriseBonus
    }
}
