/// Файл: Views/Combat/DispositionCombatScene+CardInteraction.swift
/// Назначение: Card drag visuals, action button highlights, flash effects for Disposition Combat.
/// Зона ответственности: Lift/move/return cards, highlight/clear/flash action buttons and legacy zones.
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import SpriteKit

// MARK: - Card Drag Visuals

extension DispositionCombatScene {

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
        let targetZ = originalCardZPositions[id] ?? 20
        let targetScale = originalCardScales[id] ?? 1.0

        node.removeAction(forKey: "cardSway")
        node.removeAction(forKey: "cardLift")

        // Remove selection glow
        removeSelectionGlow(from: node)

        let move = SKAction.move(to: targetPos, duration: 0.25)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: targetScale, duration: 0.25)
        scale.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: targetRot, duration: 0.2)
        rotate.timingMode = .easeOut
        node.run(SKAction.group([move, scale, rotate])) { [weak self] in
            let index = Int(targetZ) - 20
            self?.addCardSway(to: node, index: index)
        }
        node.zPosition = targetZ
    }

    // MARK: - Zone Highlights

    func highlightDropZone(at point: CGPoint) {
        clearHighlights()
        if let action = hitTestActionButton(at: point) {
            switch action {
            case .strike:
                highlightActionButton(strikeButton)
            case .influence:
                highlightActionButton(influenceButton)
            case .sacrifice:
                highlightActionButton(sacrificeButton)
            }
        }
    }

    func clearHighlights() {
        // Clear old zone nodes (safety, may be nil after layout redesign)
        strikeZone?.glowWidth = 0
        influenceZone?.glowWidth = 0
        sacrificeZone?.glowWidth = 0
        // Clear action button highlights
        clearActionButtonHighlight(strikeButton)
        clearActionButtonHighlight(influenceButton)
        clearActionButtonHighlight(sacrificeButton)
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

    // MARK: - Action Button Highlights

    func highlightActionButton(_ button: SKNode?) {
        guard let button, let bg = button.children.first as? SKShapeNode else { return }
        bg.fillColor = bg.strokeColor.withAlphaComponent(0.35)
    }

    func clearActionButtonHighlight(_ button: SKNode?) {
        guard let button, let bg = button.children.first as? SKShapeNode else { return }
        bg.fillColor = bg.strokeColor.withAlphaComponent(0.15)
    }

    func flashActionButton(_ button: SKNode?) {
        guard let button, let bg = button.children.first as? SKShapeNode else { return }
        let originalFill = bg.strokeColor.withAlphaComponent(0.15)
        let flash = SKAction.sequence([
            SKAction.run { bg.fillColor = bg.strokeColor.withAlphaComponent(0.5) },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { bg.fillColor = originalFill }
        ])
        button.run(flash)
    }

    // MARK: - Selection Glow

    func addSelectionGlow(to node: SKNode) {
        guard let border = node.childNode(withName: "cardBorder") as? SKShapeNode else { return }
        border.glowWidth = 4
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { border.glowWidth = 5 },
            SKAction.wait(forDuration: 0.6),
            SKAction.run { border.glowWidth = 3 },
            SKAction.wait(forDuration: 0.6)
        ]))
        border.run(pulse, withKey: "glowPulse")
    }

    func removeSelectionGlow(from node: SKNode) {
        guard let border = node.childNode(withName: "cardBorder") as? SKShapeNode else { return }
        border.removeAction(forKey: "glowPulse")
        border.glowWidth = 1
    }

    // MARK: - Neighbor Spread

    func spreadNeighbors(aroundSelectedId selectedId: String) {
        guard let vm = viewModel else { return }
        let cards = vm.hand
        guard let selectedIndex = cards.firstIndex(where: { $0.id == selectedId }) else { return }
        let spreadAmount: CGFloat = 15

        for (i, card) in cards.enumerated() {
            guard card.id != selectedId,
                  let node = handCardNodes[card.id],
                  let origPos = originalCardPositions[card.id] else { continue }

            let offset: CGFloat = i < selectedIndex ? -spreadAmount : spreadAmount
            let targetPos = CGPoint(x: origPos.x + offset, y: origPos.y)
            let move = SKAction.move(to: targetPos, duration: 0.2)
            move.timingMode = .easeOut
            node.run(move, withKey: "neighborSpread")
        }
    }

    func resetNeighborSpread() {
        for (cardId, node) in handCardNodes {
            guard let origPos = originalCardPositions[cardId] else { continue }
            node.removeAction(forKey: "neighborSpread")
            let move = SKAction.move(to: origPos, duration: 0.2)
            move.timingMode = .easeOut
            node.run(move, withKey: "neighborReturn")
        }
    }
}
