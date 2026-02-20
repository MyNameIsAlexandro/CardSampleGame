/// Файл: Views/Combat/DispositionCombatScene+Layout.swift
/// Назначение: Layout Disposition Combat сцены — создание и позиционирование всех узлов.
/// Зона ответственности: Disposition track bar, idol, action zones, hand area, HUD, intent label.
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import SpriteKit
import TwilightEngine

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
        idol.position = CGPoint(x: centerX, y: 590)
        idol.zPosition = 15
        addChild(idol)
        idolNode = idol
    }

    // MARK: - Disposition Track

    private func buildDispositionTrack(centerX: CGFloat) {
        let barWidth: CGFloat = 300
        let barHeight: CGFloat = 16
        let barY: CGFloat = 468

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
        strike.position = CGPoint(x: centerX, y: 420)
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
            sublabel: L10n.dispositionActionSacrifice.localized,
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
            sublabel: L10n.dispositionActionEndTurn.localized,
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
        intent.position = CGPoint(x: centerX, y: 515)
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
        let aura = SKShapeNode(ellipseOf: CGSize(width: 200, height: 50))
        aura.fillColor = .clear
        aura.strokeColor = .clear
        aura.position = CGPoint(x: centerX, y: 105)
        aura.zPosition = 19
        aura.alpha = 0
        addChild(aura)
        momentumAuraNode = aura
    }

    // MARK: - HUD
    // Safe area margins: bottom ~50pt, top ~50pt, sides ~35pt in scene coords.
    // All HUD elements stay within x: 40…350, y: 55…645.
    // Stats use symbol+number (no bars) flanking End Turn at y=190.

    private func buildHUD(centerX: CGFloat, sceneW: CGFloat) {
        let statsY: CGFloat = 190

        // Hero HP — left of End Turn
        let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hpLabel.name = "heroHPLabel"
        hpLabel.fontSize = 16
        hpLabel.fontColor = SKColor(red: 0.9, green: 0.35, blue: 0.35, alpha: 1)
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.verticalAlignmentMode = .center
        hpLabel.text = "♥ --"
        hpLabel.position = CGPoint(x: 45, y: statsY)
        hpLabel.zPosition = 30
        addChild(hpLabel)

        // Energy — right of End Turn
        let energyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        energyLabel.name = "energyLabel"
        energyLabel.fontSize = 16
        energyLabel.fontColor = SKColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1)
        energyLabel.horizontalAlignmentMode = .right
        energyLabel.verticalAlignmentMode = .center
        energyLabel.text = "⚡ 3/3"
        energyLabel.position = CGPoint(x: sceneW - 45, y: statsY)
        energyLabel.zPosition = 30
        addChild(energyLabel)

        // Streak — below energy, appears only when active
        let streakLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        streakLabel.name = "streakLabel"
        streakLabel.fontSize = 13
        streakLabel.fontColor = SKColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1)
        streakLabel.horizontalAlignmentMode = .right
        streakLabel.verticalAlignmentMode = .center
        streakLabel.text = ""
        streakLabel.alpha = 0
        streakLabel.position = CGPoint(x: sceneW - 45, y: statsY - 20)
        streakLabel.zPosition = 30
        addChild(streakLabel)

        // Discard pile indicator — below hand, left
        let discardLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        discardLabel.name = "discardLabel"
        discardLabel.fontSize = 11
        discardLabel.fontColor = SKColor(white: 0.45, alpha: 1)
        discardLabel.horizontalAlignmentMode = .left
        discardLabel.verticalAlignmentMode = .center
        discardLabel.text = ""
        discardLabel.position = CGPoint(x: 45, y: 65)
        discardLabel.zPosition = 30
        addChild(discardLabel)

        // Exhaust pile indicator — below hand, right
        let exhaustLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        exhaustLabel.name = "exhaustLabel"
        exhaustLabel.fontSize = 11
        exhaustLabel.fontColor = SKColor(red: 0.6, green: 0.35, blue: 0.2, alpha: 0.7)
        exhaustLabel.horizontalAlignmentMode = .right
        exhaustLabel.verticalAlignmentMode = .center
        exhaustLabel.text = ""
        exhaustLabel.position = CGPoint(x: sceneW - 45, y: 65)
        exhaustLabel.zPosition = 30
        addChild(exhaustLabel)

        // Phase label — top area
        let phaseLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        phaseLabel.name = "phaseLabel"
        phaseLabel.fontSize = 11
        phaseLabel.fontColor = SKColor(white: 0.5, alpha: 1)
        phaseLabel.horizontalAlignmentMode = .center
        phaseLabel.text = L10n.encounterPhasePlayerAction.localized
        phaseLabel.position = CGPoint(x: centerX, y: 648)
        phaseLabel.zPosition = 30
        addChild(phaseLabel)

        let zoneLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        zoneLabel.name = "zoneLabel"
        zoneLabel.fontSize = 10
        zoneLabel.fontColor = SKColor(white: 0.45, alpha: 1)
        zoneLabel.horizontalAlignmentMode = .right
        zoneLabel.position = CGPoint(x: sceneW - 45, y: 648)
        zoneLabel.zPosition = 30
        addChild(zoneLabel)

        updateHUDValues()
    }

    // MARK: - Modifier Strips

    private func buildModifierStrips(centerX: CGFloat) {
        let enemyStrip = SKNode()
        enemyStrip.position = CGPoint(x: centerX, y: 498)
        enemyStrip.zPosition = 16
        addChild(enemyStrip)
        enemyModifierStrip = enemyStrip

        let heroStrip = SKNode()
        heroStrip.position = CGPoint(x: centerX, y: 165)
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

        if let zoneLabel = childNode(withName: "zoneLabel") as? SKLabelNode {
            zoneLabel.text = localizedZoneName(for: vm.resonanceZone)
        }

        // Pile indicators
        if let discardLabel = childNode(withName: "discardLabel") as? SKLabelNode {
            let count = vm.discardCount
            discardLabel.text = count > 0 ? "♻ \(count)" : ""
        }
        if let exhaustLabel = childNode(withName: "exhaustLabel") as? SKLabelNode {
            let count = vm.exhaustCount
            exhaustLabel.text = count > 0 ? "🔥 \(count)" : ""
        }
    }

    // MARK: - Zone Localization

    private func localizedZoneName(
        for zone: TwilightEngine.ResonanceZone
    ) -> String {
        switch zone {
        case .deepNav: return L10n.resonanceZoneDeepNav.localized
        case .nav: return L10n.resonanceZoneNav.localized
        case .yav: return L10n.resonanceZoneYav.localized
        case .prav: return L10n.resonanceZonePrav.localized
        case .deepPrav: return L10n.resonanceZoneDeepPrav.localized
        }
    }
}
