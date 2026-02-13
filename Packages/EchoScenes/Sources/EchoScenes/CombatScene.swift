/// Файл: Packages/EchoScenes/Sources/EchoScenes/CombatScene.swift
/// Назначение: Содержит реализацию файла CombatScene.swift.
/// Зона ответственности: Реализует визуально-сценовый слой EchoScenes.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit
import FirebladeECS
import EchoEngine
import TwilightEngine
import Foundation

private func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}
private func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
}

/// SpriteKit scene that renders an ECS-driven combat encounter.
/// Owns a CombatSimulation (logic) and RenderSystemGroup (visuals).
/// Touch input dispatches commands into the ECS — never mutates state directly.
public final class CombatScene: SKScene {

    // MARK: - ECS

    public private(set) var simulation: CombatSimulation!
    public private(set) var renderGroup: RenderSystemGroup!
    var storedEnemyDefinition: EnemyDefinition!

    // MARK: - Layout Constants (zone-based, 390×700 scene)

    // Enemy zone: top area, avatar on the left
    let enemyPosition = CGPoint(x: -130, y: 270)
    // Player zone: above hand, avatar on the left
    let playerPosition = CGPoint(x: -130, y: -20)
    // Arena center: where cards fly, fate overlay appears
    let arenaCenter = CGPoint(x: 0, y: 140)

    // MARK: - UI Nodes

    var attackButton: SKLabelNode!
    var influenceButton: SKLabelNode?
    var skipButton: SKLabelNode!
    var phaseLabel: SKLabelNode!
    var roundLabel: SKLabelNode!
    var fateOverlay: SKNode!
    var handContainer: SKNode!
    var deckCountLabel: SKLabelNode!
    var discardCountLabel: SKLabelNode!
    var exhaustCountLabel: SKLabelNode!
    var energyLabel: SKLabelNode!
    var resonanceLabel: SKLabelNode!
    var intentNode: SKNode?
    var tooltipNode: SKNode?
    var combatLogNode: SKNode!
    var combatLogEntries: [String] = []
    let maxLogEntries = 5
    var discardOverlay: SKNode?
    var exhaustOverlay: SKNode?
    var playerStatusNode: SKNode?
    var enemyStatusNode: SKNode?
    var mulliganOverlay: SKNode?
    var mulliganSelected: Set<String> = []
    var longPressTimer: Timer?
    var touchStartLocation: CGPoint?
    var isAnimating = false
    var handScrollOffset: CGFloat = 0
    var handContentWidth: CGFloat = 0
    var handCropNode: SKCropNode!
    var handInnerNode: SKNode!
    var isDraggingHand = false
    var arenaCardNodes: [SKNode] = []
    var drawPileNode: SKNode?
    var fateDeckNode: SKNode?
    var awaitingFateReveal = false
    var fateRevealCompletion: (() -> Void)?
    var pendingFateValue: Int = 0
    var pendingFateIsCritical = false
    var pendingFateLabel: String = ""
    var pendingFateResolution: FateResolution?

    // MARK: - Callbacks

    public var onCombatEnd: ((CombatOutcome) -> Void)?
    public var onCombatEndWithResult: ((EchoCombatResult) -> Void)?
    public var onSoundEffect: ((String) -> Void)?
    public var onHaptic: ((String) -> Void)?

    // MARK: - Configuration

    public func configure(
        enemyDefinition: EnemyDefinition,
        playerName: String = "Hero",
        playerHealth: Int = 10,
        playerMaxHealth: Int = 10,
        playerStrength: Int = 5,
        playerDeck: [Card] = [],
        fateCards: [FateCard] = [],
        resonance: Float = 0,
        seed: UInt64 = 42
    ) {
        storedEnemyDefinition = enemyDefinition
        simulation = CombatSimulation.create(
            enemyDefinition: enemyDefinition,
            playerName: playerName,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth,
            playerStrength: playerStrength,
            playerDeck: playerDeck,
            fateCards: fateCards,
            resonance: resonance,
            seed: seed
        )
    }

    // MARK: - Scene Lifecycle

    public override func didMove(to view: SKView) {
        backgroundColor = CombatSceneTheme.background
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        guard simulation != nil else { return }

        setupBackground()
        renderGroup = RenderSystemGroup(scene: self)
        setupCombatEntities()
        setupHUD()

        simulation.beginCombat()
        syncRender()
        updateHUD()
        showMulliganOverlay()
    }

    // MARK: - Background

    private func setupBackground() {
        // Gradient background: dark purple bottom → near-black top
        let gradientNode = SKSpriteNode(color: .clear, size: size)
        gradientNode.zPosition = -10
        if let texture = makeGradientTexture(size: size,
                                              topColor: CombatSceneTheme.background,
                                              bottomColor: CombatSceneTheme.backgroundLight) {
            gradientNode.texture = texture
        }
        addChild(gradientNode)

        // Zone separators are created in setupHUD()
    }

    private func makeGradientTexture(size: CGSize, topColor: SKColor, bottomColor: SKColor) -> SKTexture? {
        let w = Int(size.width)
        let h = Int(size.height)
        guard w > 0, h > 0 else { return nil }

        #if os(iOS)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        #elseif os(macOS)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                          isPlanar: false, colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }
        #endif

        let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else {
            #if os(iOS)
            UIGraphicsEndImageContext()
            #endif
            return nil
        }
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: 0),
                               end: CGPoint(x: 0, y: size.height),
                               options: [])

        #if os(iOS)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = image?.cgImage else { return nil }
        #elseif os(macOS)
        guard let cgImage = rep.cgImage else { return nil }
        #endif
        return SKTexture(cgImage: cgImage)
    }

    // MARK: - Avatar Helpers

    private func makeAvatarNode(initial: String, color: SKColor, radius: CGFloat) -> SKNode {
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = color.withAlphaComponent(0.3)
        circle.strokeColor = color
        circle.lineWidth = 2

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = String(initial.prefix(1)).uppercased()
        label.fontSize = radius * 0.8
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        circle.addChild(label)

        return circle
    }

    // MARK: - Entity Setup

    private func setupCombatEntities() {
        let nexus = simulation.nexus
        let infoOffsetX: CGFloat = 150  // horizontal offset from avatar to info area center

        // Enemy avatar (left) + health bar + label (right)
        if let enemy = simulation.enemyEntity {
            let tag: EnemyTagComponent = nexus.get(unsafe: enemy.identifier)

            let avatar = makeAvatarNode(initial: storedEnemyDefinition.name.resolved, color: CombatSceneTheme.health, radius: 30)
            avatar.position = enemyPosition
            avatar.zPosition = 5
            avatar.name = "avatar_enemy"
            addChild(avatar)

            enemy.assign(SpriteComponent(
                textureName: "enemy_\(tag.definitionId)",
                position: enemyPosition,
                scale: 1.0,
                zPosition: 5
            ))
            let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
            enemy.assign(HealthBarComponent(
                showHP: true,
                showWill: health.maxWill > 0,
                barWidth: 100,
                verticalOffset: -10,
                horizontalOffset: infoOffsetX
            ))
            // Label to the right of avatar
            enemy.assign(LabelComponent(
                text: storedEnemyDefinition.name.resolved,
                fontName: "AvenirNext-Bold",
                fontSize: 14,
                colorName: "white",
                verticalOffset: 14,
                horizontalOffset: infoOffsetX
            ))
        }

        // Player avatar (left) + health bar + label (right)
        if let player = simulation.playerEntity {
            let tag: PlayerTagComponent = nexus.get(unsafe: player.identifier)

            let avatar = makeAvatarNode(initial: tag.name, color: CombatSceneTheme.spirit, radius: 26)
            avatar.position = playerPosition
            avatar.zPosition = 5
            avatar.name = "avatar_player"
            addChild(avatar)

            player.assign(SpriteComponent(
                textureName: "hero_default",
                position: playerPosition,
                scale: 0.8,
                zPosition: 5
            ))
            player.assign(HealthBarComponent(
                showHP: true,
                barWidth: 100,
                verticalOffset: -10,
                horizontalOffset: infoOffsetX
            ))
            player.assign(LabelComponent(
                text: tag.name,
                fontName: "AvenirNext-Bold",
                fontSize: 13,
                colorName: "cyan",
                verticalOffset: 14,
                horizontalOffset: infoOffsetX
            ))
        }
    }

    // MARK: - HUD
    // MARK: - Frame Update

    public override func update(_ currentTime: TimeInterval) {
        syncRender()
    }
}
