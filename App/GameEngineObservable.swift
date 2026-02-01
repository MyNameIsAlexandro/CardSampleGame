import SwiftUI
import TwilightEngine

/// App-layer ObservableObject wrapper for TwilightGameEngine.
///
/// Engine is pure logic (no Combine/SwiftUI). This class bridges to SwiftUI
/// by forwarding `onStateChanged` to `objectWillChange`. All views observe
/// this wrapper and access engine state via `vm.engine.X`.
final class GameEngineObservable: ObservableObject {
    let engine: TwilightGameEngine

    init(registry: ContentRegistry = .shared) {
        self.engine = TwilightGameEngine(registry: registry)
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
