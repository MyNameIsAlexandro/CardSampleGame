import FirebladeECS
import TwilightEngine

/// Combat event emitted by the system for UI/logging.
public enum CombatEvent {
    case playerAttacked(damage: Int, fateValue: Int, enemyHealthRemaining: Int)
    case playerMissed(fateValue: Int)
    case enemyAttacked(damage: Int, fateValue: Int, playerHealthRemaining: Int)
    case enemyHealed(amount: Int)
    case enemyRitual(resonanceShift: Float)
    case enemyBlocked
    case cardPlayed(cardId: String, damage: Int, heal: Int, cardsDrawn: Int, statusApplied: String?)
    case insufficientEnergy(cardId: String)
    case roundAdvanced(newRound: Int)
}

/// Manages combat phases, attack resolution, and victory/defeat.
public struct CombatSystem: EchoSystem {

    public init() {}

    public func update(nexus: Nexus) {
        // Phase machine could auto-advance here if needed.
    }

    // MARK: - Player Attack

    /// Player attacks enemy. Draws a Fate card, calculates damage.
    /// Formula: baseDamage = strength + bonusDamage, totalAttack = baseDamage + fateValue
    /// If totalAttack >= enemyDefense: damage = max(1, totalAttack - enemyDefense + 1)
    public func playerAttack(
        player: Entity,
        enemy: Entity,
        bonusDamage: Int = 0,
        nexus: Nexus
    ) -> CombatEvent {
        let playerTag: PlayerTagComponent = nexus.get(unsafe: player.identifier)
        let enemyTag: EnemyTagComponent = nexus.get(unsafe: enemy.identifier)
        let enemyHealth: HealthComponent = nexus.get(unsafe: enemy.identifier)

        // Draw fate card
        let combatFamily = nexus.family(requires: CombatStateComponent.self)
        var fateValue = 0

        // Try to get FateDeck from combat entity
        for combatEntity in combatFamily.entities {
            if combatEntity.has(FateDeckComponent.self) {
                let fateDeckComp: FateDeckComponent = nexus.get(unsafe: combatEntity.identifier)
                if combatEntity.has(ResonanceComponent.self) {
                    let resonance: ResonanceComponent = nexus.get(unsafe: combatEntity.identifier)
                    if let result = fateDeckComp.fateDeck.drawAndResolve(worldResonance: resonance.value) {
                        fateValue = result.effectiveValue
                    }
                } else if let result = fateDeckComp.fateDeck.drawAndResolve(worldResonance: 0) {
                    fateValue = result.effectiveValue
                }
                break
            }
        }

        let baseDamage = playerTag.strength + bonusDamage
        let totalAttack = baseDamage + fateValue

        if totalAttack >= enemyTag.defense {
            let damage = max(1, totalAttack - enemyTag.defense + 1)
            enemyHealth.current = max(0, enemyHealth.current - damage)
            return .playerAttacked(damage: damage, fateValue: fateValue, enemyHealthRemaining: enemyHealth.current)
        } else {
            return .playerMissed(fateValue: fateValue)
        }
    }

    // MARK: - Enemy Resolve

    /// Resolve enemy intent. Draws a Fate card for defense.
    public func resolveEnemyIntent(
        enemy: Entity,
        player: Entity,
        nexus: Nexus
    ) -> CombatEvent {
        let intent: IntentComponent = nexus.get(unsafe: enemy.identifier)
        let playerHealth: HealthComponent = nexus.get(unsafe: player.identifier)
        let enemyHealth: HealthComponent = nexus.get(unsafe: enemy.identifier)

        guard let enemyIntent = intent.intent else {
            return .enemyBlocked
        }

        switch enemyIntent.type {
        case .attack:
            // Draw fate for defense
            var fateValue = 0
            let combatFamily = nexus.family(requires: CombatStateComponent.self)
            for combatEntity in combatFamily.entities {
                if combatEntity.has(FateDeckComponent.self) {
                    let fateDeckComp: FateDeckComponent = nexus.get(unsafe: combatEntity.identifier)
                    let resonance: Float
                    if combatEntity.has(ResonanceComponent.self) {
                        let res: ResonanceComponent = nexus.get(unsafe: combatEntity.identifier)
                        resonance = res.value
                    } else {
                        resonance = 0
                    }
                    if let result = fateDeckComp.fateDeck.drawAndResolve(worldResonance: resonance) {
                        fateValue = result.effectiveValue
                    }
                    break
                }
            }

            let damageReduction = fateValue
            var actualDamage = max(0, enemyIntent.value - damageReduction)
            // Player shield absorbs damage
            if player.has(StatusEffectComponent.self) {
                let status: StatusEffectComponent = nexus.get(unsafe: player.identifier)
                let shield = status.total(for: "shield")
                if shield > 0 {
                    let absorbed = min(shield, actualDamage)
                    status.apply(stat: "shield", amount: -absorbed, duration: 1)
                    if status.total(for: "shield") <= 0 {
                        status.effects.removeAll { $0.stat == "shield" }
                    }
                    actualDamage -= absorbed
                }
            }
            actualDamage = max(0, actualDamage)
            if actualDamage > 0 {
                playerHealth.current = max(0, playerHealth.current - actualDamage)
            }
            return .enemyAttacked(damage: actualDamage, fateValue: fateValue, playerHealthRemaining: playerHealth.current)

        case .heal:
            let healAmount = enemyIntent.value
            enemyHealth.current = min(enemyHealth.max, enemyHealth.current + healAmount)
            return .enemyHealed(amount: healAmount)

        case .ritual:
            let shift = Float(enemyIntent.secondaryValue ?? -5)
            let combatFamily = nexus.family(requires: CombatStateComponent.self)
            for combatEntity in combatFamily.entities {
                if combatEntity.has(ResonanceComponent.self) {
                    let res: ResonanceComponent = nexus.get(unsafe: combatEntity.identifier)
                    res.value = max(-100, min(100, res.value + shift))
                    break
                }
            }
            return .enemyRitual(resonanceShift: shift)

        case .block, .buff, .defend, .prepare, .debuff, .summon, .restoreWP:
            return .enemyBlocked
        }
    }

    // MARK: - Card Play

    /// Play a card from hand. Resolves first ability effect, discards card.
    public func playCard(
        cardId: String,
        player: Entity,
        enemy: Entity,
        deckSystem: DeckSystem,
        nexus: Nexus
    ) -> CombatEvent {
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        guard let card = deck.hand.first(where: { $0.id == cardId }) else {
            return .cardPlayed(cardId: cardId, damage: 0, heal: 0, cardsDrawn: 0, statusApplied: nil)
        }

        // Check energy cost
        let energy: EnergyComponent = nexus.get(unsafe: player.identifier)
        let cost = card.cost ?? 1
        guard cost <= energy.current else {
            return .insufficientEnergy(cardId: cardId)
        }
        energy.current -= cost

        let playerHealth: HealthComponent = nexus.get(unsafe: player.identifier)
        let enemyHealth: HealthComponent = nexus.get(unsafe: enemy.identifier)

        let playerStatus: StatusEffectComponent = nexus.get(unsafe: player.identifier)
        let enemyStatus: StatusEffectComponent = nexus.get(unsafe: enemy.identifier)

        var totalDamage = 0
        var totalHeal = 0
        var totalDrawn = 0
        var statusApplied: String? = nil
        var strengthApplied = false

        // Resolve all abilities
        if card.abilities.isEmpty {
            // No abilities — use card power as damage
            let dmg = max(0, card.power ?? 0)
            if dmg > 0 {
                enemyHealth.current = max(0, enemyHealth.current - dmg)
                totalDamage += dmg
            }
        }
        for ability in card.abilities {
            switch ability.effect {
            case .damage(let amount, _):
                var dmg = max(0, amount)
                // Strength buff applies once per card
                if !strengthApplied {
                    dmg += playerStatus.total(for: "strength")
                    strengthApplied = true
                }
                // Enemy shield absorbs damage
                let shield = enemyStatus.total(for: "shield")
                if shield > 0 {
                    let absorbed = min(shield, dmg)
                    enemyStatus.apply(stat: "shield", amount: -absorbed, duration: 1)
                    if enemyStatus.total(for: "shield") <= 0 {
                        enemyStatus.effects.removeAll { $0.stat == "shield" }
                    }
                    dmg -= absorbed
                }
                dmg = max(0, dmg)
                enemyHealth.current = max(0, enemyHealth.current - dmg)
                totalDamage += dmg

            case .heal(let amount):
                let heal = min(amount, playerHealth.max - playerHealth.current)
                playerHealth.current += heal
                totalHeal += heal

            case .drawCards(let count):
                let beforeCount = deck.hand.count
                deckSystem.drawCards(count: count, for: player, nexus: nexus)
                totalDrawn += deck.hand.count - beforeCount

            case .temporaryStat(let stat, let amount, let duration):
                if stat == "poison" {
                    enemyStatus.apply(stat: stat, amount: amount, duration: duration)
                } else {
                    playerStatus.apply(stat: stat, amount: amount, duration: duration)
                }
                statusApplied = stat

            case .gainFaith(let amount):
                energy.current = min(energy.max, energy.current + amount)
                statusApplied = "energy"

            default:
                break
            }
        }

        // Discard or exhaust the played card
        if card.exhaust {
            deckSystem.exhaustCard(id: cardId, for: player, nexus: nexus)
        } else {
            deckSystem.discardCard(id: cardId, for: player, nexus: nexus)
        }

        return .cardPlayed(cardId: cardId, damage: totalDamage, heal: totalHeal, cardsDrawn: totalDrawn, statusApplied: statusApplied)
    }

    // MARK: - Round Management

    /// Advance to next round: increment round counter, clear intents.
    public func advanceRound(nexus: Nexus) {
        let combatFamily = nexus.family(requires: CombatStateComponent.self)
        for state in combatFamily {
            state.round += 1
        }

        // Clear all enemy intents
        let intentFamily = nexus.family(requires: IntentComponent.self)
        for intent in intentFamily {
            intent.intent = nil
        }

        // Tick status effects: apply poison, decrement durations
        let statusFamily = nexus.family(requires: StatusEffectComponent.self)
        for entity in statusFamily.entities {
            let status: StatusEffectComponent = nexus.get(unsafe: entity.identifier)
            let poison = status.total(for: "poison")
            if poison > 0, entity.has(HealthComponent.self) {
                let health: HealthComponent = nexus.get(unsafe: entity.identifier)
                health.current = max(0, health.current - poison)
            }
            status.tick()
        }
    }

    /// Check for victory or defeat.
    public func checkVictoryOrDefeat(nexus: Nexus) -> CombatOutcome? {
        // Check enemy defeated
        let enemies = nexus.family(requiresAll: EnemyTagComponent.self, HealthComponent.self)
        var allEnemiesDead = true
        for (_, health) in enemies {
            if health.isAlive { allEnemiesDead = false; break }
        }
        if allEnemiesDead && enemies.count > 0 {
            setCombatPhase(.victory, nexus: nexus)
            return .victory
        }

        // Check player defeated
        let players = nexus.family(requiresAll: PlayerTagComponent.self, HealthComponent.self)
        for (_, health) in players {
            if !health.isAlive {
                setCombatPhase(.defeat, nexus: nexus)
                return .defeat
            }
        }

        return nil
    }

    // MARK: - Phase Management

    public func setCombatPhase(_ phase: EchoCombatPhase, nexus: Nexus) {
        let family = nexus.family(requires: CombatStateComponent.self)
        for state in family {
            state.phase = phase
            if phase == .victory || phase == .defeat {
                state.isActive = false
            }
        }
    }
}
