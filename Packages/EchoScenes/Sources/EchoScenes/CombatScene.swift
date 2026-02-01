import SpriteKit
import FirebladeECS
import EchoEngine
import TwilightEngine

/// SpriteKit scene that renders an ECS-driven combat encounter.
/// Owns a CombatSimulation (logic) and RenderSystemGroup (visuals).
/// Touch input dispatches commands into the ECS — never mutates state directly.
public final class CombatScene: SKScene {

    // MARK: - ECS

    public private(set) var simulation: CombatSimulation!
    public private(set) var renderGroup: RenderSystemGroup!

    // MARK: - Layout Constants

    private let enemyPosition = CGPoint(x: 0, y: 120)
    private let playerPosition = CGPoint(x: 0, y: -100)

    // MARK: - UI Nodes

    private var attackButton: SKLabelNode!
    private var skipButton: SKLabelNode!
    private var phaseLabel: SKLabelNode!
    private var roundLabel: SKLabelNode!

    // MARK: - Callbacks

    public var onCombatEnd: ((CombatOutcome) -> Void)?

    // MARK: - Configuration

    public func configure(
        enemyDefinition: EnemyDefinition,
        playerName: String = "Hero",
        playerHealth: Int = 10,
        playerMaxHealth: Int = 10,
        playerStrength: Int = 5,
        playerDeck: [Card] = [],
        fateCards: [FateCard] = [],
        seed: UInt64 = 42
    ) {
        simulation = CombatSimulation.create(
            enemyDefinition: enemyDefinition,
            playerName: playerName,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth,
            playerStrength: playerStrength,
            playerDeck: playerDeck,
            fateCards: fateCards,
            seed: seed
        )
    }

    // MARK: - Scene Lifecycle

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        guard simulation != nil else { return }

        renderGroup = RenderSystemGroup(scene: self)
        setupCombatEntities()
        setupHUD()

        simulation.beginCombat()
        syncRender()
        updateHUD()
    }

    // MARK: - Entity Setup

    private func setupCombatEntities() {
        let nexus = simulation.nexus

        // Enemy sprite + health bar + label
        if let enemy = simulation.enemyEntity {
            let tag: EnemyTagComponent = nexus.get(unsafe: enemy.identifier)
            enemy.assign(SpriteComponent(
                textureName: "enemy_\(tag.definitionId)",
                position: enemyPosition,
                scale: 1.0,
                zPosition: 5
            ))
            enemy.assign(HealthBarComponent(
                showHP: true,
                showWill: false,
                barWidth: 80,
                verticalOffset: -50
            ))
            enemy.assign(LabelComponent(
                text: tag.definitionId,
                fontName: "AvenirNext-Bold",
                fontSize: 16,
                colorName: "white",
                verticalOffset: 50
            ))
        }

        // Player sprite + health bar + label
        if let player = simulation.playerEntity {
            let tag: PlayerTagComponent = nexus.get(unsafe: player.identifier)
            player.assign(SpriteComponent(
                textureName: "hero_default",
                position: playerPosition,
                scale: 0.8,
                zPosition: 5
            ))
            player.assign(HealthBarComponent(
                showHP: true,
                barWidth: 80,
                verticalOffset: -40
            ))
            player.assign(LabelComponent(
                text: tag.name,
                fontName: "AvenirNext-Bold",
                fontSize: 14,
                colorName: "cyan",
                verticalOffset: 40
            ))
        }
    }

    // MARK: - HUD

    private func setupHUD() {
        let halfH = size.height / 2

        phaseLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        phaseLabel.fontSize = 14
        phaseLabel.fontColor = .gray
        phaseLabel.position = CGPoint(x: 0, y: halfH - 30)
        phaseLabel.zPosition = 20
        addChild(phaseLabel)

        roundLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        roundLabel.fontSize = 12
        roundLabel.fontColor = .gray
        roundLabel.position = CGPoint(x: 0, y: halfH - 50)
        roundLabel.zPosition = 20
        addChild(roundLabel)

        let buttonY = -halfH + 60

        attackButton = makeButton(text: "Attack", position: CGPoint(x: -60, y: buttonY), name: "btn_attack")
        skipButton = makeButton(text: "Skip", position: CGPoint(x: 60, y: buttonY), name: "btn_skip")
    }

    private func makeButton(text: String, position: CGPoint, name: String) -> SKLabelNode {
        let bg = SKShapeNode(rectOf: CGSize(width: 100, height: 36), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.2, alpha: 0.9)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.6)
        bg.position = position
        bg.zPosition = 20
        bg.name = name

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        bg.addChild(label)
        addChild(bg)

        return label
    }

    private func updateHUD() {
        phaseLabel.text = "Phase: \(simulation.phase)"
        roundLabel.text = "Round \(simulation.round)"

        let isPlayerTurn = simulation.phase == .playerTurn && !simulation.isOver
        attackButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        skipButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
    }

    // MARK: - Render Sync

    private func syncRender() {
        renderGroup.update(nexus: simulation.nexus)
    }

    // MARK: - Touch Input

    #if os(iOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location)
    }
    #elseif os(macOS)
    public override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleTap(at: location)
    }
    #endif

    private func handleTap(at location: CGPoint) {
        guard !simulation.isOver, simulation.phase == .playerTurn else { return }

        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
            switch node.name {
            case "btn_attack":
                performPlayerAttack()
                return
            case "btn_skip":
                performPlayerSkip()
                return
            default:
                break
            }
        }
    }

    // MARK: - Combat Actions

    private func performPlayerAttack() {
        let event = simulation.playerAttack()

        // Animate based on event
        if let enemy = simulation.enemyEntity {
            let anim: AnimationComponent
            if simulation.nexus.has(componentId: AnimationComponent.identifier, entityId: enemy.identifier) {
                anim = simulation.nexus.get(unsafe: enemy.identifier)
            } else {
                anim = AnimationComponent()
                enemy.assign(anim)
            }

            if case .playerAttacked = event {
                anim.enqueue(.shake(intensity: 8, duration: 0.3))
                anim.enqueue(.flash(colorName: "white", duration: 0.2))
            }
        }

        resolveAfterPlayerAction()
    }

    private func performPlayerSkip() {
        simulation.playerSkip()
        resolveAfterPlayerAction()
    }

    private func resolveAfterPlayerAction() {
        syncRender()
        updateHUD()

        if simulation.isOver {
            handleCombatEnd()
            return
        }

        // Enemy turn after short delay
        run(SKAction.wait(forDuration: 0.6)) { [weak self] in
            self?.resolveEnemyTurn()
        }
    }

    private func resolveEnemyTurn() {
        let event = simulation.resolveEnemyTurn()

        // Animate player hit
        if let player = simulation.playerEntity {
            let anim: AnimationComponent
            if simulation.nexus.has(componentId: AnimationComponent.identifier, entityId: player.identifier) {
                anim = simulation.nexus.get(unsafe: player.identifier)
            } else {
                anim = AnimationComponent()
                player.assign(anim)
            }

            if case .enemyAttacked = event {
                anim.enqueue(.shake(intensity: 5, duration: 0.2))
            }
        }

        syncRender()
        updateHUD()

        if simulation.isOver {
            handleCombatEnd()
        }
    }

    private func handleCombatEnd() {
        guard let outcome = simulation.outcome else { return }

        let text = outcome == .victory ? "Victory!" : "Defeat"
        let color: SKColor = outcome == .victory ? .green : .red

        let endLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        endLabel.text = text
        endLabel.fontSize = 48
        endLabel.fontColor = color
        endLabel.position = .zero
        endLabel.zPosition = 100
        endLabel.alpha = 0
        addChild(endLabel)

        endLabel.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.5),
            SKAction.wait(forDuration: 1.5),
        ])) { [weak self] in
            self?.onCombatEnd?(outcome)
        }
    }

    // MARK: - Frame Update

    public override func update(_ currentTime: TimeInterval) {
        syncRender()
    }
}
