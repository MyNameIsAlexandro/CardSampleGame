/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+TestingSupport.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+TestingSupport.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    // MARK: - Testing Helpers

    /// Initialize world regions from preloaded content registry.
    func initializeFromContentRegistry(_ registry: ContentRegistry) {
        _ = registry
        setupRegionsFromRegistry()
    }

    /// Override world tension for deterministic test setup.
    func setWorldTension(_ tension: Int) {
        worldTension = min(100, max(0, tension))
    }

    /// Override current region for deterministic test setup.
    func setCurrentRegion(_ regionId: String) {
        currentRegionId = regionId
    }

    /// Override resonance for deterministic test setup.
    func setResonance(_ value: Float) {
        setWorldResonance(value)
    }

    #if DEBUG
    /// Block scripted events to isolate random encounter behavior in tests.
    func blockAllScriptedEvents() {
        let definitions = contentRegistry.getAllEventDefinitions()
        for definition in definitions {
            completedEventIds.insert(definition.id)
        }
        _blockScriptedEvents = true
    }
    #endif
}
