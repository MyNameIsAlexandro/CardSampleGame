/// Файл: Packages/EchoScenes/Sources/EchoScenes/CombatScene+ArenaEffects.swift
/// Назначение: Содержит реализацию файла CombatScene+ArenaEffects.swift.
/// Зона ответственности: Реализует визуально-сценовый слой EchoScenes.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit
import FirebladeECS
import EchoEngine
import TwilightEngine
import Foundation

/// Arena-переходы и визуальные эффекты боя.
/// Этот extension содержит только технические анимационные helper-методы.
extension CombatScene {
    // MARK: - Arena Cards

    /// Fly selected cards to the arena zone and keep them visible.
    func animateCardsToArena(_ cardNodes: [CardNode], completion: @escaping () -> Void) {
        guard !cardNodes.isEmpty else {
            completion()
            return
        }

        let cardW = CardNode.cardSize.width
        let arenaScale: CGFloat = 0.7
        let spacing: CGFloat = 8
        let scaledW = cardW * arenaScale
        let totalW = scaledW * CGFloat(cardNodes.count) + spacing * CGFloat(cardNodes.count - 1)
        let startX = -totalW / 2 + scaledW / 2

        let group = DispatchGroup()

        for (index, cardNode) in cardNodes.enumerated() {
            group.enter()

            let scenePos = handContainer.convert(cardNode.position, to: self)
            let flyCard = CardNode(card: cardNode.card)
            flyCard.position = scenePos
            flyCard.zPosition = 40 + CGFloat(index)
            addChild(flyCard)
            arenaCardNodes.append(flyCard)

            cardNode.removeFromParent()

            let targetX = startX + CGFloat(index) * (scaledW + spacing)
            let target = CGPoint(x: targetX, y: arenaCenter.y)

            let flyAction = SKAction.move(to: target, duration: 0.3)
            flyAction.timingMode = .easeOut
            let scaleAction = SKAction.scale(to: arenaScale, duration: 0.3)

            flyCard.run(SKAction.group([flyAction, scaleAction])) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.run(SKAction.wait(forDuration: 0.2)) {
                completion()
            }
        }
    }

    /// Fade out and remove all cards from the arena.
    func clearArenaCards() {
        for node in arenaCardNodes {
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent(),
            ]))
        }
        arenaCardNodes.removeAll()
    }

    // MARK: - Animation Helpers

    func getOrCreateAnim(for entity: Entity) -> AnimationComponent {
        if simulation.nexus.has(componentId: AnimationComponent.identifier, entityId: entity.identifier) {
            return simulation.nexus.get(unsafe: entity.identifier)
        }
        let animation = AnimationComponent()
        entity.assign(animation)
        return animation
    }

    func screenShake(intensity: CGFloat) {
        let actions = (0..<4).flatMap { _ -> [SKAction] in
            [
                SKAction.moveBy(
                    x: CGFloat.random(in: -intensity...intensity),
                    y: CGFloat.random(in: -intensity...intensity),
                    duration: 0.04
                ),
                SKAction.move(to: .zero, duration: 0.04),
            ]
        }
        run(SKAction.sequence(actions))
    }

    // MARK: - Fate Card Overlay

    func showFateCard(value: Int, isCritical: Bool, label: String, resolution: FateResolution? = nil, completion: @escaping () -> Void) {
        let card = FateCardNode()
        card.alpha = 0
        fateOverlay.addChild(card)
        onSoundEffect?(isCritical ? "fateCritical" : "fateReveal")
        if isCritical {
            onHaptic?("heavy")
        }

        let context = SKLabelNode(fontNamed: "AvenirNext-Medium")
        let sign = value > 0 ? "+\(value)" : "\(value)"
        context.text = "\(label) \(sign)"
        context.fontSize = 14
        context.fontColor = CombatSceneTheme.muted
        context.position = CGPoint(x: 0, y: -(FateCardNode.cardSize.height / 2 + 14))
        context.verticalAlignmentMode = .top
        card.addChild(context)

        if let resolution, let keyword = resolution.keyword {
            let keywordLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            let matchIcon = resolution.suitMatch ? " ★" : ""
            keywordLabel.text = "\(keyword.rawValue.capitalized)\(matchIcon)"
            keywordLabel.fontSize = 12
            keywordLabel.fontColor = resolution.suitMatch ? CombatSceneTheme.highlight : CombatSceneTheme.faith
            keywordLabel.position = CGPoint(x: 0, y: -(FateCardNode.cardSize.height / 2 + 30))
            keywordLabel.verticalAlignmentMode = .top
            card.addChild(keywordLabel)
        }

        card.run(SKAction.fadeIn(withDuration: 0.15)) { [weak card] in
            card?.reveal(value: value, isCritical: isCritical) {
                card?.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.6),
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.removeFromParent(),
                ])) {
                    completion()
                }
            }
        }
    }

    func showDamageNumber(_ value: Int, at position: CGPoint, color: SKColor, prefix: String = "-") {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "\(prefix)\(abs(value))"
        label.fontSize = 22
        label.fontColor = color
        label.position = CGPoint(x: 0, y: position.y + 30)
        label.zPosition = 60
        label.setScale(0.5)
        addChild(label)

        label.run(SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 40, duration: 0.8),
                SKAction.fadeOut(withDuration: 0.8),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: - Particles

    func spawnImpactParticles(at position: CGPoint, isCritical: Bool) {
        let emitter = isCritical ? CombatParticles.criticalHit() : CombatParticles.attackImpact()
        emitter.position = position
        addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent(),
        ]))
    }
}
