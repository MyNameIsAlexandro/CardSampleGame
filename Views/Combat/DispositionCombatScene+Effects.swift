/// Файл: Views/Combat/DispositionCombatScene+Effects.swift
/// Назначение: Visual effects for Disposition Combat — floating text, fate flash, card-to-bar animation.
/// Зона ответственности: All non-structural visual feedback (text popups, fly animations, keyword flashes).
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import SpriteKit
import TwilightEngine

// MARK: - Visual Effects

extension DispositionCombatScene {

    // MARK: - Floating Text

    func showFloatingText(_ text: String, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = color
        label.position = CGPoint(x: position.x, y: position.y - 40)
        label.zPosition = 60
        label.alpha = 0
        addChild(label)

        let appear = SKAction.fadeIn(withDuration: 0.1)
        let float = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        float.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([appear, float, fade, remove]))
    }

    // MARK: - Enemy Action Display

    func enemyActionDisplay(_ action: EnemyAction) -> (String, SKColor, Bool) {
        switch action {
        case .attack(let d):  return (L10n.dispositionFloatAttack.localized(with: d), .red, true)
        case .rage(let d):    return (L10n.dispositionFloatRage.localized(with: d), SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 1), true)
        case .defend(let v):  return (L10n.dispositionFloatDefend.localized(with: v), .cyan, false)
        case .provoke(let p): return (L10n.dispositionFloatProvoke.localized(with: p), .orange, false)
        case .adapt:          return (L10n.dispositionFloatAdapt.localized, .yellow, false)
        case .plea(let s):    return (L10n.dispositionFloatPlea.localized(with: s), .purple, false)
        }
    }

    // MARK: - Fate Keyword Flash

    func showFateKeywordIfPresent() {
        guard let vm = viewModel, let keyword = vm.lastFateKeyword else { return }
        let centerX = size.width / 2
        let (text, color) = fateKeywordDisplay(for: keyword)

        let flash = SKLabelNode(fontNamed: "AvenirNext-Bold")
        flash.text = text
        flash.fontSize = 20
        flash.fontColor = color
        flash.position = CGPoint(x: centerX, y: size.height * Layout.fateFlash)
        flash.alpha = 0
        flash.zPosition = 100
        overlayLayer?.addChild(flash)

        let appear = SKAction.fadeIn(withDuration: 0.15)
        let hold = SKAction.wait(forDuration: 0.8)
        let disappear = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([appear, hold, disappear, remove]))
    }

    func fateKeywordDisplay(for keyword: FateKeyword) -> (String, SKColor) {
        switch keyword {
        case .surge:  return (L10n.fateKeywordSurge.localized, SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1))
        case .shadow: return (L10n.fateKeywordShadow.localized, SKColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1))
        case .ward:   return (L10n.fateKeywordWard.localized, SKColor(red: 0.3, green: 0.8, blue: 0.6, alpha: 1))
        case .focus:  return (L10n.fateKeywordFocus.localized, SKColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1))
        case .echo:   return (L10n.fateKeywordEcho.localized, SKColor(red: 0.8, green: 0.8, blue: 0.3, alpha: 1))
        }
    }

    // MARK: - Card-to-Bar Animation

    func animateCardToBar(
        cardId: String,
        shiftValue: Int,
        isStrike: Bool,
        completion: @escaping () -> Void
    ) {
        guard let cardNode = handCardNodes[cardId] else {
            completion()
            return
        }

        let barPos = dispositionBar?.position ?? CGPoint(x: size.width / 2, y: size.height * Layout.bar)
        let color: SKColor = isStrike
            ? SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1)
            : SKColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1)
        let sign = isStrike ? "\u{2212}" : "+"

        let flyAction = SKAction.move(to: barPos, duration: 0.25)
        flyAction.timingMode = .easeIn
        let shrink = SKAction.scale(to: 0.3, duration: 0.25)
        let fade = SKAction.fadeOut(withDuration: 0.1)

        cardNode.run(SKAction.group([flyAction, shrink])) { [weak self] in
            cardNode.run(fade) {
                cardNode.removeFromParent()
            }
            self?.showFloatingText("\(sign)\(shiftValue)", at: barPos, color: color)
            self?.onHaptic?(abs(shiftValue) > 15 ? "heavy" : "medium")
            completion()
        }
    }

    // MARK: - Hero Damage Floating Text

    func showHeroDamageFloat(for enemyAction: EnemyAction) {
        guard let vm = viewModel else { return }
        switch enemyAction {
        case .attack(let damage), .rage(let damage):
            let totalDamage = damage + vm.enemySacrificeBuff
            let hpLabelPos = CGPoint(x: 150, y: size.height - 30)
            run(SKAction.wait(forDuration: 0.3)) { [weak self] in
                self?.showFloatingText("\u{2212}\(totalDamage) \u{2665}", at: hpLabelPos, color: .red)
            }
        default: break
        }
    }
}
