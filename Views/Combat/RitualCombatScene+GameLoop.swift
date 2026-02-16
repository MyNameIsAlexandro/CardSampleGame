/// Файл: Views/Combat/RitualCombatScene+GameLoop.swift
/// Назначение: Game loop ритуальной сцены — touch, DragCommand, фазы, эмиссия результата.
/// Зона ответственности: Input handling, phase transitions, combat resolution.
/// Контекст: Phase 3 Ritual Combat (R9). Extension of RitualCombatScene.

import SpriteKit
import TwilightEngine

// MARK: - Game Loop

extension RitualCombatScene {

    // MARK: - Phase Machine

    func advancePhase() {
        guard let sim = simulation else { return }
        logEntry("Раунд \(sim.round) · \(phaseDisplayName(sim.phase))", type: .system)

        switch sim.phase {
        case .playerAction:
            disableInput()
            sealNodes.forEach { $0.setActive(false) }

            if sim.round > 1 {
                showEnemyIntent { [weak self] in
                    self?.enableInput()
                    self?.updateSealVisibility()
                    self?.syncVisuals()
                }
            } else {
                enableInput()
                updateSealVisibility()
            }

        case .resolution:
            disableInput()
            sealNodes.forEach { $0.setActive(false) }
            resolveEnemyTurn()

        case .finished:
            disableInput()
            sealNodes.forEach { $0.setActive(false) }
            emitResult()
        }
    }

    private func showEnemyIntent(completion: @escaping () -> Void) {
        guard let sim = simulation else { completion(); return }

        setSubPhaseLabel("Угроза")

        for (i, enemy) in sim.enemies.enumerated() where enemy.hp > 0 {
            guard i < idolNodes.count else { continue }
            let delay = SKAction.wait(forDuration: Double(i) * 0.1)
            let show = SKAction.run { [weak self] in
                self?.idolNodes[i].showIntent(type: "ATK", value: enemy.power)
            }
            run(SKAction.sequence([delay, show]))
        }
        onHaptic?("light")

        run(SKAction.wait(forDuration: 1.2)) { [weak self] in
            self?.idolNodes.forEach { $0.hideIntent() }
            self?.restorePhaseLabel()
            completion()
        }
    }

    func updateSealVisibility() {
        guard let sim = simulation else { return }
        let hasSelection = !sim.selectedCardIds.isEmpty

        for seal in sealNodes {
            switch seal.sealType {
            case .wait:
                seal.setActive(true)
            case .strike, .speak:
                seal.setActive(hasSelection)
            }
        }
    }

    private func enableInput() {
        inputEnabled = true
    }

    private func disableInput() {
        inputEnabled = false
        selectedTargetId = nil
        idolNodes.forEach { $0.setHoverTarget(false) }
        cancelSealDrag()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        dismissCardTooltip()

        if let toggle = childNode(withName: "logToggle"),
           toggle.frame.contains(location) {
            combatLog?.toggle()
            return
        }

        guard inputEnabled else { return }

        if let cardId = hitTestCard(at: location) {
            touchStartLocation = location
            dragController?.beginTouch(cardId: cardId)
            liftCard(id: cardId)
            return
        }

        if let sealIndex = hitTestSeal(at: location) {
            beginSealDrag(sealIndex: sealIndex, at: location)
            return
        }

        if hitTestBonfire(at: location) {
            handleBonfireTap()
            return
        }

        if let idolId = hitTestIdol(at: location) {
            selectedTargetId = idolId
            idolNodes.forEach { $0.setHoverTarget($0.enemyId == idolId) }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first else { return }
        let location = touch.location(in: self)

        if draggingSealType != nil {
            updateSealDrag(at: location)
            return
        }

        if let start = touchStartLocation {
            let offset = CGSize(width: location.x - start.x, height: location.y - start.y)
            dragController?.updateDrag(offset: offset)

            if case .dragging(let cardId, _) = dragController?.state {
                moveCard(id: cardId, to: location)
            }
        }

        if let idolId = hitTestIdol(at: location) {
            selectedTargetId = idolId
            idolNodes.forEach { $0.setHoverTarget($0.enemyId == idolId) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchStartLocation = nil

        if draggingSealType != nil {
            endSealDrag(at: location)
            return
        }

        guard let dc = dragController else {
            idolNodes.forEach { $0.setHoverTarget(false) }
            return
        }

        switch dc.state {
        case .pressing(let cardId):
            dc.reset()
            draggedCardId = nil
            if simulation?.selectedCardIds.contains(cardId) == true {
                simulation?.deselectCard(cardId)
                syncVisuals()
                updateSealVisibility()
            } else {
                snapCardToCircle(id: cardId) { [weak self] in
                    self?.handleDragCommand(.selectCard(cardId: cardId))
                    self?.updateSealVisibility()
                }
            }

        case .dragging(let cardId, _):
            dc.reset()
            let zone = determineDropZone(at: location)
            switch zone {
            case .circle:
                snapCardToCircle(id: cardId) { [weak self] in
                    self?.handleDragCommand(.selectCard(cardId: cardId))
                    self?.updateSealVisibility()
                }
            case .bonfire:
                snapCardToBonfire(id: cardId) { [weak self] in
                    self?.handleDragCommand(.burnForEffort(cardId: cardId))
                }
            case .none:
                returnCardToHand(id: cardId)
                handleDragCommand(.cancelDrag)
            }

        case .idle, .released:
            break
        }

        idolNodes.forEach { $0.setHoverTarget(false) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartLocation = nil
        if let cardId = draggedCardId {
            returnCardToHand(id: cardId)
        }
        cancelSealDrag()
        dragController?.cancel()
        idolNodes.forEach { $0.setHoverTarget(false) }
    }

    // MARK: - Seal Drag

    private func beginSealDrag(sealIndex: Int, at location: CGPoint) {
        guard sealIndex < sealNodes.count else { return }
        let seal = sealNodes[sealIndex]
        draggingSealType = seal.sealType

        let ghost = SKShapeNode(rectOf: SealNode.size, cornerRadius: 10)
        ghost.fillColor = SKColor(red: 0.25, green: 0.20, blue: 0.30, alpha: 0.8)
        ghost.strokeColor = SKColor(red: 0.60, green: 0.50, blue: 0.70, alpha: 1)
        ghost.lineWidth = 2
        ghost.zPosition = 40

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = seal.sealType.icon
        label.fontSize = 26
        label.verticalAlignmentMode = .center
        ghost.addChild(label)

        ghost.position = location
        ghost.setScale(1.3)
        addChild(ghost)
        draggingSealGhost = ghost

        onHaptic?("light")
    }

    private func updateSealDrag(at location: CGPoint) {
        draggingSealGhost?.position = location

        targetingArrow?.removeFromParent()
        targetingArrow = nil

        if let idolId = hitTestIdol(at: location) {
            selectedTargetId = idolId
            idolNodes.forEach { idol in
                let isTarget = idol.enemyId == idolId
                idol.setHoverTarget(isTarget, sealType: isTarget ? draggingSealType : nil)
                idol.alpha = isTarget ? 1.0 : 0.5
            }
        } else {
            idolNodes.forEach {
                $0.setHoverTarget(false)
                $0.alpha = 1.0
            }

            if let sealType = draggingSealType,
               let nearestIdol = nearestAliveIdol(to: location) {
                let arrow = makeTargetingArrow(from: location, to: nearestIdol.position, sealType: sealType)
                addChild(arrow)
                targetingArrow = arrow
            }
        }
    }

    private func endSealDrag(at location: CGPoint) {
        guard let sealType = draggingSealType else { return }
        cancelSealDrag()

        let targetId = hitTestIdol(at: location) ?? nearestAliveIdol(to: location)?.enemyId
        selectedTargetId = targetId

        switch sealType {
        case .strike:
            performCommitAttack()
        case .speak:
            performCommitInfluence()
        case .wait:
            performSkipTurn()
        }
    }

    private func cancelSealDrag() {
        draggingSealGhost?.removeFromParent()
        draggingSealGhost = nil
        draggingSealType = nil
        targetingArrow?.removeFromParent()
        targetingArrow = nil
        idolNodes.forEach { $0.alpha = 1.0 }
    }

    private func nearestAliveIdol(to point: CGPoint) -> IdolNode? {
        guard let sim = simulation else { return nil }
        var best: IdolNode?
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for (i, idol) in idolNodes.enumerated() {
            guard i < sim.enemies.count, sim.enemies[i].hp > 0 else { continue }
            let dist = hypot(point.x - idol.position.x, point.y - idol.position.y)
            if dist < bestDist { bestDist = dist; best = idol }
        }
        return best
    }

    private func makeTargetingArrow(from start: CGPoint, to end: CGPoint, sealType: SealType) -> SKShapeNode {
        let path = CGMutablePath()
        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2 + 30
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: midX, y: midY))

        let arrow = SKShapeNode(path: path)
        arrow.strokeColor = sealType == .speak
            ? SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.6)
            : SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.6)
        arrow.lineWidth = 2
        arrow.zPosition = 35
        arrow.glowWidth = 3
        return arrow
    }

    // MARK: - Hit Testing

    private func hitTestCard(at point: CGPoint) -> String? {
        let layer = handLayer ?? self
        let localPoint = convert(point, to: layer)
        for (cardId, node) in handCardNodes {
            if node.frame.contains(localPoint) || node.contains(localPoint) {
                return cardId
            }
        }
        return nil
    }

    private func hitTestSeal(at point: CGPoint) -> Int? {
        for (i, seal) in sealNodes.enumerated() where seal.isActive {
            let localPoint = convert(point, to: seal.parent ?? self)
            if seal.frame.contains(localPoint) {
                return i
            }
        }
        return nil
    }

    private func hitTestIdol(at point: CGPoint) -> String? {
        for idol in idolNodes {
            let localPoint = convert(point, to: idol.parent ?? self)
            let idolFrame = CGRect(
                x: idol.position.x - IdolNode.frameSize.width / 2,
                y: idol.position.y - IdolNode.frameSize.height / 2,
                width: IdolNode.frameSize.width,
                height: IdolNode.frameSize.height
            )
            if idolFrame.contains(localPoint) {
                return idol.enemyId
            }
        }
        return nil
    }

    private func hitTestBonfire(at point: CGPoint) -> Bool {
        guard let bonfire = bonfireNode else { return false }
        let dist = hypot(point.x - bonfire.position.x, point.y - bonfire.position.y)
        return dist < 55
    }

    private func determineDropZone(at point: CGPoint) -> DragDropZone {
        if let circle = ritualCircle {
            let dist = hypot(point.x - circle.position.x, point.y - circle.position.y)
            if dist < 70 { return .circle }
        }
        if hitTestBonfire(at: point) { return .bonfire }
        return .none
    }

    // MARK: - Drag Command

    func handleDragCommand(_ command: DragCommand) {
        guard let sim = simulation else { return }

        switch command {
        case .selectCard(let cardId):
            sim.selectCard(cardId)
            let name = sim.hand.first(where: { $0.id == cardId })?.name ?? cardId
            logEntry("Выбрана карта: \(name)")
            syncVisuals()

        case .burnForEffort(let cardId):
            if sim.burnForEffort(cardId) {
                let name = sim.hand.first(where: { $0.id == cardId })?.name ?? cardId
                logEntry("Сожжена для усилия: \(name)")
                bonfireNode?.playBurnAnimation()
                onSoundEffect?("effortBurn")
                onHaptic?("medium")
                syncVisuals()
            }

        case .showTooltip(let cardId):
            showCardTooltip(cardId: cardId)

        case .cancelDrag:
            syncVisuals()
        }
    }

    // MARK: - Seal Actions (Commit)

    func performCommitAttack() {
        guard let sim = simulation,
              !sim.selectedCardIds.isEmpty else { return }

        let targetId = selectedTargetId ?? sim.enemies.first(where: { $0.hp > 0 })?.id
        guard let target = targetId else { return }

        accumulatedCardsPlayed += sim.selectedCardIds.count
        let result = sim.commitAttack(targetId: target)
        accumulatedDamageDealt += result.damage
        logEntry("Удар → \(result.damage) урона", type: .damage)

        if let fate = result.fateDrawResult {
            setSubPhaseLabel("Судьба")
            let idolPos = idolNodes.first(where: { $0.enemyId == target })?.position
            fateDirector?.onRevealComplete = { [weak self] in
                self?.restorePhaseLabel()
                self?.afterAttackResolution(targetId: target)
            }
            fateDirector?.beginReveal(
                cardName: fate.card.name,
                effectiveValue: fate.effectiveValue,
                isSuitMatch: false,
                isCritical: fate.isCritical,
                targetPosition: idolPos,
                damageValue: result.isHit ? result.damage : nil
            )
        } else {
            afterAttackResolution(targetId: target)
        }
    }

    private func afterAttackResolution(targetId: String) {
        guard let sim = simulation else { return }
        syncVisuals()

        if let enemy = sim.enemies.first(where: { $0.id == targetId }), enemy.hp <= 0 {
            if let idol = idolNodes.first(where: { $0.enemyId == targetId }) {
                idol.playKillAnimation { [weak self] in
                    self?.checkCombatEnd()
                }
                onHaptic?("heavy")
                return
            }
        }

        checkCombatEnd()
    }

    func performCommitInfluence() {
        guard let sim = simulation,
              !sim.selectedCardIds.isEmpty else { return }

        let targetId = selectedTargetId ?? sim.enemies.first(where: {
            $0.hp > 0 && ($0.wp ?? 0) > 0
        })?.id
        guard let target = targetId else { return }

        accumulatedCardsPlayed += sim.selectedCardIds.count
        let result = sim.commitInfluence(targetId: target)
        accumulatedDamageDealt += result.damage
        logEntry("Влияние → \(result.damage) к воле", type: .damage)

        if let fate = result.fateDrawResult {
            setSubPhaseLabel("Судьба")
            let idolPos = idolNodes.first(where: { $0.enemyId == target })?.position
            fateDirector?.onRevealComplete = { [weak self] in
                self?.restorePhaseLabel()
                self?.afterInfluenceResolution(targetId: target, isPacified: result.isPacified)
            }
            fateDirector?.beginReveal(
                cardName: fate.card.name,
                effectiveValue: fate.effectiveValue,
                isSuitMatch: false,
                isCritical: fate.isCritical,
                targetPosition: idolPos,
                damageValue: result.damage
            )
        } else {
            afterInfluenceResolution(targetId: target, isPacified: result.isPacified)
        }
    }

    private func afterInfluenceResolution(targetId: String, isPacified: Bool) {
        syncVisuals()

        if isPacified {
            if let idol = idolNodes.first(where: { $0.enemyId == targetId }) {
                idol.playPacifyAnimation { [weak self] in
                    self?.checkCombatEnd()
                }
                onHaptic?("medium")
                return
            }
        }

        checkCombatEnd()
    }

    private func performSkipTurn() {
        transitionToResolution()
    }

    // MARK: - Resolution Phase

    private func transitionToResolution() {
        guard let sim = simulation else { return }
        sim.setPhase(.resolution)
        advancePhase()
    }

    func resolveEnemyTurn() {
        guard let sim = simulation else { return }

        let attacks = sim.resolveEnemyTurn()
        for attack in attacks {
            accumulatedDamageTaken += attack.damage
            logEntry("Враг атакует → \(attack.damage) урона", type: .damage)
        }

        if !attacks.isEmpty {
            amuletNode?.playDamageFlash()
            onHaptic?("medium")
        }
        syncVisuals()

        run(SKAction.wait(forDuration: 0.6)) { [weak self] in
            self?.advancePhase()
        }
    }

    // MARK: - Combat End

    private func checkCombatEnd() {
        guard let sim = simulation else { return }

        let allDefeated = sim.enemies.allSatisfy { $0.hp <= 0 || $0.isPacified }
        if allDefeated {
            sim.setPhase(.finished)
            advancePhase()
        } else {
            transitionToResolution()
        }
    }

    private func emitResult() {
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
