/// Файл: Views/Combat/DispositionCombatScene+Layout.swift
/// Назначение: Layout Disposition Combat сцены — создание и позиционирование всех узлов.
/// Зона ответственности: Disposition track bar, idol, action buttons, hand area, HUD, intent label.
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import SpriteKit
import TwilightEngine

// MARK: - Layout

extension DispositionCombatScene {

    /// Create all nodes and position them in the dynamic portrait scene.
    func buildLayout() {
        removeAllChildren()
        handCardNodes.removeAll()

        let sceneW = size.width
        let centerX = sceneW / 2

        buildLayers()
        buildIdol(centerX: centerX)
        buildDispositionTrack(centerX: centerX)
        buildActionButtons(centerX: centerX)
        buildMomentumAura(centerX: centerX)
        buildHUD(centerX: centerX, sceneW: sceneW)
        buildModifierStrips(centerX: centerX)
    }

    // MARK: - Layers

    private func buildLayers() {
        let combat = SKNode()
        combat.zPosition = 10
        addChild(combat)
        combatLayer = combat

        let hand = SKNode()
        hand.zPosition = 20
        addChild(hand)
        handLayer = hand

        let overlay = SKNode()
        overlay.zPosition = 50
        addChild(overlay)
        overlayLayer = overlay
    }

    // MARK: - Enemy Idol

    private func buildIdol(centerX: CGFloat) {
        guard let vm = viewModel else { return }
        let idol = IdolNode(enemyId: vm.enemyType)
        idol.configure(name: vm.enemyType, maxHP: 0, maxWP: nil)
        idol.position = CGPoint(x: centerX, y: size.height * Layout.idol)
        idol.zPosition = 15
        addChild(idol)
        idolNode = idol
    }

    // MARK: - Disposition Track

    private func buildDispositionTrack(centerX: CGFloat) {
        let barWidth: CGFloat = 300
        let barHeight: CGFloat = 22
        let barY = size.height * Layout.bar

        let barBg = SKShapeNode(
            rect: CGRect(x: -barWidth / 2, y: -barHeight / 2, width: barWidth, height: barHeight),
            cornerRadius: 4
        )
        barBg.fillColor = SKColor(red: 0.15, green: 0.13, blue: 0.18, alpha: 1)
        barBg.strokeColor = SKColor(red: 0.30, green: 0.25, blue: 0.35, alpha: 1)
        barBg.lineWidth = 1
        barBg.position = CGPoint(x: centerX, y: barY)
        barBg.zPosition = 12
        addChild(barBg)
        dispositionBar = barBg

        let fill = SKShapeNode(
            rect: CGRect(x: -barWidth / 2, y: -barHeight / 2 + 1, width: barWidth / 2, height: barHeight - 2),
            cornerRadius: 3
        )
        fill.fillColor = SKColor(red: 0.80, green: 0.80, blue: 0.30, alpha: 1)
        fill.strokeColor = .clear
        fill.zPosition = 13
        barBg.addChild(fill)
        dispositionFill = fill

        // Icon endpoints on the bar itself
        let leftIcon = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        leftIcon.text = "⚔"
        leftIcon.fontSize = 14
        leftIcon.fontColor = SKColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 0.8)
        leftIcon.position = CGPoint(x: -barWidth / 2 - 14, y: 0)
        leftIcon.verticalAlignmentMode = .center
        leftIcon.horizontalAlignmentMode = .center
        barBg.addChild(leftIcon)

        let rightIcon = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        rightIcon.text = "☽"
        rightIcon.fontSize = 14
        rightIcon.fontColor = SKColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 0.8)
        rightIcon.position = CGPoint(x: barWidth / 2 + 14, y: 0)
        rightIcon.verticalAlignmentMode = .center
        rightIcon.horizontalAlignmentMode = .center
        barBg.addChild(rightIcon)

        // Human-readable endpoint labels below bar
        let destroyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        destroyLabel.text = "Уничтожить"
        destroyLabel.fontSize = 11
        destroyLabel.fontColor = SKColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 0.6)
        destroyLabel.position = CGPoint(x: -barWidth / 2, y: -barHeight / 2 - 12)
        destroyLabel.verticalAlignmentMode = .center
        destroyLabel.horizontalAlignmentMode = .left
        barBg.addChild(destroyLabel)

        let subjugateLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subjugateLabel.text = "Подчинить"
        subjugateLabel.fontSize = 11
        subjugateLabel.fontColor = SKColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 0.6)
        subjugateLabel.position = CGPoint(x: barWidth / 2, y: -barHeight / 2 - 12)
        subjugateLabel.verticalAlignmentMode = .center
        subjugateLabel.horizontalAlignmentMode = .right
        barBg.addChild(subjugateLabel)

        let valueLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueLabel.name = "dispositionValue"
        valueLabel.text = "0"
        valueLabel.fontSize = 20
        valueLabel.fontColor = .white
        valueLabel.position = CGPoint(x: centerX, y: barY + barHeight / 2 + 5)
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.verticalAlignmentMode = .bottom
        valueLabel.zPosition = 14
        addChild(valueLabel)
        dispositionLabel = valueLabel

        let marker = SKShapeNode(rectOf: CGSize(width: 2, height: barHeight + 6))
        marker.fillColor = SKColor(white: 0.7, alpha: 0.8)
        marker.strokeColor = .clear
        marker.position = .zero
        marker.zPosition = 14
        barBg.addChild(marker)
    }

    // MARK: - Action Buttons (tap-to-play, shown when card selected)

    private func buildActionButtons(centerX: CGFloat) {
        let container = SKNode()
        container.name = "actionButtonsContainer"
        container.position = CGPoint(x: centerX, y: size.height * Layout.actions)
        container.alpha = 0
        container.zPosition = 25
        combatLayer?.addChild(container)
        actionButtonsContainer = container

        let buttonW: CGFloat = 105
        let buttonH: CGFloat = 55
        let spacing: CGFloat = 8
        let totalW = buttonW * 3 + spacing * 2
        let startX = -totalW / 2 + buttonW / 2

        let strike = makeActionButton(
            name: "strikeButton",
            icon: "⚔",
            label: L10n.encounterActionAttack.localized,
            color: SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1),
            size: CGSize(width: buttonW, height: buttonH),
            position: CGPoint(x: startX, y: 0)
        )
        container.addChild(strike)
        strikeButton = strike

        let influence = makeActionButton(
            name: "influenceButton",
            icon: "☽",
            label: L10n.encounterActionInfluence.localized,
            color: SKColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1),
            size: CGSize(width: buttonW, height: buttonH),
            position: CGPoint(x: startX + buttonW + spacing, y: 0)
        )
        container.addChild(influence)
        influenceButton = influence

        let sacrifice = makeActionButton(
            name: "sacrificeButton",
            icon: "♦",
            label: L10n.dispositionActionSacrifice.localized,
            color: SKColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1),
            size: CGSize(width: buttonW, height: buttonH),
            position: CGPoint(x: startX + (buttonW + spacing) * 2, y: 0)
        )
        container.addChild(sacrifice)
        sacrificeButton = sacrifice

        // End turn button — below action buttons
        let endBtn = makeActionZone(
            size: CGSize(width: 120, height: 36),
            label: "⏭",
            sublabel: L10n.dispositionActionEndTurn.localized,
            color: SKColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 0.8)
        )
        endBtn.name = "endTurnButton"
        endBtn.position = CGPoint(x: size.width - 80, y: size.height * Layout.endTurn)
        endBtn.zPosition = 15
        addChild(endBtn)
        endTurnButton = endBtn

        // Intent label — near idol
        let intent = SKLabelNode(fontNamed: "AvenirNext-Bold")
        intent.name = "intentLabel"
        intent.fontSize = 14
        intent.fontColor = SKColor(white: 0.8, alpha: 1)
        intent.horizontalAlignmentMode = .center
        intent.verticalAlignmentMode = .center
        intent.position = CGPoint(x: centerX, y: size.height * Layout.intent)
        intent.zPosition = 16
        intent.alpha = 0
        addChild(intent)
        intentLabel = intent
    }

    private func makeActionButton(
        name: String,
        icon: String,
        label: String,
        color: SKColor,
        size: CGSize,
        position: CGPoint
    ) -> SKNode {
        let node = SKNode()
        node.name = name
        node.position = position

        let bg = SKShapeNode(rectOf: size, cornerRadius: 10)
        bg.fillColor = color.withAlphaComponent(0.15)
        bg.strokeColor = color.withAlphaComponent(0.6)
        bg.lineWidth = 1.5
        node.addChild(bg)

        let iconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        iconLabel.text = icon
        iconLabel.fontSize = 18
        iconLabel.position = CGPoint(x: 0, y: 10)
        iconLabel.verticalAlignmentMode = .center
        node.addChild(iconLabel)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = label
        sub.fontSize = 9
        sub.fontColor = .white.withAlphaComponent(0.7)
        sub.position = CGPoint(x: 0, y: -4)
        sub.verticalAlignmentMode = .center
        node.addChild(sub)

        let preview = SKLabelNode(fontNamed: "AvenirNext-Bold")
        preview.text = ""
        preview.fontSize = 13
        preview.fontColor = .white
        preview.position = CGPoint(x: 0, y: -18)
        preview.verticalAlignmentMode = .center
        preview.name = "\(name)Preview"
        node.addChild(preview)

        return node
    }

    func showActionButtons(for card: Card) {
        guard let vm = viewModel, let container = actionButtonsContainer else { return }

        let strikePower = vm.previewStrikePower(card: card)
        let influencePower = vm.previewInfluencePower(card: card)
        let basePower = card.power ?? 1

        if let label = strikeButton?.childNode(withName: "strikeButtonPreview") as? SKLabelNode {
            let presentation = actionPreviewPresentation(
                for: .strike,
                value: strikePower,
                basePower: basePower
            )
            label.text = presentation.text
            label.fontColor = presentation.color
        }
        if let label = influenceButton?.childNode(withName: "influenceButtonPreview") as? SKLabelNode {
            let presentation = actionPreviewPresentation(
                for: .influence,
                value: influencePower,
                basePower: basePower
            )
            label.text = presentation.text
            label.fontColor = presentation.color
        }
        if let label = sacrificeButton?.childNode(withName: "sacrificeButtonPreview") as? SKLabelNode {
            let presentation = actionPreviewPresentation(
                for: .sacrifice,
                value: 1,
                basePower: 1,
                enabled: vm.canSacrifice
            )
            label.text = presentation.text
            label.fontColor = presentation.color
        }
        sacrificeButton?.alpha = vm.canSacrifice ? 1.0 : 0.4

        container.removeAllActions()
        container.alpha = 1
    }

    func hideActionButtons() {
        actionButtonsContainer?.removeAllActions()
        actionButtonsContainer?.alpha = 0
    }

    private func makeActionZone(
        size: CGSize,
        label: String,
        sublabel: String,
        color: SKColor
    ) -> SKShapeNode {
        let zone = SKShapeNode(rectOf: size, cornerRadius: 12)
        zone.fillColor = color.withAlphaComponent(0.12)
        zone.strokeColor = color
        zone.lineWidth = 1.5

        let iconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        iconLabel.text = label
        iconLabel.fontSize = 22
        iconLabel.verticalAlignmentMode = .center
        iconLabel.position = CGPoint(x: 0, y: 6)
        zone.addChild(iconLabel)

        let subLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subLabel.text = sublabel
        subLabel.fontSize = 9
        subLabel.fontColor = SKColor(white: 0.65, alpha: 1)
        subLabel.verticalAlignmentMode = .center
        subLabel.horizontalAlignmentMode = .center
        subLabel.position = CGPoint(x: 0, y: -13)
        zone.addChild(subLabel)

        return zone
    }

    // MARK: - Momentum Aura

    private func buildMomentumAura(centerX: CGFloat) {
        let aura = SKShapeNode(ellipseOf: CGSize(width: 200, height: 50))
        aura.fillColor = .clear
        aura.strokeColor = .clear
        aura.position = CGPoint(x: centerX, y: size.height * Layout.hand)
        aura.zPosition = 19
        aura.alpha = 0
        addChild(aura)
        momentumAuraNode = aura
    }

    // MARK: - HUD
    // Primary HUD stays visible; secondary counters moved to long-press details overlay.
    // Sits below Dynamic Island safe area (Layout.hudTopPad = 80pt).

    private func buildHUD(centerX: CGFloat, sceneW: CGFloat) {
        let row1Y = size.height - Layout.hudTopPad
        let row2Y = row1Y - 22

        // Row 1: HP (left) + Energy (right) — always visible, large
        let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hpLabel.name = "heroHPLabel"
        hpLabel.fontSize = 16
        hpLabel.fontColor = SKColor(red: 0.9, green: 0.35, blue: 0.35, alpha: 1)
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.verticalAlignmentMode = .center
        hpLabel.text = "♥ --"
        hpLabel.position = CGPoint(x: 20, y: row1Y)
        hpLabel.zPosition = 30
        addChild(hpLabel)

        let energyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        energyLabel.name = "energyLabel"
        energyLabel.fontSize = 16
        energyLabel.fontColor = SKColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1)
        energyLabel.horizontalAlignmentMode = .right
        energyLabel.verticalAlignmentMode = .center
        energyLabel.text = "⚡ 3/3"
        energyLabel.position = CGPoint(x: sceneW - 20, y: row1Y)
        energyLabel.zPosition = 30
        addChild(energyLabel)

        // Row 2: Phase (left) + Streak (right) — secondary info
        let phaseLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        phaseLabel.name = "phaseLabel"
        phaseLabel.fontSize = 12
        phaseLabel.fontColor = SKColor(white: 0.5, alpha: 1)
        phaseLabel.horizontalAlignmentMode = .left
        phaseLabel.verticalAlignmentMode = .center
        phaseLabel.text = L10n.encounterPhasePlayerAction.localized
        phaseLabel.position = CGPoint(x: 20, y: row2Y)
        phaseLabel.zPosition = 30
        addChild(phaseLabel)

        let streakLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        streakLabel.name = "streakLabel"
        streakLabel.fontSize = 13
        streakLabel.fontColor = SKColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1)
        streakLabel.horizontalAlignmentMode = .right
        streakLabel.verticalAlignmentMode = .center
        streakLabel.text = ""
        streakLabel.alpha = 0
        streakLabel.position = CGPoint(x: sceneW - 20, y: row2Y)
        streakLabel.zPosition = 30
        addChild(streakLabel)

        // Hand size indicator — below hand, center
        let handLabelsY = size.height * Layout.handLabels
        let handSizeLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        handSizeLabel.name = "handSizeLabel"
        handSizeLabel.fontSize = 13
        handSizeLabel.fontColor = SKColor(white: 0.50, alpha: 1)
        handSizeLabel.horizontalAlignmentMode = .center
        handSizeLabel.verticalAlignmentMode = .center
        handSizeLabel.text = ""
        handSizeLabel.position = CGPoint(x: centerX, y: handLabelsY)
        handSizeLabel.zPosition = 30
        handSizeLabel.alpha = 0
        addChild(handSizeLabel)

        // Discard pile indicator — below hand, left
        let discardLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        discardLabel.name = "discardLabel"
        discardLabel.fontSize = 12
        discardLabel.fontColor = SKColor(white: 0.45, alpha: 1)
        discardLabel.horizontalAlignmentMode = .left
        discardLabel.verticalAlignmentMode = .center
        discardLabel.text = ""
        discardLabel.position = CGPoint(x: 20, y: handLabelsY)
        discardLabel.zPosition = 30
        discardLabel.alpha = 0
        addChild(discardLabel)

        // Exhaust pile indicator — below hand, right
        let exhaustLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        exhaustLabel.name = "exhaustLabel"
        exhaustLabel.fontSize = 12
        exhaustLabel.fontColor = SKColor(red: 0.6, green: 0.35, blue: 0.2, alpha: 0.7)
        exhaustLabel.horizontalAlignmentMode = .right
        exhaustLabel.verticalAlignmentMode = .center
        exhaustLabel.text = ""
        exhaustLabel.position = CGPoint(x: sceneW - 20, y: handLabelsY)
        exhaustLabel.zPosition = 30
        exhaustLabel.alpha = 0
        addChild(exhaustLabel)

        // Zone label — removed from main HUD (available via long-press later)

        updateHUDValues()
    }

    // MARK: - Modifier Strips

    private func buildModifierStrips(centerX: CGFloat) {
        let enemyStrip = SKNode()
        enemyStrip.position = CGPoint(x: centerX, y: size.height * Layout.enemyMods)
        enemyStrip.zPosition = 16
        addChild(enemyStrip)
        enemyModifierStrip = enemyStrip

        let heroStrip = SKNode()
        heroStrip.position = CGPoint(x: centerX, y: size.height * Layout.heroMods)
        heroStrip.zPosition = 30
        addChild(heroStrip)
        heroModifierStrip = heroStrip
    }

    func updateHUDValues() {
        guard let vm = viewModel else { return }

        if let hpLabel = childNode(withName: "heroHPLabel") as? SKLabelNode {
            let hp = vm.heroHP
            let maxHP = vm.heroMaxHP
            hpLabel.text = "♥ \(hp)/\(maxHP)"

            let fraction = CGFloat(hp) / CGFloat(max(maxHP, 1))
            let baseColor: SKColor = fraction <= 0.3
                ? SKColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
                : SKColor(red: 0.9, green: 0.35, blue: 0.35, alpha: 1)
            hpLabel.fontColor = baseColor

            if let prev = prevHeroHP, prev != hp {
                let delta = hp - prev
                let flashColor: SKColor = delta < 0
                    ? SKColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 1)
                    : SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
                hpLabel.fontColor = flashColor
                hpLabel.run(SKAction.sequence([
                    SKAction.scale(to: 1.2, duration: 0.08),
                    SKAction.scale(to: 1.0, duration: 0.08),
                    SKAction.run { [weak hpLabel] in hpLabel?.fontColor = baseColor }
                ]))
            }
            prevHeroHP = hp
        }

        // Hand / pile indicators — descriptive labels
        if let handLabel = childNode(withName: "handSizeLabel") as? SKLabelNode {
            let handCount = vm.hand.count
            let total = vm.startingHandSize
            handLabel.text = L10n.dispositionHandCount.localized(with: handCount, total)
        }
        if let discardLabel = childNode(withName: "discardLabel") as? SKLabelNode {
            let count = vm.discardCount
            discardLabel.text = count > 0
                ? L10n.dispositionDiscardCount.localized(with: count)
                : ""
        }
        if let exhaustLabel = childNode(withName: "exhaustLabel") as? SKLabelNode {
            let count = vm.exhaustCount
            exhaustLabel.text = count > 0
                ? L10n.dispositionExhaustCount.localized(with: count)
                : ""
        }
    }

}
