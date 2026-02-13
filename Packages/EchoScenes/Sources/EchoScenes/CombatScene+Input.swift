/// Файл: Packages/EchoScenes/Sources/EchoScenes/CombatScene+Input.swift
/// Назначение: Содержит реализацию файла CombatScene+Input.swift.
/// Зона ответственности: Реализует визуально-сценовый слой EchoScenes.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit
import FirebladeECS
import EchoEngine
import TwilightEngine
import Foundation

private func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

private func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
}

// Touch input and mulligan
extension CombatScene {
#if os(iOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchStartLocation = location
        isDraggingHand = false

        dismissTooltip()

        // Long press for tooltip
        let cardNode = findCardNode(at: location)
        if cardNode != nil {
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self, let card = cardNode?.card else { return }
                self.touchStartLocation = nil
                self.showTooltip(for: card, at: location)
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let startLoc = touchStartLocation else { return }
        let location = touch.location(in: self)
        let dx = location.x - touch.previousLocation(in: self).x

        // Only start scrolling after 15pt horizontal movement threshold
        let totalDx = abs(location.x - startLoc.x)
        let handY = handCropNode.position.y
        let cardH = CardNode.cardSize.height
        let visibleW = self.size.width - 20
        let inHandArea = abs(location.y - handY) < cardH / 2 + 20
        let needsScroll = handContentWidth > visibleW

        if inHandArea && needsScroll && totalDx > 15 {
            if !isDraggingHand {
                isDraggingHand = true
                longPressTimer?.invalidate()
                longPressTimer = nil
            }
            handScrollOffset += dx
            applyHandScroll()
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        if tooltipNode != nil {
            dismissTooltip()
            isDraggingHand = false
            touchStartLocation = nil
            return
        }

        // If was dragging, don't fire tap
        if isDraggingHand {
            isDraggingHand = false
            touchStartLocation = nil
            return
        }

        guard let location = touchStartLocation else { return }
        touchStartLocation = nil
        handleTap(at: location)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        touchStartLocation = nil
        isDraggingHand = false
        dismissTooltip()
    }
#endif

#if os(macOS)
    public override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        dismissTooltip()
        handleTap(at: location)
    }
#endif

    func findCardNode(at location: CGPoint) -> CardNode? {
        // First try scene hit test (works for cards NOT inside SKCropNode, e.g. mulligan)
        for node in nodes(at: location) {
            if let cardNode = node as? CardNode { return cardNode }
            if let parent = node.parent as? CardNode { return parent }
        }
        // Then check hand cards manually (SKCropNode blocks hit testing)
        let localPoint = handInnerNode.convert(location, from: self)
        let halfW = CardNode.cardSize.width / 2
        let halfH = CardNode.cardSize.height / 2
        // Iterate in reverse so topmost card (highest zPosition) wins
        for node in handInnerNode.children.reversed() {
            guard let cardNode = node as? CardNode else { continue }
            let p = cardNode.position
            if localPoint.x >= p.x - halfW && localPoint.x <= p.x + halfW &&
               localPoint.y >= p.y - halfH && localPoint.y <= p.y + halfH {
                return cardNode
            }
        }
        return nil
    }

    func handleTap(at location: CGPoint) {
        // Mulligan phase intercepts all taps
        if mulliganOverlay != nil {
            handleMulliganTap(at: location)
            return
        }

        // Dismiss overlays if showing
        if exhaustOverlay != nil {
            dismissExhaustOverlay()
            return
        }
        if discardOverlay != nil {
            dismissDiscardOverlay()
            return
        }

        // Check continue button even when combat is over
        let tapped = nodes(at: location)
        if tapped.contains(where: { $0.name == "btn_continue" }),
           let outcome = simulation.outcome {
            if let result = simulation.combatResult {
                onCombatEndWithResult?(result)
            }
            onCombatEnd?(outcome)
            return
        }

        // Discard pile viewer — works anytime
        if tapped.contains(where: { $0.name == "btn_discard" }) {
            showDiscardOverlay()
            return
        }

        if tapped.contains(where: { $0.name == "btn_exhaust" }) {
            showExhaustOverlay()
            return
        }

        // Fate deck tap (during awaiting phase)
        if tapped.contains(where: { $0.name == "btn_fate_deck" }) && awaitingFateReveal {
            handleFateDeckTap()
            return
        }

        // Draw pile tap
        if tapped.contains(where: { $0.name == "btn_draw_pile" }) {
            handleDrawPileTap()
            return
        }

        guard !simulation.isOver, simulation.phase == .playerTurn, !isAnimating else { return }

        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
            switch node.name {
            case "btn_attack":
                performPlayerAttack()
                return
            case "btn_influence":
                performPlayerInfluence()
                return
            case "btn_end_turn":
                performEndTurn()
                return
            default:
                break
            }
        }

        // Check hand cards (manual hit test for SKCropNode)
        if let cardNode = findCardNode(at: location),
           cardNode.parent === handInnerNode {
            toggleCardSelection(cardNode)
        }
    }

    func toggleCardSelection(_ cardNode: CardNode) {
        let cardId = cardNode.card.id
        if simulation.selectedCardIds.contains(cardId) {
            simulation.deselectCard(cardId: cardId)
            cardNode.setSelectedAnimated(false)
            onSoundEffect?("cardDeselect")
        } else {
            if simulation.selectCard(cardId: cardId) {
                cardNode.setSelectedAnimated(true)
                onSoundEffect?("cardSelect")
            } else {
                // Can't afford — shake card
                cardNode.run(SKAction.sequence([
                    SKAction.moveBy(x: -4, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 8, y: 0, duration: 0.05),
                    SKAction.moveBy(x: -8, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 4, y: 0, duration: 0.05)
                ]))
            }
        }
        updateCardAffordability()
        updateHUD()
    }

    func updateCardAffordability() {
        let available = simulation.availableEnergy
        let selected = simulation.selectedCardIds
        for case let cardNode as CardNode in handContainer.children {
            if selected.contains(cardNode.card.id) {
                cardNode.setDimmed(false)
            } else {
                let cost = cardNode.card.cost ?? 1
                cardNode.setDimmed(cost > available)
            }
        }
    }

    func deselectAllCardsVisually() {
        for case let cardNode as CardNode in handContainer.children {
            if cardNode.isCardSelected {
                cardNode.setSelectedAnimated(false)
            }
            cardNode.setDimmed(false)
        }
    }

    // MARK: - Mulligan

    func showMulliganOverlay() {
        guard !simulation.hand.isEmpty else { return }

        mulliganSelected.removeAll()
        let overlay = SKNode()
        overlay.zPosition = 100

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.7)
        bg.strokeColor = .clear
        overlay.addChild(bg)

        // Compute grid height to position title/button around it
        let cardH = CardNode.cardSize.height
        let handCount = simulation.hand.count
        let rows = (handCount + 2) / 3  // ceil(count/3)
        let gridH = CGFloat(rows) * cardH + CGFloat(max(0, rows - 1)) * 8
        let gridTop: CGFloat = -10 + gridH / 2
        let gridBottom: CGFloat = -10 - gridH / 2

        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = L("combat.mulligan.title")
        title.fontSize = 18
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: gridTop + 30)
        title.verticalAlignmentMode = .center
        overlay.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text = L("combat.mulligan.prompt")
        subtitle.fontSize = 11
        subtitle.fontColor = CombatSceneTheme.muted
        subtitle.position = CGPoint(x: 0, y: gridTop + 12)
        subtitle.verticalAlignmentMode = .center
        overlay.addChild(subtitle)

        refreshMulliganCards(in: overlay)

        // Keep button below grid
        let btnY = gridBottom - 28
        let btnBg = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 8)
        btnBg.fillColor = CombatSceneTheme.success
        btnBg.strokeColor = .clear
        btnBg.position = CGPoint(x: 0, y: btnY)
        btnBg.name = "btn_mulligan_keep"
        overlay.addChild(btnBg)

        let btnLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        btnLabel.text = L("combat.mulligan.confirm")
        btnLabel.fontSize = 15
        btnLabel.fontColor = .white
        btnLabel.position = CGPoint(x: 0, y: btnY)
        btnLabel.verticalAlignmentMode = .center
        btnLabel.name = "btn_mulligan_keep"
        overlay.addChild(btnLabel)

        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.3))
        mulliganOverlay = overlay
    }

    func refreshMulliganCards(in overlay: SKNode) {
        // Remove old card nodes
        overlay.children.filter { $0 is CardNode }.forEach { $0.removeFromParent() }

        let cards = simulation.hand
        guard !cards.isEmpty else { return }

        let availableW = size.width - 20
        let cardW = CardNode.cardSize.width
        let cardH = CardNode.cardSize.height
        let gap: CGFloat = 8

        // Grid layout: 3 per row, full size
        let cols = min(cards.count, 3)
        let stepX = cardW + gap
        let stepY = cardH + gap
        let rows = (cards.count + cols - 1) / cols

        // Center the grid vertically around y = -10
        let gridH = CGFloat(rows) * cardH + CGFloat(rows - 1) * gap
        let topY: CGFloat = -10 + gridH / 2 - cardH / 2

        // Scale if even 3 cards don't fit in width
        let rowW = stepX * CGFloat(cols - 1) + cardW
        let scale: CGFloat = rowW > availableW ? availableW / rowW : 1.0

        for (i, card) in cards.enumerated() {
            let col = i % cols
            let row = i / cols
            // Center each row
            let rowCount = min(cols, cards.count - row * cols)
            let rowTotalW = (stepX * CGFloat(rowCount - 1) + cardW) * scale
            let rowStartX = -rowTotalW / 2 + cardW * scale / 2

            let node = CardNode(card: card)
            node.setScale(scale)
            node.position = CGPoint(
                x: rowStartX + CGFloat(col) * stepX * scale,
                y: topY - CGFloat(row) * stepY * scale
            )
            node.name = "mulligan_\(card.id)"
            if mulliganSelected.contains(card.id) {
                node.setSelected(true)
                node.alpha = 0.5
            }
            overlay.addChild(node)
        }
    }

    func handleMulliganTap(at location: CGPoint) {
        guard let overlay = mulliganOverlay else { return }

        let tapped = nodes(at: location)

        // Keep button
        if tapped.contains(where: { $0.name == "btn_mulligan_keep" }) {
            if !mulliganSelected.isEmpty {
                simulation.mulligan(cardIds: Array(mulliganSelected))
            }
            overlay.run(SKAction.fadeOut(withDuration: 0.2)) { [weak self] in
                overlay.removeFromParent()
                self?.mulliganOverlay = nil
                self?.refreshHand()
                self?.updateHUD()
            }
            return
        }

        // Toggle card selection
        for node in tapped {
            if let cardNode = node as? CardNode {
                toggleMulliganCard(cardNode.card.id, in: overlay)
                return
            }
            if let parent = node.parent as? CardNode {
                toggleMulliganCard(parent.card.id, in: overlay)
                return
            }
        }
    }

    func toggleMulliganCard(_ cardId: String, in overlay: SKNode) {
        if mulliganSelected.contains(cardId) {
            mulliganSelected.remove(cardId)
        } else {
            mulliganSelected.insert(cardId)
        }
        refreshMulliganCards(in: overlay)
    }
}
