/// Файл: Packages/EchoScenes/Sources/EchoScenes/CombatScene+Overlays.swift
/// Назначение: Содержит реализацию файла CombatScene+Overlays.swift.
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

// Overlays, log, tooltip, fate deck
extension CombatScene {
    func showDiscardOverlay() {
        dismissDiscardOverlay()

        let cards = simulation.discardPile
        let overlay = SKNode()
        overlay.zPosition = 100

        // Dark background
        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.8)
        bg.strokeColor = .clear
        overlay.addChild(bg)

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = L("combat.discard.title", cards.count)
        title.fontSize = 16
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: size.height / 2 - 50)
        title.verticalAlignmentMode = .center
        overlay.addChild(title)

        if cards.isEmpty {
            let empty = SKLabelNode(fontNamed: "AvenirNext-Regular")
            empty.text = L("combat.pile.empty")
            empty.fontSize = 14
            empty.fontColor = CombatSceneTheme.muted
            empty.position = .zero
            empty.verticalAlignmentMode = .center
            overlay.addChild(empty)
        } else {
            // Show cards in a grid, scaled to fit 3 per row
            let gridScale: CGFloat = 0.6
            let cardW = CardNode.cardSize.width * gridScale + 6
            let cardH = CardNode.cardSize.height * gridScale + 8
            let cols = min(cards.count, 3)
            let totalW = cardW * CGFloat(cols)
            let startX = -totalW / 2 + cardW / 2

            for (i, card) in cards.enumerated() {
                let col = i % 3
                let row = i / 3
                let node = CardNode(card: card)
                node.setScale(gridScale)
                node.position = CGPoint(
                    x: startX + CGFloat(col) * cardW,
                    y: CGFloat(20) - CGFloat(row) * cardH
                )
                overlay.addChild(node)
            }
        }

        // Tap to close hint
        let hint = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hint.text = L("combat.tap.to.close")
        hint.fontSize = 10
        hint.fontColor = CombatSceneTheme.muted
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        hint.verticalAlignmentMode = .center
        overlay.addChild(hint)

        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.2))
        discardOverlay = overlay
    }

    func dismissDiscardOverlay() {
        discardOverlay?.removeFromParent()
        discardOverlay = nil
    }

    // MARK: - Exhaust Pile Viewer

    func showExhaustOverlay() {
        dismissExhaustOverlay()

        let cards = simulation.exhaustPile
        guard !cards.isEmpty else { return }

        let overlay = SKNode()
        overlay.zPosition = 100

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.8)
        bg.strokeColor = .clear
        overlay.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = L("combat.exhaust.title", cards.count)
        title.fontSize = 16
        title.fontColor = CombatSceneTheme.muted
        title.position = CGPoint(x: 0, y: size.height / 2 - 50)
        title.verticalAlignmentMode = .center
        overlay.addChild(title)

        let gridScale: CGFloat = 0.6
        let cardW = CardNode.cardSize.width * gridScale + 6
        let cardH = CardNode.cardSize.height * gridScale + 8
        let cols = min(cards.count, 3)
        let totalW = cardW * CGFloat(cols)
        let startX = -totalW / 2 + cardW / 2

        for (i, card) in cards.enumerated() {
            let col = i % 3
            let row = i / 3
            let node = CardNode(card: card)
            node.setScale(gridScale)
            node.alpha = 0.6
            node.position = CGPoint(
                x: startX + CGFloat(col) * cardW,
                y: CGFloat(20) - CGFloat(row) * cardH
            )
            overlay.addChild(node)
        }

        let hint = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hint.text = L("combat.tap.to.close")
        hint.fontSize = 10
        hint.fontColor = CombatSceneTheme.muted
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        hint.verticalAlignmentMode = .center
        overlay.addChild(hint)

        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.2))
        exhaustOverlay = overlay
    }

    func dismissExhaustOverlay() {
        exhaustOverlay?.removeFromParent()
        exhaustOverlay = nil
    }

    // MARK: - Combat Log

    func addLogEntry(_ text: String) {
        combatLogEntries.append(text)
        if combatLogEntries.count > maxLogEntries {
            combatLogEntries.removeFirst()
        }
        refreshLog()
    }

    func refreshLog() {
        combatLogNode.removeAllChildren()
        for (i, entry) in combatLogEntries.reversed().enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Regular")
            label.text = entry
            label.fontSize = 8
            label.fontColor = CombatSceneTheme.muted.withAlphaComponent(CGFloat(1.0 - Double(i) * 0.15))
            label.horizontalAlignmentMode = .right
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: CGFloat(i) * 12)
            combatLogNode.addChild(label)
        }
    }

    func logCombatEvent(_ event: CombatEvent) {
        switch event {
        case .playerAttacked(let dmg, _, _, _):
            addLogEntry(L("encounter.log.player.attack", dmg))
        case .playerMissed:
            addLogEntry(L("encounter.log.player.missed"))
        case .enemyAttacked(let dmg, _, _, _):
            addLogEntry(dmg > 0 ? L("encounter.log.enemy.damage", dmg) : L("encounter.log.enemy.blocked"))
        case .enemyHealed(let amt):
            addLogEntry(L("encounter.log.enemy.heals", amt))
        case .enemyRitual(let shift):
            addLogEntry(L("encounter.log.enemy.ritual", "\(shift > 0 ? "+" : "")\(Int(shift))"))
        case .enemyBlocked:
            addLogEntry(L("encounter.log.enemy.defends"))
        case .cardPlayed(_, let dmg, let heal, let drawn, let status):
            var parts: [String] = []
            if dmg > 0 { parts.append("\(dmg) dmg") }
            if heal > 0 { parts.append("+\(heal) hp") }
            if drawn > 0 { parts.append("+\(drawn) cards") }
            if let s = status {
                if s == "resonance" {
                    let res = Int(simulation.resonance)
                    parts.append("resonance → \(res)")
                } else {
                    parts.append(s)
                }
            }
            addLogEntry("Card: \(parts.joined(separator: ", "))")
        case .insufficientEnergy:
            addLogEntry(L("encounter.log.no.energy"))
        case .roundAdvanced(let r):
            addLogEntry(L("encounter.log.round.start", r))
        case .playerInfluenced(let dmg, _, _, _):
            addLogEntry(L("encounter.log.player.influence", dmg))
        case .influenceNotAvailable:
            addLogEntry(L("encounter.log.influence.impossible"))
        case .trackSwitched(let track):
            addLogEntry(L("encounter.log.track.switch", track.rawValue))
        }
    }

    // MARK: - Tooltip

    func showTooltip(for card: Card, at location: CGPoint) {
        dismissTooltip()

        let tooltip = SKNode()
        tooltip.zPosition = 100

        let cost = card.cost ?? 1
        var lines = [
            card.name,
            L("combat.card.cost", cost)
        ]

        if card.abilities.isEmpty {
            lines.append(card.description)
        } else {
            for ability in card.abilities {
                lines.append("• \(ability.description)")
            }
        }

        var keywords: [String] = []
        if card.exhaust { keywords.append(L("combat.keyword.exhaust")) }
        keywords.append(contentsOf: card.traits)
        if !keywords.isEmpty {
            lines.append(keywords.joined(separator: " · "))
        }

        let text = lines.joined(separator: "\n")

        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 160
        label.fontSize = 11
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let padding: CGFloat = 12
        let bgWidth = max(label.frame.width + padding * 2, 120)
        let bgHeight = max(label.frame.height + padding * 2, 50)

        let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.85)
        bg.strokeColor = CombatSceneTheme.muted
        bg.lineWidth = 1

        tooltip.addChild(bg)
        tooltip.addChild(label)

        // Position above touch, clamped to scene
        let halfW = size.width / 2
        let tooltipX = max(-halfW + bgWidth / 2 + 8, min(halfW - bgWidth / 2 - 8, location.x))
        tooltip.position = CGPoint(x: tooltipX, y: location.y + bgHeight / 2 + 20)

        addChild(tooltip)
        tooltipNode = tooltip

        // Fade in
        tooltip.alpha = 0
        tooltip.run(SKAction.fadeIn(withDuration: 0.15))
    }

    func dismissTooltip() {
        tooltipNode?.removeFromParent()
        tooltipNode = nil
    }

    // MARK: - Draw Pile & Fate Deck Visuals

    func makeDrawPileNode() -> SKNode {
        let node = SKNode()
        node.name = "btn_draw_pile"
        // Stack of 3 card backs
        for i in 0..<3 {
            let cardBack = SKShapeNode(rectOf: CGSize(width: 36, height: 50), cornerRadius: 4)
            cardBack.fillColor = CombatSceneTheme.cardBack
            cardBack.strokeColor = CombatSceneTheme.spirit.withAlphaComponent(0.6)
            cardBack.lineWidth = 1
            cardBack.position = CGPoint(x: CGFloat(i) * 2, y: CGFloat(i) * 2)
            cardBack.name = "btn_draw_pile"
            node.addChild(cardBack)
        }
        // Card back pattern
        let pattern = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        pattern.text = "🂠"
        pattern.fontSize = 20
        pattern.verticalAlignmentMode = .center
        pattern.position = CGPoint(x: 4, y: 4)
        pattern.name = "btn_draw_pile"
        node.addChild(pattern)
        return node
    }

    func showFateDeckInArena() {
        fateDeckNode?.removeFromParent()

        let node = SKNode()
        node.name = "btn_fate_deck"
        node.position = CGPoint(x: 0, y: arenaCenter.y - 50)
        node.zPosition = 45

        let cardBack = SKShapeNode(rectOf: FateCardNode.cardSize, cornerRadius: 6)
        cardBack.fillColor = CombatSceneTheme.faith.withAlphaComponent(0.2)
        cardBack.strokeColor = CombatSceneTheme.faith.withAlphaComponent(0.8)
        cardBack.lineWidth = 1.5
        cardBack.name = "btn_fate_deck"
        node.addChild(cardBack)

        let icon = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        icon.text = "☆"
        icon.fontSize = 24
        icon.fontColor = CombatSceneTheme.faith
        icon.verticalAlignmentMode = .center
        icon.name = "btn_fate_deck"
        node.addChild(icon)

        let hint = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        hint.text = L("combat.fate.tap")
        hint.fontSize = 10
        hint.fontColor = CombatSceneTheme.faith
        hint.position = CGPoint(x: 0, y: -(FateCardNode.cardSize.height / 2 + 10))
        hint.verticalAlignmentMode = .top
        hint.name = "btn_fate_deck"
        node.addChild(hint)

        // Pulse animation to attract attention
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        node.run(pulse, withKey: "pulse")

        node.alpha = 0
        addChild(node)
        node.run(SKAction.fadeIn(withDuration: 0.2))
        fateDeckNode = node
    }

    func hideFateDeck() {
        fateDeckNode?.removeAllActions()
        fateDeckNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        fateDeckNode = nil
    }

    func handleDrawPileTap() {
        guard !simulation.isOver, simulation.phase == .playerTurn, !isAnimating else { return }
        guard simulation.drawPileCount > 0 else { return }

        if let card = simulation.drawOneCard() {
            onSoundEffect?("cardDraw")
            refreshHand()
            updateHUD()

            // Animate the new card: find it in hand and flash it
            for case let cardNode as CardNode in handContainer.children where cardNode.card.id == card.id {
                cardNode.alpha = 0
                cardNode.run(SKAction.fadeIn(withDuration: 0.2))
            }
        }
    }

    func handleFateDeckTap() {
        guard awaitingFateReveal, let completion = fateRevealCompletion else { return }
        awaitingFateReveal = false
        fateRevealCompletion = nil

        hideFateDeck()

        showFateCard(
            value: pendingFateValue,
            isCritical: pendingFateIsCritical,
            label: pendingFateLabel,
            resolution: pendingFateResolution,
            completion: completion
        )
    }

    /// Show fate deck and wait for player tap. When tapped, reveals the fate card and calls completion.
    func presentFateDeckForReveal(value: Int, isCritical: Bool, label: String, resolution: FateResolution?, completion: @escaping () -> Void) {
        pendingFateValue = value
        pendingFateIsCritical = isCritical
        pendingFateLabel = label
        pendingFateResolution = resolution
        fateRevealCompletion = completion
        awaitingFateReveal = true
        showFateDeckInArena()
    }

    // MARK: - Combat Actions (Phased Flow)

    /// Executes the full player attack flow with explicit visual phases:
}
