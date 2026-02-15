/// Файл: Views/Combat/IdolNode.swift
/// Назначение: Визуальный узел вражеского идола — HP-зарубки, WP-руны, intent, kill/pacify FX.
/// Зона ответственности: Presentation-only — дигетическое представление врага. Без доменной логики.
/// Контекст: Phase 3 Ritual Combat (R4). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import SpriteKit

// MARK: - Idol Visual State

/// Visual state of an enemy idol.
enum IdolVisualState: Equatable {
    case idle
    case intentShown
    case damaged
    case killed
    case pacified
    case hoverTarget
}

// MARK: - Idol Node

/// Diegetic enemy idol with carved HP notches, glowing WP runes, and intent tokens.
/// Pure visual node — state set via method calls, no stored simulation reference.
///
/// Usage:
///   1. Init with `enemyId`
///   2. `configure(name:maxHP:maxWP:)` to set up visual layers
///   3. `updateHP/updateWP/showIntent` to sync with combat state
///   4. `playKillAnimation/playPacifyAnimation` for resolution FX
final class IdolNode: SKNode {

    // MARK: - Constants

    static let frameSize = CGSize(width: 70, height: 100)
    private let notchSize = CGSize(width: 2, height: 12)
    private let runeSize: CGFloat = 12

    // MARK: - Identity

    let enemyId: String
    private(set) var visualState: IdolVisualState = .idle

    // MARK: - Child Nodes

    private let frameNode: SKShapeNode
    private let nameLabel: SKLabelNode
    private var hpNotches: [SKShapeNode] = []
    private var wpRunes: [SKShapeNode] = []
    private var intentToken: SKNode?
    private var hoverOutline: SKShapeNode?

    // MARK: - Init

    init(enemyId: String) {
        self.enemyId = enemyId

        let frame = SKShapeNode(rectOf: IdolNode.frameSize, cornerRadius: 8)
        frame.fillColor = SKColor(red: 0.18, green: 0.14, blue: 0.22, alpha: 1)
        frame.strokeColor = SKColor(red: 0.50, green: 0.45, blue: 0.55, alpha: 1)
        frame.lineWidth = 1.5
        self.frameNode = frame

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.fontSize = 11
        label.fontColor = SKColor(red: 0.75, green: 0.70, blue: 0.80, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 20)
        self.nameLabel = label

        super.init()

        addChild(frameNode)
        addChild(nameLabel)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Configuration

    /// Set up idol visual layers from combat data.
    func configure(name: String, maxHP: Int, maxWP: Int?) {
        nameLabel.text = name
        setupHPNotches(max: maxHP)
        if let wp = maxWP, wp > 0 {
            setupWPRunes(max: wp)
        }
    }

    // MARK: - HP Notches

    private func setupHPNotches(max: Int) {
        hpNotches.forEach { $0.removeFromParent() }
        hpNotches.removeAll()

        let totalWidth = CGFloat(max) * (notchSize.width + 3) - 3
        let startX = -totalWidth / 2 + notchSize.width / 2
        let y: CGFloat = -35

        for i in 0..<max {
            let notch = SKShapeNode(rectOf: notchSize, cornerRadius: 1)
            notch.fillColor = SKColor(red: 0.75, green: 0.70, blue: 0.65, alpha: 1)
            notch.strokeColor = .clear
            notch.position = CGPoint(x: startX + CGFloat(i) * (notchSize.width + 3), y: y)
            addChild(notch)
            hpNotches.append(notch)
        }
    }

    /// Update HP notches visually.
    func updateHP(current: Int, max: Int, animated: Bool) {
        if hpNotches.count != max {
            setupHPNotches(max: max)
        }

        let filledColor = SKColor(red: 0.75, green: 0.70, blue: 0.65, alpha: 1)
        let emptyColor = SKColor(red: 0.25, green: 0.20, blue: 0.20, alpha: 1)

        for (i, notch) in hpNotches.enumerated() {
            let isFilled = i < current
            let targetColor = isFilled ? filledColor : emptyColor
            notch.fillColor = targetColor
        }

        if animated && visualState != .killed {
            visualState = .damaged
            playDamageShake()
        }
    }

    // MARK: - WP Runes

    private func setupWPRunes(max: Int) {
        wpRunes.forEach { $0.removeFromParent() }
        wpRunes.removeAll()

        let spacing: CGFloat = runeSize + 4
        let totalWidth = CGFloat(max) * spacing - 4
        let startX = -totalWidth / 2 + runeSize / 2
        let y: CGFloat = 0

        for i in 0..<max {
            let rune = makeDiamondRune()
            rune.position = CGPoint(x: startX + CGFloat(i) * spacing, y: y)
            addChild(rune)
            wpRunes.append(rune)
        }
    }

    /// Update WP rune visuals — fade right-to-left on WP loss.
    func updateWP(current: Int, max: Int, animated: Bool) {
        if wpRunes.count != max {
            setupWPRunes(max: max)
        }

        let activeColor = SKColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1)
        let fadedColor = SKColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 1)

        for (i, rune) in wpRunes.enumerated() {
            let isActive = i < current
            if animated && !isActive && rune.fillColor != fadedColor {
                let delay = SKAction.wait(forDuration: Double(wpRunes.count - 1 - i) * 0.05)
                let fade = SKAction.run { rune.fillColor = fadedColor; rune.alpha = 0.4 }
                rune.run(SKAction.sequence([delay, fade]))
            } else {
                rune.fillColor = isActive ? activeColor : fadedColor
                rune.alpha = isActive ? 1.0 : 0.4
            }
        }
    }

    private func makeDiamondRune() -> SKShapeNode {
        let half = runeSize / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: half))
        path.addLine(to: CGPoint(x: half, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -half))
        path.addLine(to: CGPoint(x: -half, y: 0))
        path.closeSubpath()

        let rune = SKShapeNode(path: path)
        rune.fillColor = SKColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1)
        rune.strokeColor = .clear
        rune.glowWidth = 2
        return rune
    }

    // MARK: - Intent Token

    /// Show intent indicator above the idol.
    func showIntent(type: String, value: Int) {
        hideIntent()
        visualState = .intentShown

        let token = SKNode()
        token.position = CGPoint(x: 0, y: IdolNode.frameSize.height / 2 + 18)

        let bg = SKShapeNode(rectOf: CGSize(width: 40, height: 22), cornerRadius: 6)
        bg.fillColor = SKColor(red: 0.90, green: 0.35, blue: 0.35, alpha: 0.85)
        bg.strokeColor = .clear
        token.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.text = "\(type) \(value)"
        token.addChild(label)

        token.setScale(0)
        addChild(token)
        intentToken = token

        let dropIn = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.2),
            SKAction.fadeIn(withDuration: 0.2)
        ])
        dropIn.timingMode = .easeOut
        token.run(dropIn)
    }

    /// Hide the intent token.
    func hideIntent() {
        guard let token = intentToken else { return }
        token.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
        intentToken = nil
        if visualState == .intentShown { visualState = .idle }
    }

    // MARK: - Kill Animation

    /// Crack + split + dust animation for defeated enemy.
    func playKillAnimation(completion: @escaping () -> Void) {
        visualState = .killed

        let leftHalf = SKNode()
        let rightHalf = SKNode()
        leftHalf.position = .zero
        rightHalf.position = .zero

        let leftClip = frameNode.copy() as! SKShapeNode
        let rightClip = frameNode.copy() as! SKShapeNode
        leftHalf.addChild(leftClip)
        rightHalf.addChild(rightClip)

        frameNode.alpha = 0
        nameLabel.alpha = 0
        hpNotches.forEach { $0.alpha = 0 }
        wpRunes.forEach { $0.alpha = 0 }
        hideIntent()

        addChild(leftHalf)
        addChild(rightHalf)

        let duration: TimeInterval = 0.5
        let leftSplit = SKAction.group([
            SKAction.rotate(byAngle: -.pi / 12, duration: duration),
            SKAction.moveBy(x: -15, y: -30, duration: duration),
            SKAction.fadeOut(withDuration: duration)
        ])
        let rightSplit = SKAction.group([
            SKAction.rotate(byAngle: .pi / 12, duration: duration),
            SKAction.moveBy(x: 15, y: -30, duration: duration),
            SKAction.fadeOut(withDuration: duration)
        ])

        addDustParticles()

        leftHalf.run(SKAction.sequence([leftSplit, SKAction.removeFromParent()]))
        rightHalf.run(SKAction.sequence([rightSplit, SKAction.removeFromParent()])) {
            completion()
        }
    }

    // MARK: - Pacify Animation

    /// Bow + glow fade animation for pacified enemy.
    func playPacifyAnimation(completion: @escaping () -> Void) {
        visualState = .pacified

        hideIntent()
        let duration: TimeInterval = 0.4

        let bow = SKAction.rotate(toAngle: -.pi / 18, duration: duration)
        bow.timingMode = .easeInEaseOut
        let fade = SKAction.fadeAlpha(to: 0.3, duration: duration * 1.5)

        frameNode.run(bow)
        run(SKAction.sequence([fade, SKAction.wait(forDuration: 0.1)])) {
            completion()
        }
    }

    // MARK: - Hover Target

    /// Toggle gold outline for drag-over targeting.
    func setHoverTarget(_ hovering: Bool) {
        if hovering {
            if hoverOutline == nil {
                let outline = SKShapeNode(rectOf: CGSize(
                    width: IdolNode.frameSize.width + 8,
                    height: IdolNode.frameSize.height + 8
                ), cornerRadius: 10)
                outline.fillColor = .clear
                outline.strokeColor = SKColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1)
                outline.lineWidth = 2
                outline.zPosition = -1
                addChild(outline)
                hoverOutline = outline
            }
            if visualState == .idle { visualState = .hoverTarget }
        } else {
            hoverOutline?.removeFromParent()
            hoverOutline = nil
            if visualState == .hoverTarget { visualState = .idle }
        }
    }

    // MARK: - Damage Shake

    private func playDamageShake() {
        let dx: CGFloat = 6
        let shake = SKAction.sequence([
            SKAction.moveBy(x: dx, y: 0, duration: 0.04),
            SKAction.moveBy(x: -dx * 2, y: 0, duration: 0.04),
            SKAction.moveBy(x: dx * 2, y: 0, duration: 0.04),
            SKAction.moveBy(x: -dx * 2, y: 0, duration: 0.04),
            SKAction.moveBy(x: dx * 2, y: 0, duration: 0.04),
            SKAction.moveBy(x: -dx, y: 0, duration: 0.04)
        ])
        frameNode.run(shake)

        hpNotches.forEach { notch in
            let flash = SKAction.sequence([
                SKAction.run { notch.fillColor = SKColor(red: 0.90, green: 0.35, blue: 0.35, alpha: 1) },
                SKAction.wait(forDuration: 0.1),
                SKAction.run { [weak self] in
                    guard let self else { return }
                    let idx = self.hpNotches.firstIndex(of: notch) ?? 0
                    let isFilled = idx < (self.hpNotches.count)
                    notch.fillColor = isFilled
                        ? SKColor(red: 0.75, green: 0.70, blue: 0.65, alpha: 1)
                        : SKColor(red: 0.25, green: 0.20, blue: 0.20, alpha: 1)
                }
            ])
            notch.run(flash)
        }
    }

    // MARK: - Dust Particles

    private func addDustParticles() {
        let e = SKEmitterNode()
        e.particleBirthRate = 30
        e.numParticlesToEmit = 20
        e.particleLifetime = 0.8
        e.particleLifetimeRange = 0.3
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 25
        e.particleSpeedRange = 15
        e.particleAlpha = 0.6
        e.particleAlphaSpeed = -0.6
        e.particleScale = 0.03
        e.particleScaleRange = 0.02
        e.particleColor = SKColor(red: 0.55, green: 0.50, blue: 0.45, alpha: 1)
        e.particleColorBlendFactor = 1.0
        e.particleBlendMode = .alpha
        e.position = .zero
        e.zPosition = 2
        addChild(e)

        e.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Layout Helper

    /// Compute positions for multiple idols in a row.
    /// - Parameter count: Number of enemies (1–3)
    /// - Returns: Array of positions (centered around origin)
    static func layoutPositions(count: Int) -> [CGPoint] {
        switch count {
        case 1:
            return [.zero]
        case 2:
            return [CGPoint(x: -60, y: 0), CGPoint(x: 60, y: 0)]
        case 3:
            return [CGPoint(x: -75, y: 0), .zero, CGPoint(x: 75, y: 0)]
        default:
            return (0..<count).map { i in
                let spacing: CGFloat = 80
                let totalWidth = CGFloat(count - 1) * spacing
                return CGPoint(x: -totalWidth / 2 + CGFloat(i) * spacing, y: 0)
            }
        }
    }
}
