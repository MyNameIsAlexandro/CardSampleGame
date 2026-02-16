/// Файл: Views/Combat/FateRevealDirector.swift
/// Назначение: Режиссёр анимации раскрытия Fate-карты — полная драматическая последовательность.
/// Зона ответственности: Animation state machine, event-driven (без хранения ссылки на Simulation).
/// Контекст: Phase 3 Ritual Combat (R6). Epic 3 — Full Drama Sequence.

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

// MARK: - Reveal Tempo

/// Drama tempo — controls total sequence duration.
enum RevealTempo {
    case major  // 2.5s — attacks, influences, critical moments
    case minor  // 1.5s — minor effects

    var scale: TimeInterval {
        switch self {
        case .major: return 1.0
        case .minor: return 0.6
        }
    }
}

// MARK: - Reveal Data

/// Stored parameters for the current reveal sequence.
private struct RevealData {
    let cardName: String
    let effectiveValue: Int
    let isSuitMatch: Bool
    let isCritical: Bool
    let tempo: RevealTempo
    let targetPosition: CGPoint?
    let damageValue: Int?
    let keyword: String?
}

// MARK: - Fate Reveal Director

/// Directs the fate card reveal animation sequence with full drama.
/// Event-driven: receives fate draw results via method calls, not stored simulation reference.
/// This preserves determinism — the director is a pure presentation observer.
///
/// Sequence (major tempo, ~2.5s):
///   1. Screen dims (0.4s) + card back scales in
///   2. Card flips (0.3s) with edge darkening
///   3. Value punches (0.2s) — scale 0.5→1.3→1.0
///   4. Suit match flash (0.3s) — gold outline pulse (if applicable)
///   5. Keyword label fade in (0.15s) — shows below card (if applicable)
///   6. Damage number arcs to target (0.4s) — if target position provided
///   7. Card + overlay fade out (0.2s)
@MainActor
final class FateRevealDirector {

    // MARK: - State

    private(set) var phase: FateRevealPhase = .idle
    private var pendingReveal: RevealData?

    // MARK: - Scene Attachment

    weak var parentNode: SKNode?
    private var cardNode: SKNode?
    private var dimOverlay: SKShapeNode?

    // MARK: - Callbacks

    var onRevealComplete: (() -> Void)?
    var onSoundEffect: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?

    // MARK: - Base Timing (scaled by tempo)

    private let baseAnticipation: TimeInterval = 0.4
    private let baseFlip: TimeInterval = 0.3
    private let basePunch: TimeInterval = 0.2
    private let baseSuitMatch: TimeInterval = 0.3
    private let baseKeyword: TimeInterval = 0.15
    private let baseDamageFly: TimeInterval = 0.4
    private let baseHold: TimeInterval = 0.3
    private let baseFadeOut: TimeInterval = 0.2

    // MARK: - Card Constants

    private let cardSize = CGSize(width: 70, height: 98)
    private let cornerRadius: CGFloat = 8

    // MARK: - Public API

    func attach(to node: SKNode) {
        parentNode = node
    }

    /// Begin a fate reveal animation with full drama parameters.
    func beginReveal(
        cardName: String,
        effectiveValue: Int,
        isSuitMatch: Bool,
        isCritical: Bool,
        tempo: RevealTempo = .major,
        targetPosition: CGPoint? = nil,
        damageValue: Int? = nil,
        keyword: String? = nil
    ) {
        reset()
        let data = RevealData(
            cardName: cardName,
            effectiveValue: effectiveValue,
            isSuitMatch: isSuitMatch,
            isCritical: isCritical,
            tempo: tempo,
            targetPosition: targetPosition,
            damageValue: damageValue,
            keyword: keyword
        )
        pendingReveal = data
        phase = .anticipation

        guard let parent = parentNode else {
            completeSequence()
            return
        }

        runAnticipation(in: parent, data: data)
    }

    func reset() {
        cardNode?.removeAllActions()
        cardNode?.removeFromParent()
        cardNode = nil
        dimOverlay?.removeAllActions()
        dimOverlay?.removeFromParent()
        dimOverlay = nil
        pendingReveal = nil
        phase = .idle
    }

    // MARK: - Phase 1: Anticipation (screen dim + card back)

    private func runAnticipation(in parent: SKNode, data: RevealData) {
        let t = data.tempo.scale

        let dim = SKShapeNode(rectOf: CGSize(width: 500, height: 800))
        dim.fillColor = SKColor(white: 0, alpha: 1)
        dim.strokeColor = .clear
        dim.alpha = 0
        dim.zPosition = 45
        parent.addChild(dim)
        dimOverlay = dim

        let dimIn = SKAction.fadeAlpha(to: 0.4, duration: baseAnticipation * t)
        dim.run(dimIn)

        let container = SKNode()
        container.zPosition = 50
        parent.addChild(container)
        cardNode = container

        let back = makeCardBack()
        back.name = "fate_back"
        container.addChild(back)

        container.setScale(0)
        let scaleUp = SKAction.scale(to: 1.0, duration: baseAnticipation * t)
        scaleUp.timingMode = .easeOut

        container.run(scaleUp) { [weak self] in
            self?.runFlip(data: data)
        }
    }

    // MARK: - Phase 2: Flip (collapse back → expand face)

    private func runFlip(data: RevealData) {
        phase = .flip
        guard let container = cardNode else { return completeSequence() }
        let t = data.tempo.scale

        onSoundEffect?(data.isCritical ? "fateCritical" : "fateReveal")
        if data.isCritical { onHaptic?("heavy") } else { onHaptic?("medium") }

        let back = container.childNode(withName: "fate_back")
        let halfFlip = baseFlip * t / 2

        let collapseBack = SKAction.scaleX(to: 0, duration: halfFlip)
        collapseBack.timingMode = .easeIn

        let face = makeCardFace(value: data.effectiveValue, isCritical: data.isCritical)
        face.name = "fate_face"
        face.xScale = 0
        container.addChild(face)

        let expandFace = SKAction.scaleX(to: 1.0, duration: halfFlip)
        expandFace.timingMode = .easeOut

        back?.run(collapseBack)
        face.run(SKAction.sequence([
            SKAction.wait(forDuration: halfFlip),
            expandFace
        ])) { [weak self] in
            back?.removeFromParent()
            self?.runValuePunch(data: data)
        }
    }

    // MARK: - Phase 2b: Value Punch (scale 0.5→1.3→1.0)

    private func runValuePunch(data: RevealData) {
        guard let container = cardNode else { return completeSequence() }
        let t = data.tempo.scale

        let face = container.childNode(withName: "fate_face")
        let valueLabel = face?.childNode(withName: "fate_value") as? SKLabelNode

        valueLabel?.setScale(0.5)
        let punchUp = SKAction.scale(to: 1.3, duration: basePunch * t * 0.5)
        punchUp.timingMode = .easeOut
        let punchDown = SKAction.scale(to: 1.0, duration: basePunch * t * 0.5)
        punchDown.timingMode = .easeIn

        valueLabel?.run(SKAction.sequence([punchUp, punchDown])) { [weak self] in
            if data.isSuitMatch {
                self?.runSuitMatch(data: data)
            } else if data.keyword != nil {
                self?.runKeywordEffect(data: data)
            } else {
                self?.runDamageFlyOrHold(data: data)
            }
        }
    }

    // MARK: - Phase 3: Suit Match Flash

    private func runSuitMatch(data: RevealData) {
        phase = .suitMatch
        guard let container = cardNode else { return completeSequence() }
        let t = data.tempo.scale

        let flash = SKShapeNode(rectOf: CGSize(width: cardSize.width + 8, height: cardSize.height + 8),
                                cornerRadius: cornerRadius + 2)
        flash.fillColor = .clear
        flash.strokeColor = SKColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1)
        flash.lineWidth = 3
        flash.glowWidth = 6
        flash.alpha = 0
        flash.zPosition = -1
        container.addChild(flash)

        onHaptic?("medium")

        let flashIn = SKAction.fadeAlpha(to: 1.0, duration: baseSuitMatch * t * 0.4)
        let flashOut = SKAction.fadeAlpha(to: 0.0, duration: baseSuitMatch * t * 0.6)

        flash.run(SKAction.sequence([flashIn, flashOut, SKAction.removeFromParent()])) { [weak self] in
            if data.keyword != nil {
                self?.runKeywordEffect(data: data)
            } else {
                self?.runDamageFlyOrHold(data: data)
            }
        }
    }

    // MARK: - Phase 4: Keyword Effect

    private func runKeywordEffect(data: RevealData) {
        phase = .keywordEffect
        guard let container = cardNode, let keyword = data.keyword else {
            runDamageFlyOrHold(data: data)
            return
        }
        let t = data.tempo.scale

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = keyword
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1)
        label.verticalAlignmentMode = .top
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -cardSize.height / 2 - 8)
        label.alpha = 0
        container.addChild(label)

        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: baseKeyword * t)
        label.run(fadeIn) { [weak self] in
            self?.runDamageFlyOrHold(data: data)
        }
    }

    // MARK: - Phase 5: Damage Fly or Hold

    private func runDamageFlyOrHold(data: RevealData) {
        if let targetPos = data.targetPosition, let damage = data.damageValue, damage > 0 {
            runDamageFly(to: targetPos, damage: damage, data: data)
        } else {
            runHoldAndFadeOut(data: data)
        }
    }

    private func runDamageFly(to target: CGPoint, damage: Int, data: RevealData) {
        guard let parent = parentNode else { return runHoldAndFadeOut(data: data) }
        let t = data.tempo.scale

        let dmgLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        dmgLabel.text = "-\(damage)"
        dmgLabel.fontSize = 20
        dmgLabel.fontColor = SKColor(red: 0.95, green: 0.30, blue: 0.25, alpha: 1)
        dmgLabel.verticalAlignmentMode = .center
        dmgLabel.horizontalAlignmentMode = .center
        dmgLabel.position = cardNode?.position ?? .zero
        dmgLabel.zPosition = 55
        parent.addChild(dmgLabel)

        let midX = (dmgLabel.position.x + target.x) / 2
        let midY = max(dmgLabel.position.y, target.y) + 40

        let path = CGMutablePath()
        path.move(to: dmgLabel.position)
        path.addQuadCurve(to: target, control: CGPoint(x: midX, y: midY))

        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: baseDamageFly * t)
        fly.timingMode = .easeIn
        let fade = SKAction.fadeAlpha(to: 0.3, duration: baseDamageFly * t)

        dmgLabel.run(SKAction.group([fly, fade])) {
            dmgLabel.removeFromParent()
        }

        let wait = SKAction.wait(forDuration: baseDamageFly * t * 0.5)
        cardNode?.run(wait) { [weak self] in
            self?.runHoldAndFadeOut(data: data)
        }
    }

    // MARK: - Phase 6: Hold + Fade Out

    private func runHoldAndFadeOut(data: RevealData) {
        phase = .complete
        guard let container = cardNode else { return completeSequence() }
        let t = data.tempo.scale

        container.run(SKAction.wait(forDuration: baseHold * t)) { [weak self] in
            self?.runFadeOut(tempo: t)
        }
    }

    private func runFadeOut(tempo t: TimeInterval) {
        guard let container = cardNode else { return completeSequence() }

        let cardFade = SKAction.fadeOut(withDuration: baseFadeOut * t)
        let dimFade = SKAction.fadeOut(withDuration: baseFadeOut * t)

        dimOverlay?.run(SKAction.sequence([dimFade, SKAction.removeFromParent()]))
        dimOverlay = nil

        container.run(SKAction.sequence([cardFade, SKAction.removeFromParent()])) { [weak self] in
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
        label.name = "fate_value"
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
