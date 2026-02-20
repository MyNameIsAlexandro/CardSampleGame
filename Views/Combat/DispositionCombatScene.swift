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

    // Enemy intent display (between idol and disposition bar)
    var intentLabel: SKLabelNode?
    // Momentum aura behind hand
    var momentumAuraNode: SKShapeNode?

    // HUD nodes
    var enemyModifierStrip: SKNode?
    var heroModifierStrip: SKNode?
    var prevHeroHP: Int?
    var prevEnergy: Int?

    // MARK: - Layers

    var combatLayer: SKNode?
    var handLayer: SKNode?
    var overlayLayer: SKNode?

    // MARK: - Input State

    var inputEnabled: Bool = false
    var draggedCardId: String?
    var dragStartLocation: CGPoint?
    var isDragging: Bool = false
    var selectedCardId: String?
    var cardPreviewNode: SKNode?
    var originalCardPositions: [String: CGPoint] = [:]
    var originalCardRotations: [String: CGFloat] = [:]
    var originalCardZPositions: [String: CGFloat] = [:]
    var originalCardScales: [String: CGFloat] = [:]

    /// Minimum distance to start drag (prevents accidental plays).
    static let dragThreshold: CGFloat = 20

    // MARK: - Enemy AI State

    var enemyModeState: EnemyModeState?

    // Stored enemy intent for Slay the Spire-style telegraph
    var pendingEnemyAction: EnemyAction?

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
        self.backgroundColor = resonanceBackgroundColor(for: simulation.resonanceZone)
        self.enemyModeState = EnemyModeState(seed: simulation.seed)

        buildLayout()
        syncVisuals(animated: false)
        beginPlayerPhase()
    }

    // MARK: - Sync Visuals

    func syncVisuals(animated: Bool = true) {
        guard let vm = viewModel else { return }

        updateDispositionBar(disposition: vm.disposition, animated: animated)
        updateEnergyLabel()
        updateStreakLabel()
        rebuildHandCards()
        dimUnplayableCards()
        updateActionZoneVisibility()
        updateMomentumAura()
        updateHUDValues()
        syncModifierBadges()
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

        let bonus = DispositionCalculator.survivalStrikeBonus(
            mode: newMode, actionType: .strike
        )
        vm.setEnemyModeStrikeBonus(bonus)
    }

    // MARK: - Energy Label

    func updateEnergyLabel() {
        guard let vm = viewModel,
              let label = childNode(withName: "energyLabel") as? SKLabelNode else { return }
        let newEnergy = vm.energy
        label.text = "⚡ \(newEnergy)/\(vm.simulation.startingEnergy)"

        if let prev = prevEnergy, prev != newEnergy {
            let originalColor = label.fontColor
            label.fontColor = .white
            label.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1),
                SKAction.run { [weak label] in label?.fontColor = originalColor }
            ]))
        }
        prevEnergy = newEnergy
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
        let cards = vm.hand

        // Remove nodes for cards no longer in hand
        let currentCardIds = Set(cards.map(\.id))
        for (cardId, node) in handCardNodes where !currentCardIds.contains(cardId) {
            node.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.scale(to: 0.5, duration: 0.2)
                ]),
                SKAction.removeFromParent()
            ]))
            handCardNodes.removeValue(forKey: cardId)
            originalCardPositions.removeValue(forKey: cardId)
            originalCardRotations.removeValue(forKey: cardId)
            originalCardZPositions.removeValue(forKey: cardId)
            originalCardScales.removeValue(forKey: cardId)
        }

        guard !cards.isEmpty else { return }

        let scaleFactor = cards.count > RitualTheme.scaleThreshold
            ? min(1.0, CGFloat(RitualTheme.scaleThreshold) / CGFloat(cards.count))
            : 1.0
        let centerX = DispositionCombatScene.sceneSize.width / 2
        let baseY: CGFloat = 105
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

            if let existingNode = handCardNodes[card.id] {
                // Animate existing card to its new position
                existingNode.removeAction(forKey: "cardSway")
                let move = SKAction.move(to: position, duration: 0.25)
                move.timingMode = .easeOut
                let rotate = SKAction.rotate(toAngle: rotation, duration: 0.2)
                rotate.timingMode = .easeOut
                let rescale = SKAction.scale(to: scaleFactor, duration: 0.2)
                existingNode.run(SKAction.group([move, rotate, rescale])) { [weak self] in
                    self?.addCardSway(to: existingNode, index: i)
                }
                existingNode.zPosition = CGFloat(20 + i)
            } else {
                // Create new card node
                let node = makeCardNode(card: card)
                node.position = position
                node.zRotation = rotation
                node.zPosition = CGFloat(20 + i)
                node.setScale(scaleFactor)
                node.name = "card_\(card.id)"
                layer.addChild(node)
                handCardNodes[card.id] = node
                addCardSway(to: node, index: i)
            }

            originalCardPositions[card.id] = position
            originalCardRotations[card.id] = rotation
            originalCardZPositions[card.id] = CGFloat(20 + i)
            originalCardScales[card.id] = scaleFactor
        }
    }

    func addCardSway(to node: SKNode, index: Int) {
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

    // MARK: - Momentum Aura

    func updateMomentumAura() {
        guard let vm = viewModel, let aura = momentumAuraNode else { return }
        let count = vm.streakCount
        if count >= 2 {
            let intensity = min(CGFloat(count - 1) * 0.08, 0.25)
            let color: SKColor
            switch vm.streakType {
            case .strike: color = SKColor(red: 0.9, green: 0.3, blue: 0.2, alpha: intensity)
            case .influence: color = SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: intensity)
            default: color = SKColor(red: 0.6, green: 0.3, blue: 0.7, alpha: intensity)
            }
            aura.fillColor = color
            aura.alpha = 1
        } else {
            aura.alpha = 0
        }
    }

    // MARK: - Intent Display

    func showEnemyIntent(_ action: EnemyAction) {
        guard let label = intentLabel else { return }
        let (text, color) = intentDisplay(for: action)
        label.text = text
        label.fontColor = color
        label.alpha = 0
        label.run(SKAction.fadeIn(withDuration: 0.3))
    }

    func hideEnemyIntent() {
        intentLabel?.run(SKAction.fadeOut(withDuration: 0.2))
    }

    private func intentDisplay(for action: EnemyAction) -> (String, SKColor) {
        switch action {
        case .attack(let dmg):
            return (L10n.dispositionIntentAttack.localized(with: dmg), SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1))
        case .rage(let dmg):
            return (L10n.dispositionIntentRage.localized(with: dmg), SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1))
        case .defend(let val):
            return (L10n.dispositionIntentDefend.localized(with: val), SKColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1))
        case .provoke(let pen):
            return (L10n.dispositionIntentProvoke.localized(with: pen), SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1))
        case .adapt:
            return (L10n.dispositionIntentAdapt.localized, SKColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1))
        case .plea(let shift):
            return (L10n.dispositionIntentPlea.localized(with: shift), SKColor(red: 0.7, green: 0.4, blue: 0.9, alpha: 1))
        }
    }

    // MARK: - Modifier Badges

    func syncModifierBadges() {
        guard let vm = viewModel else { return }

        syncBadge(in: enemyModifierStrip, type: .defend, value: vm.defendReduction)
        syncBadge(in: enemyModifierStrip, type: .adapt, value: vm.adaptPenalty)
        syncBadge(in: enemyModifierStrip, type: .sacrificeBuff, value: vm.enemySacrificeBuff)
        layoutBadges(in: enemyModifierStrip, centered: true)

        syncBadge(in: heroModifierStrip, type: .provoke, value: vm.provokePenalty)
        syncBadge(in: heroModifierStrip, type: .plea, value: vm.pleaBacklash)
        layoutBadges(in: heroModifierStrip, centered: false)
    }

    private func syncBadge(
        in strip: SKNode?,
        type: ModifierBadgeNode.ModifierType,
        value: Int
    ) {
        guard let strip else { return }
        let existing = strip.childNode(withName: type.rawValue) as? ModifierBadgeNode

        if value > 0 {
            if let badge = existing {
                badge.updateValue(value)
            } else {
                let badge = ModifierBadgeNode.make(type: type, value: value)
                strip.addChild(badge)
                badge.animateAppear()
            }
        } else if let badge = existing {
            badge.animateDisappear {
                badge.removeFromParent()
            }
        }
    }

    private func layoutBadges(in strip: SKNode?, centered: Bool) {
        guard let strip else { return }
        let badges = strip.children.compactMap { $0 as? ModifierBadgeNode }
        guard !badges.isEmpty else { return }

        let badgeWidth: CGFloat = 50
        let spacing: CGFloat = 6
        let totalWidth = CGFloat(badges.count) * badgeWidth
            + CGFloat(badges.count - 1) * spacing
        let startX = centered
            ? -totalWidth / 2 + badgeWidth / 2
            : badgeWidth / 2

        for (i, badge) in badges.enumerated() {
            let targetX = startX + CGFloat(i) * (badgeWidth + spacing)
            badge.run(SKAction.moveTo(x: targetX, duration: 0.2))
        }
    }

    // MARK: - Resonance Background

    private func resonanceBackgroundColor(for zone: TwilightEngine.ResonanceZone) -> SKColor {
        switch zone {
        case .nav, .deepNav:
            return SKColor(red: 0.08, green: 0.04, blue: 0.14, alpha: 1)
        case .prav, .deepPrav:
            return SKColor(red: 0.12, green: 0.09, blue: 0.04, alpha: 1)
        case .yav:
            return SKColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
        }
    }
}
