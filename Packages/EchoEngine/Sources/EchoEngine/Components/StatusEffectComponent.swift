/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/StatusEffectComponent.swift
/// Назначение: Содержит реализацию файла StatusEffectComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS

/// A single active status effect with remaining duration.
public struct StatusEffect: Equatable {
    public let stat: String     // "shield", "poison", "strength"
    public var amount: Int
    public var duration: Int    // turns remaining; 0 = permanent

    public init(stat: String, amount: Int, duration: Int) {
        self.stat = stat
        self.amount = amount
        self.duration = duration
    }
}

/// Tracks active status effects on an entity.
public final class StatusEffectComponent: Component {
    public var effects: [StatusEffect]

    public init(effects: [StatusEffect] = []) {
        self.effects = effects
    }

    /// Get total value for a given stat across all active effects.
    public func total(for stat: String) -> Int {
        effects.filter { $0.stat == stat }.reduce(0) { $0 + $1.amount }
    }

    /// Add or stack a status effect.
    public func apply(stat: String, amount: Int, duration: Int) {
        if let idx = effects.firstIndex(where: { $0.stat == stat }) {
            effects[idx].amount += amount
            effects[idx].duration = max(effects[idx].duration, duration)
        } else {
            effects.append(StatusEffect(stat: stat, amount: amount, duration: duration))
        }
    }

    /// Tick all effects: decrement durations, remove expired.
    public func tick() {
        effects = effects.compactMap { effect in
            guard effect.duration > 0 else { return effect } // permanent
            var e = effect
            e.duration -= 1
            return e.duration > 0 ? e : nil
        }
    }
}
