/// Файл: Packages/EchoEngine/Sources/EchoEngine/CombatSimulation.swift
/// Назначение: Содержит реализацию файла CombatSimulation.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

/// High-level orchestrator for a complete combat encounter.
/// Owns the Nexus and all systems. Provides a simple API for tests and future UI.
public final class CombatSimulation {
    public let nexus: Nexus
    public let combatSystem: CombatSystem
    public let aiSystem: AISystem
    public let deckSystem: DeckSystem

    // Combat stats tracking
    public private(set) var statDamageDealt: Int = 0
    public private(set) var statDamageTaken: Int = 0
    public private(set) var statCardsPlayed: Int = 0

    // Card selection state (select-then-commit model)
    public private(set) var selectedCardIds: [String] = []
    public private(set) var reservedEnergy: Int = 0

    public init(nexus: Nexus, rng: WorldRNG) {
        self.nexus = nexus
        self.combatSystem = CombatSystem()
        self.aiSystem = AISystem(rng: rng)
        self.deckSystem = DeckSystem(rng: rng)
    }

    func appendSelectedCardId(_ cardId: String) {
        selectedCardIds.append(cardId)
    }

    func removeSelectedCardId(at index: Int) {
        selectedCardIds.remove(at: index)
    }

    func resetSelection() {
        selectedCardIds.removeAll()
        reservedEnergy = 0
    }

    func reserveEnergy(_ amount: Int) {
        reservedEnergy += amount
    }

    func refundEnergy(_ amount: Int) {
        reservedEnergy = max(0, reservedEnergy - amount)
    }

    func recordDamageDealt(_ amount: Int) {
        statDamageDealt += amount
    }

    func recordDamageTaken(_ amount: Int) {
        statDamageTaken += amount
    }

    func recordCardsPlayed(_ count: Int) {
        statCardsPlayed += count
    }
}
