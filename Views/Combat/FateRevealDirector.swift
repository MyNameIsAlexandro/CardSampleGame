/// Файл: Views/Combat/FateRevealDirector.swift
/// Назначение: Режиссёр анимации раскрытия Fate-карты (3D flip, keyword effects).
/// Зона ответственности: Animation state machine, event-driven (без хранения ссылки на Simulation).
/// Контекст: Phase 3 Ritual Combat (R6). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.5

import SpriteKit

// MARK: - Reveal Phase

/// Animation phase of the fate card reveal sequence.
enum FateRevealPhase: Equatable {
    case idle
    case anticipation
    case flip
    case suitMatch
    case keywordEffect
    case complete
}

// MARK: - Reveal Data

/// Stored parameters for the current reveal sequence.
private struct RevealData {
    let cardName: String
    let effectiveValue: Int
    let isSuitMatch: Bool
    let isCritical: Bool
}

// MARK: - Fate Reveal Director

/// Directs the fate card reveal animation sequence.
/// Event-driven: receives fate draw results via method calls, not stored simulation reference.
/// This preserves determinism — the director is a pure presentation observer.
///
/// Usage:
///   1. `attach(to:)` with a parent SKNode (optional — works headless for tests)
///   2. `beginReveal(...)` triggers the animation sequence
///   3. `onRevealComplete` fires when animation finishes
///   4. `reset()` cancels and cleans up
final class FateRevealDirector {

    // MARK: - State

    /// Current animation phase
    private(set) var phase: FateRevealPhase = .idle

    /// Stored reveal parameters for the running sequence
    private var pendingReveal: RevealData?

    // MARK: - Scene Attachment

    /// Parent node for card animation. Nil = headless mode (phase tracking only).
    weak var parentNode: SKNode?

    /// Active card container node
    private var cardNode: SKNode?

    // MARK: - Callbacks

    /// Fires when the full reveal sequence completes
    var onRevealComplete: (() -> Void)?

    /// Sound effect request (e.g. "fateReveal", "fateCritical")
    var onSoundEffect: ((String) -> Void)?

    /// Haptic feedback request (e.g. "heavy", "medium")
    var onHaptic: ((String) -> Void)?

    // MARK: - Timing

    private let anticipationDuration: TimeInterval = 0.3
    private let flipDuration: TimeInterval = 0.15
    private let suitMatchDuration: TimeInterval = 0.3
    private let holdDuration: TimeInterval = 0.4
    private let fadeOutDuration: TimeInterval = 0.2

    // MARK: - Card Constants

    private let cardSize = CGSize(width: 60, height: 84)
    private let cornerRadius: CGFloat = 8

    // MARK: - Public API

    /// Attach director to a scene node for visual output.
    func attach(to node: SKNode) {
        parentNode = node
    }

    /// Begin a fate reveal animation for a drawn card.
    func beginReveal(
        cardName: String,
        effectiveValue: Int,
        isSuitMatch: Bool,
        isCritical: Bool
    ) {
        reset()
        let data = RevealData(
            cardName: cardName,
            effectiveValue: effectiveValue,
            isSuitMatch: isSuitMatch,
            isCritical: isCritical
        )
        pendingReveal = data
        phase = .anticipation

        guard let parent = parentNode else {
            completeSequence()
            return
        }

        runAnticipation(in: parent, data: data)
    }

    /// Reset director to idle state. Cancels any running animation.
    func reset() {
        cardNode?.removeAllActions()
        cardNode?.removeFromParent()
        cardNode = nil
        pendingReveal = nil
        phase = .idle
    }

    // MARK: - Animation Phases

    private func runAnticipation(in parent: SKNode, data: RevealData) {
        let container = SKNode()
        container.zPosition = 50
        parent.addChild(container)
        cardNode = container

        let back = makeCardBack()
        back.name = "fate_back"
        container.addChild(back)

        container.setScale(0)
        let scaleUp = SKAction.scale(to: 1.0, duration: anticipationDuration)
        scaleUp.timingMode = .easeOut

        container.run(scaleUp) { [weak self] in
            self?.runFlip(data: data)
        }
    }

    private func runFlip(data: RevealData) {
        phase = .flip
        guard let container = cardNode else { return completeSequence() }

        onSoundEffect?(data.isCritical ? "fateCritical" : "fateReveal")
        if data.isCritical {
            onHaptic?("heavy")
        }

        let back = container.childNode(withName: "fate_back")

        let collapseBack = SKAction.scaleX(to: 0, duration: flipDuration)
        collapseBack.timingMode = .easeIn

        let face = makeCardFace(value: data.effectiveValue, isCritical: data.isCritical)
        face.name = "fate_face"
        face.xScale = 0
        container.addChild(face)

        let expandFace = SKAction.scaleX(to: 1.0, duration: flipDuration)
        expandFace.timingMode = .easeOut

        back?.run(collapseBack)
        face.run(SKAction.sequence([
            SKAction.wait(forDuration: flipDuration),
            expandFace
        ])) { [weak self] in
            back?.removeFromParent()
            if data.isSuitMatch {
                self?.runSuitMatch(data: data)
            } else {
                self?.runHoldAndComplete()
            }
        }
    }

    private func runSuitMatch(data: RevealData) {
        phase = .suitMatch
        guard let container = cardNode else { return completeSequence() }

        let flash = SKShapeNode(rectOf: CGSize(width: cardSize.width + 6, height: cardSize.height + 6),
                                cornerRadius: cornerRadius + 2)
        flash.fillColor = .clear
        flash.strokeColor = SKColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1)
        flash.lineWidth = 3
        flash.alpha = 0
        flash.zPosition = -1
        container.addChild(flash)

        let flashIn = SKAction.fadeAlpha(to: 1.0, duration: suitMatchDuration * 0.4)
        let flashOut = SKAction.fadeAlpha(to: 0.0, duration: suitMatchDuration * 0.6)

        flash.run(SKAction.sequence([flashIn, flashOut, SKAction.removeFromParent()])) { [weak self] in
            self?.runHoldAndComplete()
        }
    }

    private func runHoldAndComplete() {
        phase = .keywordEffect
        guard let container = cardNode else { return completeSequence() }

        container.run(SKAction.wait(forDuration: holdDuration)) { [weak self] in
            self?.runFadeOut()
        }
    }

    private func runFadeOut() {
        phase = .complete
        guard let container = cardNode else { return completeSequence() }

        container.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: fadeOutDuration),
            SKAction.removeFromParent()
        ])) { [weak self] in
            self?.cardNode = nil
            self?.completeSequence()
        }
    }

    private func completeSequence() {
        pendingReveal = nil
        phase = .idle
        onRevealComplete?()
    }

    // MARK: - Card Node Builders

    private func makeCardBack() -> SKShapeNode {
        let node = SKShapeNode(rectOf: cardSize, cornerRadius: cornerRadius)
        node.fillColor = SKColor(red: 0.12, green: 0.18, blue: 0.30, alpha: 1)
        node.strokeColor = SKColor(red: 0.65, green: 0.60, blue: 0.65, alpha: 1)
        node.lineWidth = 2

        let question = SKLabelNode(fontNamed: "AvenirNext-Bold")
        question.text = "?"
        question.fontSize = 28
        question.fontColor = SKColor(red: 0.65, green: 0.60, blue: 0.65, alpha: 1)
        question.verticalAlignmentMode = .center
        question.horizontalAlignmentMode = .center
        node.addChild(question)

        return node
    }

    private func makeCardFace(value: Int, isCritical: Bool) -> SKShapeNode {
        let node = SKShapeNode(rectOf: cardSize, cornerRadius: cornerRadius)
        node.fillColor = faceColor(value: value, isCritical: isCritical)
        node.strokeColor = SKColor(red: 0.65, green: 0.60, blue: 0.65, alpha: 1)
        node.lineWidth = 2

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        if isCritical {
            label.text = "CRIT"
        } else {
            label.text = value > 0 ? "+\(value)" : "\(value)"
        }
        node.addChild(label)

        return node
    }

    private func faceColor(value: Int, isCritical: Bool) -> SKColor {
        if isCritical { return SKColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1) }
        if value > 0 { return SKColor(red: 0.20, green: 0.62, blue: 0.30, alpha: 1) }
        if value < 0 { return SKColor(red: 0.90, green: 0.35, blue: 0.35, alpha: 1) }
        return SKColor(red: 0.90, green: 0.75, blue: 0.25, alpha: 1)
    }
}
