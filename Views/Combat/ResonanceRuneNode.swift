/// Файл: Views/Combat/ResonanceRuneNode.swift
/// Назначение: HUD-узел руны резонанса — символьный индикатор (☽/☯/☀) с зоной и цветом.
/// Зона ответственности: Presentation-only — отображение зоны резонанса, плавный переход цвета.
/// Контекст: Phase 3 Ritual Combat (R8). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.6

import SpriteKit

// MARK: - Resonance Zone

/// Resonance zone derived from numeric value.
enum ResonanceZone: Equatable {
    case nav   // dark (< -30)
    case yav   // neutral (-30...+30)
    case prav  // light (> +30)

    var symbol: String {
        switch self {
        case .nav:  return "☽"
        case .yav:  return "☯"
        case .prav: return "☀"
        }
    }

    var color: SKColor {
        switch self {
        case .nav:  return SKColor(red: 0.45, green: 0.25, blue: 0.65, alpha: 1)
        case .yav:  return SKColor(red: 0.75, green: 0.60, blue: 0.30, alpha: 1)
        case .prav: return SKColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1)
        }
    }

    static func from(resonance: Float) -> ResonanceZone {
        if resonance < -30 { return .nav }
        if resonance > 30 { return .prav }
        return .yav
    }
}

// MARK: - Resonance Rune Node

/// Central resonance indicator showing mythic zone symbol and numeric value.
/// Pure visual node — state set via method calls, no stored simulation reference.
///
/// Usage:
///   1. Add to scene
///   2. `update(resonance:)` each frame or on change
final class ResonanceRuneNode: SKNode {

    // MARK: - Constants

    static let nodeSize = CGSize(width: 60, height: 60)

    // MARK: - State

    private(set) var currentZone: ResonanceZone = .yav

    // MARK: - Child Nodes

    private let bgNode: SKShapeNode
    private let runeLabel: SKLabelNode
    private let valueLabel: SKLabelNode

    // MARK: - Init

    override init() {
        let bg = SKShapeNode(circleOfRadius: 26)
        bg.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.12, alpha: 0.7)
        bg.strokeColor = SKColor(red: 0.75, green: 0.60, blue: 0.30, alpha: 1)
        bg.lineWidth = 1.5
        self.bgNode = bg

        let rune = SKLabelNode(fontNamed: "AvenirNext-Bold")
        rune.text = "☯"
        rune.fontSize = 28
        rune.verticalAlignmentMode = .center
        rune.horizontalAlignmentMode = .center
        rune.position = CGPoint(x: 0, y: 3)
        self.runeLabel = rune

        let value = SKLabelNode(fontNamed: "AvenirNext-Medium")
        value.text = "0"
        value.fontSize = 11
        value.fontColor = SKColor(red: 0.65, green: 0.60, blue: 0.55, alpha: 1)
        value.verticalAlignmentMode = .top
        value.horizontalAlignmentMode = .center
        value.position = CGPoint(x: 0, y: -14)
        self.valueLabel = value

        super.init()

        addChild(bgNode)
        addChild(runeLabel)
        addChild(valueLabel)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Update

    /// Update resonance display from current value.
    /// - Parameter resonance: World resonance value (-100...100)
    func update(resonance: Float) {
        let newZone = ResonanceZone.from(resonance: resonance)

        let sign = resonance > 0 ? "+" : ""
        valueLabel.text = "\(sign)\(Int(resonance))"

        if newZone != currentZone {
            currentZone = newZone
            transitionToZone(newZone)
        }
    }

    // MARK: - Zone Transition

    private func transitionToZone(_ zone: ResonanceZone) {
        runeLabel.text = zone.symbol

        let colorize = SKAction.run { [weak self] in
            self?.bgNode.strokeColor = zone.color
            self?.runeLabel.fontColor = zone.color
        }

        let scaleUp = SKAction.scale(to: 1.15, duration: 0.25)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.25)
        scaleDown.timingMode = .easeIn

        runeLabel.run(SKAction.sequence([colorize, scaleUp, scaleDown]))
    }
}
