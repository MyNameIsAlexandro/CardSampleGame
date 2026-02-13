/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/EncounterEngine+SuitMatching.swift
/// Назначение: Содержит реализацию файла EncounterEngine+SuitMatching.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension EncounterEngine {
    func findEnemyIndex(id: String) -> Int? {
        enemies.firstIndex(where: { $0.id == id })
    }

    /// Suit alignment: nav ↔ physical/defense, prav ↔ spiritual, yav ↔ neutral (matches all)
    func isSuitMatch(_ suit: FateCardSuit?, for context: ActionContext) -> Bool {
        guard let suit = suit else { return false }
        switch (suit, context) {
        case (.yav, _): return true
        case (.nav, .combatPhysical), (.nav, .defense): return true
        case (.prav, .combatSpiritual), (.prav, .dialogue): return true
        default: return false
        }
    }

    func isSuitMismatch(_ suit: FateCardSuit?, for context: ActionContext) -> Bool {
        guard let suit = suit else { return false }
        switch (suit, context) {
        case (.yav, _): return false
        case (.nav, .combatSpiritual), (.nav, .dialogue): return true
        case (.prav, .combatPhysical), (.prav, .defense): return true
        default: return false
        }
    }
}
