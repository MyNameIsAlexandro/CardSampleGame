/// Файл: Views/Combat/RitualCombatScene.swift
/// Назначение: SpriteKit-сцена ритуального боя (Стол Волхва) — core lifecycle.
/// Зона ответственности: Properties, configure, restore, syncVisuals. Layout в +Layout, loop в +GameLoop.
/// Контекст: Phase 3 Ritual Combat (R9). Не обращается к ECS напрямую.

import SpriteKit
import TwilightEngine

/// Ritual Combat scene — portrait 390×700 "Sorcerer's Table" aesthetic.
/// All game logic delegated to `CombatSimulation` API. No direct ECS access.
///
/// Split into extensions:
///   - `RitualCombatScene+Layout.swift` — node creation and positioning
///   - `RitualCombatScene+GameLoop.swift` — input, phases, result emission
final class RitualCombatScene: SKScene {

    // MARK: - Configuration

    static let sceneSize = CGSize(width: 390, height: 700)

    // MARK: - Combat State

    private(set) var simulation: CombatSimulation?

    // MARK: - Callbacks

    var onCombatEnd: ((RitualCombatResult) -> Void)?
    var onSoundEffect: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?

    // MARK: - Node References

    var idolNodes: [IdolNode] = []
    var ritualCircle: RitualCircleNode?
    var sealNodes: [SealNode] = []
    var bonfireNode: BonfireNode?
    var amuletNode: AmuletNode?
    var resonanceRune: ResonanceRuneNode?
    var handCardNodes: [String: SKNode] = [:]

    // MARK: - Controllers

    var dragController: DragDropController?
    var fateDirector: FateRevealDirector?
    var atmosphereController: ResonanceAtmosphereController?
    var combatLog: CombatLogOverlay?

    // MARK: - Layers

    var ritualLayer: SKNode?
    var handLayer: SKNode?
    var overlayLayer: SKNode?

    // MARK: - Stats Accumulators

    var initialHeroHP: Int = 0
    var initialResonance: Float = 0
    var accumulatedDamageDealt: Int = 0
    var accumulatedDamageTaken: Int = 0
    var accumulatedCardsPlayed: Int = 0

    // MARK: - Input State

    var selectedTargetId: String?
    var inputEnabled: Bool = false
    var touchStartLocation: CGPoint?
    var suppressDefenseRevealForCurrentResolution: Bool = false

    // MARK: - Card Drag State

    var draggedCardId: String?
    var originalCardPositions: [String: CGPoint] = [:]
    var originalCardRotations: [String: CGFloat] = [:]

    // MARK: - Seal Drag State

    var draggingSealType: SealType?
    var draggingSealGhost: SKNode?
    var targetingArrow: SKShapeNode?

    // MARK: - Configure

    /// Configure scene with a pre-built combat simulation.
    func configure(with simulation: CombatSimulation) {
        self.scaleMode = .aspectFill
        self.backgroundColor = SKColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
        self.simulation = simulation
        self.initialHeroHP = simulation.heroMaxHP
        self.initialResonance = simulation.snapshot().worldResonance
        self.accumulatedDamageDealt = 0
        self.accumulatedDamageTaken = 0
        self.accumulatedCardsPlayed = 0

        buildLayout()
        wireControllers()
        syncVisuals(animated: false)
        advancePhase()
    }

    // MARK: - Restore

    /// Restore scene from a saved combat snapshot.
    func restore(from snapshot: CombatSnapshot) {
        let restored = CombatSimulation.restore(from: snapshot)
        configure(with: restored)
    }

    // MARK: - Sync Visuals

    /// Push full simulation state to all nodes.
    func syncVisuals(animated: Bool = true) {
        guard let sim = simulation else { return }

        for (i, idol) in idolNodes.enumerated() {
            guard i < sim.enemies.count else { break }
            let enemy = sim.enemies[i]
            idol.updateHP(current: enemy.hp, max: enemy.maxHp, animated: animated)
            if let wp = enemy.wp, let maxWp = enemy.maxWp {
                idol.updateWP(current: wp, max: maxWp, animated: animated)
            }
        }

        bonfireNode?.setBurnCount(sim.effortBonus, max: sim.maxEffort)
        ritualCircle?.setCard(present: !sim.selectedCardIds.isEmpty)
        ritualCircle?.updateEffortGlow(effortBonus: sim.effortBonus, maxEffort: sim.maxEffort)

        amuletNode?.updateHP(current: sim.heroHP, max: initialHeroHP)

        let liveResonance = sim.snapshot().worldResonance
        resonanceRune?.update(resonance: liveResonance)
        atmosphereController?.update(resonance: liveResonance)

        if let roundLabel = childNode(withName: "roundLabel") as? SKLabelNode {
            let phaseName = phaseDisplayName(sim.phase)
            roundLabel.text = formattedRoundPhaseLabel(round: sim.round, phaseText: phaseName)
        }

        if let fateLabel = childNode(withName: "fateLabel") as? SKLabelNode {
            fateLabel.text = "🂠 \(sim.fateDeckCount)"
        }

        if let energyLabel = childNode(withName: "energyLabel") as? SKLabelNode {
            energyLabel.text = "⚡ \(sim.energy - sim.reservedEnergy)/\(sim.energy)"
        }

        let resonanceColor = ResonanceZone.from(resonance: liveResonance).color
        ritualCircle?.updateGlowColor(resonanceColor)
        sealNodes.forEach { $0.updateGlow(color: resonanceColor) }

        rebuildHandCards()
        dimUnplayableCards()
    }

    // MARK: - Hand Cards

    func rebuildHandCards() {
        guard let sim = simulation else { return }
        let layer = handLayer ?? self

        handCardNodes.values.forEach { $0.removeFromParent() }
        handCardNodes.removeAll()
        originalCardPositions.removeAll()
        originalCardRotations.removeAll()

        let cards = sim.hand
        guard !cards.isEmpty else { return }

        let cardSize = RitualTheme.cardSize
        let scaleFactor = cards.count > RitualTheme.scaleThreshold
            ? min(1.0, CGFloat(RitualTheme.scaleThreshold) / CGFloat(cards.count))
            : 1.0
        let centerX = RitualCombatScene.sceneSize.width / 2
        let baseY: CGFloat = 85
        let centerIndex = CGFloat(cards.count - 1) / 2.0
        let overlapSpacing = min(
            RitualTheme.baseOverlapSpacing,
            (RitualCombatScene.sceneSize.width - 40) / CGFloat(cards.count)
        )

        for (i, card) in cards.enumerated() {
            let isSelected = sim.selectedCardIds.contains(card.id)
            let offset = CGFloat(i) - centerIndex
            let angle = offset * RitualTheme.fanAngleStep
            let yOffset = -abs(offset) * RitualTheme.arcYDropPerUnit
            let selectedLift: CGFloat = isSelected ? RitualTheme.selectedLift : 0

            let position = CGPoint(
                x: centerX + offset * overlapSpacing,
                y: baseY + yOffset + selectedLift
            )
            let rotation = -angle * .pi / 180

            let node = makeCardNode(card: card, size: cardSize, selected: isSelected)
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

    private func makeCardNode(card: Card, size: CGSize, selected: Bool) -> SKNode {
        let container = SKNode()

        let bg = SKShapeNode(rectOf: size, cornerRadius: 8)
        bg.fillColor = selected
            ? SKColor(red: 0.20, green: 0.42, blue: 0.30, alpha: 1)
            : SKColor(red: 0.12, green: 0.10, blue: 0.16, alpha: 1)
        bg.strokeColor = selected
            ? SKColor(red: 0.40, green: 0.75, blue: 0.50, alpha: 1)
            : SKColor(red: 0.35, green: 0.30, blue: 0.40, alpha: 1)
        bg.lineWidth = selected ? 2.0 : 1.5
        container.addChild(bg)

        let typeIcon = cardTypeIcon(card.type)
        let iconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        iconLabel.text = typeIcon
        iconLabel.fontSize = 18
        iconLabel.position = CGPoint(x: 0, y: size.height / 2 - 22)
        iconLabel.verticalAlignmentMode = .center
        container.addChild(iconLabel)

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

        let descLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        descLabel.text = String(card.description.prefix(18))
        descLabel.fontSize = 8
        descLabel.fontColor = SKColor(white: 0.65, alpha: 1)
        descLabel.position = CGPoint(x: 0, y: -size.height / 2 + 18)
        descLabel.verticalAlignmentMode = .center
        descLabel.horizontalAlignmentMode = .center
        container.addChild(descLabel)

        return container
    }

    func cardTypeIcon(_ type: CardType) -> String {
        switch type {
        case .attack, .weapon: return "⚔"
        case .defense, .armor: return "🛡"
        case .spell, .ritual: return "✦"
        case .blessing, .spirit: return "☽"
        case .item, .artifact: return "◆"
        default: return "◇"
        }
    }

    func phaseDisplayName(_ phase: CombatSimulationPhase) -> String {
        switch phase {
        case .playerAction: return L10n.encounterPhasePlayerAction.localized
        case .resolution: return L10n.encounterPhaseEnemyResolution.localized
        case .finished: return L10n.encounterPhaseRoundEnd.localized
        }
    }

    func setSubPhaseLabel(_ text: String) {
        guard let roundLabel = childNode(withName: "roundLabel") as? SKLabelNode,
              let sim = simulation else { return }
        roundLabel.text = formattedRoundPhaseLabel(round: sim.round, phaseText: text)
    }

    func restorePhaseLabel() {
        guard let sim = simulation else { return }
        setSubPhaseLabel(phaseDisplayName(sim.phase))
    }

    func formattedRoundPhaseLabel(round: Int, phaseText: String) -> String {
        "\(L10n.encounterRoundLabel.localized(with: round)) · \(phaseText)"
    }

    // MARK: - Combat Log

    /// Add a combat log entry.
    func logEntry(_ text: String, type: CombatLogEntryType = .action) {
        combatLog?.addEntry(text: text, type: type)
    }

    // MARK: - Wire Controllers

    private func wireControllers() {
        let dc = DragDropController()
        dc.onCommand = { [weak self] command in
            self?.handleDragCommand(command)
        }
        dragController = dc

        let fate = FateRevealDirector()
        if let overlay = overlayLayer {
            fate.attach(to: overlay)
        }
        fate.onSoundEffect = { [weak self] name in self?.onSoundEffect?(name) }
        fate.onHaptic = { [weak self] name in self?.onHaptic?(name) }
        fateDirector = fate

        let atmo = ResonanceAtmosphereController()
        atmo.attach(to: self, sceneSize: RitualCombatScene.sceneSize)
        atmosphereController = atmo
    }
}

// MARK: - Outcome & Defense Reveal

extension RitualCombatScene {

    func playDefenseReveal(totalDamage: Int, completion: @escaping () -> Void) {
        guard totalDamage > 0 else {
            completion()
            return
        }

        guard let fateDirector else {
            completion()
            return
        }

        setSubPhaseLabel(L10n.combatFateDefense.localized)
        fateDirector.onRevealComplete = { [weak self] in
            self?.restorePhaseLabel()
            completion()
        }
        fateDirector.beginReveal(
            cardName: L10n.combatFateDefense.localized,
            effectiveValue: -totalDamage,
            isSuitMatch: false,
            isCritical: totalDamage >= 8,
            tempo: .minor,
            targetPosition: amuletNode?.position,
            damageValue: totalDamage
        )
    }

    func emitResult() {
        guard let sim = simulation else { return }

        let heroAlive = sim.heroHP > 0
        let anyKilled = sim.enemies.contains { $0.hp <= 0 }
        let anyPacified = sim.enemies.contains { $0.isPacified }
        let outcome: RitualCombatOutcome = heroAlive && anyKilled
            ? .victory(.killed)
            : (heroAlive && anyPacified ? .victory(.pacified) : .defeat)

        let defeatedEnemies = sim.enemies.filter { $0.hp <= 0 || $0.isPacified }
        let rewards = (
            faith: defeatedEnemies.reduce(0) { $0 + $1.faithReward },
            loot: defeatedEnemies.flatMap(\.lootCardIds)
        )

        let transaction: (resonance: Float, faith: Int, loot: [String])
        switch outcome {
        case .victory(.killed): transaction = (-5, rewards.faith, rewards.loot)
        case .victory(.pacified): transaction = (5, rewards.faith, rewards.loot)
        case .defeat: transaction = (0, 0, [])
        }

        onCombatEnd?(RitualCombatResult(
            outcome: outcome,
            hpDelta: sim.heroHP - initialHeroHP,
            resonanceDelta: transaction.resonance,
            faithDelta: transaction.faith,
            lootCardIds: transaction.loot,
            updatedFateDeckState: sim.snapshot().fateDeckState,
            turnsPlayed: sim.round,
            totalDamageDealt: accumulatedDamageDealt,
            totalDamageTaken: accumulatedDamageTaken,
            cardsPlayed: accumulatedCardsPlayed
        ))
    }
}
