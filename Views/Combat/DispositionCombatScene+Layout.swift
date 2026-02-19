/// Файл: Views/Combat/DispositionCombatScene+Layout.swift
/// Назначение: Layout Disposition Combat сцены — создание и позиционирование всех узлов.
/// Зона ответственности: Disposition track bar, idol, action zones, hand area, HUD, intent label.
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import SpriteKit

// MARK: - Layout

extension DispositionCombatScene {

    /// Create all nodes and position them in the 390×700 portrait scene.
    func buildLayout() {
        removeAllChildren()
        handCardNodes.removeAll()

        let sceneW = DispositionCombatScene.sceneSize.width
        let centerX = sceneW / 2

        buildLayers()
        buildIdol(centerX: centerX)
        buildDispositionTrack(centerX: centerX)
        buildActionZones(centerX: centerX)
        buildMomentumAura(centerX: centerX)
        buildHUD(centerX: centerX, sceneW: sceneW)
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
        idol.configure(name: vm.enemyType, maxHP: vm.heroMaxHP, maxWP: nil)
        idol.position = CGPoint(x: centerX, y: 600)
        idol.zPosition = 15
        addChild(idol)
        idolNode = idol
    }

    // MARK: - Disposition Track

    private func buildDispositionTrack(centerX: CGFloat) {
        let barWidth: CGFloat = 300
        let barHeight: CGFloat = 16
        let barY: CGFloat = 510

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

        let leftLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        leftLabel.text = "-100"
        leftLabel.fontSize = 9
        leftLabel.fontColor = SKColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 0.7)
        leftLabel.position = CGPoint(x: -barWidth / 2, y: -barHeight / 2 - 12)
        leftLabel.horizontalAlignmentMode = .center
        barBg.addChild(leftLabel)

        let rightLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        rightLabel.text = "+100"
        rightLabel.fontSize = 9
        rightLabel.fontColor = SKColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 0.7)
        rightLabel.position = CGPoint(x: barWidth / 2, y: -barHeight / 2 - 12)
        rightLabel.horizontalAlignmentMode = .center
        barBg.addChild(rightLabel)

        let valueLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueLabel.name = "dispositionValue"
        valueLabel.text = "0"
        valueLabel.fontSize = 16
        valueLabel.fontColor = .white
        valueLabel.position = CGPoint(x: centerX, y: barY + 16)
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.verticalAlignmentMode = .bottom
        valueLabel.zPosition = 14
        addChild(valueLabel)
        dispositionLabel = valueLabel

        let marker = SKShapeNode(rectOf: CGSize(width: 2, height: barHeight + 4))
        marker.fillColor = SKColor(white: 0.7, alpha: 0.8)
        marker.strokeColor = .clear
        marker.position = .zero
        marker.zPosition = 14
        barBg.addChild(marker)
    }

    // MARK: - Action Zones (vertical layout per design §9)

    private func buildActionZones(centerX: CGFloat) {
        // Vertical layout: Strike near enemy (top), Influence middle, Sacrifice below.
        // Y-band detection in GameLoop makes full screen areas responsive.

        // Strike zone — near enemy, disposition toward -100
        let strike = makeActionZone(
            size: CGSize(width: 160, height: 50),
            label: "⚔",
            sublabel: L10n.encounterActionAttack.localized,
            color: SKColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 0.8)
        )
        strike.name = "strikeZone"
        strike.position = CGPoint(x: centerX, y: 450)
        strike.zPosition = 15
        addChild(strike)
        strikeZone = strike

        // Influence zone — altar area, disposition toward +100
        let influence = makeActionZone(
            size: CGSize(width: 160, height: 50),
            label: "☽",
            sublabel: L10n.encounterActionInfluence.localized,
            color: SKColor(red: 0.30, green: 0.50, blue: 0.90, alpha: 0.8)
        )
        influence.name = "influenceZone"
        influence.position = CGPoint(x: centerX, y: 340)
        influence.zPosition = 15
        addChild(influence)
        influenceZone = influence

        // Sacrifice zone — bonfire, exhaust card for +1 energy
        let sacrifice = makeActionZone(
            size: CGSize(width: 130, height: 45),
            label: "♦",
            sublabel: "Sacrifice",
            color: SKColor(red: 0.60, green: 0.30, blue: 0.70, alpha: 0.8)
        )
        sacrifice.name = "sacrificeZone"
        sacrifice.position = CGPoint(x: centerX, y: 250)
        sacrifice.zPosition = 15
        addChild(sacrifice)
        sacrificeZone = sacrifice

        // End turn button
        let endBtn = makeActionZone(
            size: CGSize(width: 100, height: 36),
            label: "⏭",
            sublabel: "End Turn",
            color: SKColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 0.8)
        )
        endBtn.name = "endTurnButton"
        endBtn.position = CGPoint(x: centerX, y: 190)
        endBtn.zPosition = 15
        addChild(endBtn)
        endTurnButton = endBtn

        // Intent label — positioned between idol and disposition bar
        let intent = SKLabelNode(fontNamed: "AvenirNext-Bold")
        intent.name = "intentLabel"
        intent.fontSize = 14
        intent.fontColor = SKColor(white: 0.8, alpha: 1)
        intent.horizontalAlignmentMode = .center
        intent.verticalAlignmentMode = .center
        intent.position = CGPoint(x: centerX, y: 555)
        intent.zPosition = 16
        intent.alpha = 0
        addChild(intent)
        intentLabel = intent
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
        let aura = SKShapeNode(ellipseOf: CGSize(width: 340, height: 100))
        aura.fillColor = .clear
        aura.strokeColor = .clear
        aura.position = CGPoint(x: centerX, y: 85)
        aura.zPosition = 19
        aura.alpha = 0
        addChild(aura)
        momentumAuraNode = aura
    }

    // MARK: - HUD

    private func buildHUD(centerX: CGFloat, sceneW: CGFloat) {
        let energyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        energyLabel.name = "energyLabel"
        energyLabel.fontSize = 14
        energyLabel.fontColor = SKColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1)
        energyLabel.horizontalAlignmentMode = .center
        energyLabel.text = "⚡ 3/3"
        energyLabel.position = CGPoint(x: centerX, y: 25)
        energyLabel.zPosition = 30
        addChild(energyLabel)

        let streakLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        streakLabel.name = "streakLabel"
        streakLabel.fontSize = 13
        streakLabel.fontColor = SKColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1)
        streakLabel.horizontalAlignmentMode = .right
        streakLabel.text = ""
        streakLabel.alpha = 0
        streakLabel.position = CGPoint(x: sceneW - 15, y: 25)
        streakLabel.zPosition = 30
        addChild(streakLabel)

        let hpLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        hpLabel.name = "heroHPLabel"
        hpLabel.fontSize = 12
        hpLabel.fontColor = SKColor(red: 0.9, green: 0.4, blue: 0.4, alpha: 1)
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.text = "♥ 100"
        hpLabel.position = CGPoint(x: 15, y: 25)
        hpLabel.zPosition = 30
        addChild(hpLabel)

        let phaseLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        phaseLabel.name = "phaseLabel"
        phaseLabel.fontSize = 11
        phaseLabel.fontColor = SKColor(white: 0.5, alpha: 1)
        phaseLabel.horizontalAlignmentMode = .center
        phaseLabel.text = L10n.encounterPhasePlayerAction.localized
        phaseLabel.position = CGPoint(x: centerX, y: 690 - 14)
        phaseLabel.zPosition = 30
        addChild(phaseLabel)

        let zoneLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        zoneLabel.name = "zoneLabel"
        zoneLabel.fontSize = 10
        zoneLabel.fontColor = SKColor(white: 0.45, alpha: 1)
        zoneLabel.horizontalAlignmentMode = .right
        zoneLabel.position = CGPoint(x: sceneW - 15, y: 690 - 14)
        zoneLabel.zPosition = 30
        addChild(zoneLabel)

        updateHUDValues()
    }

    func updateHUDValues() {
        guard let vm = viewModel else { return }

        if let hpLabel = childNode(withName: "heroHPLabel") as? SKLabelNode {
            hpLabel.text = "♥ \(vm.heroHP)/\(vm.heroMaxHP)"
        }

        if let zoneLabel = childNode(withName: "zoneLabel") as? SKLabelNode {
            zoneLabel.text = vm.resonanceZone.rawValue.uppercased()
        }
    }
}
