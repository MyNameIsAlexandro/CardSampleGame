/// Файл: Views/Combat/RitualCombatScene+Layout.swift
/// Назначение: Layout ритуальной сцены — создание и позиционирование всех узлов.
/// Зона ответственности: Построение иерархии нод портретного 390×700 layout.
/// Контекст: Phase 3 Ritual Combat (R9). Extension of RitualCombatScene.

import SpriteKit

// MARK: - Layout

extension RitualCombatScene {

    /// Create all nodes and position them in the 390×700 portrait scene.
    func buildLayout() {
        removeAllChildren()
        idolNodes.removeAll()
        sealNodes.removeAll()
        handCardNodes.removeAll()

        let sceneW = RitualCombatScene.sceneSize.width
        let centerX = sceneW / 2

        buildLayers(centerX: centerX)
        buildIdols(centerX: centerX)
        buildRitualZone(centerX: centerX)
        buildHUD(centerX: centerX, sceneW: sceneW)
    }

    // MARK: - Layers

    private func buildLayers(centerX: CGFloat) {
        let ritual = SKNode()
        ritual.zPosition = 10
        addChild(ritual)
        ritualLayer = ritual

        let hand = SKNode()
        hand.zPosition = 20
        addChild(hand)
        handLayer = hand

        let overlay = SKNode()
        overlay.zPosition = 50
        addChild(overlay)
        overlayLayer = overlay
    }

    // MARK: - Enemy Idols

    private func buildIdols(centerX: CGFloat) {
        guard let sim = simulation else { return }
        let positions = IdolNode.layoutPositions(count: sim.enemies.count)
        let idolY: CGFloat = 600

        for (i, enemy) in sim.enemies.enumerated() {
            let idol = IdolNode(enemyId: enemy.id)
            idol.configure(name: enemy.name, maxHP: enemy.maxHp, maxWP: enemy.maxWp)
            idol.position = CGPoint(x: centerX + positions[i].x, y: idolY + positions[i].y)
            idol.zPosition = 15
            addChild(idol)
            idolNodes.append(idol)
        }
    }

    // MARK: - Ritual Zone

    private func buildRitualZone(centerX: CGFloat) {
        guard let layer = ritualLayer else { return }

        let circle = RitualCircleNode()
        circle.position = CGPoint(x: centerX, y: 400)
        layer.addChild(circle)
        ritualCircle = circle

        let sealY: CGFloat = 310
        let sealSpacing: CGFloat = 75
        let sealTypes: [SealType] = [.strike, .speak, .wait]

        for (i, type) in sealTypes.enumerated() {
            let seal = SealNode(type: type)
            let offsetX = CGFloat(i - 1) * sealSpacing
            seal.position = CGPoint(x: centerX + offsetX, y: sealY)
            layer.addChild(seal)
            sealNodes.append(seal)
        }

        let bonfire = BonfireNode()
        bonfire.position = CGPoint(x: centerX + 120, y: 400)
        layer.addChild(bonfire)
        bonfireNode = bonfire
    }

    // MARK: - HUD

    private func buildHUD(centerX: CGFloat, sceneW: CGFloat) {
        let amulet = AmuletNode()
        amulet.position = CGPoint(x: 55, y: 30)
        amulet.zPosition = 30
        addChild(amulet)
        amuletNode = amulet

        let rune = ResonanceRuneNode()
        rune.position = CGPoint(x: sceneW - 45, y: 30)
        rune.zPosition = 30
        addChild(rune)
        resonanceRune = rune
    }
}
