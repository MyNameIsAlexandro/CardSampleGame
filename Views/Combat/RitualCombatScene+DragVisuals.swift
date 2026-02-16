/// Файл: Views/Combat/RitualCombatScene+DragVisuals.swift
/// Назначение: Визуальные эффекты перетаскивания карт — подъём, перемещение, snap, возврат.
/// Зона ответственности: Анимации карт при drag-and-drop. Не содержит game logic.
/// Контекст: Phase 3 Ritual Combat (R9). Epic 2 — Card Drag Visual Feedback.

import SpriteKit

// MARK: - Card Drag Visuals

extension RitualCombatScene {

    /// Lift a card: scale up, raise z, add shadow.
    func liftCard(id: String) {
        guard let node = handCardNodes[id] else { return }
        draggedCardId = id

        node.removeAction(forKey: "cardSway")
        node.zPosition = 35

        let scaleUp = SKAction.scale(to: RitualTheme.dragLiftScale, duration: 0.15)
        scaleUp.timingMode = .easeOut
        node.run(scaleUp, withKey: "cardLift")

        if node.childNode(withName: "dragShadow") == nil {
            let shadow = SKShapeNode(rectOf: RitualTheme.cardSize, cornerRadius: 8)
            shadow.fillColor = SKColor(white: 0, alpha: 0.3)
            shadow.strokeColor = .clear
            shadow.position = RitualTheme.dragShadowOffset
            shadow.zPosition = -1
            shadow.name = "dragShadow"
            node.addChild(shadow)
        }
    }

    /// Move a dragged card to follow the touch position.
    func moveCard(id: String, to position: CGPoint) {
        guard let node = handCardNodes[id] else { return }
        let layer = handLayer ?? self
        let localPos = convert(position, to: layer)
        node.position = localPos
        node.zRotation = 0
    }

    /// Snap card to ritual circle center with spring animation.
    func snapCardToCircle(id: String, completion: @escaping () -> Void) {
        guard let node = handCardNodes[id],
              let circle = ritualCircle else {
            completion()
            return
        }

        let layer = handLayer ?? self
        let targetPos = convert(circle.position, to: layer)

        let move = SKAction.move(to: targetPos, duration: 0.2)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: 1.0, duration: 0.2)
        scale.timingMode = .easeOut
        let group = SKAction.group([move, scale])

        removeDragShadow(from: node)

        node.run(group) {
            completion()
        }
    }

    /// Snap card to bonfire with shrink-to-zero animation.
    func snapCardToBonfire(id: String, completion: @escaping () -> Void) {
        guard let node = handCardNodes[id],
              let bonfire = bonfireNode else {
            completion()
            return
        }

        let layer = handLayer ?? self
        let targetPos = convert(bonfire.position, to: layer)

        let move = SKAction.move(to: targetPos, duration: 0.2)
        move.timingMode = .easeIn
        let scale = SKAction.scale(to: 0, duration: 0.25)
        scale.timingMode = .easeIn
        let fade = SKAction.fadeAlpha(to: 0, duration: 0.25)
        let group = SKAction.group([move, scale, fade])

        removeDragShadow(from: node)

        node.run(group) {
            node.removeFromParent()
            completion()
        }
    }

    /// Return card to its original hand position with spring animation.
    func returnCardToHand(id: String) {
        guard let node = handCardNodes[id] else { return }
        draggedCardId = nil

        let targetPos = originalCardPositions[id] ?? node.position
        let targetRot = originalCardRotations[id] ?? node.zRotation

        let move = SKAction.move(to: targetPos, duration: 0.3)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: 1.0, duration: 0.3)
        scale.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: targetRot, duration: 0.2)
        rotate.timingMode = .easeOut
        let group = SKAction.group([move, scale, rotate])

        removeDragShadow(from: node)
        node.zPosition = CGFloat(20)

        node.run(group)
    }

    /// Dim cards that cannot be played (cost exceeds available energy).
    func dimUnplayableCards() {
        guard let sim = simulation else { return }
        let availableEnergy = sim.energy - sim.reservedEnergy

        for (cardId, node) in handCardNodes {
            guard let card = sim.hand.first(where: { $0.id == cardId }) else { continue }
            let cost = card.cost ?? 0
            let isPlayable = cost <= availableEnergy
            let isSelected = sim.selectedCardIds.contains(cardId)
            node.alpha = (isPlayable || isSelected) ? 1.0 : 0.4
        }
    }

    // MARK: - Bonfire (Effort Undo)

    func handleBonfireTap() {
        guard let sim = simulation,
              let lastBurnedId = sim.effortCardIds.last else { return }
        if sim.undoBurnForEffort(lastBurnedId) {
            onHaptic?("light")
            syncVisuals()
        }
    }

    // MARK: - Private Helpers

    private func removeDragShadow(from node: SKNode) {
        node.childNode(withName: "dragShadow")?.removeFromParent()
    }
}

// MARK: - Drop Zone

/// Target zones for card drag release.
enum DragDropZone {
    case circle
    case bonfire
    case none
}
