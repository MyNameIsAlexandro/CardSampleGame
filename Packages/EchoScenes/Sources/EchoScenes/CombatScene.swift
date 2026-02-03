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
    private var storedEnemyDefinition: EnemyDefinition!

    // MARK: - Layout Constants (zone-based, 390×700 scene)

    // Enemy zone: top area, avatar on the left
    private let enemyPosition = CGPoint(x: -130, y: 270)
    // Player zone: above hand, avatar on the left
    private let playerPosition = CGPoint(x: -130, y: -20)
    // Arena center: where cards fly, fate overlay appears
    private let arenaCenter = CGPoint(x: 0, y: 140)

    // MARK: - UI Nodes

    private var attackButton: SKLabelNode!
    private var influenceButton: SKLabelNode?
    private var skipButton: SKLabelNode!
    private var phaseLabel: SKLabelNode!
    private var roundLabel: SKLabelNode!
    private var fateOverlay: SKNode!
    private var handContainer: SKNode!
    private var deckCountLabel: SKLabelNode!
    private var discardCountLabel: SKLabelNode!
    private var exhaustCountLabel: SKLabelNode!
    private var energyLabel: SKLabelNode!
    private var resonanceLabel: SKLabelNode!
    private var intentNode: SKNode?
    private var tooltipNode: SKNode?
    private var combatLogNode: SKNode!
    private var combatLogEntries: [String] = []
    private let maxLogEntries = 5
    private var discardOverlay: SKNode?
    private var exhaustOverlay: SKNode?
    private var playerStatusNode: SKNode?
    private var enemyStatusNode: SKNode?
    private var mulliganOverlay: SKNode?
    private var mulliganSelected: Set<String> = []
    private var longPressTimer: Timer?
    private var touchStartLocation: CGPoint?
    private var isAnimating = false
    private var handScrollOffset: CGFloat = 0
    private var handContentWidth: CGFloat = 0
    private var handCropNode: SKCropNode!
    private var handInnerNode: SKNode!
    private var isDraggingHand = false
    private var arenaCardNodes: [SKNode] = []
    private var drawPileNode: SKNode?
    private var fateDeckNode: SKNode?
    private var awaitingFateReveal = false
    private var fateRevealCompletion: (() -> Void)?
    private var pendingFateValue: Int = 0
    private var pendingFateIsCritical = false
    private var pendingFateLabel: String = ""
    private var pendingFateResolution: FateResolution?

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

    private func setupHUD() {
        let halfH = size.height / 2

        // --- HUD zone (top) ---
        phaseLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        phaseLabel.fontSize = 12
        phaseLabel.fontColor = CombatSceneTheme.muted
        phaseLabel.position = CGPoint(x: 0, y: halfH - 25)
        phaseLabel.zPosition = 20
        addChild(phaseLabel)

        roundLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        roundLabel.fontSize = 11
        roundLabel.fontColor = CombatSceneTheme.muted
        roundLabel.position = CGPoint(x: 0, y: halfH - 42)
        roundLabel.zPosition = 20
        addChild(roundLabel)

        // --- Buttons zone (bottom, Y = -260) ---
        let buttonY: CGFloat = -260

        let hasInfluence = simulation.enemyMaxWill > 0
        if hasInfluence {
            attackButton = makeButton(text: L("encounter.action.attack"), position: CGPoint(x: -100, y: buttonY), name: "btn_attack")
            influenceButton = makeButton(text: L("encounter.action.influence"), position: CGPoint(x: 0, y: buttonY), name: "btn_influence")
            skipButton = makeButton(text: L("encounter.action.wait"), position: CGPoint(x: 100, y: buttonY), name: "btn_end_turn")
        } else {
            attackButton = makeButton(text: L("encounter.action.attack"), position: CGPoint(x: -60, y: buttonY), name: "btn_attack")
            skipButton = makeButton(text: L("encounter.action.wait"), position: CGPoint(x: 60, y: buttonY), name: "btn_end_turn")
        }

        // --- Fate overlay in arena center ---
        fateOverlay = SKNode()
        fateOverlay.position = arenaCenter
        fateOverlay.zPosition = 50
        addChild(fateOverlay)

        // --- Indicators zone (Y = -215) ---
        let indicatorY: CGFloat = -215

        // Energy + Resonance (center)
        energyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        energyLabel.fontSize = 13
        energyLabel.fontColor = CombatSceneTheme.faith
        energyLabel.position = CGPoint(x: 0, y: indicatorY)
        energyLabel.zPosition = 15
        addChild(energyLabel)

        resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        resonanceLabel.fontSize = 11
        resonanceLabel.fontColor = CombatSceneTheme.muted
        resonanceLabel.position = CGPoint(x: 0, y: indicatorY - 14)
        resonanceLabel.zPosition = 15
        addChild(resonanceLabel)

        // Deck pile (left of hand)
        deckCountLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        deckCountLabel.fontSize = 14
        deckCountLabel.fontColor = CombatSceneTheme.spirit
        deckCountLabel.position = CGPoint(x: -size.width / 2 + 30, y: indicatorY)
        deckCountLabel.zPosition = 15
        addChild(deckCountLabel)

        // Draw pile visual (tappable card-back stack)
        let drawPile = makeDrawPileNode()
        drawPile.position = CGPoint(x: -size.width / 2 + 30, y: indicatorY + 30)
        drawPile.zPosition = 16
        drawPile.name = "btn_draw_pile"
        addChild(drawPile)
        drawPileNode = drawPile

        // Discard pile (right of hand, tappable)
        discardCountLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        discardCountLabel.fontSize = 14
        discardCountLabel.fontColor = CombatSceneTheme.muted
        discardCountLabel.position = CGPoint(x: size.width / 2 - 30, y: indicatorY)
        discardCountLabel.zPosition = 15
        discardCountLabel.name = "btn_discard"
        addChild(discardCountLabel)

        exhaustCountLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        exhaustCountLabel.fontSize = 11
        exhaustCountLabel.fontColor = CombatSceneTheme.muted
        exhaustCountLabel.position = CGPoint(x: size.width / 2 - 30, y: indicatorY - 16)
        exhaustCountLabel.zPosition = 15
        exhaustCountLabel.name = "btn_exhaust"
        addChild(exhaustCountLabel)

        // --- Hand zone (Y = -60 to -200, clipped) ---
        let cardH = CardNode.cardSize.height
        let handY: CGFloat = -130  // center of hand zone
        let visibleW = size.width

        handCropNode = SKCropNode()
        handCropNode.position = CGPoint(x: 0, y: handY)
        handCropNode.zPosition = 15
        let mask = SKSpriteNode(color: .white, size: CGSize(width: visibleW, height: cardH + 20))
        handCropNode.maskNode = mask
        addChild(handCropNode)

        handInnerNode = SKNode()
        handCropNode.addChild(handInnerNode)
        handContainer = handInnerNode

        // --- Combat log in arena zone ---
        combatLogNode = SKNode()
        combatLogNode.position = CGPoint(x: size.width / 2 - 10, y: arenaCenter.y)
        combatLogNode.zPosition = 15
        addChild(combatLogNode)

        // --- Arena separator lines ---
        let sepTop = SKShapeNode(rectOf: CGSize(width: size.width * 0.7, height: 1))
        sepTop.fillColor = CombatSceneTheme.separator
        sepTop.strokeColor = .clear
        sepTop.position = CGPoint(x: 0, y: 20)
        sepTop.alpha = 0.3
        sepTop.zPosition = 1
        addChild(sepTop)

        let sepBottom = SKShapeNode(rectOf: CGSize(width: size.width * 0.7, height: 1))
        sepBottom.fillColor = CombatSceneTheme.separator
        sepBottom.strokeColor = .clear
        sepBottom.position = CGPoint(x: 0, y: -55)
        sepBottom.alpha = 0.3
        sepBottom.zPosition = 1
        addChild(sepBottom)

        refreshHand()
    }

    private func makeButton(text: String, position: CGPoint, name: String) -> SKLabelNode {
        let bg = SKShapeNode(rectOf: CGSize(width: 100, height: 36), cornerRadius: 8)
        bg.fillColor = CombatSceneTheme.cardBack
        bg.strokeColor = CombatSceneTheme.muted.withAlphaComponent(0.6)
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
        phaseLabel.text = L("encounter.phase.label", "\(simulation.phase)")
        roundLabel.text = L("encounter.round.label", simulation.round)

        let isPlayerTurn = simulation.phase == .playerTurn && !simulation.isOver
        attackButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        influenceButton?.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        skipButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        handContainer.alpha = isPlayerTurn ? 1.0 : 0.5

        let drawCount = simulation.drawPileCount
        deckCountLabel.text = "🂠 \(drawCount)"
        drawPileNode?.alpha = drawCount > 0 ? 1.0 : 0.4
        discardCountLabel.text = "♻ \(simulation.discardPileCount)"
        let exhaustCount = simulation.exhaustPileCount
        exhaustCountLabel.text = exhaustCount > 0 ? "✕ \(exhaustCount)" : ""
        let available = simulation.availableEnergy
        let total = simulation.energy
        if simulation.reservedEnergy > 0 {
            energyLabel.text = "⚡ \(available)/\(simulation.maxEnergy) (-\(simulation.reservedEnergy))"
        } else {
            energyLabel.text = "⚡ \(total)/\(simulation.maxEnergy)"
        }

        let res = simulation.resonance
        let resInt = Int(res)
        if resInt == 0 {
            resonanceLabel.text = "☯ " + L("resonance.yav")
            resonanceLabel.fontColor = CombatSceneTheme.muted
        } else if res > 0 {
            resonanceLabel.text = "☀ " + L("resonance.prav") + " +\(resInt)"
            resonanceLabel.fontColor = CombatSceneTheme.faith
        } else {
            resonanceLabel.text = "☽ " + L("resonance.nav") + " \(resInt)"
            resonanceLabel.fontColor = CombatSceneTheme.spirit
        }

        // Обновить текст под врагом: HP + Will
        if let enemy = simulation.enemyEntity {
            let label: LabelComponent = simulation.nexus.get(unsafe: enemy.identifier)
            var text = storedEnemyDefinition.name.resolved
            text += "  ♥\(simulation.enemyHealth)/\(simulation.enemyMaxHealth)"
            if simulation.enemyMaxWill > 0 {
                text += "  ✦\(simulation.enemyWill)/\(simulation.enemyMaxWill)"
            }
            label.text = text
        }

        updateIntentDisplay()
        updateStatusIcons()
    }

    private func updateStatusIcons() {
        playerStatusNode?.removeFromParent()
        playerStatusNode = nil
        enemyStatusNode?.removeFromParent()
        enemyStatusNode = nil

        let stats = ["shield", "strength", "poison"]
        let icons: [String: (String, SKColor)] = [
            "shield": ("🛡", CombatSceneTheme.muted),
            "strength": ("⚔", CombatSceneTheme.faith),
            "poison": ("☠", CombatSceneTheme.success)
        ]

        // Player status
        let playerEffects = stats.compactMap { stat -> (String, Int)? in
            let val = simulation.playerStatus(for: stat)
            return val > 0 ? (stat, val) : nil
        }
        if !playerEffects.isEmpty {
            let node = SKNode()
            node.position = CGPoint(x: playerPosition.x + 120, y: playerPosition.y)
            node.zPosition = 25
            for (i, (stat, amount)) in playerEffects.enumerated() {
                let (icon, color) = icons[stat] ?? ("?", .white)
                let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                lbl.text = "\(icon)\(amount)"
                lbl.fontSize = 10
                lbl.fontColor = color
                lbl.verticalAlignmentMode = .center
                lbl.horizontalAlignmentMode = .left
                lbl.position = CGPoint(x: 0, y: -CGFloat(i) * 14)
                node.addChild(lbl)
            }
            addChild(node)
            playerStatusNode = node
        }

        // Enemy status
        let enemyEffects = stats.compactMap { stat -> (String, Int)? in
            let val = simulation.enemyStatus(for: stat)
            return val > 0 ? (stat, val) : nil
        }
        if !enemyEffects.isEmpty {
            let node = SKNode()
            node.position = CGPoint(x: enemyPosition.x + 120, y: enemyPosition.y)
            node.zPosition = 25
            for (i, (stat, amount)) in enemyEffects.enumerated() {
                let (icon, color) = icons[stat] ?? ("?", .white)
                let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                lbl.text = "\(icon)\(amount)"
                lbl.fontSize = 10
                lbl.fontColor = color
                lbl.verticalAlignmentMode = .center
                lbl.horizontalAlignmentMode = .left
                lbl.position = CGPoint(x: 0, y: -CGFloat(i) * 14)
                node.addChild(lbl)
            }
            addChild(node)
            enemyStatusNode = node
        }
    }

    private func updateIntentDisplay() {
        intentNode?.removeFromParent()
        intentNode = nil

        guard let intent = simulation.enemyIntent, !simulation.isOver else { return }

        let node = SKNode()
        node.position = CGPoint(x: enemyPosition.x, y: enemyPosition.y + 55)
        node.zPosition = 30

        let icon: String
        let color: SKColor
        switch intent.type {
        case .attack:
            icon = "⚔ \(intent.value)"
            color = CombatSceneTheme.health
        case .heal:
            icon = "♥ \(intent.value)"
            color = CombatSceneTheme.success
        case .ritual:
            icon = "✦ " + L("encounter.intent.ritual")
            color = CombatSceneTheme.spirit
        case .block, .defend:
            icon = "🛡 " + L("encounter.intent.defend")
            color = CombatSceneTheme.muted
        case .buff:
            icon = "↑ " + L("encounter.intent.buff")
            color = CombatSceneTheme.faith
        case .debuff:
            icon = "↓ " + L("encounter.intent.debuff")
            color = CombatSceneTheme.spirit
        case .prepare:
            icon = "… " + L("encounter.intent.prepare")
            color = CombatSceneTheme.muted
        default:
            icon = "? \(intent.type.rawValue)"
            color = CombatSceneTheme.muted
        }

        let bg = SKShapeNode(rectOf: CGSize(width: 70, height: 22), cornerRadius: 6)
        bg.fillColor = color.withAlphaComponent(0.25)
        bg.strokeColor = color.withAlphaComponent(0.6)
        bg.lineWidth = 1
        node.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = icon
        label.fontSize = 11
        label.fontColor = color
        label.verticalAlignmentMode = .center
        node.addChild(label)

        addChild(node)
        intentNode = node

        // Pulse animation
        node.alpha = 0
        node.run(SKAction.fadeIn(withDuration: 0.3))
    }

    private func refreshHand() {
        handContainer.removeAllChildren()
        let cards = simulation.hand
        guard !cards.isEmpty else {
            handContentWidth = 0
            handScrollOffset = 0
            handInnerNode.position.x = 0
            return
        }

        let cardW = CardNode.cardSize.width
        let step: CGFloat = cardW + 6
        let totalWidth = step * CGFloat(cards.count - 1) + cardW
        handContentWidth = totalWidth

        let visibleWidth = self.size.width - 20
        // Cards laid out in inner node from center
        let startX = -totalWidth / 2 + cardW / 2

        for (i, card) in cards.enumerated() {
            let node = CardNode(card: card)
            node.position = CGPoint(x: startX + CGFloat(i) * step, y: 0)
            node.zPosition = CGFloat(i)
            handContainer.addChild(node)
        }

        // Reset scroll if content fits
        if totalWidth <= visibleWidth {
            handScrollOffset = 0
        }
        applyHandScroll()
    }

    private func applyHandScroll() {
        let visibleWidth = self.size.width
        if handContentWidth <= visibleWidth {
            handInnerNode.position.x = 0
            return
        }
        // Allow scrolling so the first and last card can reach the center of the visible area
        let cardW = CardNode.cardSize.width
        let maxScroll = (handContentWidth - visibleWidth) / 2 + cardW / 2
        handScrollOffset = max(-maxScroll, min(maxScroll, handScrollOffset))
        handInnerNode.position.x = handScrollOffset
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
        touchStartLocation = location
        isDraggingHand = false

        dismissTooltip()

        // Long press for tooltip
        let cardNode = findCardNode(at: location)
        if cardNode != nil {
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self, let card = cardNode?.card else { return }
                self.touchStartLocation = nil
                self.showTooltip(for: card, at: location)
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let startLoc = touchStartLocation else { return }
        let location = touch.location(in: self)
        let dx = location.x - touch.previousLocation(in: self).x

        // Only start scrolling after 15pt horizontal movement threshold
        let totalDx = abs(location.x - startLoc.x)
        let handY = handCropNode.position.y
        let cardH = CardNode.cardSize.height
        let visibleW = self.size.width - 20
        let inHandArea = abs(location.y - handY) < cardH / 2 + 20
        let needsScroll = handContentWidth > visibleW

        if inHandArea && needsScroll && totalDx > 15 {
            if !isDraggingHand {
                isDraggingHand = true
                longPressTimer?.invalidate()
                longPressTimer = nil
            }
            handScrollOffset += dx
            applyHandScroll()
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        if tooltipNode != nil {
            dismissTooltip()
            isDraggingHand = false
            touchStartLocation = nil
            return
        }

        // If was dragging, don't fire tap
        if isDraggingHand {
            isDraggingHand = false
            touchStartLocation = nil
            return
        }

        guard let location = touchStartLocation else { return }
        touchStartLocation = nil
        handleTap(at: location)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        touchStartLocation = nil
        isDraggingHand = false
        dismissTooltip()
    }
    #elseif os(macOS)
    public override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        dismissTooltip()
        handleTap(at: location)
    }
    #endif

    private func findCardNode(at location: CGPoint) -> CardNode? {
        // First try scene hit test (works for cards NOT inside SKCropNode, e.g. mulligan)
        for node in nodes(at: location) {
            if let cardNode = node as? CardNode { return cardNode }
            if let parent = node.parent as? CardNode { return parent }
        }
        // Then check hand cards manually (SKCropNode blocks hit testing)
        let localPoint = handInnerNode.convert(location, from: self)
        let halfW = CardNode.cardSize.width / 2
        let halfH = CardNode.cardSize.height / 2
        // Iterate in reverse so topmost card (highest zPosition) wins
        for node in handInnerNode.children.reversed() {
            guard let cardNode = node as? CardNode else { continue }
            let p = cardNode.position
            if localPoint.x >= p.x - halfW && localPoint.x <= p.x + halfW &&
               localPoint.y >= p.y - halfH && localPoint.y <= p.y + halfH {
                return cardNode
            }
        }
        return nil
    }

    private func handleTap(at location: CGPoint) {
        // Mulligan phase intercepts all taps
        if mulliganOverlay != nil {
            handleMulliganTap(at: location)
            return
        }

        // Dismiss overlays if showing
        if exhaustOverlay != nil {
            dismissExhaustOverlay()
            return
        }
        if discardOverlay != nil {
            dismissDiscardOverlay()
            return
        }

        // Check continue button even when combat is over
        let tapped = nodes(at: location)
        if tapped.contains(where: { $0.name == "btn_continue" }),
           let outcome = simulation.outcome {
            if let result = simulation.combatResult {
                onCombatEndWithResult?(result)
            }
            onCombatEnd?(outcome)
            return
        }

        // Discard pile viewer — works anytime
        if tapped.contains(where: { $0.name == "btn_discard" }) {
            showDiscardOverlay()
            return
        }

        if tapped.contains(where: { $0.name == "btn_exhaust" }) {
            showExhaustOverlay()
            return
        }

        // Fate deck tap (during awaiting phase)
        if tapped.contains(where: { $0.name == "btn_fate_deck" }) && awaitingFateReveal {
            handleFateDeckTap()
            return
        }

        // Draw pile tap
        if tapped.contains(where: { $0.name == "btn_draw_pile" }) {
            handleDrawPileTap()
            return
        }

        guard !simulation.isOver, simulation.phase == .playerTurn, !isAnimating else { return }

        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
            switch node.name {
            case "btn_attack":
                performPlayerAttack()
                return
            case "btn_influence":
                performPlayerInfluence()
                return
            case "btn_end_turn":
                performEndTurn()
                return
            default:
                break
            }
        }

        // Check hand cards (manual hit test for SKCropNode)
        if let cardNode = findCardNode(at: location),
           cardNode.parent === handInnerNode {
            toggleCardSelection(cardNode)
        }
    }

    private func toggleCardSelection(_ cardNode: CardNode) {
        let cardId = cardNode.card.id
        if simulation.selectedCardIds.contains(cardId) {
            simulation.deselectCard(cardId: cardId)
            cardNode.setSelectedAnimated(false)
            onSoundEffect?("cardDeselect")
        } else {
            if simulation.selectCard(cardId: cardId) {
                cardNode.setSelectedAnimated(true)
                onSoundEffect?("cardSelect")
            } else {
                // Can't afford — shake card
                cardNode.run(SKAction.sequence([
                    SKAction.moveBy(x: -4, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 8, y: 0, duration: 0.05),
                    SKAction.moveBy(x: -8, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 4, y: 0, duration: 0.05)
                ]))
            }
        }
        updateCardAffordability()
        updateHUD()
    }

    private func updateCardAffordability() {
        let available = simulation.availableEnergy
        let selected = simulation.selectedCardIds
        for case let cardNode as CardNode in handContainer.children {
            if selected.contains(cardNode.card.id) {
                cardNode.setDimmed(false)
            } else {
                let cost = cardNode.card.cost ?? 1
                cardNode.setDimmed(cost > available)
            }
        }
    }

    private func deselectAllCardsVisually() {
        for case let cardNode as CardNode in handContainer.children {
            if cardNode.isCardSelected {
                cardNode.setSelectedAnimated(false)
            }
            cardNode.setDimmed(false)
        }
    }

    // MARK: - Mulligan

    private func showMulliganOverlay() {
        guard !simulation.hand.isEmpty else { return }

        mulliganSelected.removeAll()
        let overlay = SKNode()
        overlay.zPosition = 100

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.7)
        bg.strokeColor = .clear
        overlay.addChild(bg)

        // Compute grid height to position title/button around it
        let cardH = CardNode.cardSize.height
        let handCount = simulation.hand.count
        let rows = (handCount + 2) / 3  // ceil(count/3)
        let gridH = CGFloat(rows) * cardH + CGFloat(max(0, rows - 1)) * 8
        let gridTop: CGFloat = -10 + gridH / 2
        let gridBottom: CGFloat = -10 - gridH / 2

        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = L("combat.mulligan.title")
        title.fontSize = 18
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: gridTop + 30)
        title.verticalAlignmentMode = .center
        overlay.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text = L("combat.mulligan.prompt")
        subtitle.fontSize = 11
        subtitle.fontColor = CombatSceneTheme.muted
        subtitle.position = CGPoint(x: 0, y: gridTop + 12)
        subtitle.verticalAlignmentMode = .center
        overlay.addChild(subtitle)

        refreshMulliganCards(in: overlay)

        // Keep button below grid
        let btnY = gridBottom - 28
        let btnBg = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 8)
        btnBg.fillColor = CombatSceneTheme.success
        btnBg.strokeColor = .clear
        btnBg.position = CGPoint(x: 0, y: btnY)
        btnBg.name = "btn_mulligan_keep"
        overlay.addChild(btnBg)

        let btnLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        btnLabel.text = L("combat.mulligan.confirm")
        btnLabel.fontSize = 15
        btnLabel.fontColor = .white
        btnLabel.position = CGPoint(x: 0, y: btnY)
        btnLabel.verticalAlignmentMode = .center
        btnLabel.name = "btn_mulligan_keep"
        overlay.addChild(btnLabel)

        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.3))
        mulliganOverlay = overlay
    }

    private func refreshMulliganCards(in overlay: SKNode) {
        // Remove old card nodes
        overlay.children.filter { $0 is CardNode }.forEach { $0.removeFromParent() }

        let cards = simulation.hand
        guard !cards.isEmpty else { return }

        let availableW = size.width - 20
        let cardW = CardNode.cardSize.width
        let cardH = CardNode.cardSize.height
        let gap: CGFloat = 8

        // Grid layout: 3 per row, full size
        let cols = min(cards.count, 3)
        let stepX = cardW + gap
        let stepY = cardH + gap
        let rows = (cards.count + cols - 1) / cols

        // Center the grid vertically around y = -10
        let gridH = CGFloat(rows) * cardH + CGFloat(rows - 1) * gap
        let topY: CGFloat = -10 + gridH / 2 - cardH / 2

        // Scale if even 3 cards don't fit in width
        let rowW = stepX * CGFloat(cols - 1) + cardW
        let scale: CGFloat = rowW > availableW ? availableW / rowW : 1.0

        for (i, card) in cards.enumerated() {
            let col = i % cols
            let row = i / cols
            // Center each row
            let rowCount = min(cols, cards.count - row * cols)
            let rowTotalW = (stepX * CGFloat(rowCount - 1) + cardW) * scale
            let rowStartX = -rowTotalW / 2 + cardW * scale / 2

            let node = CardNode(card: card)
            node.setScale(scale)
            node.position = CGPoint(
                x: rowStartX + CGFloat(col) * stepX * scale,
                y: topY - CGFloat(row) * stepY * scale
            )
            node.name = "mulligan_\(card.id)"
            if mulliganSelected.contains(card.id) {
                node.setSelected(true)
                node.alpha = 0.5
            }
            overlay.addChild(node)
        }
    }

    private func handleMulliganTap(at location: CGPoint) {
        guard let overlay = mulliganOverlay else { return }

        let tapped = nodes(at: location)

        // Keep button
        if tapped.contains(where: { $0.name == "btn_mulligan_keep" }) {
            if !mulliganSelected.isEmpty {
                simulation.mulligan(cardIds: Array(mulliganSelected))
            }
            overlay.run(SKAction.fadeOut(withDuration: 0.2)) { [weak self] in
                overlay.removeFromParent()
                self?.mulliganOverlay = nil
                self?.refreshHand()
                self?.updateHUD()
            }
            return
        }

        // Toggle card selection
        for node in tapped {
            if let cardNode = node as? CardNode {
                toggleMulliganCard(cardNode.card.id, in: overlay)
                return
            }
            if let parent = node.parent as? CardNode {
                toggleMulliganCard(parent.card.id, in: overlay)
                return
            }
        }
    }

    private func toggleMulliganCard(_ cardId: String, in overlay: SKNode) {
        if mulliganSelected.contains(cardId) {
            mulliganSelected.remove(cardId)
        } else {
            mulliganSelected.insert(cardId)
        }
        refreshMulliganCards(in: overlay)
    }

    // MARK: - Discard Pile Viewer

    private func showDiscardOverlay() {
        dismissDiscardOverlay()

        let cards = simulation.discardPile
        let overlay = SKNode()
        overlay.zPosition = 100

        // Dark background
        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.8)
        bg.strokeColor = .clear
        overlay.addChild(bg)

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = L("combat.discard.title", cards.count)
        title.fontSize = 16
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: size.height / 2 - 50)
        title.verticalAlignmentMode = .center
        overlay.addChild(title)

        if cards.isEmpty {
            let empty = SKLabelNode(fontNamed: "AvenirNext-Regular")
            empty.text = L("combat.pile.empty")
            empty.fontSize = 14
            empty.fontColor = CombatSceneTheme.muted
            empty.position = .zero
            empty.verticalAlignmentMode = .center
            overlay.addChild(empty)
        } else {
            // Show cards in a grid, scaled to fit 3 per row
            let gridScale: CGFloat = 0.6
            let cardW = CardNode.cardSize.width * gridScale + 6
            let cardH = CardNode.cardSize.height * gridScale + 8
            let cols = min(cards.count, 3)
            let totalW = cardW * CGFloat(cols)
            let startX = -totalW / 2 + cardW / 2

            for (i, card) in cards.enumerated() {
                let col = i % 3
                let row = i / 3
                let node = CardNode(card: card)
                node.setScale(gridScale)
                node.position = CGPoint(
                    x: startX + CGFloat(col) * cardW,
                    y: CGFloat(20) - CGFloat(row) * cardH
                )
                overlay.addChild(node)
            }
        }

        // Tap to close hint
        let hint = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hint.text = L("combat.tap.to.close")
        hint.fontSize = 10
        hint.fontColor = CombatSceneTheme.muted
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        hint.verticalAlignmentMode = .center
        overlay.addChild(hint)

        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.2))
        discardOverlay = overlay
    }

    private func dismissDiscardOverlay() {
        discardOverlay?.removeFromParent()
        discardOverlay = nil
    }

    // MARK: - Exhaust Pile Viewer

    private func showExhaustOverlay() {
        dismissExhaustOverlay()

        let cards = simulation.exhaustPile
        guard !cards.isEmpty else { return }

        let overlay = SKNode()
        overlay.zPosition = 100

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.8)
        bg.strokeColor = .clear
        overlay.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = L("combat.exhaust.title", cards.count)
        title.fontSize = 16
        title.fontColor = CombatSceneTheme.muted
        title.position = CGPoint(x: 0, y: size.height / 2 - 50)
        title.verticalAlignmentMode = .center
        overlay.addChild(title)

        let gridScale: CGFloat = 0.6
        let cardW = CardNode.cardSize.width * gridScale + 6
        let cardH = CardNode.cardSize.height * gridScale + 8
        let cols = min(cards.count, 3)
        let totalW = cardW * CGFloat(cols)
        let startX = -totalW / 2 + cardW / 2

        for (i, card) in cards.enumerated() {
            let col = i % 3
            let row = i / 3
            let node = CardNode(card: card)
            node.setScale(gridScale)
            node.alpha = 0.6
            node.position = CGPoint(
                x: startX + CGFloat(col) * cardW,
                y: CGFloat(20) - CGFloat(row) * cardH
            )
            overlay.addChild(node)
        }

        let hint = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hint.text = L("combat.tap.to.close")
        hint.fontSize = 10
        hint.fontColor = CombatSceneTheme.muted
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        hint.verticalAlignmentMode = .center
        overlay.addChild(hint)

        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.2))
        exhaustOverlay = overlay
    }

    private func dismissExhaustOverlay() {
        exhaustOverlay?.removeFromParent()
        exhaustOverlay = nil
    }

    // MARK: - Combat Log

    private func addLogEntry(_ text: String) {
        combatLogEntries.append(text)
        if combatLogEntries.count > maxLogEntries {
            combatLogEntries.removeFirst()
        }
        refreshLog()
    }

    private func refreshLog() {
        combatLogNode.removeAllChildren()
        for (i, entry) in combatLogEntries.reversed().enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Regular")
            label.text = entry
            label.fontSize = 8
            label.fontColor = CombatSceneTheme.muted.withAlphaComponent(CGFloat(1.0 - Double(i) * 0.15))
            label.horizontalAlignmentMode = .right
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: CGFloat(i) * 12)
            combatLogNode.addChild(label)
        }
    }

    private func logCombatEvent(_ event: CombatEvent) {
        switch event {
        case .playerAttacked(let dmg, _, _, _):
            addLogEntry(L("encounter.log.player.attack", dmg))
        case .playerMissed:
            addLogEntry(L("encounter.log.player.missed"))
        case .enemyAttacked(let dmg, _, _, _):
            addLogEntry(dmg > 0 ? L("encounter.log.enemy.damage", dmg) : L("encounter.log.enemy.blocked"))
        case .enemyHealed(let amt):
            addLogEntry(L("encounter.log.enemy.heals", amt))
        case .enemyRitual(let shift):
            addLogEntry(L("encounter.log.enemy.ritual", "\(shift > 0 ? "+" : "")\(Int(shift))"))
        case .enemyBlocked:
            addLogEntry(L("encounter.log.enemy.defends"))
        case .cardPlayed(_, let dmg, let heal, let drawn, let status):
            var parts: [String] = []
            if dmg > 0 { parts.append("\(dmg) dmg") }
            if heal > 0 { parts.append("+\(heal) hp") }
            if drawn > 0 { parts.append("+\(drawn) cards") }
            if let s = status {
                if s == "resonance" {
                    let res = Int(simulation.resonance)
                    parts.append("resonance → \(res)")
                } else {
                    parts.append(s)
                }
            }
            addLogEntry("Card: \(parts.joined(separator: ", "))")
        case .insufficientEnergy:
            addLogEntry(L("encounter.log.no.energy"))
        case .roundAdvanced(let r):
            addLogEntry(L("encounter.log.round.start", r))
        case .playerInfluenced(let dmg, _, _, _):
            addLogEntry(L("encounter.log.player.influence", dmg))
        case .influenceNotAvailable:
            addLogEntry(L("encounter.log.influence.impossible"))
        case .trackSwitched(let track):
            addLogEntry(L("encounter.log.track.switch", track.rawValue))
        }
    }

    // MARK: - Tooltip

    private func showTooltip(for card: Card, at location: CGPoint) {
        dismissTooltip()

        let tooltip = SKNode()
        tooltip.zPosition = 100

        let cost = card.cost ?? 1
        var lines = [
            card.name,
            L("combat.card.cost", cost)
        ]

        if card.abilities.isEmpty {
            lines.append(card.description)
        } else {
            for ability in card.abilities {
                lines.append("• \(ability.description)")
            }
        }

        var keywords: [String] = []
        if card.exhaust { keywords.append(L("combat.keyword.exhaust")) }
        keywords.append(contentsOf: card.traits)
        if !keywords.isEmpty {
            lines.append(keywords.joined(separator: " · "))
        }

        let text = lines.joined(separator: "\n")

        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 160
        label.fontSize = 11
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let padding: CGFloat = 12
        let bgWidth = max(label.frame.width + padding * 2, 120)
        let bgHeight = max(label.frame.height + padding * 2, 50)

        let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.85)
        bg.strokeColor = CombatSceneTheme.muted
        bg.lineWidth = 1

        tooltip.addChild(bg)
        tooltip.addChild(label)

        // Position above touch, clamped to scene
        let halfW = size.width / 2
        let tooltipX = max(-halfW + bgWidth / 2 + 8, min(halfW - bgWidth / 2 - 8, location.x))
        tooltip.position = CGPoint(x: tooltipX, y: location.y + bgHeight / 2 + 20)

        addChild(tooltip)
        tooltipNode = tooltip

        // Fade in
        tooltip.alpha = 0
        tooltip.run(SKAction.fadeIn(withDuration: 0.15))
    }

    private func dismissTooltip() {
        tooltipNode?.removeFromParent()
        tooltipNode = nil
    }

    // MARK: - Draw Pile & Fate Deck Visuals

    private func makeDrawPileNode() -> SKNode {
        let node = SKNode()
        node.name = "btn_draw_pile"
        // Stack of 3 card backs
        for i in 0..<3 {
            let cardBack = SKShapeNode(rectOf: CGSize(width: 36, height: 50), cornerRadius: 4)
            cardBack.fillColor = CombatSceneTheme.cardBack
            cardBack.strokeColor = CombatSceneTheme.spirit.withAlphaComponent(0.6)
            cardBack.lineWidth = 1
            cardBack.position = CGPoint(x: CGFloat(i) * 2, y: CGFloat(i) * 2)
            cardBack.name = "btn_draw_pile"
            node.addChild(cardBack)
        }
        // Card back pattern
        let pattern = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        pattern.text = "🂠"
        pattern.fontSize = 20
        pattern.verticalAlignmentMode = .center
        pattern.position = CGPoint(x: 4, y: 4)
        pattern.name = "btn_draw_pile"
        node.addChild(pattern)
        return node
    }

    private func showFateDeckInArena() {
        fateDeckNode?.removeFromParent()

        let node = SKNode()
        node.name = "btn_fate_deck"
        node.position = CGPoint(x: 0, y: arenaCenter.y - 50)
        node.zPosition = 45

        let cardBack = SKShapeNode(rectOf: FateCardNode.cardSize, cornerRadius: 6)
        cardBack.fillColor = CombatSceneTheme.faith.withAlphaComponent(0.2)
        cardBack.strokeColor = CombatSceneTheme.faith.withAlphaComponent(0.8)
        cardBack.lineWidth = 1.5
        cardBack.name = "btn_fate_deck"
        node.addChild(cardBack)

        let icon = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        icon.text = "☆"
        icon.fontSize = 24
        icon.fontColor = CombatSceneTheme.faith
        icon.verticalAlignmentMode = .center
        icon.name = "btn_fate_deck"
        node.addChild(icon)

        let hint = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        hint.text = L("combat.fate.tap")
        hint.fontSize = 10
        hint.fontColor = CombatSceneTheme.faith
        hint.position = CGPoint(x: 0, y: -(FateCardNode.cardSize.height / 2 + 10))
        hint.verticalAlignmentMode = .top
        hint.name = "btn_fate_deck"
        node.addChild(hint)

        // Pulse animation to attract attention
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        node.run(pulse, withKey: "pulse")

        node.alpha = 0
        addChild(node)
        node.run(SKAction.fadeIn(withDuration: 0.2))
        fateDeckNode = node
    }

    private func hideFateDeck() {
        fateDeckNode?.removeAllActions()
        fateDeckNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        fateDeckNode = nil
    }

    private func handleDrawPileTap() {
        guard !simulation.isOver, simulation.phase == .playerTurn, !isAnimating else { return }
        guard simulation.drawPileCount > 0 else { return }

        if let card = simulation.drawOneCard() {
            onSoundEffect?("cardDraw")
            refreshHand()
            updateHUD()

            // Animate the new card: find it in hand and flash it
            for case let cardNode as CardNode in handContainer.children where cardNode.card.id == card.id {
                cardNode.alpha = 0
                cardNode.run(SKAction.fadeIn(withDuration: 0.2))
            }
        }
    }

    private func handleFateDeckTap() {
        guard awaitingFateReveal, let completion = fateRevealCompletion else { return }
        awaitingFateReveal = false
        fateRevealCompletion = nil

        hideFateDeck()

        showFateCard(
            value: pendingFateValue,
            isCritical: pendingFateIsCritical,
            label: pendingFateLabel,
            resolution: pendingFateResolution,
            completion: completion
        )
    }

    /// Show fate deck and wait for player tap. When tapped, reveals the fate card and calls completion.
    private func presentFateDeckForReveal(value: Int, isCritical: Bool, label: String, resolution: FateResolution?, completion: @escaping () -> Void) {
        pendingFateValue = value
        pendingFateIsCritical = isCritical
        pendingFateLabel = label
        pendingFateResolution = resolution
        fateRevealCompletion = completion
        awaitingFateReveal = true
        showFateDeckInArena()
    }

    // MARK: - Combat Actions (Phased Flow)

    /// Executes the full player attack flow with explicit visual phases:
    /// Cards → Arena → Fate → Resolution → Apply → Enemy Turn → Round End
    private func performPlayerAttack() {
        isAnimating = true
        let selectedNodes = handContainer.children.compactMap { $0 as? CardNode }
            .filter { simulation.selectedCardIds.contains($0.card.id) }

        // Phase 1: Fly cards to arena
        animateCardsToArena(selectedNodes) { [weak self] in
            guard let self else { return }

            // Commit logic (instant)
            let roundBefore = self.simulation.round
            let events = self.simulation.commitAttack()
            for event in events { self.logCombatEvent(event) }

            let attackEvent = events.last { if case .playerAttacked = $0 { return true }; if case .playerMissed = $0 { return true }; return false }
            let fateValue: Int; let damage: Int; let resolution: FateResolution?
            switch attackEvent {
            case .playerAttacked(let d, let fv, _, let res): fateValue = fv; damage = d; resolution = res
            case .playerMissed(let fv, let res): fateValue = fv; damage = 0; resolution = res
            default: fateValue = 0; damage = 0; resolution = nil
            }

            // Phase 2: Show fate deck, wait for player tap
            self.onSoundEffect?("fateReveal")
            self.presentFateDeckForReveal(value: fateValue, isCritical: resolution?.isCritical ?? false, label: L("encounter.action.attack"), resolution: resolution) { [weak self] in
                guard let self else { return }

                // Phase 3: Apply damage
                self.onSoundEffect?("attackHit")
                self.onHaptic?("medium")

                if let playerAvatar = self.childNode(withName: "avatar_player") {
                    playerAvatar.run(SKAction.sequence([
                        SKAction.moveBy(x: 15, y: 15, duration: 0.1),
                        SKAction.moveBy(x: -15, y: -15, duration: 0.1)
                    ]))
                }
                let isCrit = resolution?.isCritical ?? false
                if damage > 0, let enemy = self.simulation.enemyEntity {
                    let anim = self.getOrCreateAnim(for: enemy)
                    anim.enqueue(.shake(intensity: isCrit ? 14 : 8, duration: 0.3))
                    anim.enqueue(.flash(colorName: "white", duration: 0.2))
                    self.spawnImpactParticles(at: CGPoint(x: 0, y: self.enemyPosition.y), isCritical: isCrit)
                    if isCrit { self.screenShake(intensity: 6) }
                }
                if damage > 0 {
                    self.showDamageNumber(damage, at: CGPoint(x: 0, y: self.enemyPosition.y), color: CombatSceneTheme.highlight)
                }

                // Clear arena cards
                self.clearArenaCards()
                self.deselectAllCardsVisually()
                self.syncRender()
                self.updateHUD()
                self.refreshHand()

                if self.simulation.isOver {
                    self.isAnimating = false
                    self.handleCombatEnd()
                    return
                }

                // Phase 4: Enemy turn banner + enemy action
                self.showEnemyTurnBanner {
                    self.runEnemyPhase(roundBefore: roundBefore)
                }
            }
        }
    }

    /// Executes the full player influence flow (same phases, spiritual track).
    private func performPlayerInfluence() {
        isAnimating = true
        let selectedNodes = handContainer.children.compactMap { $0 as? CardNode }
            .filter { simulation.selectedCardIds.contains($0.card.id) }

        animateCardsToArena(selectedNodes) { [weak self] in
            guard let self else { return }

            let roundBefore = self.simulation.round
            let events = self.simulation.commitInfluence()
            for event in events { self.logCombatEvent(event) }

            let influenceEvent = events.last { if case .playerInfluenced = $0 { return true }; if case .influenceNotAvailable = $0 { return true }; return false }
            let fateValue: Int; let willDamage: Int; let resolution: FateResolution?
            switch influenceEvent {
            case .playerInfluenced(let wd, let fv, _, let res): fateValue = fv; willDamage = wd; resolution = res
            default: fateValue = 0; willDamage = 0; resolution = nil
            }

            self.onSoundEffect?("fateReveal")
            self.presentFateDeckForReveal(value: fateValue, isCritical: resolution?.isCritical ?? false, label: L("encounter.action.influence"), resolution: resolution) { [weak self] in
                guard let self else { return }

                self.onSoundEffect?("influence")
                self.onHaptic?("medium")

                if let playerAvatar = self.childNode(withName: "avatar_player") {
                    playerAvatar.run(SKAction.sequence([
                        SKAction.scale(to: 1.15, duration: 0.15),
                        SKAction.scale(to: 1.0, duration: 0.15)
                    ]))
                }
                if willDamage > 0, let enemy = self.simulation.enemyEntity {
                    let anim = self.getOrCreateAnim(for: enemy)
                    anim.enqueue(.flash(colorName: "cyan", duration: 0.3))
                }
                if willDamage > 0 {
                    self.showDamageNumber(willDamage, at: CGPoint(x: 0, y: self.enemyPosition.y), color: CombatSceneTheme.spirit)
                }

                self.clearArenaCards()
                self.deselectAllCardsVisually()
                self.syncRender()
                self.updateHUD()
                self.refreshHand()

                if self.simulation.isOver {
                    self.isAnimating = false
                    self.handleCombatEnd()
                    return
                }

                self.showEnemyTurnBanner {
                    self.runEnemyPhase(roundBefore: roundBefore)
                }
            }
        }
    }

    private func performEndTurn() {
        isAnimating = true
        deselectAllCardsVisually()
        let roundBefore = simulation.round
        simulation.endTurn()
        syncRender()
        updateHUD()

        showEnemyTurnBanner { [weak self] in
            self?.runEnemyPhase(roundBefore: roundBefore)
        }
    }

    // MARK: - Phase: Cards to Arena

    /// Fly selected cards to the arena zone and keep them visible.
    private func animateCardsToArena(_ cardNodes: [CardNode], completion: @escaping () -> Void) {
        guard !cardNodes.isEmpty else {
            completion()
            return
        }

        let cardW = CardNode.cardSize.width
        let arenaScale: CGFloat = 0.7
        let spacing: CGFloat = 8
        let scaledW = cardW * arenaScale
        let totalW = scaledW * CGFloat(cardNodes.count) + spacing * CGFloat(cardNodes.count - 1)
        let startX = -totalW / 2 + scaledW / 2

        let group = DispatchGroup()

        for (i, cardNode) in cardNodes.enumerated() {
            group.enter()

            let scenePos = handContainer.convert(cardNode.position, to: self)
            let flyCard = CardNode(card: cardNode.card)
            flyCard.position = scenePos
            flyCard.zPosition = 40 + CGFloat(i)
            addChild(flyCard)
            arenaCardNodes.append(flyCard)

            cardNode.removeFromParent()

            let targetX = startX + CGFloat(i) * (scaledW + spacing)
            let target = CGPoint(x: targetX, y: arenaCenter.y)

            let flyAction = SKAction.move(to: target, duration: 0.3)
            flyAction.timingMode = .easeOut
            let scaleAction = SKAction.scale(to: arenaScale, duration: 0.3)

            flyCard.run(SKAction.group([flyAction, scaleAction])) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // Settle pause
            self.run(SKAction.wait(forDuration: 0.2)) {
                completion()
            }
        }
    }

    /// Fade out and remove all cards from the arena.
    private func clearArenaCards() {
        for node in arenaCardNodes {
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        }
        arenaCardNodes.removeAll()
    }

    // MARK: - Phase: Enemy Turn Banner

    private func showEnemyTurnBanner(completion: @escaping () -> Void) {
        let banner = SKNode()
        banner.zPosition = 80
        banner.position = CGPoint(x: 0, y: arenaCenter.y)

        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 0.8, height: 40), cornerRadius: 8)
        bg.fillColor = CombatSceneTheme.health.withAlphaComponent(0.3)
        bg.strokeColor = CombatSceneTheme.health.withAlphaComponent(0.6)
        bg.lineWidth = 1
        banner.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = L("combat.enemy.turn")
        label.fontSize = 20
        label.fontColor = CombatSceneTheme.health
        label.verticalAlignmentMode = .center
        banner.addChild(label)

        banner.alpha = 0
        banner.setScale(0.8)
        addChild(banner)

        banner.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.scale(to: 1.05, duration: 0.2)
            ]),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 0.4),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ])) {
            completion()
        }
    }

    // MARK: - Phase: Enemy Action

    private func runEnemyPhase(roundBefore: Int) {
        // Pulse enemy intent
        if let intentNode = intentNode {
            intentNode.run(SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15)
            ]))
        }

        run(SKAction.wait(forDuration: 0.3)) { [weak self] in
            guard let self else { return }

            let event = self.simulation.resolveEnemyTurn()
            self.logCombatEvent(event)
            self.onSoundEffect?("enemyAttack")
            self.onHaptic?("heavy")

            let fateValue: Int; let damage: Int
            switch event {
            case .enemyAttacked(let d, let fv, _, _): fateValue = fv; damage = d
            default: fateValue = 0; damage = 0
            }

            self.showFateCard(value: fateValue, isCritical: false, label: L("combat.fate.defense.label")) { [weak self] in
                guard let self else { return }

                // Enemy lunge
                if let enemyAvatar = self.childNode(withName: "avatar_enemy") {
                    enemyAvatar.run(SKAction.sequence([
                        SKAction.moveBy(x: 15, y: -15, duration: 0.1),
                        SKAction.moveBy(x: -15, y: 15, duration: 0.1)
                    ]))
                }

                if case .enemyAttacked = event, let player = self.simulation.playerEntity {
                    let anim = self.getOrCreateAnim(for: player)
                    anim.enqueue(.shake(intensity: 5, duration: 0.2))
                    self.spawnImpactParticles(at: CGPoint(x: 0, y: self.playerPosition.y), isCritical: false)
                }

                if damage > 0 {
                    self.showDamageNumber(damage, at: CGPoint(x: 0, y: self.playerPosition.y), color: CombatSceneTheme.health)
                }

                self.syncRender()
                self.updateHUD()

                if self.simulation.isOver {
                    self.isAnimating = false
                    self.handleCombatEnd()
                    return
                }

                // Round end phase
                self.showRoundEnd(roundBefore: roundBefore)
            }
        }
    }

    // MARK: - Phase: Round End

    private func showRoundEnd(roundBefore: Int) {
        let newRound = simulation.round

        if newRound > roundBefore {
            // Show round indicator
            let roundBanner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            roundBanner.text = L("combat.round.start", newRound)
            roundBanner.fontSize = 24
            roundBanner.fontColor = CombatSceneTheme.faith
            roundBanner.position = arenaCenter
            roundBanner.verticalAlignmentMode = .center
            roundBanner.zPosition = 80
            roundBanner.alpha = 0
            roundBanner.setScale(0.8)
            addChild(roundBanner)

            roundBanner.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.15),
                    SKAction.scale(to: 1.1, duration: 0.15)
                ]),
                SKAction.scale(to: 1.0, duration: 0.1),
                SKAction.wait(forDuration: 0.3),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ])) { [weak self] in
                self?.finishRound()
            }
        } else {
            finishRound()
        }
    }

    private func finishRound() {
        refreshHand()
        updateHUD()
        isAnimating = false
    }

    // MARK: - Animation Helpers

    private func getOrCreateAnim(for entity: Entity) -> AnimationComponent {
        if simulation.nexus.has(componentId: AnimationComponent.identifier, entityId: entity.identifier) {
            return simulation.nexus.get(unsafe: entity.identifier)
        }
        let anim = AnimationComponent()
        entity.assign(anim)
        return anim
    }

    private func screenShake(intensity: CGFloat) {
        let actions = (0..<4).flatMap { _ -> [SKAction] in
            [SKAction.moveBy(x: CGFloat.random(in: -intensity...intensity),
                             y: CGFloat.random(in: -intensity...intensity),
                             duration: 0.04),
             SKAction.move(to: .zero, duration: 0.04)]
        }
        self.run(SKAction.sequence(actions))
    }

    // MARK: - Fate Card Overlay

    private func showFateCard(value: Int, isCritical: Bool, label: String, resolution: FateResolution? = nil, completion: @escaping () -> Void) {
        let card = FateCardNode()
        card.alpha = 0
        fateOverlay.addChild(card)
        onSoundEffect?(isCritical ? "fateCritical" : "fateReveal")
        if isCritical { onHaptic?("heavy") }

        // Context label below card
        let context = SKLabelNode(fontNamed: "AvenirNext-Medium")
        let sign = value > 0 ? "+\(value)" : "\(value)"
        context.text = "\(label) \(sign)"
        context.fontSize = 14
        context.fontColor = CombatSceneTheme.muted
        context.position = CGPoint(x: 0, y: -(FateCardNode.cardSize.height / 2 + 14))
        context.verticalAlignmentMode = .top
        card.addChild(context)

        // Keyword + suit match indicator
        if let resolution = resolution, let keyword = resolution.keyword {
            let keywordLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            let matchIcon = resolution.suitMatch ? " ★" : ""
            keywordLabel.text = "\(keyword.rawValue.capitalized)\(matchIcon)"
            keywordLabel.fontSize = 12
            keywordLabel.fontColor = resolution.suitMatch ? CombatSceneTheme.highlight : CombatSceneTheme.faith
            keywordLabel.position = CGPoint(x: 0, y: -(FateCardNode.cardSize.height / 2 + 30))
            keywordLabel.verticalAlignmentMode = .top
            card.addChild(keywordLabel)
        }

        // Animate: fade in → flip → hold → fade out
        card.run(SKAction.fadeIn(withDuration: 0.15)) { [weak card] in
            card?.reveal(value: value, isCritical: isCritical) {
                card?.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.6),
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.removeFromParent()
                ])) {
                    completion()
                }
            }
        }
    }

    private func showDamageNumber(_ value: Int, at position: CGPoint, color: SKColor, prefix: String = "-") {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "\(prefix)\(abs(value))"
        label.fontSize = 22
        label.fontColor = color
        // Show damage numbers centered horizontally, near the target's Y
        label.position = CGPoint(x: 0, y: position.y + 30)
        label.zPosition = 60
        label.setScale(0.5)
        addChild(label)

        label.run(SKAction.sequence([
            // Scale bounce on appear
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1),
            // Float up and fade
            SKAction.group([
                SKAction.moveBy(x: 0, y: 40, duration: 0.8),
                SKAction.fadeOut(withDuration: 0.8)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Particles

    private func spawnImpactParticles(at position: CGPoint, isCritical: Bool) {
        let emitter = isCritical ? CombatParticles.criticalHit() : CombatParticles.attackImpact()
        emitter.position = position
        addChild(emitter)
        // Auto-remove after particles finish
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ]))
    }

    private func handleCombatEnd() {
        guard let outcome = simulation.outcome else { return }

        // Enemy fade-out on victory
        if case .victory = outcome, let enemyAvatar = childNode(withName: "avatar_enemy") {
            enemyAvatar.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.6),
                    SKAction.scale(to: 0.3, duration: 0.6)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        // Victory/defeat particle burst
        let burstEmitter = CombatParticles.attackImpact()
        burstEmitter.position = .zero
        let isWin: Bool
        if case .victory = outcome { isWin = true } else { isWin = false }
        burstEmitter.particleColor = isWin ? .systemGreen : .systemRed
        burstEmitter.numParticlesToEmit = 30
        addChild(burstEmitter)
        burstEmitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.removeFromParent()
        ]))

        // Dark overlay
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor(white: 0.0, alpha: 0.75)
        overlay.strokeColor = .clear
        overlay.position = .zero
        overlay.zPosition = 90
        overlay.alpha = 0
        overlay.name = "end_overlay"
        addChild(overlay)

        let container = SKNode()
        container.zPosition = 100
        container.alpha = 0
        addChild(container)

        // Sound + haptic for combat end
        switch outcome {
        case .victory:
            onSoundEffect?("victory")
            onHaptic?("success")
        case .defeat:
            onSoundEffect?("defeat")
            onHaptic?("error")
        }

        let isVictory: Bool
        let victoryText: String
        switch outcome {
        case .victory(.pacified):
            isVictory = true
            victoryText = L("encounter.outcome.pacified")
        case .victory:
            isVictory = true
            victoryText = L("encounter.outcome.victory")
        case .defeat:
            isVictory = false
            victoryText = L("encounter.outcome.defeat")
        }
        let titleColor: SKColor = isVictory ? CombatSceneTheme.success : CombatSceneTheme.health

        // Title
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = victoryText
        titleLabel.fontSize = 42
        titleLabel.fontColor = titleColor
        titleLabel.position = CGPoint(x: 0, y: 60)
        titleLabel.verticalAlignmentMode = .center
        container.addChild(titleLabel)

        // Separator
        let sep = SKShapeNode(rectOf: CGSize(width: 120, height: 1))
        sep.fillColor = CombatSceneTheme.muted
        sep.strokeColor = .clear
        sep.position = CGPoint(x: 0, y: 30)
        container.addChild(sep)

        // Stats
        let stats = [
            L("encounter.result.rounds", simulation.round),
            L("encounter.result.hp", simulation.playerHealth),
            L("encounter.result.enemy.hp", simulation.enemyHealth)
        ]
        for (i, stat) in stats.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = stat
            label.fontSize = 14
            label.fontColor = CombatSceneTheme.muted
            label.position = CGPoint(x: 0, y: 10 - CGFloat(i) * 22)
            label.verticalAlignmentMode = .center
            container.addChild(label)
        }

        // Continue button
        let btnBg = SKShapeNode(rectOf: CGSize(width: 130, height: 36), cornerRadius: 8)
        btnBg.fillColor = titleColor
        btnBg.strokeColor = .clear
        btnBg.position = CGPoint(x: 0, y: -70)
        btnBg.name = "btn_continue"
        container.addChild(btnBg)

        let btnLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        btnLabel.text = L("encounter.outcome.continue")
        btnLabel.fontSize = 15
        btnLabel.fontColor = .white
        btnLabel.position = CGPoint(x: 0, y: -70)
        btnLabel.verticalAlignmentMode = .center
        btnLabel.name = "btn_continue"
        container.addChild(btnLabel)

        // Animate in
        overlay.run(SKAction.fadeIn(withDuration: 0.4))
        container.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.fadeIn(withDuration: 0.4)
        ]))
    }

    // MARK: - Frame Update

    public override func update(_ currentTime: TimeInterval) {
        syncRender()
    }
}
