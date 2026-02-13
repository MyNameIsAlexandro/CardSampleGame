/// Файл: Packages/EchoScenes/Tests/EchoScenesTests/CombatSceneThemeTests.swift
/// Назначение: Содержит реализацию файла CombatSceneThemeTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import SpriteKit
@testable import EchoScenes

@Suite("CombatSceneTheme Tests")
struct CombatSceneThemeTests {

    @Test("Theme colors have expected characteristics")
    func testThemeColors() {
        // Background should be very dark
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        CombatSceneTheme.background.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(r < 0.15)
        #expect(g < 0.15)
        #expect(b < 0.15)

        // Health should be reddish
        CombatSceneTheme.health.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(r > g)
        #expect(r > b)

        // Success should be greenish
        CombatSceneTheme.success.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(g > r)
        #expect(g > b)

        // Spirit should be bluish
        CombatSceneTheme.spirit.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(b > r)
        #expect(b > g)
    }
}
