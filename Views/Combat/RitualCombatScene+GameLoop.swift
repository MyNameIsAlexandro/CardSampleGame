/// Файл: Views/Combat/RitualCombatScene+GameLoop.swift
/// Назначение: Game loop ритуальной сцены — touch, DragCommand, фазы, эмиссия результата.
/// Зона ответственности: Input handling, phase transitions, combat resolution.
/// Контекст: Phase 3 Ritual Combat (R9). Extension of RitualCombatScene.

import SpriteKit
import TwilightEngine

// MARK: - Game Loop

extension RitualCombatScene {

    // MARK: - Phase Machine

    func advancePhase() {
        guard let sim = simulation else { return }

        switch sim.phase {
        case .playerAction:
            enableInput()
            sealNodes.forEach { $0.setActive(true) }

        case .resolution:
            disableInput()
            sealNodes.forEach { $0.setActive(false) }
            resolveEnemyTurn()

        case .finished:
            disableInput()
            sealNodes.forEach { $0.setActive(false) }
            emitResult()
        }
    }

    private func enableInput() {
        inputEnabled = true
    }

    private func disableInput() {
        inputEnabled = false
        selectedTargetId = nil
        idolNodes.forEach { $0.setHoverTarget(false) }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let cardId = hitTestCard(at: location) {
            touchStartLocation = location
            dragController?.beginTouch(cardId: cardId)
            return
        }

        if let sealIndex = hitTestSeal(at: location) {
            handleSealTap(index: sealIndex)
            return
        }

        if let idolId = hitTestIdol(at: location) {
            selectedTargetId = idolId
            idolNodes.forEach { $0.setHoverTarget($0.enemyId == idolId) }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let start = touchStartLocation {
            let offset = CGSize(width: location.x - start.x, height: location.y - start.y)
            dragController?.updateDrag(offset: offset)
        }

        if let idolId = hitTestIdol(at: location) {
            selectedTargetId = idolId
            idolNodes.forEach { $0.setHoverTarget($0.enemyId == idolId) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled else { return }
        touchStartLocation = nil

        if let dc = dragController, dc.state != .idle {
            dc.endTouch()
            return
        }

        idolNodes.forEach { $0.setHoverTarget(false) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragController?.cancel()
        idolNodes.forEach { $0.setHoverTarget(false) }
    }

    // MARK: - Hit Testing

    private func hitTestCard(at point: CGPoint) -> String? {
        let layer = handLayer ?? self
        let localPoint = convert(point, to: layer)
        for (cardId, node) in handCardNodes {
            if node.frame.contains(localPoint) || node.contains(localPoint) {
                return cardId
            }
        }
        return nil
    }

    private func hitTestSeal(at point: CGPoint) -> Int? {
        for (i, seal) in sealNodes.enumerated() where seal.isActive {
            let localPoint = convert(point, to: seal.parent ?? self)
            if seal.frame.contains(localPoint) {
                return i
            }
        }
        return nil
    }

    private func hitTestIdol(at point: CGPoint) -> String? {
        for idol in idolNodes {
            let localPoint = convert(point, to: idol.parent ?? self)
            let idolFrame = CGRect(
                x: idol.position.x - IdolNode.frameSize.width / 2,
                y: idol.position.y - IdolNode.frameSize.height / 2,
                width: IdolNode.frameSize.width,
                height: IdolNode.frameSize.height
            )
            if idolFrame.contains(localPoint) {
                return idol.enemyId
            }
        }
        return nil
    }

    private func determineDropZone(at point: CGPoint) -> DragDropZone {
        if let circle = ritualCircle {
            let dist = hypot(point.x - circle.position.x, point.y - circle.position.y)
            if dist < 70 { return .circle }
        }
        if let bonfire = bonfireNode {
            let dist = hypot(point.x - bonfire.position.x, point.y - bonfire.position.y)
            if dist < 55 { return .bonfire }
        }
        return .none
    }

    // MARK: - Drag Command

    func handleDragCommand(_ command: DragCommand) {
        guard let sim = simulation else { return }

        switch command {
        case .selectCard(let cardId):
            sim.selectCard(cardId)
            accumulatedCardsPlayed += 1
            syncVisuals()

        case .burnForEffort(let cardId):
            if sim.burnForEffort(cardId) {
                bonfireNode?.playBurnAnimation()
                onSoundEffect?("effortBurn")
                onHaptic?("medium")
                syncVisuals()
            }

        case .cancelDrag:
            syncVisuals()
        }
    }

    // MARK: - Seal Actions

    private func handleSealTap(index: Int) {
        guard index < sealNodes.count else { return }
        let seal = sealNodes[index]

        switch seal.sealType {
        case .strike:
            performCommitAttack()
        case .speak:
            performCommitInfluence()
        case .wait:
            performSkipTurn()
        }
    }

    private func performCommitAttack() {
        guard let sim = simulation,
              !sim.selectedCardIds.isEmpty else { return }

        let targetId = selectedTargetId ?? sim.enemies.first(where: { $0.hp > 0 })?.id
        guard let target = targetId else { return }

        let result = sim.commitAttack(targetId: target)
        accumulatedDamageDealt += result.damage

        if let fate = result.fateDrawResult {
            fateDirector?.onRevealComplete = { [weak self] in
                self?.afterAttackResolution(targetId: target)
            }
            fateDirector?.beginReveal(
                cardName: fate.card.name,
                effectiveValue: fate.effectiveValue,
                isSuitMatch: false,
                isCritical: fate.isCritical
            )
        } else {
            afterAttackResolution(targetId: target)
        }
    }

    private func afterAttackResolution(targetId: String) {
        guard let sim = simulation else { return }
        syncVisuals()

        if let enemy = sim.enemies.first(where: { $0.id == targetId }), enemy.hp <= 0 {
            if let idol = idolNodes.first(where: { $0.enemyId == targetId }) {
                idol.playKillAnimation { [weak self] in
                    self?.checkCombatEnd()
                }
                onHaptic?("heavy")
                return
            }
        }

        checkCombatEnd()
    }

    private func performCommitInfluence() {
        // Speak seal — placeholder for spiritual combat path
        // Currently transitions to resolution phase
        transitionToResolution()
    }

    private func performSkipTurn() {
        transitionToResolution()
    }

    // MARK: - Resolution Phase

    private func transitionToResolution() {
        guard let sim = simulation else { return }
        sim.setPhase(.resolution)
        advancePhase()
    }

    func resolveEnemyTurn() {
        guard let sim = simulation else { return }

        let attacks = sim.resolveEnemyTurn()

        for attack in attacks {
            accumulatedDamageTaken += attack.damage
            if let idol = idolNodes.first(where: { $0.enemyId == attack.enemyId }) {
                idol.showIntent(type: "ATK", value: attack.damage)
            }
        }

        amuletNode?.playDamageFlash()
        onHaptic?("medium")
        syncVisuals()

        run(SKAction.wait(forDuration: 0.8)) { [weak self] in
            self?.idolNodes.forEach { $0.hideIntent() }
            self?.advancePhase()
        }
    }

    // MARK: - Combat End

    private func checkCombatEnd() {
        guard let sim = simulation else { return }

        let allDefeated = sim.enemies.allSatisfy { $0.hp <= 0 }
        if allDefeated {
            sim.setPhase(.finished)
            advancePhase()
        } else {
            transitionToResolution()
        }
    }

    private func emitResult() {
        guard let sim = simulation else { return }

        let allDefeated = sim.enemies.allSatisfy { $0.hp <= 0 }
        let heroAlive = sim.heroHP > 0

        let outcome: RitualCombatOutcome
        if heroAlive && allDefeated {
            outcome = .victory(.killed)
        } else {
            outcome = .defeat
        }

        let result = RitualCombatResult(
            outcome: outcome,
            hpDelta: sim.heroHP - initialHeroHP,
            resonanceDelta: 0,
            faithDelta: 0,
            lootCardIds: [],
            updatedFateDeckState: sim.snapshot().fateDeckState,
            turnsPlayed: sim.round,
            totalDamageDealt: accumulatedDamageDealt,
            totalDamageTaken: accumulatedDamageTaken,
            cardsPlayed: accumulatedCardsPlayed
        )

        onCombatEnd?(result)
    }
}

// MARK: - Drop Zone

enum DragDropZone {
    case circle
    case bonfire
    case none
}

// MARK: - Safe Collection Access

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
