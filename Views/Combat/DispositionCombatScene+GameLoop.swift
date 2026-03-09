/// Файл: Views/Combat/DispositionCombatScene+GameLoop.swift
/// Назначение: Game loop Disposition Combat — touch handling, card actions, enemy turns, result emission.
/// Зона ответственности: Input → tap-tap action buttons / drag-drop → enemy resolution → outcome.
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

        let action = vm.computeEnemyAction(mode: modeState.currentMode)
        pendingEnemyAction = action
        showEnemyIntent(action)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Summary continue button works regardless of inputEnabled
        if let summary = childNode(withName: "combatSummary") {
            if let btn = summary.childNode(withName: "summaryButton") {
                let btnFrame = btn.calculateAccumulatedFrame()
                let expanded = btnFrame.insetBy(dx: -20, dy: -20)
                if expanded.contains(convert(location, to: summary)) {
                    summaryCompletion?()
                    summaryCompletion = nil
                    return
                }
            }
            return
        }

        guard inputEnabled else { return }
        hideInteractionDetails()

        // If card selected -> check action buttons
        if let selId = selectedCardId {
            if let action = hitTestActionButton(at: location) {
                resetInteractionLongPressState()
                let cardId = selId
                selectedCardId = nil
                hideCardPreview()
                hideActionButtons()
                switch action {
                case .strike: performStrike(cardId: cardId)
                case .influence: performInfluence(cardId: cardId)
                case .sacrifice: performSacrifice(cardId: cardId)
                }
                return
            }
            // Tap end turn while card selected
            if hitTestEndTurn(at: location) {
                resetInteractionLongPressState()
                deselectCard()
                hideActionButtons()
                performEndTurn()
                return
            }
        }

        // Tap on a card — start potential drag or tap-select
        if let cardId = hitTestCard(at: location) {
            draggedCardId = cardId
            dragStartLocation = location
            isDragging = false
            scheduleInteractionLongPress(for: .card(cardId))
            return
        }

        if let target = interactionTarget(at: location) {
            dragStartLocation = location
            scheduleInteractionLongPress(for: target)
            return
        }

        // Tap end turn button
        if hitTestEndTurn(at: location) {
            resetInteractionLongPressState()
            deselectCard()
            hideActionButtons()
            performEndTurn()
            return
        }

        // Tap empty area → deselect
        if selectedCardId != nil {
            deselectCard()
            hideActionButtons()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let start = dragStartLocation {
            let dx = location.x - start.x
            let dy = location.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance > DispositionCombatScene.dragThreshold {
                cancelInteractionLongPress()
            }
        }

        guard let cardId = draggedCardId else { return }

        if interactionLongPressTriggered {
            return
        }

        if !isDragging {
            // Check if moved past drag threshold
            guard let start = dragStartLocation else { return }
            let dx = location.x - start.x
            let dy = location.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            guard distance > DispositionCombatScene.dragThreshold else { return }

            // Transition to drag mode
            cancelInteractionLongPress()
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
        cancelInteractionLongPress()

        if interactionLongPressTriggered {
            interactionLongPressTriggered = false
            draggedCardId = nil
            dragStartLocation = nil
            isDragging = false
            clearHighlights()
            return
        }

        if let cardId = draggedCardId {
            draggedCardId = nil
            dragStartLocation = nil

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

        dragStartLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetInteractionLongPressState()
        if let cardId = draggedCardId {
            if isDragging {
                returnCardToHand(id: cardId)
            }
        }
        draggedCardId = nil
        dragStartLocation = nil
        isDragging = false
        clearHighlights()
    }

    // MARK: - Card Selection (Tap-to-Preview)

    func selectCard(id: String) {
        // Deselect previous
        if let prevId = selectedCardId {
            returnCardToHand(id: prevId)
        }
        hideInteractionDetails()
        selectedCardId = id

        guard let node = handCardNodes[id],
              let vm = viewModel,
              let card = vm.hand.first(where: { $0.id == id }) else { return }

        node.removeAction(forKey: "cardSway")
        let centerX = size.width / 2

        // Lift card to preview position
        let previewY = size.height * Layout.cardPreview
        let move = SKAction.move(to: CGPoint(x: centerX, y: previewY), duration: 0.2)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: 1.1, duration: 0.2)
        scale.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: 0, duration: 0.15)
        node.zPosition = 40
        node.run(SKAction.group([move, scale, rotate]))

        addSelectionGlow(to: node)

        showActionButtons(for: card)
        pulseActionZones()
        showInteractionHintIfNeeded(at: CGPoint(x: centerX, y: previewY))
        onHaptic?("light")
    }

    func deselectCard() {
        guard let cardId = selectedCardId else { return }
        selectedCardId = nil
        hideInteractionDetails()
        returnCardToHand(id: cardId)
        hideCardPreview()
        hideActionButtons()
        clearHighlights()
    }

    func hideCardPreview() {
        cardPreviewNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))
        cardPreviewNode = nil
    }

    private func pulseActionZones() {
        guard let container = actionButtonsContainer else { return }
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.15),
            SKAction.fadeAlpha(to: 0.7, duration: 0.15),
            SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        ])
        container.run(pulse, withKey: "buttonPulse")
    }

    // MARK: - Player Actions

    private func performStrike(cardId: String) {
        guard let vm = viewModel else { return }
        let previewPower: Int
        if let card = vm.hand.first(where: { $0.id == cardId }) {
            previewPower = vm.previewStrikePower(card: card)
        } else {
            previewPower = 0
        }

        let accepted = vm.playStrike(cardId: cardId, targetId: vm.enemyType)
        if accepted {
            onSoundEffect?("sealStrike")
            flashActionButton(strikeButton)
            showFateKeywordIfPresent()
            animateCardToBar(cardId: cardId, shiftValue: previewPower, isStrike: true) { [weak self] in
                self?.afterPlayerAction()
            }
        } else {
            rejectCardPlay(id: cardId)
        }
    }

    private func performInfluence(cardId: String) {
        guard let vm = viewModel else { return }
        let previewPower: Int
        if let card = vm.hand.first(where: { $0.id == cardId }) {
            previewPower = vm.previewInfluencePower(card: card)
        } else {
            previewPower = 0
        }

        let accepted = vm.playInfluence(cardId: cardId)
        if accepted {
            onSoundEffect?("sealSpeak")
            flashActionButton(influenceButton)
            showFateKeywordIfPresent()
            animateCardToBar(cardId: cardId, shiftValue: previewPower, isStrike: false) { [weak self] in
                self?.afterPlayerAction()
            }
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
            flashActionButton(sacrificeButton)
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
                let centerX = size.width / 2
                showFloatingText(
                    "⚡ \(vm.energy)/\(cost)",
                    at: CGPoint(x: centerX, y: size.height * Layout.actions),
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
        resetInteractionLongPressState()
        selectedCardId = nil
        hideInteractionDetails()
        hideCardPreview()
        hideActionButtons()
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
        resetInteractionLongPressState()
        hideInteractionDetails()
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
        let idolPos = idolNode?.position ?? CGPoint(x: size.width / 2, y: size.height * Layout.idol)

        // Anticipation pulse before enemy acts
        idolNode?.run(SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ]))

        let (floatText, floatColor, isHeavy) = enemyActionDisplay(enemyAction)
        showFloatingText(floatText, at: idolPos, color: floatColor)
        if isHeavy { onHaptic?("heavy") }

        showHeroDamageFloat(for: enemyAction)
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
        resetInteractionLongPressState()
        hideInteractionDetails()
        hideEnemyIntent()

        guard let vm = viewModel else { return }

        let isVictory = vm.outcome == .destroyed || vm.outcome == .subjugated
        let flavorText: String = {
            switch vm.outcome {
            case .destroyed:    return L10n.dispositionOutcomeDestroyed.localized
            case .subjugated:   return L10n.dispositionOutcomeSubjugated.localized
            case .defeated:     return L10n.dispositionOutcomeDefeated.localized
            case .none:         return L10n.dispositionOutcomeCombatOver.localized
            }
        }()
        updatePhaseLabel(flavorText)

        if isVictory {
            onSoundEffect?("victory")
            onHaptic?("success")
        } else {
            onSoundEffect?("defeat")
            onHaptic?("error")
        }

        // Show victory/defeat animation on idol
        if isVictory {
            if vm.outcome == .destroyed {
                idolNode?.playKillAnimation {}
            } else {
                idolNode?.playPacifyAnimation {}
            }
        }

        // Compute deltas
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

        // Show summary after brief delay for animations
        run(SKAction.wait(forDuration: 0.8)) { [weak self] in
            guard let self, let vm = self.viewModel else { return }
            self.showCombatSummary(
                outcome: vm.outcome ?? .defeated,
                turnsPlayed: vm.turnsPlayed,
                cardsPlayed: vm.cardsPlayed,
                finalDisposition: vm.disposition,
                heroHP: vm.heroHP,
                heroMaxHP: vm.heroMaxHP
            ) { [weak self] in
                guard let self, let vm = self.viewModel else { return }
                guard let result = vm.makeCombatResult(
                    faithDelta: faithDelta,
                    resonanceDelta: resonanceDelta
                ) else { return }
                self.onCombatEnd?(result)
            }
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

    // MARK: - Drop Zones

    enum DropZone {
        case strike
        case influence
        case sacrifice
        case none
    }

    enum CombatAction {
        case strike, influence, sacrifice
    }

    func hitTestActionButton(at point: CGPoint) -> CombatAction? {
        guard let container = actionButtonsContainer, container.alpha > 0.5 else { return nil }
        let localPoint = convert(point, to: container)
        let pad: CGFloat = 10

        let buttons: [(SKNode?, CombatAction)] = [
            (strikeButton, .strike), (influenceButton, .influence), (sacrificeButton, .sacrifice)
        ]
        for (btn, action) in buttons {
            guard let btn else { continue }
            let frame = expandedHitFrame(for: btn, padding: pad)
            if frame.contains(localPoint) { return action }
        }
        return nil
    }

    /// Drag fallback routes only to visible action buttons. Legacy Y-bands are disabled.
    func determineDropZone(at point: CGPoint) -> DropZone {
        if let action = hitTestActionButton(at: point) {
            switch action {
            case .strike: return .strike
            case .influence: return .influence
            case .sacrifice: return .sacrifice
            }
        }
        return .none
    }

}
