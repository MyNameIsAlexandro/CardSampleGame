/// Файл: App/AppServices.swift
/// Назначение: Содержит реализацию файла AppServices.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import TwilightEngine

/// App composition root for engine-adjacent dependencies.
///
/// Owns a single `ContentRegistry` instance and the derived services that must
/// share the same content snapshot (registry + localization + RNG).
///
/// Intent: eliminate engine-level singletons (`*.shared`) from the app layer.
struct AppServices {
    let engineServices: EngineServices
    let contentManager: ContentManager
    let safeContentAccess: SafeContentAccess
    let cardFactory: CardFactory

    var registry: ContentRegistry { engineServices.contentRegistry }
    var localizationManager: LocalizationManager { engineServices.localizationManager }
    var rng: WorldRNG { engineServices.rng }

    init(rng: WorldRNG, registry: ContentRegistry, localizationManager: LocalizationManager) {
        let engineServices = EngineServices(
            rng: rng,
            contentRegistry: registry,
            localizationManager: localizationManager
        )
        self.engineServices = engineServices
        self.contentManager = ContentManager(registry: registry)
        self.safeContentAccess = SafeContentAccess(registry: registry)
        self.cardFactory = CardFactory(
            contentRegistry: registry,
            localizationManager: localizationManager
        )
    }
}

