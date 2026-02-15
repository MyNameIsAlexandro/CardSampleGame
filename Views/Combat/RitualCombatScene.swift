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

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = SKColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
        scaleMode = .aspectFill
    }

    // MARK: - Configure

    /// Configure scene with a pre-built combat simulation.
    func configure(with simulation: CombatSimulation) {
        self.simulation = simulation
        self.initialHeroHP = simulation.heroHP
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
        resonanceRune?.update(resonance: initialResonance)
        atmosphereController?.update(resonance: initialResonance)

        let resonanceColor = ResonanceZone.from(resonance: initialResonance).color
        ritualCircle?.updateGlowColor(resonanceColor)
        sealNodes.forEach { $0.updateGlow(color: resonanceColor) }

        rebuildHandCards()
    }

    // MARK: - Hand Cards

    func rebuildHandCards() {
        guard let sim = simulation else { return }
        let layer = handLayer ?? self

        handCardNodes.values.forEach { $0.removeFromParent() }
        handCardNodes.removeAll()

        let cards = sim.hand
        let cardWidth: CGFloat = 52
        let cardHeight: CGFloat = 74
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(cards.count) * (cardWidth + spacing) - spacing
        let startX = (RitualCombatScene.sceneSize.width - totalWidth) / 2 + cardWidth / 2
        let y: CGFloat = 90

        for (i, card) in cards.enumerated() {
            let isSelected = sim.selectedCardIds.contains(card.id)
            let node = makeCardNode(card: card, size: CGSize(width: cardWidth, height: cardHeight), selected: isSelected)
            node.position = CGPoint(x: startX + CGFloat(i) * (cardWidth + spacing), y: y)
            node.name = "card_\(card.id)"
            layer.addChild(node)
            handCardNodes[card.id] = node
        }
    }

    private func makeCardNode(card: Card, size: CGSize, selected: Bool) -> SKNode {
        let container = SKNode()

        let bg = SKShapeNode(rectOf: size, cornerRadius: 6)
        bg.fillColor = selected
            ? SKColor(red: 0.25, green: 0.50, blue: 0.35, alpha: 1)
            : SKColor(red: 0.15, green: 0.12, blue: 0.18, alpha: 1)
        bg.strokeColor = selected
            ? SKColor(red: 0.40, green: 0.75, blue: 0.50, alpha: 1)
            : SKColor(red: 0.40, green: 0.35, blue: 0.45, alpha: 1)
        bg.lineWidth = 1.5
        container.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = String(card.name.prefix(6))
        label.fontSize = 10
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        if selected {
            container.position.y += 12
        }

        return container
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
