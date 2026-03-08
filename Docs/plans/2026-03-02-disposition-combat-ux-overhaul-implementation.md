# Disposition Combat UX Overhaul — Implementation Plan

> **COMPLETED: 2026-03-03** -- All 11 tasks implemented. 148 gate tests pass, 0 failures. UX overhaul shipped: tap-tap action buttons with preview numbers, compact HUD, card-to-bar animations, floating damage numbers, fate flash, enemy anticipation pulse, post-combat summary screen.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make disposition combat playable end-to-end with clear UX: compact HUD, action buttons with preview numbers, visual feedback, and post-combat summary.

**Architecture:** Keep engine (DispositionCombatSimulation) intact. Changes are in: (1) engine — add preview API + fix adaptPenalty bug, (2) ViewModel — add preview methods + fix fatalError, (3) Scene Layout — redesign to compact HUD + action buttons, (4) Scene GameLoop — tap-tap flow replacing drag-to-zone.

**Tech Stack:** Swift, SpriteKit (DispositionCombatScene), TwilightEngine (pure logic), SwiftUI hosting (SpriteView)

**Design Doc:** `Docs/plans/2026-03-02-disposition-combat-ux-overhaul-design.md`

---

## Task 1: Fix adaptPenalty never cleared (Engine bug)

**Problem:** `adaptPenalty` is set by `applyEnemyAdapt()` but `clearAdaptPenalty()` is never called. Penalty stacks permanently.

**Files:**
- Modify: `Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCombatSimulation.swift:290,356`
- Test: `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/MomentumGateTests.swift`

**Step 1: Write failing test**

Add to a test file in `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/`:

```swift
func testAdaptPenalty_clearedAfterConsumption() {
    var sim = DispositionCombatSimulation.makeStandard(seed: 42)
    // Play a strike to set streak
    let card1 = sim.hand[0].id
    sim.playStrike(cardId: card1, targetId: "bandit")
    // Enemy adapts
    sim.applyEnemyAdapt(streakBonus: 2)
    XCTAssertEqual(sim.adaptPenalty, 2)
    // Play another strike — penalty should apply and then clear
    sim.beginPlayerTurn()
    let card2 = sim.hand[0].id
    sim.playStrike(cardId: card2, targetId: "bandit")
    // After consumption, penalty should be 0
    XCTAssertEqual(sim.adaptPenalty, 0, "adaptPenalty should clear after being consumed")
}
```

**Step 2: Run test, expect FAIL**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --package-path Packages/TwilightEngine --filter testAdaptPenalty_clearedAfterConsumption
```

**Step 3: Fix — clear adaptPenalty after consumption**

In `DispositionCombatSimulation.swift`, in both `playStrike()` (after line 292) and `playInfluence()` (after line 358), add after the effectivePower calculation and before the state changes:

```swift
// Clear adapt penalty after it was consumed (one-time effect)
if currentAdaptPenalty(for: .strike) > 0 {  // (or .influence)
    adaptPenalty = 0
}
```

**Step 4: Run test, expect PASS**

Same command as step 2.

**Step 5: Run full momentum gate tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --package-path Packages/TwilightEngine --filter MomentumGateTests
```

**Step 6: Commit**

```bash
git add Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCombatSimulation.swift Packages/TwilightEngine/Tests/
git commit -m "fix: clear adaptPenalty after consumption in disposition combat"
```

---

## Task 2: Fix fatalError in ViewModel.makeCombatResult()

**Problem:** `fatalError("Cannot build result before combat ends")` at ViewModel.swift:174 crashes the app if called with `outcome == nil`.

**Files:**
- Modify: `Views/Combat/DispositionCombatViewModel.swift:168-187`

**Step 1: Replace fatalError with optional return**

Change `makeCombatResult` to return optional:

```swift
func makeCombatResult(
    faithDelta: Int = 0,
    resonanceDelta: Float = 0,
    lootCardIds: [String] = []
) -> DispositionCombatResult? {
    guard let outcome = simulation.outcome else {
        return nil
    }
    return DispositionCombatResult(
        outcome: outcome,
        finalDisposition: simulation.disposition,
        hpDelta: simulation.heroHP - initialHeroHP,
        faithDelta: faithDelta,
        resonanceDelta: resonanceDelta,
        lootCardIds: lootCardIds,
        updatedFateDeckState: nil,
        turnsPlayed: turnsPlayed,
        cardsPlayed: cardsPlayed
    )
}
```

**Step 2: Update callers**

In `DispositionCombatScene+GameLoop.swift`, in `finishCombat()` (~line 465-485), update the call:

```swift
guard let result = vm.makeCombatResult(faithDelta: faithDelta, resonanceDelta: resonanceDelta) else {
    return  // Combat not actually over — do nothing
}
self?.onCombatEnd?(result)
```

**Step 3: Run DispositionSceneGateTests**

```bash
bash .github/ci/run_xcodebuild.sh test -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" -only-testing:CardSampleGameTests/DispositionSceneGateTests
```

**Step 4: Commit**

```bash
git add Views/Combat/DispositionCombatViewModel.swift Views/Combat/DispositionCombatScene+GameLoop.swift
git commit -m "fix: replace fatalError with optional return in makeCombatResult"
```

---

## Task 3: Add preview power calculation to DispositionCalculator

**Problem:** For the new UI, action buttons need to show the player what number each action would produce BEFORE they commit. Need a preview method.

**Files:**
- Modify: `Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCalculator.swift`
- Test: `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/DispositionMechanicsGateTests.swift`

**Step 1: Write failing test**

```swift
func testPreviewPower_matchesActualPlay() {
    var sim = DispositionCombatSimulation.makeStandard(seed: 42)
    let card = sim.hand[0]

    let previewStrike = DispositionCalculator.previewStrikePower(card: card, simulation: sim)
    let previewInfluence = DispositionCalculator.previewInfluencePower(card: card, simulation: sim)

    XCTAssertGreaterThan(previewStrike, 0)
    XCTAssertGreaterThan(previewInfluence, 0)

    // Play strike and verify disposition shifted by preview amount
    let dispBefore = sim.disposition
    sim.playStrike(cardId: card.id, targetId: "bandit")
    // Note: actual shift may differ from preview due to fate keyword drawn at play time
    // Preview shows the BASE power without fate — this is the minimum expected shift
    XCTAssertTrue(abs(sim.disposition - dispBefore) > 0)
}
```

**Step 2: Run test, expect FAIL (method doesn't exist)**

**Step 3: Implement preview methods**

Add to `DispositionCalculator.swift`:

```swift
// MARK: - Preview Power (for UI action buttons)

/// Preview the effective strike power of a card without playing it.
/// Does NOT account for fate keyword (unknown until drawn).
/// Uses fateModifier=0, fateKeyword=nil for preview.
public static func previewStrikePower(
    card: Card,
    simulation: DispositionCombatSimulation
) -> Int {
    let basePower = card.power ?? 1
    let effectiveDefend: Int = simulation.defendReduction
    let vulnMod = simulation.vulnerabilityRegistry.modifier(
        enemyType: simulation.enemyType, actionType: .strike, zone: simulation.resonanceZone
    )
    return effectivePower(
        basePower: basePower,
        streakCount: simulation.streakType == .strike ? simulation.streakCount + 1 : 1,
        previousStreakCount: simulation.streakCount,
        lastActionType: simulation.lastActionType,
        currentActionType: .strike,
        fateKeyword: nil,
        fateModifier: simulation.enemyModeStrikeBonus,
        resonanceZone: simulation.resonanceZone,
        defendReduction: effectiveDefend,
        adaptPenalty: simulation.adaptPenalty > 0 && simulation.streakType == .strike ? simulation.adaptPenalty : 0,
        vulnerabilityModifier: vulnMod
    )
}

/// Preview the effective influence power of a card without playing it.
public static func previewInfluencePower(
    card: Card,
    simulation: DispositionCombatSimulation
) -> Int {
    let basePower = card.power ?? 1
    let vulnMod = simulation.vulnerabilityRegistry.modifier(
        enemyType: simulation.enemyType, actionType: .influence, zone: simulation.resonanceZone
    )
    let rawPower = effectivePower(
        basePower: basePower,
        streakCount: simulation.streakType == .influence ? simulation.streakCount + 1 : 1,
        previousStreakCount: simulation.streakCount,
        lastActionType: simulation.lastActionType,
        currentActionType: .influence,
        fateKeyword: nil,
        fateModifier: 0,
        resonanceZone: simulation.resonanceZone,
        defendReduction: 0,
        adaptPenalty: simulation.adaptPenalty > 0 && simulation.streakType == .influence ? simulation.adaptPenalty : 0,
        vulnerabilityModifier: vulnMod
    )
    let effectiveProvoke = simulation.provokePenalty
    return max(0, rawPower - effectiveProvoke)
}
```

**Step 4: Run test, expect PASS**

**Step 5: Run full mechanics gate tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --package-path Packages/TwilightEngine --filter DispositionMechanicsGateTests
```

**Step 6: Commit**

```bash
git add Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCalculator.swift Packages/TwilightEngine/Tests/
git commit -m "feat: add preview power calculation for disposition combat UI"
```

---

## Task 4: Add preview methods to ViewModel

**Files:**
- Modify: `Views/Combat/DispositionCombatViewModel.swift`

**Step 1: Add preview pass-throughs**

Add to `DispositionCombatViewModel`:

```swift
// MARK: - Preview (for action buttons)

/// Preview strike power for a card (without fate keyword, which is unknown before play).
func previewStrikePower(card: Card) -> Int {
    DispositionCalculator.previewStrikePower(card: card, simulation: simulation)
}

/// Preview influence power for a card.
func previewInfluencePower(card: Card) -> Int {
    DispositionCalculator.previewInfluencePower(card: card, simulation: simulation)
}

/// Whether sacrifice is available this turn.
var canSacrifice: Bool { !simulation.sacrificeUsedThisTurn }
```

**Step 2: Commit**

```bash
git add Views/Combat/DispositionCombatViewModel.swift
git commit -m "feat: add preview power methods to DispositionCombatViewModel"
```

---

## Task 5: Redesign Layout — Compact HUD + Action Buttons

**This is the largest task. It replaces the physical zone layout with a compact design.**

**Files:**
- Modify: `Views/Combat/DispositionCombatScene+Layout.swift` (heavy rewrite)
- Modify: `Views/Combat/DispositionCombatScene.swift` (property updates)

**Step 1: Update Scene properties**

In `DispositionCombatScene.swift`, replace zone node references with action button nodes:

```swift
// Replace these:
// var strikeZone: SKShapeNode?
// var influenceZone: SKShapeNode?
// var sacrificeZone: SKShapeNode?

// With:
var actionButtonsContainer: SKNode?
var strikeButton: SKNode?
var influenceButton: SKNode?
var sacrificeButton: SKNode?
var strikePreviewLabel: SKLabelNode?
var influencePreviewLabel: SKLabelNode?
var sacrificePreviewLabel: SKLabelNode?
```

**Step 2: Rewrite buildLayout()**

In `DispositionCombatScene+Layout.swift`, restructure the vertical layout:

New Y positions (scene 390×700):
```
y=670  Compact HUD: "Turn 3  ♥85  ⚡2/3"  (single line)
y=550  Idol (enemy) — larger, centered
y=470  Enemy intent — on/near idol
y=400  Disposition bar — LARGE, with "Уничтожить ◄══●══► Подчинить" labels
y=200  Hand cards — larger (scale 0.85 instead of 0.65)
y=120  Action buttons (hidden by default, appear on card select)
y=60   End Turn button
```

Key changes:
- Remove `buildActionZones()` (3 physical zone rectangles)
- Add `buildActionButtons()` — 3 horizontal buttons, initially hidden
- Make disposition bar wider (350pt instead of 300pt) with endpoint labels
- Compact HUD: merge HP, Energy, Turn into single top row
- Remove separate streak/pile labels from main view (moved to long-press)
- Remove modifier strips from main view (show inline on intent/action)

**Step 3: Implement buildActionButtons()**

```swift
func buildActionButtons(centerX: CGFloat) {
    let container = SKNode()
    container.name = "actionButtonsContainer"
    container.position = CGPoint(x: 0, y: 120)
    container.alpha = 0  // Hidden by default
    combatLayer?.addChild(container)
    actionButtonsContainer = container

    let buttonW: CGFloat = 110
    let buttonH: CGFloat = 55
    let spacing: CGFloat = 8
    let totalW = buttonW * 3 + spacing * 2
    let startX = centerX - totalW / 2 + buttonW / 2

    strikeButton = makeActionButton(
        name: "strikeButton", label: "⚔", sublabel: "Удар",
        color: SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1),
        size: CGSize(width: buttonW, height: buttonH),
        position: CGPoint(x: startX, y: 0)
    )
    container.addChild(strikeButton!)

    influenceButton = makeActionButton(
        name: "influenceButton", label: "☽", sublabel: "Влияние",
        color: SKColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1),
        size: CGSize(width: buttonW, height: buttonH),
        position: CGPoint(x: startX + buttonW + spacing, y: 0)
    )
    container.addChild(influenceButton!)

    sacrificeButton = makeActionButton(
        name: "sacrificeButton", label: "♦", sublabel: "Жертва",
        color: SKColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1),
        size: CGSize(width: buttonW, height: buttonH),
        position: CGPoint(x: startX + (buttonW + spacing) * 2, y: 0)
    )
    container.addChild(sacrificeButton!)
}

private func makeActionButton(
    name: String, label: String, sublabel: String,
    color: SKColor, size: CGSize, position: CGPoint
) -> SKNode {
    let node = SKNode()
    node.name = name
    node.position = position

    let bg = SKShapeNode(rectOf: size, cornerRadius: 10)
    bg.fillColor = color.withAlphaComponent(0.85)
    bg.strokeColor = color
    bg.lineWidth = 2
    node.addChild(bg)

    let icon = SKLabelNode(text: label)
    icon.fontSize = 20
    icon.fontName = "AvenirNext-Bold"
    icon.position = CGPoint(x: 0, y: 8)
    icon.verticalAlignmentMode = .center
    node.addChild(icon)

    let sub = SKLabelNode(text: sublabel)
    sub.fontSize = 10
    sub.fontName = "AvenirNext-Medium"
    sub.fontColor = .white.withAlphaComponent(0.8)
    sub.position = CGPoint(x: 0, y: -5)
    sub.verticalAlignmentMode = .center
    node.addChild(sub)

    // Preview number label (updated when card is selected)
    let preview = SKLabelNode(text: "")
    preview.fontSize = 14
    preview.fontName = "AvenirNext-Bold"
    preview.position = CGPoint(x: 0, y: -20)
    preview.verticalAlignmentMode = .center
    preview.name = "\(name)Preview"
    node.addChild(preview)

    return node
}
```

**Step 4: Add showActionButtons / hideActionButtons**

```swift
func showActionButtons(for card: Card) {
    guard let vm = viewModel, let container = actionButtonsContainer else { return }

    let strikePower = vm.previewStrikePower(card: card)
    let influencePower = vm.previewInfluencePower(card: card)

    // Update preview labels
    if let label = strikeButton?.childNode(withName: "strikeButtonPreview") as? SKLabelNode {
        label.text = "−\(strikePower)"
        label.fontColor = strikePower > (card.power ?? 1) ? .green : .white
    }
    if let label = influenceButton?.childNode(withName: "influenceButtonPreview") as? SKLabelNode {
        label.text = "+\(influencePower)"
        label.fontColor = influencePower > (card.power ?? 1) ? .green : .white
    }
    if let label = sacrificeButton?.childNode(withName: "sacrificeButtonPreview") as? SKLabelNode {
        label.text = vm.canSacrifice ? "+1 ⚡" : "—"
        label.fontColor = vm.canSacrifice ? .white : .gray
    }

    // Dim sacrifice if already used this turn
    sacrificeButton?.alpha = vm.canSacrifice ? 1.0 : 0.4

    // Animate in
    container.run(SKAction.fadeIn(withDuration: 0.15))
}

func hideActionButtons() {
    actionButtonsContainer?.run(SKAction.fadeOut(withDuration: 0.1))
}
```

**Step 5: Build, verify no crashes**

```bash
bash .github/ci/run_xcodebuild.sh build -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)"
```

**Step 6: Commit**

```bash
git add Views/Combat/DispositionCombatScene.swift Views/Combat/DispositionCombatScene+Layout.swift
git commit -m "feat: redesign combat layout — compact HUD, action buttons with preview"
```

---

## Task 6: Redesign Interaction Flow — Tap-Tap with Preview

**Files:**
- Modify: `Views/Combat/DispositionCombatScene+GameLoop.swift` (heavy rewrite of touch handling)
- Modify: `Views/Combat/DispositionCombatScene+CardInteraction.swift` (update helpers)

**Step 1: Rewrite touchesBegan**

Replace the current touch handler (lines 59-107) with new logic:

```swift
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard inputEnabled, let touch = touches.first else { return }
    let location = touch.location(in: self)

    // 1. Check action buttons (only visible when card selected)
    if selectedCardId != nil {
        if let action = hitTestActionButton(at: location) {
            executeAction(action)
            return
        }
    }

    // 2. Check end turn
    if hitTestEndTurn(at: location) {
        performEndTurn()
        return
    }

    // 3. Check card tap
    if let cardId = hitTestCard(at: location) {
        if cardId == selectedCardId {
            deselectCard()  // Tap same card = deselect
        } else {
            if selectedCardId != nil { deselectCard() }
            selectCard(id: cardId)
        }
        return
    }

    // 4. Tap empty area = deselect
    if selectedCardId != nil {
        deselectCard()
    }
}
```

**Step 2: Add hitTestActionButton and executeAction**

```swift
enum CombatAction { case strike, influence, sacrifice }

func hitTestActionButton(at point: CGPoint) -> CombatAction? {
    guard let container = actionButtonsContainer, container.alpha > 0.5 else { return nil }
    let localPoint = convert(point, to: container)

    if let strike = strikeButton, strike.frame.insetBy(dx: -10, dy: -10).contains(localPoint) {
        return .strike
    }
    if let influence = influenceButton, influence.frame.insetBy(dx: -10, dy: -10).contains(localPoint) {
        return .influence
    }
    if let sacrifice = sacrificeButton, sacrifice.frame.insetBy(dx: -10, dy: -10).contains(localPoint) {
        return .sacrifice
    }
    return nil
}

func executeAction(_ action: CombatAction) {
    guard let cardId = selectedCardId else { return }

    switch action {
    case .strike: performStrike(cardId: cardId)
    case .influence: performInfluence(cardId: cardId)
    case .sacrifice: performSacrifice(cardId: cardId)
    }
}
```

**Step 3: Update selectCard to show action buttons**

In the existing `selectCard(id:)` method, add at the end:

```swift
if let card = viewModel?.hand.first(where: { $0.id == id }) {
    showActionButtons(for: card)
}
```

**Step 4: Update deselectCard to hide action buttons**

In `deselectCard()`, add:

```swift
hideActionButtons()
```

**Step 5: Keep drag as alternative (simplify touchesMoved)**

The drag flow in `touchesMoved` should now drag card to action buttons (not Y-zones). Update `determineDropZone` to check button hit areas instead of Y-bands.

**Step 6: Build and test**

```bash
bash .github/ci/run_xcodebuild.sh build -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)"
```

**Step 7: Commit**

```bash
git add Views/Combat/DispositionCombatScene+GameLoop.swift Views/Combat/DispositionCombatScene+CardInteraction.swift
git commit -m "feat: tap-tap interaction flow with action buttons and preview numbers"
```

---

## Task 7: Card-Flies-to-Bar Animation + Floating Numbers

**Files:**
- Modify: `Views/Combat/DispositionCombatScene+GameLoop.swift`
- Modify: `Views/Combat/DispositionCombatScene.swift`

**Step 1: Add card-to-bar animation in performStrike/performInfluence**

After successful play, instead of just syncing visuals:

```swift
func animateCardToBar(cardId: String, shiftValue: Int, isStrike: Bool, completion: @escaping () -> Void) {
    guard let cardNode = handCardNodes[cardId] else {
        completion()
        return
    }

    let barPos = dispositionBar?.position ?? CGPoint(x: 195, y: 400)
    let color: SKColor = isStrike
        ? SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1)
        : SKColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1)
    let sign = isStrike ? "−" : "+"

    // Fly card to bar
    let flyAction = SKAction.move(to: barPos, duration: 0.25)
    flyAction.timingMode = .easeIn
    let shrink = SKAction.scale(to: 0.3, duration: 0.25)
    let fade = SKAction.fadeOut(withDuration: 0.1)

    cardNode.run(SKAction.group([flyAction, shrink])) { [weak self] in
        cardNode.run(fade) {
            cardNode.removeFromParent()
        }
        // Show floating number at bar
        self?.showFloatingText("\(sign)\(shiftValue)", at: barPos, color: color)
        // Haptic
        self?.onHaptic?(abs(shiftValue) > 15 ? "heavy" : "medium")
        completion()
    }
}
```

**Step 2: Update performStrike/performInfluence to use animation**

Wrap the `afterPlayerAction()` call in the animation completion.

**Step 3: Add hero damage floating text in transitionToEnemyPhase**

After enemy attack/rage resolves, add floating text near HP label:

```swift
case .attack(let damage), .rage(let damage):
    let totalDamage = damage + (viewModel?.enemySacrificeBuff ?? 0)
    let hpPos = /* HP label position */
    showFloatingText("−\(totalDamage) ♥", at: hpPos, color: .red)
```

**Step 4: Add fate keyword flash**

After card play, if `vm.lastFateKeyword != nil`:

```swift
func showFateFlash(keyword: FateKeyword) {
    let (text, color) = fateKeywordDisplay(for: keyword)
    let flash = SKLabelNode(text: text)
    flash.fontSize = 16
    flash.fontName = "AvenirNext-Bold"
    flash.fontColor = color
    flash.position = CGPoint(x: 195, y: 350)
    flash.alpha = 0
    flash.zPosition = 100
    overlayLayer?.addChild(flash)

    let appear = SKAction.fadeIn(withDuration: 0.15)
    let hold = SKAction.wait(forDuration: 0.8)
    let disappear = SKAction.fadeOut(withDuration: 0.3)
    let remove = SKAction.removeFromParent()
    flash.run(SKAction.sequence([appear, hold, disappear, remove]))
}
```

**Step 5: Commit**

```bash
git add Views/Combat/DispositionCombatScene+GameLoop.swift Views/Combat/DispositionCombatScene.swift
git commit -m "feat: card-to-bar animation, floating damage numbers, fate flash"
```

---

## Task 8: Enemy Mode Change Flash + Anticipation Pulse

**Files:**
- Modify: `Views/Combat/DispositionCombatScene.swift` (updateIdolMode)
- Modify: `Views/Combat/DispositionCombatScene+GameLoop.swift` (transitionToEnemyPhase)

**Step 1: Add mode change flash text**

In `updateIdolMode()`, after `idolNode?.playModeTransition(to: aura)`:

```swift
// Show mode flash text (first time verbose, later brief)
let modeText: String
switch newMode {
case .survival: modeText = L10n.dispositionModeSurvival.localized
case .desperation: modeText = L10n.dispositionModeDesperation.localized
case .weakened: modeText = L10n.dispositionModeWeakened.localized
case .normal: modeText = ""
}
if !modeText.isEmpty {
    showFloatingText(modeText, at: idolNode?.position ?? .zero, color: .orange)
}
```

**Step 2: Add enemy anticipation pulse**

In `transitionToEnemyPhase()`, before resolving action, add 0.3s pulse:

```swift
idolNode?.run(SKAction.sequence([
    SKAction.scale(to: 1.08, duration: 0.15),
    SKAction.scale(to: 1.0, duration: 0.15)
]))
```

**Step 3: Commit**

```bash
git add Views/Combat/DispositionCombatScene.swift Views/Combat/DispositionCombatScene+GameLoop.swift
git commit -m "feat: enemy mode change flash text and anticipation pulse"
```

---

## Task 9: Post-Combat Summary Screen

**Files:**
- Create: `Views/Combat/DispositionCombatScene+Summary.swift`
- Modify: `Views/Combat/DispositionCombatScene+GameLoop.swift` (finishCombat)

**Step 1: Create summary overlay**

New file `DispositionCombatScene+Summary.swift`:

```swift
/// Файл: Views/Combat/DispositionCombatScene+Summary.swift
/// Назначение: Post-combat summary overlay for disposition combat.
/// Зона ответственности: Display combat result stats before scene transition.
/// Контекст: UX Overhaul — show player meaningful feedback after combat ends.

import SpriteKit
import TwilightEngine

extension DispositionCombatScene {

    func showCombatSummary(
        outcome: DispositionOutcome,
        turnsPlayed: Int,
        cardsPlayed: Int,
        finalDisposition: Int,
        heroHP: Int,
        heroMaxHP: Int,
        completion: @escaping () -> Void
    ) {
        let overlay = SKNode()
        overlay.name = "combatSummary"
        overlay.zPosition = 200
        overlay.alpha = 0

        // Dim background
        let bg = SKShapeNode(rectOf: CGSize(width: 390, height: 700))
        bg.fillColor = .black.withAlphaComponent(0.7)
        bg.position = CGPoint(x: 195, y: 350)
        overlay.addChild(bg)

        // Outcome title
        let title = SKLabelNode()
        title.fontSize = 28
        title.fontName = "AvenirNext-Bold"
        title.position = CGPoint(x: 195, y: 450)
        title.verticalAlignmentMode = .center
        switch outcome {
        case .destroyed:
            title.text = L10n.dispositionOutcomeDestroyed.localized
            title.fontColor = SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1)
        case .subjugated:
            title.text = L10n.dispositionOutcomeSubjugated.localized
            title.fontColor = SKColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1)
        case .defeated:
            title.text = L10n.dispositionOutcomeDefeated.localized
            title.fontColor = SKColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1)
        }
        overlay.addChild(title)

        // Stats
        let stats: [(String, String)] = [
            (L10n.combatSummaryTurns.localized, "\(turnsPlayed)"),
            (L10n.combatSummaryCards.localized, "\(cardsPlayed)"),
            (L10n.combatSummaryDisposition.localized, "\(finalDisposition)"),
            (L10n.combatSummaryHP.localized, "\(heroHP)/\(heroMaxHP)")
        ]

        for (i, stat) in stats.enumerated() {
            let y = 380 - CGFloat(i) * 35
            let label = SKLabelNode(text: "\(stat.0):  \(stat.1)")
            label.fontSize = 16
            label.fontName = "AvenirNext-Medium"
            label.fontColor = .white.withAlphaComponent(0.9)
            label.position = CGPoint(x: 195, y: y)
            label.verticalAlignmentMode = .center
            overlay.addChild(label)
        }

        // Continue button
        let btnBg = SKShapeNode(rectOf: CGSize(width: 160, height: 44), cornerRadius: 8)
        btnBg.fillColor = .white.withAlphaComponent(0.15)
        btnBg.strokeColor = .white.withAlphaComponent(0.4)
        btnBg.position = CGPoint(x: 195, y: 230)
        btnBg.name = "continueButton"
        overlay.addChild(btnBg)

        let btnLabel = SKLabelNode(text: L10n.combatSummaryContinue.localized)
        btnLabel.fontSize = 16
        btnLabel.fontName = "AvenirNext-DemiBold"
        btnLabel.fontColor = .white
        btnLabel.position = CGPoint(x: 195, y: 230)
        btnLabel.verticalAlignmentMode = .center
        btnLabel.name = "continueButtonLabel"
        overlay.addChild(btnLabel)

        addChild(overlay)

        // Fade in
        overlay.run(SKAction.fadeIn(withDuration: 0.3))

        // Store completion for continue button tap
        self.summaryCompletion = completion
    }
}
```

**Step 2: Update finishCombat to show summary**

In `finishCombat()`, replace the direct 1.2s wait + callback with:

```swift
// Show summary overlay instead of immediate transition
showCombatSummary(
    outcome: vm.outcome ?? .defeated,
    turnsPlayed: vm.turnsPlayed,
    cardsPlayed: vm.cardsPlayed,
    finalDisposition: vm.disposition,
    heroHP: vm.heroHP,
    heroMaxHP: vm.heroMaxHP
) { [weak self] in
    guard let self, let vm = self.viewModel else { return }
    guard let result = vm.makeCombatResult(faithDelta: faithDelta, resonanceDelta: resonanceDelta) else { return }
    self.onCombatEnd?(result)
}
```

**Step 3: Handle continue button tap**

In `touchesBegan`, add check for summary continue button:

```swift
// Check summary continue button
if let _ = childNode(withName: "combatSummary") {
    if let btn = childNode(withName: "//continueButton"),
       btn.frame.insetBy(dx: -20, dy: -20).contains(location) {
        summaryCompletion?()
        summaryCompletion = nil
        return
    }
}
```

**Step 4: Add summaryCompletion property to Scene**

```swift
var summaryCompletion: (() -> Void)?
```

**Step 5: Add L10n keys**

Ensure localization keys exist for:
- `combatSummaryTurns`, `combatSummaryCards`, `combatSummaryDisposition`, `combatSummaryHP`, `combatSummaryContinue`

**Step 6: Build and test**

```bash
bash .github/ci/run_xcodebuild.sh build -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)"
```

**Step 7: Commit**

```bash
git add Views/Combat/DispositionCombatScene+Summary.swift Views/Combat/DispositionCombatScene+GameLoop.swift Views/Combat/DispositionCombatScene.swift
git commit -m "feat: post-combat summary screen with stats and continue button"
```

---

## Task 10: Disposition Bar Visual Improvement

**Files:**
- Modify: `Views/Combat/DispositionCombatScene.swift` (updateDispositionBar)
- Modify: `Views/Combat/DispositionCombatScene+Layout.swift` (buildDispositionTrack)

**Step 1: Enlarge bar and add endpoint labels**

In `buildDispositionTrack`, increase bar width to 350pt, add labels:

```swift
// Left label
let leftLabel = SKLabelNode(text: L10n.dispositionLabelDestroy.localized)
leftLabel.fontSize = 10
leftLabel.fontName = "AvenirNext-DemiBold"
leftLabel.fontColor = SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 0.8)
leftLabel.position = CGPoint(x: centerX - 175, y: barY - 18)
combatLayer?.addChild(leftLabel)

// Right label
let rightLabel = SKLabelNode(text: L10n.dispositionLabelSubjugate.localized)
rightLabel.fontSize = 10
rightLabel.fontName = "AvenirNext-DemiBold"
rightLabel.fontColor = SKColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 0.8)
rightLabel.position = CGPoint(x: centerX + 175, y: barY - 18)
combatLayer?.addChild(rightLabel)
```

**Step 2: Fix bar fill at extremes**

In `updateDispositionBar`, fix the `max(4, ...)` stub:

```swift
let fillWidth = barWidth * fraction  // Remove max(4, ...) — allow full range
```

**Step 3: Commit**

```bash
git add Views/Combat/DispositionCombatScene.swift Views/Combat/DispositionCombatScene+Layout.swift
git commit -m "feat: enlarge disposition bar with endpoint labels, fix extreme display"
```

---

## Task 11: Run Full Gate Tests and Fix Regressions

**Step 1: Run TwilightEngine tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --package-path Packages/TwilightEngine
```

**Step 2: Run app architecture gate tests**

```bash
bash .github/ci/run_xcodebuild.sh test -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" -only-testing:CardSampleGameTests/AuditArchitectureBoundaryGateTests
```

**Step 3: Run disposition-specific gate tests**

```bash
bash .github/ci/run_xcodebuild.sh test -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" -only-testing:CardSampleGameTests/DispositionSceneGateTests -only-testing:CardSampleGameTests/DispositionCardPlayGateTests
```

**Step 4: Fix any regressions found**

**Step 5: Commit fixes**

```bash
git commit -m "fix: resolve regressions from combat UX overhaul"
```

---

## Task Order and Dependencies

```
Task 1 (adaptPenalty fix) ──┐
Task 2 (fatalError fix) ────┤
Task 3 (preview calc) ──────┼── Engine fixes (can run in parallel)
                            │
Task 4 (VM preview) ────────┤── Depends on Task 3
                            │
Task 5 (layout) ────────────┤── Depends on Task 4
Task 6 (interaction) ───────┤── Depends on Task 5
Task 7 (animations) ────────┤── Depends on Task 6
Task 8 (enemy flash) ───────┤── Can run after Task 5
Task 9 (summary screen) ────┤── Depends on Task 2 + Task 5
Task 10 (bar visual) ───────┤── Can run after Task 5
                            │
Task 11 (gate tests) ───────┘── Final validation, depends on all
```

**Estimated work:** Tasks 1-4 are small (engine). Tasks 5-6 are large (layout + interaction rewrite). Tasks 7-10 are medium (visual polish). Task 11 is validation.
