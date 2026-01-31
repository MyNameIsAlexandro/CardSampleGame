# Combat UI Polish — Full UX Pass

## Goal
Rework the combat screen to visually surface weakness/strength, abilities, and enemy intent with card-style enemy panels, subtle animations, and phase flow banners.

## Design Decisions
- **Enemy panel**: Card-style per enemy, horizontal scroll for multi-enemy
- **Animations**: Subtle (0.3s transitions, fade/pulse/shimmer — no flying objects)
- **Engine changes**: None — purely UI, ViewModel already exposes all needed data

---

## 1. EnemyCardView (new component)

Replaces inline `EnemyPanel` in CombatView. Each enemy rendered as a card inside horizontal `ScrollView`.

**Layout (top to bottom):**
- **Header**: Enemy name + type icon (beast/spirit/undead/demon/human/boss)
- **Health**: `DualHealthBar` (HP red + WP blue)
- **Intent**: `EnemyIntentBadge` (existing) — shown during intent/playerAction phases
- **Indicators row**:
  - Weakness badges: green capsules with keyword text (e.g., "fire"). Indicate ×1.5 damage
  - Strength badges: red capsules with keyword text. Indicate ×0.67 damage
  - Ability icons: shield (armor), heart (regen), sword (bonusDamage). Long-press for tooltip

**Selection**: Yellow border glow when enemy is selected target. Tap to select.

**File**: `Views/Components/EnemyCardView.swift`

## 2. Intent Animations

**Intent reveal (intent phase):**
- Badge appears with `.transition(.scale.combined(with: .opacity))`, 0.3s
- Attack intent: single red pulse
- Block/defend: blue shimmer
- Heal/restoreWP: green shimmer

**File**: Changes to `EnemyIntentView.swift` (add transitions)

## 3. Weakness/Strength/Ability Feedback

**CombatFeedbackOverlay (new component):**
Reusable overlay for combat feedback text. Accepts type enum, auto-dismisses.

- `.weaknessTriggered` → green flash on enemy card + "WEAK!" text, fade-out 1s
- `.resistanceTriggered` → gray flash + "RESIST" text, fade-out 1s
- `.abilityTriggered` regen → green particles rising above HP bar
- `.abilityTriggered` armor → semi-transparent shield overlay (brief)
- `.abilityTriggered` bonusDamage → red aura around intent badge

**Floating damage colors (extend existing):**
- Red: hero damage (existing)
- Yellow: enemy HP damage (existing)
- Blue: enemy WP damage (new)
- Green: heal/regen (new)

**File**: `Views/Components/CombatFeedbackOverlay.swift`

## 4. Hero Stats Bar + Action Bar

**Hero Stats Bar:**
- Three sections: HP (heart + number + mini-bar) | Faith (icon + number) | Active bonuses as capsules (sword+N, shield+N, star+N)
- Bonus capsules appear with scale animation when > 0

**Action Bar:**
- Attack/Influence buttons show "+N" badge when turnBonus > 0
- Inactive buttons: opacity 0.4 instead of hidden
- Press: scale(0.95) + haptic `.impactOccurred(.light)`

**Combat Log color coding:**
- Red text: hero damage
- Yellow text: enemy damage
- Green text: heal
- Gray text: system messages
- Weakness/resistance lines get icon prefix (green arrow up / red arrow down)

**Files**: Changes to `CombatView.swift` (CombatSubviews sections)

## 5. Phase Flow Banners

**PhaseBanner (new component):**
Auto-dismissing banner at top of combat area.

- `intent` phase → "Enemy Intent" banner (orange)
- `playerAction` phase → "Your Turn" banner (green)
- `enemyResolution` phase → "Enemy Acts" banner (red)
- `roundEnd` phase → "Round N+1" divider (gray)

Transition: `.move(edge: .top).combined(with: .opacity)`, auto-dismiss 1s.

**File**: `Views/Components/PhaseBanner.swift`

## 6. DualHealthBar Enhancement

- Animate bar width changes with `.animation(.easeOut(duration: 0.3))`
- "Ghost bar": old value lingers 0.5s as faded bar behind new value, then fades out

**File**: Changes to `Views/Components/DualHealthBar.swift`

## 7. Fate Deck Bar

- Deck left, Flee button right
- Discard count badge next to deck
- Auto Fate draw: card scales from deck position to center (0→1 over 0.4s) before FateCardRevealView opens

**Files**: Changes to `CombatView.swift` (FateDeckBar section)

---

## Components Summary

| Component | Status | File |
|-----------|--------|------|
| EnemyCardView | New | Views/Components/EnemyCardView.swift |
| CombatFeedbackOverlay | New | Views/Components/CombatFeedbackOverlay.swift |
| PhaseBanner | New | Views/Components/PhaseBanner.swift |
| DualHealthBar | Modify | Views/Components/DualHealthBar.swift |
| EnemyIntentView | Modify | Views/Components/EnemyIntentView.swift |
| CombatView | Modify | Views/Combat/CombatView.swift |

## What We Don't Touch
- EncounterEngine, EncounterViewModel — no changes needed
- ResonanceWidget, FateCardRevealView, FateCardChoiceSheet, FateDeckWidget, HeroPanel
- CombatOverView (victory/defeat overlay)

## Testing
- Visual: manual testing via BattleArenaView (Quick Battle)
- Build: `xcodebuild build`
- Existing 658 tests must not break

## Implementation Order
1. EnemyCardView + integrate into CombatView
2. CombatFeedbackOverlay + wire to lastChanges
3. PhaseBanner + wire to phase transitions
4. DualHealthBar ghost bar animation
5. EnemyIntentView transitions
6. Hero Stats Bar + Action Bar polish
7. Combat Log color coding
8. Fate Deck Bar tweaks
