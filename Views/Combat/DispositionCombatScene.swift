/// Файл: Views/Combat/DispositionCombatScene.swift
/// Назначение: SpriteKit-сцена Disposition Combat — core lifecycle, configure, syncVisuals.
/// Зона ответственности: Properties, card rendering, visual sync. Layout в +Layout, loop в +GameLoop.
/// Контекст: Phase 3 Disposition Combat. Scene uses DispositionCombatViewModel (не simulation напрямую).

import SpriteKit
import TwilightEngine

/// Disposition Combat scene — portrait 390×700 single-track duel.
/// All game logic delegated to `DispositionCombatViewModel`. No direct simulation access.
///
/// Split into extensions:
///   - `DispositionCombatScene+Layout.swift` — node creation and positioning
///   - `DispositionCombatScene+GameLoop.swift` — input, phases, result emission
final class DispositionCombatScene: SKScene {

    // MARK: - Configuration

    static let sceneSize = CGSize(width: 390, height: 700)

    // MARK: - ViewModel

    private(set) var viewModel: DispositionCombatViewModel?

    // MARK: - Callbacks

    var onCombatEnd: ((DispositionCombatResult) -> Void)?
    var onSoundEffect: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?

    // MARK: - Node References

    var idolNode: IdolNode?
    var dispositionBar: SKShapeNode?
    var dispositionFill: SKShapeNode?
    var dispositionLabel: SKLabelNode?
    var strikeZone: SKShapeNode?
    var influenceZone: SKShapeNode?
    var sacrificeZone: SKShapeNode?
    var endTurnButton: SKShapeNode?
    var handCardNodes: [String: SKNode] = [:]

    // MARK: - Layers

    var combatLayer: SKNode?
    var handLayer: SKNode?
    var overlayLayer: SKNode?

    // MARK: - Input State

    var inputEnabled: Bool = false
    var draggedCardId: String?
    var dragStartLocation: CGPoint?
    var originalCardPositions: [String: CGPoint] = [:]
    var originalCardRotations: [String: CGFloat] = [:]

    // MARK: - Enemy AI State

    var enemyModeState: EnemyModeState?

    // MARK: - Phase

    enum CombatPhase {
        case playerAction
        case enemyResolution
        case finished
    }

    var phase: CombatPhase = .playerAction

    // MARK: - Configure

    func configure(with simulation: DispositionCombatSimulation) {
        let vm = DispositionCombatViewModel(simulation: simulation)
        self.viewModel = vm
        self.scaleMode = .aspectFill
        self.backgroundColor = SKColor(red: 0.06, green: 0.05, blue: 0.09, alpha: 1)
        self.enemyModeState = EnemyModeState(seed: simulation.seed)

        buildLayout()
        syncVisuals(animated: false)
        beginPlayerPhase()
    }

    // MARK: - Sync Visuals

    func syncVisuals(animated: Bool = true) {
        guard let vm = viewModel else { return }

        updateDispositionBar(disposition: vm.disposition, animated: animated)
        updateIdolMode()
        updateEnergyLabel()
        updateStreakLabel()
        rebuildHandCards()
        dimUnplayableCards()
        updateActionZoneVisibility()
    }

    // MARK: - Disposition Bar

    func updateDispositionBar(disposition: Int, animated: Bool) {
        guard let fill = dispositionFill else { return }

        let barWidth: CGFloat = 300
        let fraction = CGFloat(disposition + 100) / 200.0
        let fillWidth = max(4, barWidth * fraction)

        let color: SKColor
        if disposition < -50 {
            color = SKColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1)
        } else if disposition < -20 {
            color = SKColor(red: 0.90, green: 0.50, blue: 0.20, alpha: 1)
        } else if disposition < 20 {
            color = SKColor(red: 0.80, green: 0.80, blue: 0.30, alpha: 1)
        } else if disposition < 50 {
            color = SKColor(red: 0.40, green: 0.75, blue: 0.40, alpha: 1)
        } else {
            color = SKColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 1)
        }

        if animated {
            let resize = SKAction.resize(toWidth: fillWidth, duration: 0.3)
            resize.timingMode = .easeOut
            fill.run(resize)
            let colorize = SKAction.customAction(withDuration: 0.3) { node, _ in
                (node as? SKShapeNode)?.fillColor = color
            }
            fill.run(colorize)
        } else {
            let rect = CGRect(x: -barWidth / 2, y: -8, width: fillWidth, height: 16)
            fill.path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            fill.fillColor = color
        }

        dispositionLabel?.text = "\(disposition)"
    }

    // MARK: - Enemy Mode

    func updateIdolMode() {
        guard let vm = viewModel, let idol = idolNode, var modeState = enemyModeState else { return }

        let newMode = modeState.evaluateMode(disposition: vm.disposition)
        enemyModeState = modeState

        let aura: IdolModeAura
        switch newMode {
        case .normal: aura = .normal
        case .survival: aura = .survival
        case .desperation: aura = .desperation
        case .weakened: aura = .weakened
        }

        if idol.currentModeAura != aura {
            idol.playModeTransition(to: aura)
            onHaptic?("medium")
        }
    }

    // MARK: - Energy Label

    func updateEnergyLabel() {
        guard let vm = viewModel,
              let label = childNode(withName: "energyLabel") as? SKLabelNode else { return }
        label.text = "⚡ \(vm.energy)/\(vm.simulation.startingEnergy)"
    }

    // MARK: - Streak Label

    func updateStreakLabel() {
        guard let vm = viewModel,
              let label = childNode(withName: "streakLabel") as? SKLabelNode else { return }
        if let streakType = vm.streakType, vm.streakCount > 1 {
            let icon = streakType == .strike ? "⚔" : (streakType == .influence ? "☽" : "♦")
            label.text = "\(icon)×\(vm.streakCount)"
            label.alpha = 1
        } else {
            label.alpha = 0
        }
    }

    // MARK: - Hand Cards

    func rebuildHandCards() {
        guard let vm = viewModel else { return }
        let layer = handLayer ?? self

        handCardNodes.values.forEach { $0.removeFromParent() }
        handCardNodes.removeAll()
        originalCardPositions.removeAll()
        originalCardRotations.removeAll()

        let cards = vm.hand
        guard !cards.isEmpty else { return }

        let cardSize = RitualTheme.cardSize
        let scaleFactor = cards.count > RitualTheme.scaleThreshold
            ? min(1.0, CGFloat(RitualTheme.scaleThreshold) / CGFloat(cards.count))
            : 1.0
        let centerX = DispositionCombatScene.sceneSize.width / 2
        let baseY: CGFloat = 85
        let centerIndex = CGFloat(cards.count - 1) / 2.0
        let overlapSpacing = min(
            RitualTheme.baseOverlapSpacing,
            (DispositionCombatScene.sceneSize.width - 40) / CGFloat(cards.count)
        )

        for (i, card) in cards.enumerated() {
            let offset = CGFloat(i) - centerIndex
            let angle = offset * RitualTheme.fanAngleStep
            let yOffset = -abs(offset) * RitualTheme.arcYDropPerUnit

            let position = CGPoint(
                x: centerX + offset * overlapSpacing,
                y: baseY + yOffset
            )
            let rotation = -angle * .pi / 180

            let node = makeCardNode(card: card)
            node.position = position
            node.zRotation = rotation
            node.zPosition = CGFloat(20 + i)
            node.setScale(scaleFactor)
            node.name = "card_\(card.id)"
            layer.addChild(node)
            handCardNodes[card.id] = node
            originalCardPositions[card.id] = position
            originalCardRotations[card.id] = rotation

            addCardSway(to: node, index: i)
        }
    }

    private func addCardSway(to node: SKNode, index: Int) {
        let amp = RitualTheme.swayAmplitude
        let dur = RitualTheme.swayCycleDuration
        let stagger = RitualTheme.swayStagger * Double(index)

        let sway = SKAction.sequence([
            SKAction.wait(forDuration: stagger),
            SKAction.repeatForever(SKAction.sequence([
                SKAction.rotate(byAngle: amp, duration: dur / 2),
                SKAction.rotate(byAngle: -amp * 2, duration: dur),
                SKAction.rotate(byAngle: amp, duration: dur / 2)
            ]))
        ])
        node.run(sway, withKey: "cardSway")
    }

    func makeCardNode(card: Card) -> SKNode {
        let size = RitualTheme.cardSize
        let container = SKNode()

        let bg = SKShapeNode(rectOf: size, cornerRadius: 8)
        bg.fillColor = SKColor(red: 0.12, green: 0.10, blue: 0.16, alpha: 1)
        bg.strokeColor = SKColor(red: 0.35, green: 0.30, blue: 0.40, alpha: 1)
        bg.lineWidth = 1.5
        container.addChild(bg)

        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLabel.text = String(card.name.prefix(10))
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -2)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        container.addChild(nameLabel)

        if let power = card.power, power > 0 {
            let powerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            powerLabel.text = "\(power)"
            powerLabel.fontSize = 14
            powerLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1)
            powerLabel.position = CGPoint(x: -size.width / 2 + 14, y: size.height / 2 - 14)
            powerLabel.verticalAlignmentMode = .center
            container.addChild(powerLabel)
        }

        if let cost = card.cost, cost > 0 {
            let costLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            costLabel.text = "◉\(cost)"
            costLabel.fontSize = 10
            costLabel.fontColor = SKColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1)
            costLabel.position = CGPoint(x: size.width / 2 - 16, y: size.height / 2 - 14)
            costLabel.verticalAlignmentMode = .center
            container.addChild(costLabel)
        }

        return container
    }

    func dimUnplayableCards() {
        guard let vm = viewModel else { return }
        for (cardId, node) in handCardNodes {
            guard let card = vm.hand.first(where: { $0.id == cardId }) else { continue }
            let cost = card.cost ?? 1
            node.alpha = cost <= vm.energy ? 1.0 : 0.4
        }
    }

    // MARK: - Action Zone Visibility

    func updateActionZoneVisibility() {
        guard let vm = viewModel else { return }
        let hasEnergy = vm.energy > 0
        let hasCards = !vm.hand.isEmpty
        let combatActive = vm.outcome == nil

        strikeZone?.alpha = (hasEnergy && hasCards && combatActive) ? 1.0 : 0.3
        influenceZone?.alpha = (hasEnergy && hasCards && combatActive) ? 1.0 : 0.3
        sacrificeZone?.alpha = (hasEnergy && hasCards && combatActive
            && !vm.simulation.sacrificeUsedThisTurn) ? 1.0 : 0.3
        endTurnButton?.alpha = combatActive ? 1.0 : 0.3
    }
}
