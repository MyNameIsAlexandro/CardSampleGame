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
        let turnText = L10n.combatTurnNumber.localized(with: vm.turnsPlayed + 1)
        updatePhaseLabel("\(turnText) — \(L10n.encounterPhasePlayerAction.localized)")

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

        if modeState.currentMode == .weakened {
            pendingEnemyAction = nil
            intentLabel?.text = "?"
            intentLabel?.fontColor = .gray
            intentLabel?.alpha = 0
            intentLabel?.run(SKAction.fadeIn(withDuration: 0.3))
            return
        }

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

        // If we have a selected card and tap a zone → play it
        if let selId = selectedCardId {
            let zone = determineDropZone(at: location)
            if zone != .none {
                // Clear selection UI but don't animate card back —
                // let performAction handle card removal or rejection shake.
                selectedCardId = nil
                hideCardPreview()
                clearHighlights()
                switch zone {
                case .strike: performStrike(cardId: selId)
                case .influence: performInfluence(cardId: selId)
                case .sacrifice: performSacrifice(cardId: selId)
                case .none: break
                }
                return
            }
            // Tap end turn while card selected → deselect and end turn
            if hitTestEndTurn(at: location) {
                deselectCard()
                performEndTurn()
                return
            }
        }

        // Tap on a card — start potential drag or tap-select
        if let cardId = hitTestCard(at: location) {
            draggedCardId = cardId
            dragStartLocation = location
            isDragging = false
            return
        }

        // Tap end turn button
        if hitTestEndTurn(at: location) {
            deselectCard()
            performEndTurn()
            return
        }

        // Tap empty area → deselect
        if selectedCardId != nil {
            deselectCard()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first, let cardId = draggedCardId else { return }
        let location = touch.location(in: self)

        if !isDragging {
            // Check if moved past drag threshold
            guard let start = dragStartLocation else { return }
            let dx = location.x - start.x
            let dy = location.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            guard distance > DispositionCombatScene.dragThreshold else { return }

            // Transition to drag mode
            isDragging = true
            deselectCard()
            liftCard(id: cardId)
        }

        moveCard(id: cardId, to: location)
        highlightDropZone(at: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let cardId = draggedCardId {
            draggedCardId = nil

            if isDragging {
                // Finish drag — drop in zone or return
                isDragging = false
                clearHighlights()

                let zone = determineDropZone(at: location)
                switch zone {
                case .strike: performStrike(cardId: cardId)
                case .influence: performInfluence(cardId: cardId)
                case .sacrifice: performSacrifice(cardId: cardId)
                case .none: returnCardToHand(id: cardId)
                }
            } else {
                // Short tap on card — select/deselect
                if selectedCardId == cardId {
                    deselectCard()
                } else {
                    selectCard(id: cardId)
                }
            }
            return
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let cardId = draggedCardId {
            if isDragging {
                returnCardToHand(id: cardId)
            }
        }
        draggedCardId = nil
        isDragging = false
        clearHighlights()
    }

    // MARK: - Card Selection (Tap-to-Preview)

    func selectCard(id: String) {
        // Deselect previous
        if let prevId = selectedCardId {
            returnCardToHand(id: prevId)
        }
        selectedCardId = id

        guard let node = handCardNodes[id],
              let vm = viewModel,
              let card = vm.hand.first(where: { $0.id == id }) else { return }

        node.removeAction(forKey: "cardSway")
        let centerX = DispositionCombatScene.sceneSize.width / 2

        // Lift card to preview position
        let previewY: CGFloat = 200
        let move = SKAction.move(to: CGPoint(x: centerX, y: previewY), duration: 0.2)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: 1.6, duration: 0.2)
        scale.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: 0, duration: 0.15)
        node.zPosition = 40
        node.run(SKAction.group([move, scale, rotate]))

        // Show detail overlay above card
        showCardPreview(card: card, at: CGPoint(x: centerX, y: previewY + 90))

        // Pulse action zones to hint "tap here"
        pulseActionZones()
        onHaptic?("light")
    }

    func deselectCard() {
        guard let cardId = selectedCardId else { return }
        selectedCardId = nil
        returnCardToHand(id: cardId)
        hideCardPreview()
        clearHighlights()
    }

    private func showCardPreview(card: Card, at position: CGPoint) {
        hideCardPreview()

        let container = SKNode()
        container.name = "cardPreview"
        container.position = position
        container.zPosition = 45
        container.alpha = 0

        let bg = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 8)
        bg.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.50, alpha: 0.8)
        bg.lineWidth = 1
        container.addChild(bg)

        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLabel.text = card.name
        nameLabel.fontSize = 13
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: 4)
        container.addChild(nameLabel)

        var detailParts: [String] = []
        if let power = card.power, power > 0 { detailParts.append("⚔ \(power)") }
        if let cost = card.cost, cost > 0 { detailParts.append("◉ \(cost)") }
        let detailText = detailParts.joined(separator: "  ")

        if !detailText.isEmpty {
            let detailLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            detailLabel.text = detailText
            detailLabel.fontSize = 11
            detailLabel.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.9, alpha: 1)
            detailLabel.verticalAlignmentMode = .center
            detailLabel.horizontalAlignmentMode = .center
            detailLabel.position = CGPoint(x: 0, y: -10)
            container.addChild(detailLabel)
        }

        addChild(container)
        cardPreviewNode = container
        container.run(SKAction.fadeIn(withDuration: 0.15))
    }

    func hideCardPreview() {
        cardPreviewNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))
        cardPreviewNode = nil
    }

    private func pulseActionZones() {
        let pulse = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.strikeZone?.glowWidth = 3
                self?.influenceZone?.glowWidth = 3
                self?.sacrificeZone?.glowWidth = 3
            },
            SKAction.wait(forDuration: 0.4),
            SKAction.run { [weak self] in
                self?.strikeZone?.glowWidth = 0
                self?.influenceZone?.glowWidth = 0
                self?.sacrificeZone?.glowWidth = 0
            }
        ])
        run(pulse, withKey: "zonePulse")
    }

    // MARK: - Player Actions

    private func performStrike(cardId: String) {
        guard let vm = viewModel else { return }
        let accepted = vm.playStrike(cardId: cardId, targetId: vm.enemyType)
        if accepted {
            onSoundEffect?("sealStrike")
            onHaptic?("medium")
            flashZone(strikeZone)
            showFateKeywordIfPresent()
            afterPlayerAction()
        } else {
            rejectCardPlay(id: cardId)
        }
    }

    private func performInfluence(cardId: String) {
        guard let vm = viewModel else { return }
        let accepted = vm.playInfluence(cardId: cardId)
        if accepted {
            onSoundEffect?("sealSpeak")
            onHaptic?("light")
            flashZone(influenceZone)
            showFateKeywordIfPresent()
            afterPlayerAction()
        } else {
            rejectCardPlay(id: cardId)
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
            rejectCardPlay(id: cardId)
        }
    }

    private func rejectCardPlay(id: String) {
        returnCardToHand(id: id)
        onHaptic?("error")

        // Show rejection reason as floating text
        if let vm = viewModel, let card = vm.hand.first(where: { $0.id == id }) {
            let cost = card.cost ?? 1
            if cost > vm.energy {
                let centerX = DispositionCombatScene.sceneSize.width / 2
                showFloatingText(
                    "⚡ \(vm.energy)/\(cost)",
                    at: CGPoint(x: centerX, y: 160),
                    color: .orange
                )
            }
        }

        guard let node = handCardNodes[id] else { return }
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 8, y: 0, duration: 0.04),
            SKAction.moveBy(x: -16, y: 0, duration: 0.04),
            SKAction.moveBy(x: 16, y: 0, duration: 0.04),
            SKAction.moveBy(x: -8, y: 0, duration: 0.04)
        ])
        node.run(shake)
    }

    private func performEndTurn() {
        inputEnabled = false
        transitionToEnemyPhase()
    }

    private func afterPlayerAction() {
        guard let vm = viewModel else { return }
        selectedCardId = nil
        hideCardPreview()
        syncVisuals()

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

        guard let vm = viewModel else { return }

        vm.endTurn()
        let turnText = L10n.combatTurnNumber.localized(with: vm.turnsPlayed)
        updatePhaseLabel("\(turnText) — \(L10n.encounterPhaseEnemyResolution.localized)")
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
        let idolPos = idolNode?.position ?? CGPoint(x: 195, y: 590)

        switch enemyAction {
        case .attack(let damage):
            showFloatingText(L10n.dispositionFloatAttack.localized(with: damage), at: idolPos, color: .red)
            onHaptic?("heavy")
        case .rage(let damage):
            showFloatingText(L10n.dispositionFloatRage.localized(with: damage), at: idolPos, color: SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
            onHaptic?("heavy")
        case .defend(let value):
            showFloatingText(L10n.dispositionFloatDefend.localized(with: value), at: idolPos, color: .cyan)
        case .provoke(let penalty):
            showFloatingText(L10n.dispositionFloatProvoke.localized(with: penalty), at: idolPos, color: .orange)
        case .adapt:
            showFloatingText(L10n.dispositionFloatAdapt.localized, at: idolPos, color: .yellow)
        case .plea(let shift):
            showFloatingText(L10n.dispositionFloatPlea.localized(with: shift), at: idolPos, color: .purple)
        }

        syncVisuals()

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
            flavorText = L10n.dispositionOutcomeDestroyed.localized
        case .subjugated:
            flavorText = L10n.dispositionOutcomeSubjugated.localized
        case .defeated:
            flavorText = L10n.dispositionOutcomeDefeated.localized
        case .none:
            flavorText = L10n.dispositionOutcomeCombatOver.localized
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

    // MARK: - Fate Keyword Display

    private func showFateKeywordIfPresent() {
        guard let vm = viewModel, let keyword = vm.lastFateKeyword else { return }
        let centerX = DispositionCombatScene.sceneSize.width / 2
        let pos = CGPoint(x: centerX, y: 160)
        let (text, color) = fateKeywordDisplay(for: keyword)
        showFloatingText(text, at: pos, color: color)
    }

    private func fateKeywordDisplay(for keyword: FateKeyword) -> (String, SKColor) {
        switch keyword {
        case .surge:
            return (L10n.fateKeywordSurge.localized, SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1))
        case .shadow:
            return (L10n.fateKeywordShadow.localized, SKColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1))
        case .ward:
            return (L10n.fateKeywordWard.localized, SKColor(red: 0.3, green: 0.8, blue: 0.6, alpha: 1))
        case .focus:
            return (L10n.fateKeywordFocus.localized, SKColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1))
        case .echo:
            return (L10n.fateKeywordEcho.localized, SKColor(red: 0.8, green: 0.8, blue: 0.3, alpha: 1))
        }
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
