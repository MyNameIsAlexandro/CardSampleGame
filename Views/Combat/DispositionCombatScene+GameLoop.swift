/// Файл: Views/Combat/DispositionCombatScene+GameLoop.swift
/// Назначение: Game loop Disposition Combat — touch handling, card actions, enemy turns, result emission.
/// Зона ответственности: Input → card drag → action zones → enemy resolution → outcome.
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import SpriteKit
import TwilightEngine

// MARK: - Game Loop

extension DispositionCombatScene {

    // MARK: - Phase Machine

    func beginPlayerPhase() {
        phase = .playerAction
        guard let vm = viewModel else { return }
        vm.beginTurn()
        inputEnabled = true
        syncVisuals()
        updatePhaseLabel(L10n.encounterPhasePlayerAction.localized)
    }

    func updatePhaseLabel(_ text: String) {
        if let label = childNode(withName: "phaseLabel") as? SKLabelNode {
            label.text = text
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, inputEnabled else { return }
        let location = touch.location(in: self)

        if let cardId = hitTestCard(at: location) {
            draggedCardId = cardId
            dragStartLocation = location
            liftCard(id: cardId)
            return
        }

        if hitTestEndTurn(at: location) {
            performEndTurn()
            return
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first, let cardId = draggedCardId else { return }
        let location = touch.location(in: self)
        moveCard(id: cardId, to: location)

        highlightDropZone(at: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first, let cardId = draggedCardId else { return }
        let location = touch.location(in: self)
        draggedCardId = nil
        clearHighlights()

        let zone = determineDropZone(at: location)
        switch zone {
        case .strike:
            performStrike(cardId: cardId)
        case .influence:
            performInfluence(cardId: cardId)
        case .sacrifice:
            performSacrifice(cardId: cardId)
        case .none:
            returnCardToHand(id: cardId)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let cardId = draggedCardId {
            returnCardToHand(id: cardId)
        }
        draggedCardId = nil
        clearHighlights()
    }

    // MARK: - Player Actions

    private func performStrike(cardId: String) {
        guard let vm = viewModel else { return }
        let accepted = vm.playStrike(cardId: cardId, targetId: vm.enemyType)
        if accepted {
            onSoundEffect?("sealStrike")
            onHaptic?("medium")
            flashZone(strikeZone)
            afterPlayerAction()
        } else {
            returnCardToHand(id: cardId)
        }
    }

    private func performInfluence(cardId: String) {
        guard let vm = viewModel else { return }
        let accepted = vm.playInfluence(cardId: cardId)
        if accepted {
            onSoundEffect?("sealSpeak")
            onHaptic?("light")
            flashZone(influenceZone)
            afterPlayerAction()
        } else {
            returnCardToHand(id: cardId)
        }
    }

    private func performSacrifice(cardId: String) {
        guard let vm = viewModel else { return }
        let accepted = vm.playSacrifice(cardId: cardId)
        if accepted {
            onSoundEffect?("effortBurn")
            onHaptic?("medium")
            flashZone(sacrificeZone)
            afterPlayerAction()
        } else {
            returnCardToHand(id: cardId)
        }
    }

    private func performEndTurn() {
        inputEnabled = false
        transitionToEnemyPhase()
    }

    private func afterPlayerAction() {
        guard let vm = viewModel else { return }
        syncVisuals()
        updateHUDValues()

        if vm.outcome != nil {
            finishCombat()
            return
        }

        if vm.isAutoTurnEnd || vm.hand.isEmpty {
            run(SKAction.wait(forDuration: 0.4)) { [weak self] in
                self?.transitionToEnemyPhase()
            }
        }
    }

    // MARK: - Enemy Phase

    private func transitionToEnemyPhase() {
        phase = .enemyResolution
        inputEnabled = false
        updatePhaseLabel(L10n.encounterPhaseEnemyResolution.localized)

        guard let vm = viewModel, let modeState = enemyModeState else { return }

        vm.endTurn()
        updateIdolMode()

        let enemyAction = vm.resolveEnemyAction(mode: modeState.currentMode)

        let animDuration: TimeInterval = 0.6

        switch enemyAction {
        case .attack(let damage), .rage(let damage):
            showFloatingText("−\(damage) HP", at: idolNode?.position ?? .zero, color: .red)
            onHaptic?("heavy")
        case .defend(let value):
            showFloatingText("🛡\(value)", at: idolNode?.position ?? .zero, color: .cyan)
        case .provoke(let penalty):
            showFloatingText("⚡−\(penalty)", at: idolNode?.position ?? .zero, color: .orange)
        case .adapt:
            showFloatingText("↻", at: idolNode?.position ?? .zero, color: .yellow)
        case .plea(let shift):
            showFloatingText("\(shift > 0 ? "+" : "")\(shift)", at: idolNode?.position ?? .zero, color: .purple)
        }

        syncVisuals()
        updateHUDValues()

        run(SKAction.wait(forDuration: animDuration)) { [weak self] in
            guard let self, let vm = self.viewModel else { return }

            if vm.outcome != nil {
                self.finishCombat()
            } else {
                self.beginPlayerPhase()
            }
        }
    }

    // MARK: - Combat End

    private func finishCombat() {
        phase = .finished
        inputEnabled = false

        guard let vm = viewModel else { return }

        let isVictory = vm.outcome == .destroyed || vm.outcome == .subjugated
        updatePhaseLabel(isVictory ? "Victory" : "Defeat")

        let resultDelay: TimeInterval = 1.0
        run(SKAction.wait(forDuration: resultDelay)) { [weak self] in
            guard let self, let vm = self.viewModel else { return }

            let faithDelta: Int
            let resonanceDelta: Float
            switch vm.outcome {
            case .destroyed:
                faithDelta = 3; resonanceDelta = -3.0
            case .subjugated:
                faithDelta = 5; resonanceDelta = 3.0
            case .defeated, .none:
                faithDelta = 0; resonanceDelta = -2.0
            }

            let result = vm.makeCombatResult(
                faithDelta: faithDelta,
                resonanceDelta: resonanceDelta
            )
            self.onCombatEnd?(result)
        }
    }

    // MARK: - Hit Testing

    func hitTestCard(at point: CGPoint) -> String? {
        let layer = handLayer ?? self
        let localPoint = convert(point, to: layer)
        for (cardId, node) in handCardNodes {
            if node.frame.contains(localPoint) || node.contains(localPoint) {
                return cardId
            }
        }
        return nil
    }

    private func hitTestEndTurn(at point: CGPoint) -> Bool {
        guard let btn = endTurnButton else { return false }
        let expanded = btn.frame.insetBy(dx: -10, dy: -10)
        return expanded.contains(point)
    }

    // MARK: - Drop Zones

    enum DropZone {
        case strike
        case influence
        case sacrifice
        case none
    }

    func determineDropZone(at point: CGPoint) -> DropZone {
        if let zone = strikeZone, expandedFrame(zone).contains(point) { return .strike }
        if let zone = influenceZone, expandedFrame(zone).contains(point) { return .influence }
        if let zone = sacrificeZone, expandedFrame(zone).contains(point) { return .sacrifice }
        return .none
    }

    private func expandedFrame(_ node: SKNode) -> CGRect {
        node.frame.insetBy(dx: -15, dy: -15)
    }

    // MARK: - Card Drag Visuals

    func liftCard(id: String) {
        guard let node = handCardNodes[id] else { return }
        node.removeAction(forKey: "cardSway")
        node.zPosition = 35
        let scaleUp = SKAction.scale(to: RitualTheme.dragLiftScale, duration: 0.15)
        scaleUp.timingMode = .easeOut
        node.run(scaleUp, withKey: "cardLift")
    }

    func moveCard(id: String, to position: CGPoint) {
        guard let node = handCardNodes[id] else { return }
        let layer = handLayer ?? self
        let localPos = convert(position, to: layer)
        node.position = localPos
        node.zRotation = 0
    }

    func returnCardToHand(id: String) {
        guard let node = handCardNodes[id] else { return }
        let targetPos = originalCardPositions[id] ?? node.position
        let targetRot = originalCardRotations[id] ?? node.zRotation

        let move = SKAction.move(to: targetPos, duration: 0.3)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: 1.0, duration: 0.3)
        scale.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: targetRot, duration: 0.2)
        rotate.timingMode = .easeOut
        node.run(SKAction.group([move, scale, rotate]))
        node.zPosition = 20
    }

    // MARK: - Zone Highlights

    func highlightDropZone(at point: CGPoint) {
        clearHighlights()
        let zone = determineDropZone(at: point)
        switch zone {
        case .strike: strikeZone?.glowWidth = 4
        case .influence: influenceZone?.glowWidth = 4
        case .sacrifice: sacrificeZone?.glowWidth = 4
        case .none: break
        }
    }

    func clearHighlights() {
        strikeZone?.glowWidth = 0
        influenceZone?.glowWidth = 0
        sacrificeZone?.glowWidth = 0
    }

    func flashZone(_ zone: SKShapeNode?) {
        guard let zone else { return }
        let flash = SKAction.sequence([
            SKAction.run { zone.glowWidth = 6 },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { zone.glowWidth = 0 }
        ])
        zone.run(flash)
    }

    // MARK: - Floating Text

    func showFloatingText(_ text: String, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = color
        label.position = CGPoint(x: position.x, y: position.y - 40)
        label.zPosition = 60
        label.alpha = 0
        addChild(label)

        let appear = SKAction.fadeIn(withDuration: 0.1)
        let float = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        float.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([appear, float, fade, remove]))
    }
}
