/// Файл: Packages/EchoScenes/Sources/EchoScenes/CombatScene+Flow.swift
/// Назначение: Содержит реализацию файла CombatScene+Flow.swift.
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

// Turn flow, animations, combat end
extension CombatScene {
    func performPlayerAttack() {
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
    func performPlayerInfluence() {
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

    func performEndTurn() {
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

    // MARK: - Phase: Enemy Turn Banner

    func showEnemyTurnBanner(completion: @escaping () -> Void) {
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

    func runEnemyPhase(roundBefore: Int) {
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

    func showRoundEnd(roundBefore: Int) {
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

    func finishRound() {
        refreshHand()
        updateHUD()
        isAnimating = false
    }

    func handleCombatEnd() {
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
}
