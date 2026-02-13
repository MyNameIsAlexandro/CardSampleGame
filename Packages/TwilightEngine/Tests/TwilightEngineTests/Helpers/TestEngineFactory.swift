/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/Helpers/TestEngineFactory.swift
/// Назначение: Содержит реализацию файла TestEngineFactory.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import TwilightEngine

enum TestEngineFactory {
    static func makeServices(seed: UInt64 = 42) -> EngineServices {
        let registry = TestContentLoader.sharedLoadedRegistry()
        return EngineServices(
            rng: WorldRNG(seed: seed),
            contentRegistry: registry,
            localizationManager: LocalizationManager()
        )
    }

    static func makeEngine(seed: UInt64 = 42) -> TwilightGameEngine {
        TwilightGameEngine(services: makeServices(seed: seed))
    }
}

