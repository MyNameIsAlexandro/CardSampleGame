/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/Helpers/TestRNG.swift
/// Назначение: Содержит реализацию файла TestRNG.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import TwilightEngine

enum TestRNG {
    static func make(seed: UInt64 = 42) -> WorldRNG {
        WorldRNG(seed: seed)
    }
}

enum TestFateDeck {
    static func makeManager(cards: [FateCard], seed: UInt64 = 42) -> FateDeckManager {
        FateDeckManager(cards: cards, rng: TestRNG.make(seed: seed))
    }

    static func makeState(cards: [FateCard], seed: UInt64 = 42) -> FateDeckState {
        makeManager(cards: cards, seed: seed).getState()
    }
}

