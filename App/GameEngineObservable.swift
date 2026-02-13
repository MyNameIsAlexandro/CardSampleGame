/// Файл: App/GameEngineObservable.swift
/// Назначение: Содержит реализацию файла GameEngineObservable.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// App-layer ObservableObject wrapper for TwilightGameEngine.
///
/// Engine is pure logic (no Combine/SwiftUI). This class bridges to SwiftUI
/// by forwarding `onStateChanged` to `objectWillChange`. All views observe
/// this wrapper and access engine state via `vm.engine.X`.
final class GameEngineObservable: ObservableObject {
    let engine: TwilightGameEngine

    init(engineServices: EngineServices) {
        self.engine = TwilightGameEngine(services: engineServices)
        self.engine.onStateChanged = { [weak self] in
            self?.objectWillChange.send()
        }
    }

    /// Wrap an existing engine (for previews and tests).
    init(engine: TwilightGameEngine) {
        self.engine = engine
        self.engine.onStateChanged = { [weak self] in
            self?.objectWillChange.send()
        }
    }
}
