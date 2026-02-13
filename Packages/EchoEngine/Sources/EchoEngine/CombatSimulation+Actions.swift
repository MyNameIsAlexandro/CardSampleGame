/// Файл: Packages/EchoEngine/Sources/EchoEngine/CombatSimulation+Actions.swift
/// Назначение: Содержит реализацию файла CombatSimulation+Actions.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

extension CombatSimulation {

    /// Begin combat: draw hand, generate enemy intent, set phase to playerTurn.
    public func beginCombat() {
        guard let player = playerEntity else { return }

        deckSystem.initializeCombatHand(for: player, nexus: nexus)
        aiSystem.update(nexus: nexus)
        combatSystem.setCombatPhase(.playerTurn, nexus: nexus)
    }

    /// Player attacks enemy.
    @discardableResult
    public func playerAttack(bonusDamage: Int = 0) -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .playerMissed(fateValue: 0, fateResolution: nil)
        }
        let event = combatSystem.playerAttack(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        if case .playerAttacked(let dmg, _, _, _) = event { recordDamageDealt(dmg) }
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
        return event
    }

    /// Play a card from hand. Resolves effect and discards card. Does NOT end the turn.
    @discardableResult
    public func playCard(cardId: String) -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .cardPlayed(cardId: cardId, damage: 0, heal: 0, cardsDrawn: 0, statusApplied: nil)
        }
        let event = combatSystem.playCard(cardId: cardId, player: player, enemy: enemy, deckSystem: deckSystem, nexus: nexus)
        recordCardsPlayed(1)
        if case .cardPlayed(_, let dmg, _, _, _) = event { recordDamageDealt(dmg) }
        return event
    }

    /// Player uses spiritual influence on enemy.
    @discardableResult
    public func playerInfluence(bonusDamage: Int = 0) -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .influenceNotAvailable
        }
        let event = combatSystem.playerInfluence(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
        return event
    }

    /// Player skips (ends turn without acting).
    public func playerSkip() {
        endTurn()
    }

    /// End the player's turn: transitions phase to enemyResolve.
    /// Call resolveEnemyTurn() separately to execute the enemy action.
    public func endTurn() {
        deselectAllCards()
        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)
    }

    /// Resolve enemy turn, then advance round.
    @discardableResult
    public func resolveEnemyTurn() -> CombatEvent {
        guard let player = playerEntity, let enemy = enemyEntity else {
            return .enemyBlocked
        }
        let event = combatSystem.resolveEnemyIntent(enemy: enemy, player: player, nexus: nexus)
        if case .enemyAttacked(let dmg, _, _, _) = event { recordDamageTaken(dmg) }

        if let _ = combatSystem.checkVictoryOrDefeat(nexus: nexus) {
            return event
        }

        combatSystem.advanceRound(nexus: nexus)

        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        energy.current = energy.max
        deckSystem.drawCards(count: 1, for: player, nexus: nexus)

        aiSystem.update(nexus: nexus)
        combatSystem.setCombatPhase(.playerTurn, nexus: nexus)

        return event
    }

    /// Mulligan cards from hand.
    public func mulligan(cardIds: [String]) {
        guard let player = playerEntity else { return }
        deckSystem.mulligan(cardIds: cardIds, for: player, nexus: nexus)
    }
}
