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

    // MARK: - Proportional Layout

    /// Proportional layout — Y positions as fractions of scene height.
    /// Gaps are uniform (35–85pt). Max gap = 85pt play area.
    /// Design: compact enemy top, bar center, hand dominant bottom.
    enum Layout {
        /// Fixed top padding for Dynamic Island clearance (80pt).
        static let hudTopPad: CGFloat = 80
        // Enemy zone — tight stack
        static let idol: CGFloat = 0.82
        static let intent: CGFloat = 0.74
        static let enemyMods: CGFloat = 0.66
        static let bar: CGFloat = 0.58
        // Player zone — hand dominant
        static let heroMods: CGFloat = 0.48
        static let hand: CGFloat = 0.36
        static let actions: CGFloat = 0.20
        static let endTurn: CGFloat = 0.20
        static let handLabels: CGFloat = 0.12
        // Contextual (appear on interaction)
        static let cardPreview: CGFloat = 0.56
        static let fateFlash: CGFloat = 0.50
    }

    // MARK: - ViewModel

    private(set) var viewModel: DispositionCombatViewModel?

    // MARK: - Callbacks

    var onCombatEnd: ((DispositionCombatResult) -> Void)?
    var onSoundEffect: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?
    var summaryCompletion: (() -> Void)?

    // MARK: - Node References

    var idolNode: IdolNode?
    var dispositionBar: SKShapeNode?
    var dispositionFill: SKShapeNode?
    var dispositionLabel: SKLabelNode?
    var strikeZone: SKShapeNode?
    var influenceZone: SKShapeNode?
    var sacrificeZone: SKShapeNode?
    var actionButtonsContainer: SKNode?
    var strikeButton: SKNode?
    var influenceButton: SKNode?
    var sacrificeButton: SKNode?
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
        let fillWidth = barWidth * fraction

        // Gradient: red (-100) → gray (0) → blue (+100) per design doc §9.1
        let color: SKColor
        let t = fraction // 0.0 = -100, 0.5 = 0, 1.0 = +100
        if t < 0.5 {
            let s = t / 0.5 // 0→1 within left half
            let r = 0.85 - s * 0.45
            let g = 0.25 + s * 0.20
            let b = 0.20 + s * 0.20
            color = SKColor(red: r, green: g, blue: b, alpha: 1)
        } else {
            let s = (t - 0.5) / 0.5 // 0→1 within right half
            let r = 0.40 - s * 0.10
            let g = 0.45 + s * 0.15
            let b = 0.40 + s * 0.50
            color = SKColor(red: r, green: g, blue: b, alpha: 1)
        }

        if animated {
            let startWidth = fill.path?.boundingBox.width ?? barWidth / 2
            let action = SKAction.customAction(withDuration: 0.3) { node, elapsed in
                guard let shape = node as? SKShapeNode else { return }
                let t = min(1.0, elapsed / 0.3)
                let eased = 1.0 - (1.0 - t) * (1.0 - t)
                let w = startWidth + (fillWidth - startWidth) * eased
                let rect = CGRect(x: -barWidth / 2, y: -10, width: w, height: 20)
                shape.path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)
                shape.fillColor = color
            }
            fill.run(action, withKey: "fillAnim")
        } else {
            let rect = CGRect(x: -barWidth / 2, y: -10, width: fillWidth, height: 20)
            fill.path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)
            fill.fillColor = color
        }

        dispositionLabel?.text = "\(disposition)"
        dispositionLabel?.fontColor = color
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

            // Show mode change flash text near the idol
            let modeText: String
            switch newMode {
            case .survival:
                modeText = "Выживание — атаки усилены!"
            case .desperation:
                modeText = "Отчаяние — удвоенный урон!"
            case .weakened:
                modeText = "Ослаблен — действует слабо"
            case .normal:
                modeText = ""
            }
            if !modeText.isEmpty {
                let pos = idol.position
                showFloatingText(modeText, at: CGPoint(x: pos.x, y: pos.y - 50), color: .orange)
            }
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
        label.text = "⚡ \(newEnergy)/\(vm.startingEnergy)"

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

        let scaleFactor: CGFloat
        switch cards.count {
        case 1...3: scaleFactor = 0.85
        case 4...5: scaleFactor = 0.78
        case 6...7: scaleFactor = 0.70
        default:    scaleFactor = 0.62
        }
        let centerX = size.width / 2
        let baseY = size.height * Layout.hand

        // Horizontal row — positions are card centers, so reserve half-card on each side
        let cardW = RitualTheme.cardSize.width * scaleFactor
        let edgePad: CGFloat = 14
        let availableSpan = size.width - cardW - edgePad * 2
        let idealGap = cardW * 0.72
        let spacing: CGFloat = cards.count > 1
            ? min(idealGap, availableSpan / CGFloat(cards.count - 1))
            : 0
        let totalSpan = spacing * CGFloat(max(cards.count - 1, 0))
        let startX = centerX - totalSpan / 2

        for (i, card) in cards.enumerated() {
            let position = CGPoint(
                x: startX + CGFloat(i) * spacing,
                y: baseY
            )

            if let existingNode = handCardNodes[card.id] {
                existingNode.removeAction(forKey: "cardSway")
                let move = SKAction.move(to: position, duration: 0.25)
                move.timingMode = .easeOut
                let rotate = SKAction.rotate(toAngle: 0, duration: 0.2)
                let rescale = SKAction.scale(to: scaleFactor, duration: 0.2)
                existingNode.run(SKAction.group([move, rotate, rescale])) { [weak self] in
                    self?.addCardSway(to: existingNode, index: i)
                }
                existingNode.zPosition = CGFloat(20 + i)
            } else {
                let node = makeCardNode(card: card)
                node.position = CGPoint(x: centerX, y: baseY - 50)
                node.zRotation = 0
                node.zPosition = CGFloat(20 + i)
                node.setScale(0.3)
                node.alpha = 0
                node.name = "card_\(card.id)"
                layer.addChild(node)
                handCardNodes[card.id] = node

                let delay = SKAction.wait(forDuration: Double(i) * 0.06)
                let move = SKAction.move(to: position, duration: 0.3)
                move.timingMode = .easeOut
                let scale = SKAction.scale(to: scaleFactor, duration: 0.25)
                let fadeIn = SKAction.fadeIn(withDuration: 0.15)
                node.run(SKAction.sequence([
                    delay,
                    SKAction.group([move, scale, fadeIn])
                ])) { [weak self] in
                    self?.addCardSway(to: node, index: i)
                }
            }

            originalCardPositions[card.id] = position
            originalCardRotations[card.id] = 0
            originalCardZPositions[card.id] = CGFloat(20 + i)
            originalCardScales[card.id] = scaleFactor
        }
    }

    func dimUnplayableCards() {
        guard let vm = viewModel else { return }
        for (cardId, node) in handCardNodes {
            guard let card = vm.hand.first(where: { $0.id == cardId }) else { continue }
            let cost = card.cost ?? 1
            let playable = cost <= vm.energy
            node.alpha = playable ? 1.0 : 0.45
            if let border = node.childNode(withName: "cardBorder") as? SKShapeNode {
                border.glowWidth = playable ? 1 : 0
                border.strokeColor = playable
                    ? cardAccentColor(for: card.type).withAlphaComponent(0.5)
                    : SKColor(white: 0.3, alpha: 0.4)
            }
        }
    }

    // MARK: - Action Zone Visibility

    func updateActionZoneVisibility() {
        guard let vm = viewModel else { return }
        let hasEnergy = vm.energy > 0
        let hasCards = !vm.hand.isEmpty
        let combatActive = vm.outcome == nil

        // Legacy zone nodes (may be nil after layout redesign)
        strikeZone?.alpha = (hasEnergy && hasCards && combatActive) ? 1.0 : 0.3
        influenceZone?.alpha = (hasEnergy && hasCards && combatActive) ? 1.0 : 0.3
        sacrificeZone?.alpha = (hasEnergy && hasCards && combatActive
            && vm.canSacrifice) ? 1.0 : 0.3

        // New action buttons — visibility driven by card selection
        let canPlay = hasEnergy && hasCards && combatActive
        strikeButton?.alpha = canPlay ? 1.0 : 0.3
        influenceButton?.alpha = canPlay ? 1.0 : 0.3
        sacrificeButton?.alpha = (canPlay && vm.canSacrifice) ? 1.0 : 0.4

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
