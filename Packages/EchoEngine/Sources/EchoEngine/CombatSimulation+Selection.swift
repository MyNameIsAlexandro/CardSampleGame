/// Файл: Packages/EchoEngine/Sources/EchoEngine/CombatSimulation+Selection.swift
/// Назначение: Содержит реализацию файла CombatSimulation+Selection.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

extension CombatSimulation {

    /// Available energy after reservations.
    public var availableEnergy: Int {
        guard let player = playerEntity else { return 0 }
        let e: EnergyComponent = nexus.get(unsafe: player.identifier)
        return e.current - reservedEnergy
    }

    /// Select a card from hand for the next commit action. Returns false if card can't be selected.
    public func selectCard(cardId: String) -> Bool {
        guard let player = playerEntity else { return false }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        guard let card = deck.hand.first(where: { $0.id == cardId }) else { return false }
        guard !selectedCardIds.contains(cardId) else { return false }

        let cost = card.cost ?? 1
        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        guard cost <= (energy.current - reservedEnergy) else { return false }

        appendSelectedCardId(cardId)
        reserveEnergy(cost)
        return true
    }

    /// Deselect a previously selected card, refunding its energy reservation.
    public func deselectCard(cardId: String) {
        guard let idx = selectedCardIds.firstIndex(of: cardId) else { return }
        guard let player = playerEntity else { return }
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        if let card = deck.hand.first(where: { $0.id == cardId }) {
            refundEnergy(card.cost ?? 1)
        }
        removeSelectedCardId(at: idx)
    }

    /// Deselect all cards and reset reserved energy.
    public func deselectAllCards() {
        resetSelection()
    }

    /// Commit selected cards + attack. Returns all combat events.
    /// Cards' damage abilities accumulate as bonusDamage; heal/draw/status apply immediately.
    /// One Fate draw for the whole action.
    @discardableResult
    public func commitAttack() -> [CombatEvent] {
        guard let player = playerEntity, let enemy = enemyEntity else { return [] }

        var events: [CombatEvent] = []

        let bonusDamage = resolveSelectedCardEffects(player: player, enemy: enemy, events: &events)

        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        energy.current -= reservedEnergy

        let attackEvent = combatSystem.playerAttack(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        events.append(attackEvent)
        if case .playerAttacked(let dmg, _, _, _) = attackEvent { recordDamageDealt(dmg) }

        discardSelectedCards(player: player)

        let cardCount = selectedCardIds.count
        resetSelection()
        recordCardsPlayed(cardCount)

        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)

        return events
    }

    /// Commit selected cards + influence. Same pattern as commitAttack but for spiritual track.
    @discardableResult
    public func commitInfluence() -> [CombatEvent] {
        guard let player = playerEntity, let enemy = enemyEntity else { return [] }

        var events: [CombatEvent] = []
        let bonusDamage = resolveSelectedCardEffects(player: player, enemy: enemy, events: &events)

        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        energy.current -= reservedEnergy

        let influenceEvent = combatSystem.playerInfluence(player: player, enemy: enemy, bonusDamage: bonusDamage, nexus: nexus)
        events.append(influenceEvent)

        discardSelectedCards(player: player)

        let cardCount = selectedCardIds.count
        resetSelection()
        recordCardsPlayed(cardCount)

        combatSystem.setCombatPhase(.enemyResolve, nexus: nexus)

        return events
    }

    /// Resolve all selected card abilities. Damage is accumulated and returned as bonusDamage.
    /// Non-damage effects (heal, draw, status) apply immediately.
    private func resolveSelectedCardEffects(player: Entity, enemy: Entity, events: inout [CombatEvent]) -> Int {
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        let playerHealth: HealthComponent = nexus.get(unsafe: player.identifier)
        let playerStatus: StatusEffectComponent = nexus.get(unsafe: player.identifier)
        let enemyStatus: StatusEffectComponent = nexus.get(unsafe: enemy.identifier)

        var bonusDamage = 0

        for cardId in selectedCardIds {
            guard let card = deck.hand.first(where: { $0.id == cardId }) else { continue }

            var cardDamage = 0
            var cardHeal = 0
            var cardDrawn = 0
            var statusApplied: String? = nil

            if card.abilities.isEmpty {
                cardDamage += max(0, card.power ?? 0)
            }

            for ability in card.abilities {
                switch ability.effect {
                case .damage(let amount, _):
                    cardDamage += max(0, amount)

                case .heal(let amount):
                    let heal = min(amount, playerHealth.max - playerHealth.current)
                    playerHealth.current += heal
                    cardHeal += heal

                case .drawCards(let count):
                    let beforeCount = deck.hand.count
                    deckSystem.drawCards(count: count, for: player, nexus: nexus)
                    cardDrawn += deck.hand.count - beforeCount

                case .temporaryStat(let stat, let amount, let duration):
                    if stat == "poison" {
                        enemyStatus.apply(stat: stat, amount: amount, duration: duration)
                    } else {
                        playerStatus.apply(stat: stat, amount: amount, duration: duration)
                    }
                    statusApplied = stat

                case .gainFaith(let amount):
                    let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
                    energy.current = min(energy.max, energy.current + amount)
                    statusApplied = "energy"

                case .shiftBalance(let towards, let amount):
                    let combatFamily = nexus.family(requires: CombatStateComponent.self)
                    for combatEntity in combatFamily.entities {
                        if combatEntity.has(ResonanceComponent.self) {
                            let res: ResonanceComponent = nexus.get(unsafe: combatEntity.identifier)
                            let delta: Float
                            switch towards {
                            case .light: delta = Float(amount)
                            case .dark: delta = Float(-amount)
                            case .neutral: delta = res.value > 0 ? Float(-amount) : Float(amount)
                            }
                            res.value = max(-100, min(100, res.value + delta))
                            break
                        }
                    }
                    statusApplied = "resonance"

                case .applyCurse(let curseType, let duration):
                    enemyStatus.apply(stat: curseType.rawValue, amount: 1, duration: duration)
                    statusApplied = curseType.rawValue

                case .permanentStat(let stat, let amount):
                    if stat == "poison" {
                        enemyStatus.apply(stat: stat, amount: amount, duration: 99)
                    } else {
                        playerStatus.apply(stat: stat, amount: amount, duration: 99)
                    }
                    statusApplied = stat

                default:
                    break
                }
            }

            bonusDamage += cardDamage
            events.append(.cardPlayed(cardId: cardId, damage: cardDamage, heal: cardHeal, cardsDrawn: cardDrawn, statusApplied: statusApplied))
        }

        return bonusDamage
    }

    /// Discard or exhaust all selected cards.
    private func discardSelectedCards(player: Entity) {
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        for cardId in selectedCardIds {
            guard let card = deck.hand.first(where: { $0.id == cardId }) else { continue }
            if card.exhaust {
                deckSystem.exhaustCard(id: cardId, for: player, nexus: nexus)
            } else {
                deckSystem.discardCard(id: cardId, for: player, nexus: nexus)
            }
        }
    }
}
