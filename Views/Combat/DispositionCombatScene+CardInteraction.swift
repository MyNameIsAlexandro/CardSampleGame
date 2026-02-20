/// Файл: Views/Combat/DispositionCombatScene+CardInteraction.swift
/// Назначение: Card drag visuals, zone highlights, flash effects for Disposition Combat.
/// Зона ответственности: Lift/move/return cards, highlight/clear/flash action zones.
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

        let move = SKAction.move(to: targetPos, duration: 0.25)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: targetScale, duration: 0.25)
        scale.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: targetRot, duration: 0.2)
        rotate.timingMode = .easeOut
        node.run(SKAction.group([move, scale, rotate])) { [weak self] in
            // Derive index from z to keep sway stagger consistent
            let index = Int(targetZ) - 20
            self?.addCardSway(to: node, index: index)
        }
        node.zPosition = targetZ
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
}
