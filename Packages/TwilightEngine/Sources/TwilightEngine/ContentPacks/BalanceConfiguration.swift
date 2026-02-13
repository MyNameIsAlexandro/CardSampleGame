/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/BalanceConfiguration.swift
/// Назначение: Содержит реализацию файла BalanceConfiguration.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Balance Configuration

/// Configuration for game balance parameters loaded from content packs.
/// Replaces hardcoded balance values with data-driven configuration.
public struct BalanceConfiguration: Codable, Sendable {
    // MARK: - Resources

    /// Resource system configuration (health, faith, supplies, gold).
    public var resources: ResourceBalanceConfig

    // MARK: - Pressure/Tension

    /// Pressure system configuration (tension, escalation).
    public var pressure: PressureBalanceConfig

    // MARK: - Combat

    /// Combat system configuration (optional).
    public var combat: CombatBalanceConfig?

    // MARK: - Time

    /// Time system configuration (day/night cycle, action costs).
    public var time: TimeBalanceConfig

    // MARK: - Anchors

    /// Anchor system configuration (integrity, strengthening).
    public var anchor: AnchorBalanceConfig

    // MARK: - End Conditions

    /// Game end conditions (victory/defeat triggers).
    public var endConditions: EndConditionConfig

    // MARK: - Balance System (optional)

    /// Light/Dark balance system configuration.
    public var balanceSystem: BalanceSystemConfig?

    // MARK: - Defaults

    /// Default balance configuration for testing.
    public static let `default` = BalanceConfiguration(
        resources: .default,
        pressure: .default,
        combat: nil,
        time: .default,
        anchor: .default,
        endConditions: .default,
        balanceSystem: nil
    )
}
