/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineWorldBootstrapState.swift
/// Назначение: Содержит реализацию файла EngineWorldBootstrapState.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Immutable bootstrap values for world state initialization.
public struct EngineWorldBootstrapState: Equatable, Sendable {
    public let day: Int
    public let tension: Int
    public let lightDarkBalance: Int
    public let mainQuestStage: Int

    public init(
        day: Int,
        tension: Int,
        lightDarkBalance: Int = 50,
        mainQuestStage: Int = 1
    ) {
        self.day = max(0, day)
        self.tension = min(100, max(0, tension))
        self.lightDarkBalance = min(100, max(0, lightDarkBalance))
        self.mainQuestStage = max(1, mainQuestStage)
    }

    public static func from(balanceConfig: BalanceConfiguration) -> EngineWorldBootstrapState {
        EngineWorldBootstrapState(
            day: 0,
            tension: balanceConfig.pressure.startingPressure
        )
    }

    /// Minimal resilient bootstrap values used for incompatible save recovery.
    public static let fallback = EngineWorldBootstrapState(
        day: 1,
        tension: 30,
        lightDarkBalance: 50,
        mainQuestStage: 1
    )
}
