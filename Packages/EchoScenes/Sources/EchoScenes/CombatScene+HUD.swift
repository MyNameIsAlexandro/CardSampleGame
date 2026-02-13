/// Файл: Packages/EchoScenes/Sources/EchoScenes/CombatScene+HUD.swift
/// Назначение: Содержит реализацию файла CombatScene+HUD.swift.
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

// HUD and render sync
extension CombatScene {
    func setupHUD() {
        let halfH = size.height / 2

        // --- HUD zone (top) ---
        phaseLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        phaseLabel.fontSize = 12
        phaseLabel.fontColor = CombatSceneTheme.muted
        phaseLabel.position = CGPoint(x: 0, y: halfH - 25)
        phaseLabel.zPosition = 20
        addChild(phaseLabel)

        roundLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        roundLabel.fontSize = 11
        roundLabel.fontColor = CombatSceneTheme.muted
        roundLabel.position = CGPoint(x: 0, y: halfH - 42)
        roundLabel.zPosition = 20
        addChild(roundLabel)

        // --- Buttons zone (bottom, Y = -260) ---
        let buttonY: CGFloat = -260

        let hasInfluence = simulation.enemyMaxWill > 0
        if hasInfluence {
            attackButton = makeButton(text: L("encounter.action.attack"), position: CGPoint(x: -100, y: buttonY), name: "btn_attack")
            influenceButton = makeButton(text: L("encounter.action.influence"), position: CGPoint(x: 0, y: buttonY), name: "btn_influence")
            skipButton = makeButton(text: L("encounter.action.wait"), position: CGPoint(x: 100, y: buttonY), name: "btn_end_turn")
        } else {
            attackButton = makeButton(text: L("encounter.action.attack"), position: CGPoint(x: -60, y: buttonY), name: "btn_attack")
            skipButton = makeButton(text: L("encounter.action.wait"), position: CGPoint(x: 60, y: buttonY), name: "btn_end_turn")
        }

        // --- Fate overlay in arena center ---
        fateOverlay = SKNode()
        fateOverlay.position = arenaCenter
        fateOverlay.zPosition = 50
        addChild(fateOverlay)

        // --- Indicators zone (Y = -215) ---
        let indicatorY: CGFloat = -215

        // Energy + Resonance (center)
        energyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        energyLabel.fontSize = 13
        energyLabel.fontColor = CombatSceneTheme.faith
        energyLabel.position = CGPoint(x: 0, y: indicatorY)
        energyLabel.zPosition = 15
        addChild(energyLabel)

        resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        resonanceLabel.fontSize = 11
        resonanceLabel.fontColor = CombatSceneTheme.muted
        resonanceLabel.position = CGPoint(x: 0, y: indicatorY - 14)
        resonanceLabel.zPosition = 15
        addChild(resonanceLabel)

        // Deck pile (left of hand)
        deckCountLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        deckCountLabel.fontSize = 14
        deckCountLabel.fontColor = CombatSceneTheme.spirit
        deckCountLabel.position = CGPoint(x: -size.width / 2 + 30, y: indicatorY)
        deckCountLabel.zPosition = 15
        addChild(deckCountLabel)

        // Draw pile visual (tappable card-back stack)
        let drawPile = makeDrawPileNode()
        drawPile.position = CGPoint(x: -size.width / 2 + 30, y: indicatorY + 30)
        drawPile.zPosition = 16
        drawPile.name = "btn_draw_pile"
        addChild(drawPile)
        drawPileNode = drawPile

        // Discard pile (right of hand, tappable)
        discardCountLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        discardCountLabel.fontSize = 14
        discardCountLabel.fontColor = CombatSceneTheme.muted
        discardCountLabel.position = CGPoint(x: size.width / 2 - 30, y: indicatorY)
        discardCountLabel.zPosition = 15
        discardCountLabel.name = "btn_discard"
        addChild(discardCountLabel)

        exhaustCountLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        exhaustCountLabel.fontSize = 11
        exhaustCountLabel.fontColor = CombatSceneTheme.muted
        exhaustCountLabel.position = CGPoint(x: size.width / 2 - 30, y: indicatorY - 16)
        exhaustCountLabel.zPosition = 15
        exhaustCountLabel.name = "btn_exhaust"
        addChild(exhaustCountLabel)

        // --- Hand zone (Y = -60 to -200, clipped) ---
        let cardH = CardNode.cardSize.height
        let handY: CGFloat = -130  // center of hand zone
        let visibleW = size.width

        handCropNode = SKCropNode()
        handCropNode.position = CGPoint(x: 0, y: handY)
        handCropNode.zPosition = 15
        let mask = SKSpriteNode(color: .white, size: CGSize(width: visibleW, height: cardH + 20))
        handCropNode.maskNode = mask
        addChild(handCropNode)

        handInnerNode = SKNode()
        handCropNode.addChild(handInnerNode)
        handContainer = handInnerNode

        // --- Combat log in arena zone ---
        combatLogNode = SKNode()
        combatLogNode.position = CGPoint(x: size.width / 2 - 10, y: arenaCenter.y)
        combatLogNode.zPosition = 15
        addChild(combatLogNode)

        // --- Arena separator lines ---
        let sepTop = SKShapeNode(rectOf: CGSize(width: size.width * 0.7, height: 1))
        sepTop.fillColor = CombatSceneTheme.separator
        sepTop.strokeColor = .clear
        sepTop.position = CGPoint(x: 0, y: 20)
        sepTop.alpha = 0.3
        sepTop.zPosition = 1
        addChild(sepTop)

        let sepBottom = SKShapeNode(rectOf: CGSize(width: size.width * 0.7, height: 1))
        sepBottom.fillColor = CombatSceneTheme.separator
        sepBottom.strokeColor = .clear
        sepBottom.position = CGPoint(x: 0, y: -55)
        sepBottom.alpha = 0.3
        sepBottom.zPosition = 1
        addChild(sepBottom)

        refreshHand()
    }

    func makeButton(text: String, position: CGPoint, name: String) -> SKLabelNode {
        let bg = SKShapeNode(rectOf: CGSize(width: 100, height: 36), cornerRadius: 8)
        bg.fillColor = CombatSceneTheme.cardBack
        bg.strokeColor = CombatSceneTheme.muted.withAlphaComponent(0.6)
        bg.position = position
        bg.zPosition = 20
        bg.name = name

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        bg.addChild(label)
        addChild(bg)

        return label
    }

    func updateHUD() {
        phaseLabel.text = L("encounter.phase.label", "\(simulation.phase)")
        roundLabel.text = L("encounter.round.label", simulation.round)

        let isPlayerTurn = simulation.phase == .playerTurn && !simulation.isOver
        attackButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        influenceButton?.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        skipButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        handContainer.alpha = isPlayerTurn ? 1.0 : 0.5

        let drawCount = simulation.drawPileCount
        deckCountLabel.text = "🂠 \(drawCount)"
        drawPileNode?.alpha = drawCount > 0 ? 1.0 : 0.4
        discardCountLabel.text = "♻ \(simulation.discardPileCount)"
        let exhaustCount = simulation.exhaustPileCount
        exhaustCountLabel.text = exhaustCount > 0 ? "✕ \(exhaustCount)" : ""
        let available = simulation.availableEnergy
        let total = simulation.energy
        if simulation.reservedEnergy > 0 {
            energyLabel.text = "⚡ \(available)/\(simulation.maxEnergy) (-\(simulation.reservedEnergy))"
        } else {
            energyLabel.text = "⚡ \(total)/\(simulation.maxEnergy)"
        }

        let res = simulation.resonance
        let resInt = Int(res)
        if resInt == 0 {
            resonanceLabel.text = "☯ " + L("resonance.yav")
            resonanceLabel.fontColor = CombatSceneTheme.muted
        } else if res > 0 {
            resonanceLabel.text = "☀ " + L("resonance.prav") + " +\(resInt)"
            resonanceLabel.fontColor = CombatSceneTheme.faith
        } else {
            resonanceLabel.text = "☽ " + L("resonance.nav") + " \(resInt)"
            resonanceLabel.fontColor = CombatSceneTheme.spirit
        }

        // Обновить текст под врагом: HP + Will
        if let enemy = simulation.enemyEntity {
            let label: LabelComponent = simulation.nexus.get(unsafe: enemy.identifier)
            var text = storedEnemyDefinition.name.resolved
            text += "  ♥\(simulation.enemyHealth)/\(simulation.enemyMaxHealth)"
            if simulation.enemyMaxWill > 0 {
                text += "  ✦\(simulation.enemyWill)/\(simulation.enemyMaxWill)"
            }
            label.text = text
        }

        updateIntentDisplay()
        updateStatusIcons()
    }

    func updateStatusIcons() {
        playerStatusNode?.removeFromParent()
        playerStatusNode = nil
        enemyStatusNode?.removeFromParent()
        enemyStatusNode = nil

        let stats = ["shield", "strength", "poison"]
        let icons: [String: (String, SKColor)] = [
            "shield": ("🛡", CombatSceneTheme.muted),
            "strength": ("⚔", CombatSceneTheme.faith),
            "poison": ("☠", CombatSceneTheme.success)
        ]

        // Player status
        let playerEffects = stats.compactMap { stat -> (String, Int)? in
            let val = simulation.playerStatus(for: stat)
            return val > 0 ? (stat, val) : nil
        }
        if !playerEffects.isEmpty {
            let node = SKNode()
            node.position = CGPoint(x: playerPosition.x + 120, y: playerPosition.y)
            node.zPosition = 25
            for (i, (stat, amount)) in playerEffects.enumerated() {
                let (icon, color) = icons[stat] ?? ("?", .white)
                let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                lbl.text = "\(icon)\(amount)"
                lbl.fontSize = 10
                lbl.fontColor = color
                lbl.verticalAlignmentMode = .center
                lbl.horizontalAlignmentMode = .left
                lbl.position = CGPoint(x: 0, y: -CGFloat(i) * 14)
                node.addChild(lbl)
            }
            addChild(node)
            playerStatusNode = node
        }

        // Enemy status
        let enemyEffects = stats.compactMap { stat -> (String, Int)? in
            let val = simulation.enemyStatus(for: stat)
            return val > 0 ? (stat, val) : nil
        }
        if !enemyEffects.isEmpty {
            let node = SKNode()
            node.position = CGPoint(x: enemyPosition.x + 120, y: enemyPosition.y)
            node.zPosition = 25
            for (i, (stat, amount)) in enemyEffects.enumerated() {
                let (icon, color) = icons[stat] ?? ("?", .white)
                let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                lbl.text = "\(icon)\(amount)"
                lbl.fontSize = 10
                lbl.fontColor = color
                lbl.verticalAlignmentMode = .center
                lbl.horizontalAlignmentMode = .left
                lbl.position = CGPoint(x: 0, y: -CGFloat(i) * 14)
                node.addChild(lbl)
            }
            addChild(node)
            enemyStatusNode = node
        }
    }

    func updateIntentDisplay() {
        intentNode?.removeFromParent()
        intentNode = nil

        guard let intent = simulation.enemyIntent, !simulation.isOver else { return }

        let node = SKNode()
        node.position = CGPoint(x: enemyPosition.x, y: enemyPosition.y + 55)
        node.zPosition = 30

        let icon: String
        let color: SKColor
        switch intent.type {
        case .attack:
            icon = "⚔ \(intent.value)"
            color = CombatSceneTheme.health
        case .heal:
            icon = "♥ \(intent.value)"
            color = CombatSceneTheme.success
        case .ritual:
            icon = "✦ " + L("encounter.intent.ritual")
            color = CombatSceneTheme.spirit
        case .block, .defend:
            icon = "🛡 " + L("encounter.intent.defend")
            color = CombatSceneTheme.muted
        case .buff:
            icon = "↑ " + L("encounter.intent.buff")
            color = CombatSceneTheme.faith
        case .debuff:
            icon = "↓ " + L("encounter.intent.debuff")
            color = CombatSceneTheme.spirit
        case .prepare:
            icon = "… " + L("encounter.intent.prepare")
            color = CombatSceneTheme.muted
        default:
            icon = "? \(intent.type.rawValue)"
            color = CombatSceneTheme.muted
        }

        let bg = SKShapeNode(rectOf: CGSize(width: 70, height: 22), cornerRadius: 6)
        bg.fillColor = color.withAlphaComponent(0.25)
        bg.strokeColor = color.withAlphaComponent(0.6)
        bg.lineWidth = 1
        node.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = icon
        label.fontSize = 11
        label.fontColor = color
        label.verticalAlignmentMode = .center
        node.addChild(label)

        addChild(node)
        intentNode = node

        // Pulse animation
        node.alpha = 0
        node.run(SKAction.fadeIn(withDuration: 0.3))
    }

    func refreshHand() {
        handContainer.removeAllChildren()
        let cards = simulation.hand
        guard !cards.isEmpty else {
            handContentWidth = 0
            handScrollOffset = 0
            handInnerNode.position.x = 0
            return
        }

        let cardW = CardNode.cardSize.width
        let step: CGFloat = cardW + 6
        let totalWidth = step * CGFloat(cards.count - 1) + cardW
        handContentWidth = totalWidth

        let visibleWidth = self.size.width - 20
        // Cards laid out in inner node from center
        let startX = -totalWidth / 2 + cardW / 2

        for (i, card) in cards.enumerated() {
            let node = CardNode(card: card)
            node.position = CGPoint(x: startX + CGFloat(i) * step, y: 0)
            node.zPosition = CGFloat(i)
            handContainer.addChild(node)
        }

        // Reset scroll if content fits
        if totalWidth <= visibleWidth {
            handScrollOffset = 0
        }
        applyHandScroll()
    }

    func applyHandScroll() {
        let visibleWidth = self.size.width
        if handContentWidth <= visibleWidth {
            handInnerNode.position.x = 0
            return
        }
        // Allow scrolling so the first and last card can reach the center of the visible area
        let cardW = CardNode.cardSize.width
        let maxScroll = (handContentWidth - visibleWidth) / 2 + cardW / 2
        handScrollOffset = max(-maxScroll, min(maxScroll, handScrollOffset))
        handInnerNode.position.x = handScrollOffset
    }

    // MARK: - Render Sync

    func syncRender() {
        renderGroup.update(nexus: simulation.nexus)
    }

    // MARK: - Touch Input

}
