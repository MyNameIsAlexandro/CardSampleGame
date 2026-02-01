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
    private var fateOverlay: SKNode!
    private var handContainer: SKNode!
    private var deckCountLabel: SKLabelNode!
    private var discardCountLabel: SKLabelNode!
    private var energyLabel: SKLabelNode!
    private var intentNode: SKNode?
    private var tooltipNode: SKNode?
    private var combatLogNode: SKNode!
    private var combatLogEntries: [String] = []
    private let maxLogEntries = 5
    private var discardOverlay: SKNode?
    private var longPressTimer: Timer?
    private var touchStartLocation: CGPoint?
    private var isAnimating = false

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

        // Separator line between enemy and player zones
        let separator = SKShapeNode(rectOf: CGSize(width: size.width * 0.6, height: 1))
        separator.fillColor = CombatSceneTheme.separator
        separator.strokeColor = .clear
        separator.position = CGPoint(x: 0, y: 10)
        separator.zPosition = 1
        separator.alpha = 0.5
        addChild(separator)
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

        // Enemy avatar + health bar + label
        if let enemy = simulation.enemyEntity {
            let tag: EnemyTagComponent = nexus.get(unsafe: enemy.identifier)

            let avatar = makeAvatarNode(initial: tag.definitionId, color: CombatSceneTheme.health, radius: 36)
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

        // Player avatar + health bar + label
        if let player = simulation.playerEntity {
            let tag: PlayerTagComponent = nexus.get(unsafe: player.identifier)

            let avatar = makeAvatarNode(initial: tag.name, color: CombatSceneTheme.spirit, radius: 30)
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
        phaseLabel.fontColor = CombatSceneTheme.muted
        phaseLabel.position = CGPoint(x: 0, y: halfH - 30)
        phaseLabel.zPosition = 20
        addChild(phaseLabel)

        roundLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        roundLabel.fontSize = 12
        roundLabel.fontColor = CombatSceneTheme.muted
        roundLabel.position = CGPoint(x: 0, y: halfH - 50)
        roundLabel.zPosition = 20
        addChild(roundLabel)

        let buttonY = -halfH + 60

        attackButton = makeButton(text: "Attack", position: CGPoint(x: -60, y: buttonY), name: "btn_attack")
        skipButton = makeButton(text: "End Turn", position: CGPoint(x: 60, y: buttonY), name: "btn_end_turn")

        fateOverlay = SKNode()
        fateOverlay.position = CGPoint(x: 0, y: 20)
        fateOverlay.zPosition = 50
        addChild(fateOverlay)

        // Hand container — above buttons
        let handY = buttonY + 60
        handContainer = SKNode()
        handContainer.position = CGPoint(x: 0, y: handY)
        handContainer.zPosition = 15
        addChild(handContainer)

        // Deck/discard indicators
        let indicatorY = handY
        deckCountLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        deckCountLabel.fontSize = 11
        deckCountLabel.fontColor = CombatSceneTheme.muted
        deckCountLabel.position = CGPoint(x: -size.width / 2 + 30, y: indicatorY)
        deckCountLabel.zPosition = 15
        addChild(deckCountLabel)

        discardCountLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        discardCountLabel.fontSize = 11
        discardCountLabel.fontColor = CombatSceneTheme.muted
        discardCountLabel.position = CGPoint(x: size.width / 2 - 30, y: indicatorY)
        discardCountLabel.zPosition = 15
        discardCountLabel.name = "btn_discard"
        addChild(discardCountLabel)

        energyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        energyLabel.fontSize = 13
        energyLabel.fontColor = CombatSceneTheme.faith
        energyLabel.position = CGPoint(x: 0, y: indicatorY)
        energyLabel.zPosition = 15
        addChild(energyLabel)

        // Combat log — right side
        combatLogNode = SKNode()
        combatLogNode.position = CGPoint(x: size.width / 2 - 10, y: 0)
        combatLogNode.zPosition = 15
        addChild(combatLogNode)

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
        phaseLabel.text = "Phase: \(simulation.phase)"
        roundLabel.text = "Round \(simulation.round)"

        let isPlayerTurn = simulation.phase == .playerTurn && !simulation.isOver
        attackButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        skipButton.parent?.alpha = isPlayerTurn ? 1.0 : 0.4
        handContainer.alpha = isPlayerTurn ? 1.0 : 0.5

        deckCountLabel.text = "🂠 \(simulation.drawPileCount)"
        discardCountLabel.text = "♻ \(simulation.discardPileCount)"
        energyLabel.text = "⚡ \(simulation.energy)/\(simulation.maxEnergy)"

        updateIntentDisplay()
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
            icon = "✦ Ritual"
            color = CombatSceneTheme.spirit
        case .block, .defend:
            icon = "🛡 Defend"
            color = CombatSceneTheme.muted
        case .buff:
            icon = "↑ Buff"
            color = CombatSceneTheme.faith
        case .debuff:
            icon = "↓ Debuff"
            color = CombatSceneTheme.spirit
        case .prepare:
            icon = "… Prepare"
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
        guard !cards.isEmpty else { return }

        let cardW = CardNode.cardSize.width
        let spacing: CGFloat = 4
        let totalWidth = CGFloat(cards.count) * cardW + CGFloat(cards.count - 1) * spacing
        let startX = -totalWidth / 2 + cardW / 2

        for (i, card) in cards.enumerated() {
            let node = CardNode(card: card)
            node.position = CGPoint(x: startX + CGFloat(i) * (cardW + spacing), y: 0)
            handContainer.addChild(node)
        }
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

        // Dismiss existing tooltip on any new touch
        dismissTooltip()

        // Start long press timer for cards
        let cardNode = findCardNode(at: location)
        if cardNode != nil {
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self, let card = cardNode?.card else { return }
                self.touchStartLocation = nil // prevent tap
                self.showTooltip(for: card, at: location)
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        if tooltipNode != nil {
            dismissTooltip()
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
        for node in nodes(at: location) {
            if let cardNode = node as? CardNode { return cardNode }
            if let parent = node.parent as? CardNode { return parent }
        }
        return nil
    }

    private func handleTap(at location: CGPoint) {
        // Dismiss discard overlay if showing
        if discardOverlay != nil {
            dismissDiscardOverlay()
            return
        }

        // Check continue button even when combat is over
        let tapped = nodes(at: location)
        if tapped.contains(where: { $0.name == "btn_continue" }),
           let outcome = simulation.outcome {
            onCombatEnd?(outcome)
            return
        }

        // Discard pile viewer — works anytime
        if tapped.contains(where: { $0.name == "btn_discard" }) {
            showDiscardOverlay()
            return
        }

        guard !simulation.isOver, simulation.phase == .playerTurn, !isAnimating else { return }

        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
            switch node.name {
            case "btn_attack":
                performPlayerAttack()
                return
            case "btn_end_turn":
                performEndTurn()
                return
            default:
                // Check if tapped a card node (or its children)
                if let cardNode = node as? CardNode {
                    performPlayCard(cardNode.card.id)
                    return
                }
                if let parent = node.parent as? CardNode {
                    performPlayCard(parent.card.id)
                    return
                }
            }
        }
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
        title.text = "Discard Pile (\(cards.count))"
        title.fontSize = 16
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: size.height / 2 - 50)
        title.verticalAlignmentMode = .center
        overlay.addChild(title)

        if cards.isEmpty {
            let empty = SKLabelNode(fontNamed: "AvenirNext-Regular")
            empty.text = "Empty"
            empty.fontSize = 14
            empty.fontColor = CombatSceneTheme.muted
            empty.position = .zero
            empty.verticalAlignmentMode = .center
            overlay.addChild(empty)
        } else {
            // Show cards in a grid
            let cardW = CardNode.cardSize.width + 8
            let cols = min(cards.count, 4)
            let totalW = cardW * CGFloat(cols)
            let startX = -totalW / 2 + cardW / 2

            for (i, card) in cards.enumerated() {
                let col = i % 4
                let row = i / 4
                let node = CardNode(card: card)
                node.position = CGPoint(
                    x: startX + CGFloat(col) * cardW,
                    y: CGFloat(20) - CGFloat(row) * (CardNode.cardSize.height + 10)
                )
                overlay.addChild(node)
            }
        }

        // Tap to close hint
        let hint = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hint.text = "Tap to close"
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
        case .playerAttacked(let dmg, _, _):
            addLogEntry("You deal \(dmg) damage")
        case .playerMissed:
            addLogEntry("You missed!")
        case .enemyAttacked(let dmg, _, _):
            addLogEntry(dmg > 0 ? "Enemy deals \(dmg) damage" : "Enemy attack blocked!")
        case .enemyHealed(let amt):
            addLogEntry("Enemy heals \(amt)")
        case .enemyRitual(let shift):
            addLogEntry("Enemy ritual (\(shift > 0 ? "+" : "")\(Int(shift)))")
        case .enemyBlocked:
            addLogEntry("Enemy defends")
        case .cardPlayed(_, let dmg, let heal, let drawn, let status):
            var parts: [String] = []
            if dmg > 0 { parts.append("\(dmg) dmg") }
            if heal > 0 { parts.append("+\(heal) hp") }
            if drawn > 0 { parts.append("+\(drawn) cards") }
            if let s = status { parts.append(s) }
            addLogEntry("Card: \(parts.joined(separator: ", "))")
        case .insufficientEnergy:
            addLogEntry("Not enough energy!")
        case .roundAdvanced(let r):
            addLogEntry("— Round \(r) —")
        }
    }

    // MARK: - Tooltip

    private func showTooltip(for card: Card, at location: CGPoint) {
        dismissTooltip()

        let tooltip = SKNode()
        tooltip.zPosition = 100

        let cost = card.cost ?? 1
        let abilityText: String
        if let ability = card.abilities.first {
            abilityText = ability.description
        } else {
            abilityText = card.description
        }

        let lines = [
            card.name,
            "Cost: \(cost) ⚡",
            abilityText
        ]
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

    // MARK: - Combat Actions

    private func performPlayerAttack() {
        isAnimating = true
        let event = simulation.playerAttack()
        logCombatEvent(event)

        // Extract fate value from event
        let fateValue: Int
        let damage: Int
        switch event {
        case .playerAttacked(let d, let fv, _):
            fateValue = fv; damage = d
        case .playerMissed(let fv):
            fateValue = fv; damage = 0
        default:
            fateValue = 0; damage = 0
        }

        // Show fate card, then apply hit visuals
        showFateCard(value: fateValue, isCritical: false, label: "Attack") { [weak self] in
            guard let self else { return }

            // Lunge player avatar toward enemy
            if let playerAvatar = self.childNode(withName: "avatar_player") {
                playerAvatar.run(SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 20, duration: 0.1),
                    SKAction.moveBy(x: 0, y: -20, duration: 0.1)
                ]))
            }

            // Shake/flash enemy on hit + particle burst
            if case .playerAttacked = event, let enemy = self.simulation.enemyEntity {
                let anim = self.getOrCreateAnim(for: enemy)
                anim.enqueue(.shake(intensity: 8, duration: 0.3))
                anim.enqueue(.flash(colorName: "white", duration: 0.2))
                self.spawnImpactParticles(at: self.enemyPosition, isCritical: false)
            }

            // Damage number on enemy
            if damage > 0 {
                self.showDamageNumber(damage, at: self.enemyPosition, color: CombatSceneTheme.highlight)
            }

            self.resolveAfterPlayerAction()
        }
    }

    private func performPlayCard(_ cardId: String) {
        isAnimating = true

        // Find the CardNode in hand container before resolving
        let cardNode = handContainer.children.compactMap { $0 as? CardNode }.first { $0.card.id == cardId }

        // Resolve logic immediately (state changes)
        let event = simulation.playCard(cardId: cardId)
        logCombatEvent(event)

        if case .insufficientEnergy = event {
            // Shake the card to indicate insufficient energy
            if let cardNode = cardNode {
                cardNode.run(SKAction.sequence([
                    SKAction.moveBy(x: -4, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 8, y: 0, duration: 0.05),
                    SKAction.moveBy(x: -8, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 4, y: 0, duration: 0.05)
                ]))
            }
            isAnimating = false
            return
        }

        guard case .cardPlayed(_, let damage, let heal, _, _) = event else {
            isAnimating = false
            return
        }

        // Determine fly target
        let targetPos: CGPoint
        if damage > 0 {
            targetPos = enemyPosition
        } else if heal > 0 {
            targetPos = playerPosition
        } else {
            targetPos = CGPoint(x: 0, y: 0)
        }

        // Animate card flying from hand to target
        if let cardNode = cardNode {
            animateCardFly(cardNode: cardNode, to: targetPos) { [weak self] in
                self?.resolveCardEffect(damage: damage, heal: heal)
            }
        } else {
            resolveCardEffect(damage: damage, heal: heal)
        }
    }

    private func animateCardFly(cardNode: CardNode, to target: CGPoint, completion: @escaping () -> Void) {
        // Convert card position from handContainer to scene coordinates
        let scenePos = handContainer.convert(cardNode.position, to: self)

        // Create a flying copy in scene space
        let flyCard = CardNode(card: cardNode.card)
        flyCard.position = scenePos
        flyCard.zPosition = 55
        addChild(flyCard)

        // Add glow behind the card
        let glow = SKShapeNode(rectOf: CGSize(width: CardNode.cardSize.width + 12,
                                               height: CardNode.cardSize.height + 12),
                                cornerRadius: 10)
        glow.fillColor = CombatSceneTheme.highlight.withAlphaComponent(0.4)
        glow.strokeColor = .clear
        glow.zPosition = -1
        glow.setScale(0.8)
        flyCard.addChild(glow)

        // Pulse glow
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.15),
            SKAction.scale(to: 0.9, duration: 0.15)
        ])))

        // Remove original from hand immediately
        cardNode.removeFromParent()

        // Fly to target
        let flyAction = SKAction.move(to: target, duration: 0.3)
        flyAction.timingMode = .easeIn
        let scaleDown = SKAction.scale(to: 0.6, duration: 0.3)

        flyCard.run(SKAction.group([flyAction, scaleDown])) {
            // Flash and remove
            flyCard.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.removeFromParent()
            ])) {
                completion()
            }
        }
    }

    private func resolveCardEffect(damage: Int, heal: Int) {
        if damage > 0 {
            spawnImpactParticles(at: enemyPosition, isCritical: false)
            if let enemy = simulation.enemyEntity {
                let anim = getOrCreateAnim(for: enemy)
                anim.enqueue(.shake(intensity: 6, duration: 0.2))
            }
            showDamageNumber(damage, at: enemyPosition, color: CombatSceneTheme.highlight)
        }
        if heal > 0 {
            let emitter = CombatParticles.healEffect()
            emitter.position = playerPosition
            addChild(emitter)
            emitter.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
            showDamageNumber(heal, at: playerPosition, color: CombatSceneTheme.success, prefix: "+")
        }

        syncRender()
        updateHUD()
        refreshHand()
        isAnimating = false
    }

    private func performEndTurn() {
        simulation.endTurn()
        syncRender()
        updateHUD()
        isAnimating = true
        run(SKAction.wait(forDuration: 0.3)) { [weak self] in
            self?.resolveEnemyTurn()
        }
    }

    private func resolveAfterPlayerAction() {
        syncRender()
        updateHUD()
        refreshHand()
        isAnimating = false

        if simulation.isOver {
            handleCombatEnd()
            return
        }

        // Enemy turn after short delay
        isAnimating = true
        run(SKAction.wait(forDuration: 0.6)) { [weak self] in
            self?.resolveEnemyTurn()
        }
    }

    private func resolveEnemyTurn() {
        let event = simulation.resolveEnemyTurn()
        logCombatEvent(event)

        // Extract fate value
        let fateValue: Int
        let damage: Int
        switch event {
        case .enemyAttacked(let d, let fv, _):
            fateValue = fv; damage = d
        default:
            fateValue = 0; damage = 0
        }

        showFateCard(value: fateValue, isCritical: false, label: "Defense") { [weak self] in
            guard let self else { return }

            // Lunge enemy avatar toward player
            if let enemyAvatar = self.childNode(withName: "avatar_enemy") {
                enemyAvatar.run(SKAction.sequence([
                    SKAction.moveBy(x: 0, y: -15, duration: 0.1),
                    SKAction.moveBy(x: 0, y: 15, duration: 0.1)
                ]))
            }

            // Shake player on hit + particle burst
            if case .enemyAttacked = event, let player = self.simulation.playerEntity {
                let anim = self.getOrCreateAnim(for: player)
                anim.enqueue(.shake(intensity: 5, duration: 0.2))
                self.spawnImpactParticles(at: self.playerPosition, isCritical: false)
            }

            if damage > 0 {
                self.showDamageNumber(damage, at: self.playerPosition, color: CombatSceneTheme.health)
            }

            self.syncRender()
            self.updateHUD()
            self.isAnimating = false

            if self.simulation.isOver {
                self.handleCombatEnd()
            }
        }
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

    // MARK: - Fate Card Overlay

    private func showFateCard(value: Int, isCritical: Bool, label: String, completion: @escaping () -> Void) {
        let card = FateCardNode()
        card.alpha = 0
        fateOverlay.addChild(card)

        // Context label below card
        let context = SKLabelNode(fontNamed: "AvenirNext-Medium")
        let sign = value > 0 ? "+\(value)" : "\(value)"
        context.text = "\(label) \(sign)"
        context.fontSize = 14
        context.fontColor = CombatSceneTheme.muted
        context.position = CGPoint(x: 0, y: -(FateCardNode.cardSize.height / 2 + 14))
        context.verticalAlignmentMode = .top
        card.addChild(context)

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
        label.position = CGPoint(x: position.x, y: position.y + 30)
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

        let isVictory = outcome == .victory
        let titleColor: SKColor = isVictory ? CombatSceneTheme.success : CombatSceneTheme.health

        // Title
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = isVictory ? "Victory!" : "Defeat"
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
            "Rounds: \(simulation.round)",
            "HP: \(simulation.playerHealth)",
            "Enemy HP: \(simulation.enemyHealth)"
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
        btnLabel.text = "Continue"
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
