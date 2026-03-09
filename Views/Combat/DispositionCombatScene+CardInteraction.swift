/// Файл: Views/Combat/DispositionCombatScene+CardInteraction.swift
/// Назначение: Card drag visuals, action button highlights, preview semantics, long-press details.
/// Зона ответственности: Lift/move/return cards, action button state, hit frames, details overlay.
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import Dispatch
import SpriteKit
import TwilightEngine

enum ActionPreviewTone: Equatable {
    case neutral
    case boosted
    case weakened
    case disabled
}

struct ActionPreviewPresentation: Equatable {
    let text: String
    let tone: ActionPreviewTone

    var color: SKColor {
        switch tone {
        case .neutral:
            return .white
        case .boosted:
            return SKColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1)
        case .weakened:
            return SKColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1)
        case .disabled:
            return .gray
        }
    }
}

// MARK: - Card Drag Visuals

extension DispositionCombatScene {

    func liftCard(id: String) {
        guard let node = handCardNodes[id] else { return }
        node.removeAction(forKey: "cardSway")
        node.zPosition = 35
        let scaleUp = SKAction.scale(to: RitualTheme.dragLiftScale, duration: 0.15)
        scaleUp.timingMode = .easeOut
        node.run(scaleUp, withKey: "cardLift")
    }

    func moveCard(id: String, to position: CGPoint) {
        guard let node = handCardNodes[id] else { return }
        let layer = handLayer ?? self
        let localPos = convert(position, to: layer)
        node.position = localPos
        node.zRotation = 0
    }

    func returnCardToHand(id: String) {
        guard let node = handCardNodes[id] else { return }
        let targetPos = originalCardPositions[id] ?? node.position
        let targetRot = originalCardRotations[id] ?? node.zRotation
        let targetZ = originalCardZPositions[id] ?? 20
        let targetScale = originalCardScales[id] ?? 1.0

        node.removeAction(forKey: "cardSway")
        node.removeAction(forKey: "cardLift")

        // Remove selection glow
        removeSelectionGlow(from: node)

        let move = SKAction.move(to: targetPos, duration: 0.25)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: targetScale, duration: 0.25)
        scale.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: targetRot, duration: 0.2)
        rotate.timingMode = .easeOut
        node.run(SKAction.group([move, scale, rotate])) { [weak self] in
            let index = Int(targetZ) - 20
            self?.addCardSway(to: node, index: index)
        }
        node.zPosition = targetZ
    }

    // MARK: - Zone Highlights

    func highlightDropZone(at point: CGPoint) {
        clearHighlights()
        if let action = hitTestActionButton(at: point) {
            switch action {
            case .strike:
                highlightActionButton(strikeButton)
            case .influence:
                highlightActionButton(influenceButton)
            case .sacrifice:
                highlightActionButton(sacrificeButton)
            }
        }
    }

    func clearHighlights() {
        clearActionButtonHighlight(strikeButton)
        clearActionButtonHighlight(influenceButton)
        clearActionButtonHighlight(sacrificeButton)
    }

    // MARK: - Action Button Highlights

    func highlightActionButton(_ button: SKNode?) {
        guard let button, let bg = button.children.first as? SKShapeNode else { return }
        bg.fillColor = bg.strokeColor.withAlphaComponent(0.35)
    }

    func clearActionButtonHighlight(_ button: SKNode?) {
        guard let button, let bg = button.children.first as? SKShapeNode else { return }
        bg.fillColor = bg.strokeColor.withAlphaComponent(0.15)
    }

    func flashActionButton(_ button: SKNode?) {
        guard let button, let bg = button.children.first as? SKShapeNode else { return }
        let originalFill = bg.strokeColor.withAlphaComponent(0.15)
        let flash = SKAction.sequence([
            SKAction.run { bg.fillColor = bg.strokeColor.withAlphaComponent(0.5) },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { bg.fillColor = originalFill }
        ])
        button.run(flash)
    }

    // MARK: - Selection Glow

    func addSelectionGlow(to node: SKNode) {
        guard let border = node.childNode(withName: "cardBorder") as? SKShapeNode else { return }
        border.glowWidth = 4
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { border.glowWidth = 5 },
            SKAction.wait(forDuration: 0.6),
            SKAction.run { border.glowWidth = 3 },
            SKAction.wait(forDuration: 0.6)
        ]))
        border.run(pulse, withKey: "glowPulse")
    }

    func removeSelectionGlow(from node: SKNode) {
        guard let border = node.childNode(withName: "cardBorder") as? SKShapeNode else { return }
        border.removeAction(forKey: "glowPulse")
        border.glowWidth = 1
    }

    // MARK: - Neighbor Spread

    func spreadNeighbors(aroundSelectedId selectedId: String) {
        guard let vm = viewModel else { return }
        let cards = vm.hand
        guard let selectedIndex = cards.firstIndex(where: { $0.id == selectedId }) else { return }
        let spreadAmount: CGFloat = 15

        for (i, card) in cards.enumerated() {
            guard card.id != selectedId,
                  let node = handCardNodes[card.id],
                  let origPos = originalCardPositions[card.id] else { continue }

            let offset: CGFloat = i < selectedIndex ? -spreadAmount : spreadAmount
            let targetPos = CGPoint(x: origPos.x + offset, y: origPos.y)
            let move = SKAction.move(to: targetPos, duration: 0.2)
            move.timingMode = .easeOut
            node.run(move, withKey: "neighborSpread")
        }
    }

    func resetNeighborSpread() {
        for (cardId, node) in handCardNodes {
            guard let origPos = originalCardPositions[cardId] else { continue }
            node.removeAction(forKey: "neighborSpread")
            let move = SKAction.move(to: origPos, duration: 0.2)
            move.timingMode = .easeOut
            node.run(move, withKey: "neighborReturn")
        }
    }

    // MARK: - Preview Semantics

    func actionPreviewPresentation(
        for action: CombatAction,
        value: Int,
        basePower: Int,
        enabled: Bool = true
    ) -> ActionPreviewPresentation {
        guard enabled else {
            return ActionPreviewPresentation(text: "\u{2014}", tone: .disabled)
        }

        switch action {
        case .sacrifice:
            return ActionPreviewPresentation(text: "+1 \u{26A1}", tone: .neutral)
        case .strike, .influence:
            let sign = action == .strike ? "-" : "+"
            let tone: ActionPreviewTone
            if value > basePower {
                tone = .boosted
            } else if value < basePower {
                tone = .weakened
            } else {
                tone = .neutral
            }
            let suffix = tone == .boosted ? "\u{2191}" : ""
            return ActionPreviewPresentation(text: "\(sign)\(value)\(suffix)", tone: tone)
        }
    }

    // MARK: - Hit Frames

    func expandedHitFrame(for node: SKNode, padding: CGFloat = 10) -> CGRect {
        node.calculateAccumulatedFrame().insetBy(dx: -padding, dy: -padding)
    }

    // MARK: - Long Press Targets

    func interactionTarget(at point: CGPoint) -> InteractionDetailsTarget? {
        if let cardId = hitTestCard(at: point) {
            return .card(cardId)
        }
        if hitTestHUDArea(at: point) {
            return .hud
        }
        if hitTestEnemyArea(at: point) {
            return .enemy
        }
        return nil
    }

    func hitTestHUDArea(at point: CGPoint) -> Bool {
        let hudBand = CGRect(
            x: 0,
            y: size.height - Layout.hudTopPad - 36,
            width: size.width,
            height: 56
        )
        return hudBand.contains(point)
    }

    func hitTestEnemyArea(at point: CGPoint) -> Bool {
        if let idolNode, expandedHitFrame(for: idolNode, padding: 18).contains(point) {
            return true
        }
        if let intentLabel,
           expandedHitFrame(for: intentLabel, padding: 12).contains(point) {
            return true
        }
        return false
    }

    func scheduleInteractionLongPress(for target: InteractionDetailsTarget) {
        cancelInteractionLongPress()
        pendingInteractionTarget = target
        interactionLongPressTriggered = false

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.phase == .playerAction else { return }
            self.interactionLongPressTriggered = true
            self.showInteractionDetails(for: target)
        }
        pendingInteractionLongPress = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + DispositionCombatScene.longPressDuration,
            execute: work
        )
    }

    func cancelInteractionLongPress() {
        pendingInteractionLongPress?.cancel()
        pendingInteractionLongPress = nil
        pendingInteractionTarget = nil
    }

    func resetInteractionLongPressState() {
        interactionLongPressTriggered = false
        cancelInteractionLongPress()
    }

    // MARK: - Details Overlay

    func hideInteractionDetails() {
        interactionDetailsNode?.removeFromParent()
        interactionDetailsNode = nil
    }

    func showInteractionHintIfNeeded(at point: CGPoint) {
        guard !hasShownInteractionHint else { return }
        hasShownInteractionHint = true
        showFloatingText(
            L10n.dispositionHintLongPress.localized,
            at: CGPoint(x: point.x, y: point.y + 32),
            color: SKColor(white: 0.85, alpha: 1)
        )
    }

    func showInteractionDetails(for target: InteractionDetailsTarget) {
        guard let content = interactionDetailsContent(for: target) else { return }
        hideInteractionDetails()

        let lineHeight: CGFloat = 18
        let panelWidth: CGFloat = 260
        let panelHeight = 54 + CGFloat(content.lines.count) * lineHeight
        let posX = min(max(content.anchor.x, panelWidth / 2 + 16), size.width - panelWidth / 2 - 16)
        let preferredY = content.anchor.y > size.height * 0.5
            ? content.anchor.y - panelHeight / 2 - 28
            : content.anchor.y + panelHeight / 2 + 28
        let posY = min(max(preferredY, panelHeight / 2 + 24), size.height - panelHeight / 2 - 24)

        let container = SKNode()
        container.name = "interactionDetails"
        container.position = CGPoint(x: posX, y: posY)
        container.zPosition = 120
        container.alpha = 0

        let bg = SKShapeNode(
            rectOf: CGSize(width: panelWidth, height: panelHeight),
            cornerRadius: 12
        )
        bg.fillColor = SKColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 0.96)
        bg.strokeColor = SKColor(white: 0.45, alpha: 0.35)
        bg.lineWidth = 1
        container.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.name = "interactionDetailsTitle"
        title.text = content.title
        title.fontSize = 14
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -panelWidth / 2 + 14, y: panelHeight / 2 - 18)
        container.addChild(title)

        for (index, line) in content.lines.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.name = "interactionDetailsLine\(index)"
            label.text = line
            label.fontSize = 12
            label.fontColor = SKColor(white: 0.85, alpha: 1)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.position = CGPoint(
                x: -panelWidth / 2 + 14,
                y: panelHeight / 2 - 40 - CGFloat(index) * lineHeight
            )
            container.addChild(label)
        }

        overlayLayer?.addChild(container)
        interactionDetailsNode = container
        container.run(SKAction.fadeIn(withDuration: 0.12))
    }

    func interactionDetailsContent(
        for target: InteractionDetailsTarget
    ) -> (title: String, lines: [String], anchor: CGPoint)? {
        switch target {
        case .card(let cardId):
            return cardDetailsContent(for: cardId)
        case .hud:
            return hudDetailsContent()
        case .enemy:
            return enemyDetailsContent()
        }
    }

    func cardDetailsContent(
        for cardId: String
    ) -> (title: String, lines: [String], anchor: CGPoint)? {
        guard let vm = viewModel,
              let card = vm.hand.first(where: { $0.id == cardId }) else { return nil }

        let basePower = card.power ?? 1
        let strikePreview = actionPreviewPresentation(
            for: .strike,
            value: vm.previewStrikePower(card: card),
            basePower: basePower
        )
        let influencePreview = actionPreviewPresentation(
            for: .influence,
            value: vm.previewInfluencePower(card: card),
            basePower: basePower
        )
        let strikeVulnerability = vm.vulnerabilityModifier(for: .strike)
        let influenceVulnerability = vm.vulnerabilityModifier(for: .influence)

        var lines = [
            "\u{26A1} \(card.cost ?? 1)   \u{2726} \(basePower)",
            "\u{2694} \(strikePreview.text)   \u{263D} \(influencePreview.text)",
            resonanceDetailsText(for: vm.resonanceZone)
        ]

        var modifierParts: [String] = []
        if vm.streakCount > 1 {
            modifierParts.append("\u{21BB} x\(vm.streakCount)")
        }
        if vm.enemyModeStrikeBonus > 0 {
            modifierParts.append("\u{2191}\(vm.enemyModeStrikeBonus)")
        }
        if vm.defendReduction > 0 {
            modifierParts.append("\u{1F6E1} -\(vm.defendReduction)")
        }
        if vm.provokePenalty > 0 {
            modifierParts.append("\u{26A1} -\(vm.provokePenalty)")
        }
        if vm.adaptPenalty > 0 {
            modifierParts.append("\u{21BB} -\(vm.adaptPenalty)")
        }
        if !modifierParts.isEmpty {
            lines.append(modifierParts.joined(separator: "   "))
        }

        if strikeVulnerability != 0 || influenceVulnerability != 0 {
            lines.append(
                "\u{2694} \(signedValue(strikeVulnerability))   \u{263D} \(signedValue(influenceVulnerability))"
            )
        }

        if let keyword = vm.lastFateKeyword {
            lines.append(fateKeywordDisplay(for: keyword).0)
        }

        let anchor: CGPoint
        if let node = handCardNodes[cardId] {
            anchor = convert(node.position, from: handLayer ?? self)
        } else {
            anchor = CGPoint(x: size.width / 2, y: size.height * Layout.hand)
        }
        return (card.name, lines, anchor)
    }

    func hudDetailsContent() -> (title: String, lines: [String], anchor: CGPoint)? {
        guard let vm = viewModel else { return nil }

        let title = (childNode(withName: "phaseLabel") as? SKLabelNode)?.text
            ?? L10n.encounterPhasePlayerAction.localized

        var lines = [
            "\u{2665} \(vm.heroHP)/\(vm.heroMaxHP)   \u{26A1} \(vm.energy)/\(vm.startingEnergy)",
            "\u{1F590} \(vm.hand.count)/\(vm.startingHandSize)   \u{21BA} \(vm.discardCount)   \u{2716} \(vm.exhaustCount)",
            "\(resonanceDetailsText(for: vm.resonanceZone))   \(L10n.combatTurnNumber.localized(with: vm.turnsPlayed + 1))"
        ]

        var modifierParts: [String] = []
        if vm.defendReduction > 0 {
            modifierParts.append("\u{1F6E1} \(vm.defendReduction)")
        }
        if vm.provokePenalty > 0 {
            modifierParts.append("\u{26A1} \(vm.provokePenalty)")
        }
        if vm.adaptPenalty > 0 {
            modifierParts.append("\u{21BB} \(vm.adaptPenalty)")
        }
        if vm.enemySacrificeBuff > 0 {
            modifierParts.append("\u{2666} \(vm.enemySacrificeBuff)")
        }
        if !modifierParts.isEmpty {
            lines.append(modifierParts.joined(separator: "   "))
        }

        return (title, lines, CGPoint(x: size.width / 2, y: size.height - Layout.hudTopPad))
    }

    func enemyDetailsContent() -> (title: String, lines: [String], anchor: CGPoint)? {
        guard let vm = viewModel else { return nil }

        let strikeVulnerability = vm.vulnerabilityModifier(for: .strike)
        let influenceVulnerability = vm.vulnerabilityModifier(for: .influence)

        var lines = [
            modeDetailsText(enemyModeState?.currentMode ?? .normal),
            resonanceDetailsText(for: vm.resonanceZone),
            "\u{2694} \(signedValue(strikeVulnerability))   \u{263D} \(signedValue(influenceVulnerability))"
        ]

        var modifierParts: [String] = []
        if vm.defendReduction > 0 {
            modifierParts.append("\u{1F6E1} \(vm.defendReduction)")
        }
        if vm.adaptPenalty > 0 {
            modifierParts.append("\u{21BB} \(vm.adaptPenalty)")
        }
        if vm.enemySacrificeBuff > 0 {
            modifierParts.append("\u{2666} \(vm.enemySacrificeBuff)")
        }
        if !modifierParts.isEmpty {
            lines.append(modifierParts.joined(separator: "   "))
        }

        if let pendingEnemyAction {
            let (text, _, _) = enemyActionDisplay(pendingEnemyAction)
            lines.append(text)
        }

        let anchor = idolNode?.position ?? CGPoint(x: size.width / 2, y: size.height * Layout.idol)
        return (vm.enemyType.capitalized, lines, anchor)
    }

    func modeDetailsText(_ mode: EnemyMode) -> String {
        switch mode {
        case .normal:
            return L10n.dispositionDetailsModeNormal.localized
        case .survival:
            return L10n.dispositionDetailsModeSurvival.localized
        case .desperation:
            return L10n.dispositionDetailsModeDesperation.localized
        case .weakened:
            return L10n.dispositionDetailsModeWeakened.localized
        }
    }

    func resonanceDetailsText(for zone: TwilightEngine.ResonanceZone) -> String {
        switch zone {
        case .deepNav:
            return "\u{263D} \(L10n.resonanceZoneDeepNav.localized)"
        case .nav:
            return "\u{263D} \(L10n.resonanceZoneNav.localized)"
        case .yav:
            return "\u{262F} \(L10n.resonanceZoneYav.localized)"
        case .prav:
            return "\u{2600} \(L10n.resonanceZonePrav.localized)"
        case .deepPrav:
            return "\u{2600} \(L10n.resonanceZoneDeepPrav.localized)"
        }
    }

    func signedValue(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
