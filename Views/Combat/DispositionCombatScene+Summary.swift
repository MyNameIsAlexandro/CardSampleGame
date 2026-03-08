/// Файл: Views/Combat/DispositionCombatScene+Summary.swift
/// Назначение: Post-combat summary overlay for disposition combat.
/// Зона ответственности: Display combat result stats before scene transition.
/// Контекст: UX Overhaul — meaningful feedback after combat ends.

import SpriteKit
import TwilightEngine

extension DispositionCombatScene {

    func showCombatSummary(
        outcome: DispositionOutcome,
        turnsPlayed: Int,
        cardsPlayed: Int,
        finalDisposition: Int,
        heroHP: Int,
        heroMaxHP: Int,
        completion: @escaping () -> Void
    ) {
        let sceneW = size.width
        let sceneH = size.height
        let centerX = sceneW / 2

        let overlay = SKNode()
        overlay.name = "combatSummary"
        overlay.zPosition = 200
        overlay.alpha = 0

        // Dim background
        let bg = SKShapeNode(rectOf: CGSize(width: sceneW, height: sceneH))
        bg.fillColor = .black.withAlphaComponent(0.7)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: centerX, y: sceneH / 2)
        overlay.addChild(bg)

        // Outcome title
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.fontSize = 28
        title.position = CGPoint(x: centerX, y: sceneH * 0.55)
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center

        switch outcome {
        case .destroyed:
            title.text = L10n.dispositionOutcomeDestroyed.localized
            title.fontColor = SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1)
        case .subjugated:
            title.text = L10n.dispositionOutcomeSubjugated.localized
            title.fontColor = SKColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1)
        case .defeated:
            title.text = L10n.dispositionOutcomeDefeated.localized
            title.fontColor = SKColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1)
        }
        overlay.addChild(title)

        // Stats -- simple label list
        let stats: [(String, String)] = [
            ("Ходов", "\(turnsPlayed)"),
            ("Карт сыграно", "\(cardsPlayed)"),
            ("Расположение", "\(finalDisposition)"),
            ("HP героя", "\(heroHP)/\(heroMaxHP)")
        ]

        for (i, stat) in stats.enumerated() {
            let y = sceneH * 0.47 - CGFloat(i) * 35

            let keyLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
            keyLabel.text = stat.0
            keyLabel.fontSize = 14
            keyLabel.fontColor = .white.withAlphaComponent(0.6)
            keyLabel.position = CGPoint(x: centerX - 60, y: y)
            keyLabel.horizontalAlignmentMode = .right
            keyLabel.verticalAlignmentMode = .center
            overlay.addChild(keyLabel)

            let valueLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            valueLabel.text = stat.1
            valueLabel.fontSize = 16
            valueLabel.fontColor = .white.withAlphaComponent(0.9)
            valueLabel.position = CGPoint(x: centerX - 40, y: y)
            valueLabel.horizontalAlignmentMode = .left
            valueLabel.verticalAlignmentMode = .center
            overlay.addChild(valueLabel)
        }

        // Continue button
        let btnBg = SKShapeNode(rectOf: CGSize(width: 160, height: 44), cornerRadius: 8)
        btnBg.fillColor = .white.withAlphaComponent(0.15)
        btnBg.strokeColor = .white.withAlphaComponent(0.4)
        btnBg.lineWidth = 1
        btnBg.position = CGPoint(x: centerX, y: sceneH * 0.27)
        btnBg.name = "summaryButton"
        overlay.addChild(btnBg)

        let btnLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        btnLabel.text = "Продолжить"
        btnLabel.fontSize = 16
        btnLabel.fontColor = .white
        btnLabel.position = CGPoint(x: centerX, y: sceneH * 0.27)
        btnLabel.verticalAlignmentMode = .center
        btnLabel.horizontalAlignmentMode = .center
        overlay.addChild(btnLabel)

        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.3))

        summaryCompletion = completion
    }
}
