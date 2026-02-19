/// Файл: Views/Combat/DispositionCombatScene+GameLoop.swift
/// Назначение: Game loop Disposition Combat — touch handling, card actions, enemy turns, result emission.
/// Зона ответственности: Input → card drag → Y-band action zones → enemy resolution → outcome.
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

        // Compute and show enemy intent (Slay the Spire telegraph)
        computeAndShowEnemyIntent()
    }

    func updatePhaseLabel(_ text: String) {
        if let label = childNode(withName: "phaseLabel") as? SKLabelNode {
            label.text = text
        }
    }

    // MARK: - Enemy Intent Telegraph

    private func computeAndShowEnemyIntent() {
        guard let vm = viewModel, let modeState = enemyModeState else { return }
        let action = EnemyAI.selectAction(
            mode: modeState.currentMode,
            simulation: vm.simulation,
            rng: vm.simulation.rng
        )
        pendingEnemyAction = action
        showEnemyIntent(action)
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
        hideEnemyIntent()
        updatePhaseLabel(L10n.encounterPhaseEnemyResolution.localized)

        guard let vm = viewModel else { return }

        vm.endTurn()
        updateIdolMode()

        // Use pre-computed intent (or fallback to computing now)
        let enemyAction: EnemyAction
        if let stored = pendingEnemyAction {
            vm.resolveStoredAction(stored)
            enemyAction = stored
            pendingEnemyAction = nil
        } else if let modeState = enemyModeState {
            enemyAction = vm.resolveEnemyAction(mode: modeState.currentMode)
        } else {
            enemyAction = vm.resolveEnemyAction(mode: .normal)
        }

        let animDuration: TimeInterval = 0.6
        let idolPos = idolNode?.position ?? CGPoint(x: 195, y: 600)

        switch enemyAction {
        case .attack(let damage):
            showFloatingText("-\(damage) HP", at: idolPos, color: .red)
            onHaptic?("heavy")
        case .rage(let damage):
            showFloatingText("-\(damage) RAGE", at: idolPos, color: SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
            onHaptic?("heavy")
        case .defend(let value):
            showFloatingText("DEF \(value)", at: idolPos, color: .cyan)
        case .provoke(let penalty):
            showFloatingText("PROVOKE \(penalty)", at: idolPos, color: .orange)
        case .adapt:
            showFloatingText("ADAPT", at: idolPos, color: .yellow)
        case .plea(let shift):
            showFloatingText("PLEA +\(shift)", at: idolPos, color: .purple)
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
        hideEnemyIntent()

        guard let vm = viewModel else { return }

        let isVictory = vm.outcome == .destroyed || vm.outcome == .subjugated
        let flavorText: String
        switch vm.outcome {
        case .destroyed:
            flavorText = "Enemy Destroyed"
        case .subjugated:
            flavorText = "Enemy Subjugated"
        case .defeated:
            flavorText = "Defeated..."
        case .none:
            flavorText = "Combat Over"
        }
        updatePhaseLabel(flavorText)

        if isVictory {
            onSoundEffect?("victory")
            onHaptic?("success")
        } else {
            onSoundEffect?("defeat")
            onHaptic?("error")
        }

        let resultDelay: TimeInterval = 1.2
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
        var topCard: (id: String, zPos: CGFloat)?
        for (cardId, node) in handCardNodes {
            let cardFrame = node.calculateAccumulatedFrame()
            if cardFrame.contains(localPoint) {
                if topCard == nil || node.zPosition > topCard!.zPos {
                    topCard = (cardId, node.zPosition)
                }
            }
        }
        return topCard?.id
    }

    private func hitTestEndTurn(at point: CGPoint) -> Bool {
        guard let btn = endTurnButton else { return false }
        let expanded = btn.frame.insetBy(dx: -15, dy: -15)
        return expanded.contains(point)
    }

    // MARK: - Drop Zones (Y-band detection per design §9.2)

    enum DropZone {
        case strike
        case influence
        case sacrifice
        case none
    }

    /// Y-band detection: upper area = Strike, middle = Influence, lower-middle = Sacrifice.
    /// Below hand area (y < 155) = cancel (return card to hand).
    func determineDropZone(at point: CGPoint) -> DropZone {
        guard point.y > 155 else { return .none }
        if point.y >= 400 { return .strike }
        if point.y >= 270 { return .influence }
        return .sacrifice
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
        case .strike:
            strikeZone?.glowWidth = 5
            strikeZone?.fillColor = SKColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 0.30)
        case .influence:
            influenceZone?.glowWidth = 5
            influenceZone?.fillColor = SKColor(red: 0.30, green: 0.50, blue: 0.90, alpha: 0.30)
        case .sacrifice:
            sacrificeZone?.glowWidth = 5
            sacrificeZone?.fillColor = SKColor(red: 0.60, green: 0.30, blue: 0.70, alpha: 0.30)
        case .none:
            break
        }
    }

    func clearHighlights() {
        strikeZone?.glowWidth = 0
        strikeZone?.fillColor = SKColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 0.12)
        influenceZone?.glowWidth = 0
        influenceZone?.fillColor = SKColor(red: 0.30, green: 0.50, blue: 0.90, alpha: 0.12)
        sacrificeZone?.glowWidth = 0
        sacrificeZone?.fillColor = SKColor(red: 0.60, green: 0.30, blue: 0.70, alpha: 0.12)
    }

    func flashZone(_ zone: SKShapeNode?) {
        guard let zone else { return }
        let originalColor = zone.fillColor
        let flash = SKAction.sequence([
            SKAction.run { zone.glowWidth = 8 },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { zone.glowWidth = 0; zone.fillColor = originalColor }
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
