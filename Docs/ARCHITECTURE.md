# Architecture Map

> Strategic context for Claude sessions. Max 500 lines.
> Updated when an epic closes. Last update: Epic 6 (all epics complete).

## Core Principle

**Engine-First**: UI never mutates state. All changes go through `TwilightGameEngine.performAction()` which returns `ActionResult` with state changes. After each action, autosave.

## Module Map

```
┌─────────────────────────────────────────────┐
│                   SwiftUI                    │
│  ContentView → WorldMapView → CombatView    │
│                    │              │          │
│              EngineRegion    EncounterVM     │
│              DetailView      (ObservableObject)
└──────────────────┬───────────────┬──────────┘
                   │               │
         ┌─────────▼───────────────▼──────────┐
         │        TwilightGameEngine           │
         │  performAction() → ActionResult     │
         │  Single source of truth             │
         │                                     │
         │  Subsystems:                        │
         │  ├─ WorldState (regions, tension)   │
         │  ├─ PlayerState (HP, faith, deck)   │
         │  ├─ TimeEngine (day tracking)       │
         │  ├─ ResonanceEngine (-100..+100)    │
         │  ├─ FateDeckManager (draw/discard)  │
         │  ├─ DegradationRules (region decay) │
         │  ├─ QuestTriggerEngine              │
         │  └─ EventPipeline                   │
         └────────────────┬───────────────────┘
                          │
         ┌────────────────▼───────────────────┐
         │         EncounterEngine             │
         │  Standalone combat state machine    │
         │  Created per-encounter from context │
         │  Phases: intent→player→enemy→round  │
         │  Intent auto-generated at init +    │
         │    each roundEnd→intent transition  │
         │                                     │
         │  Uses:                              │
         │  ├─ BehaviorEvaluator (enemy AI)    │
         │  ├─ KeywordInterpreter (fate fx)    │
         │  ├─ FateDeckManager (encounter copy)│
         │  └─ ResonanceEngine (zone lookup)   │
         │                                     │
         │  Keyword specials (5 keywords):     │
         │  ├─ Physical: ignore_armor,         │
         │  │   vampirism, echo, parry, surge  │
         │  ├─ Spiritual: resonance_push,      │
         │  │   will_pierce, echo, veil, shield│
         │  └─ Defense: fortify, evade         │
         │                                     │
         │  Match/Mismatch system:             │
         │  ├─ Nav↔Physical/Defense (match)    │
         │  ├─ Prav↔Spiritual/Dialogue (match) │
         │  ├─ Yav↔All (always match)          │
         │  ├─ Match: keyword bonus × 1.5      │
         │  └─ Mismatch: keyword nullified     │
         │                                     │
         │  Enemy resonance modifiers:         │
         │  └─ resonanceBehavior[zone] →       │
         │     powerDelta / defenseDelta       │
         └────────────────────────────────────┘
                          │
         ┌────────────────▼───────────────────┐
         │         ContentRegistry             │
         │  Loaded from .pack binary files     │
         │  Heroes, Cards, Enemies, Events,    │
         │  Regions, Anchors, Quests, FateCards │
         │  Read-only at runtime               │
         └────────────────────────────────────┘
```

## Key Contracts

### TwilightGameEngine
- **Entry**: `performAction(_ action: GameAction) -> ActionResult`
- **State**: all `@Published public private(set)` properties
- **Save**: `EngineSave` captures full state, restored via `loadGame()`
- **RNG**: `WorldRNG.shared` — seeded, deterministic xorshift64
- **End conditions**: tension ≥ 100 → defeat, HP ≤ 0 → defeat, quest flag → victory

### EncounterEngine
- **Created**: `EncounterEngine(context: EncounterContext)`
- **Entry**: `performAction(_ action: PlayerAction) -> EncounterActionResult`
- **Phases**: `EncounterPhase` enum: intent → playerAction → enemyResolution → roundEnd
- **Auto-intent**: intents generated at init and each new round
- **Result**: `finishEncounter() -> EncounterResult`
- **Integration**: `TwilightGameEngine.applyEncounterResult()`
- **Dual track**: physical (HP) + spiritual (WP), pacify when WP=0

### KeywordInterpreter
- **Entry**: `resolveWithAlignment(keyword:context:isMatch:isMismatch:matchMultiplier:)`
- **5 keywords**: surge, focus, echo, shadow, ward
- **6 contexts**: combatPhysical, combatSpiritual, defense, exploration, dialogue, ritual
- **Match**: suit aligns → bonus × multiplier (default 1.5)
- **Mismatch**: suit opposes → keyword nullified (0 damage, no special)

### ContentRegistry
- **Singleton**: `ContentRegistry.shared`
- **Load**: `registerPack()` from binary .pack files
- **Query**: `getEnemy(id:)`, `getCard(id:)`, `getAvailableEvents(forRegion:)`, etc.
- **Immutable** at runtime

### Resonance
- **Range**: -100 (deep Nav) to +100 (deep Prav)
- **Zones**: deepNav (-100..-61) / nav (-60..-21) / yav (-20..20) / prav (21..60) / deepPrav (61..100)
- **Effects**: fate card modifiers, card cost +1/-1, enemy stat modifiers, suit match/mismatch

### Fate Deck
- **Structure**: FateCard with baseValue, suit (nav/yav/prav), keyword, isCritical
- **Flow**: draw → apply resonance modifiers → resolve keyword → check match → discard
- **Critical**: isCritical=true in defense → 0 damage

### World Degradation
- **Tension**: starts 30, escalates every 3 days by `3 + (day / 10)`
- **Thresholds**: 50 (30% degrade), 75 (50% + event), 90 (70% + anchor weaken)
- **State chain**: stable → borderland → breach (one-way without intervention)
- **Anchor resistance**: `P(resist) = integrity / 100`
- **Config**: `DegradationRules.current` (single source of truth)

## Data Flow: Combat

```
User taps "Explore" in region
  → engine.performAction(.explore)
  → generateEvent() picks event for currentRegionId
  → EventView shows event with choices
  → If choice triggers combat:
    → engine.makeEncounterContext() builds context
    → EncounterViewModel creates EncounterEngine
    → CombatView displays encounter
      ├─ ResonanceWidget (top)
      ├─ EnemyPanel + DualHealthBar + EnemyIntentBadge
      ├─ HeroHealthBar
      ├─ ActionBar (Attack / Influence / Wait / Flee)
      ├─ FateCardRevealView (overlay on draw)
      └─ FateDeckWidget (bottom)
    → On finish: engine.applyEncounterResult()
```

## Architectural Debt: RESOLVED

All 6 audit findings from the original report have been addressed:

1. ~~RNG split~~ — WorldRNG 100% normalized, deterministic (Epic 1)
2. ~~Access control~~ — all `public private(set)`, no unprotected state (Epic 2)
3. ~~Keyword stubs~~ — all 5 keywords with specials in 3 combat paths (Epic 3)
4. ~~Red gate tests~~ — 336 tests, 0 failures, 0 skips (Epic 4)
5. ~~World degradation~~ — single source of truth in DegradationRules (Epic 5)
6. ~~Legacy combat UI~~ — CombatView fully on EncounterViewModel (Epic 6)

## Gate Tests

| File | Count | Scope |
|------|-------|-------|
| INV_RNG_GateTests | 4 | Determinism, seed isolation, save/load |
| INV_TXN_GateTests | 8 | Contract tests, save round-trip |
| INV_KW_GateTests | 32 | Keywords, match, pacify, resonance, enemy mods, phases, critical, integration |
| INV_WLD_GateTests | 12 | Degradation, tension, anchors, 30-day simulation |
| **Total** | **56** | |

## File Layout

```
App/ContentView.swift          — Root navigation
Views/
  WorldMapView.swift           — Region map + detail sheets
  BattleArenaView.swift        — Quick battle entry point
  Combat/
    CombatView.swift           — Combat screen (EncounterViewModel)
    CombatSubviews.swift       — EnemyPanel, ActionBar, CombatLog
    EncounterViewModel.swift   — Bridges EncounterEngine to SwiftUI
    EncounterBridge.swift      — Context builder + result applier
  Components/
    DualHealthBar.swift        — HP + WP bars
    EnemyIntentView.swift      — Intent icons + badge
    FateCardRevealView.swift   — Animated fate reveal
    FateDeckWidget.swift       — Deck pile + discard
    ResonanceWidget.swift      — Resonance gauge
    EnemySelectionCard.swift   — Enemy picker card
  EventView.swift              — Event choice screen
Utilities/
  DesignSystem.swift           — AppColors, Spacing, Typography tokens
  Localization.swift           — L10n keys
Packages/
  TwilightEngine/Sources/TwilightEngine/
    Core/
      TwilightGameEngine.swift   — Main engine (2500+ lines)
      ResonanceEngine.swift      — Resonance tracking + zones
      FateCard.swift             — Fate card model + suits + keywords
      FateDeckManager.swift      — Draw/discard/shuffle
      WorldRNG.swift             — Deterministic xorshift64
      EngineSave.swift           — Full state serialization
    Encounter/
      EncounterEngine.swift      — Combat state machine
      EncounterContext.swift      — Context snapshot (hero, enemies, deck)
      KeywordInterpreter.swift   — Keyword → effect matrix
      BehaviorEvaluator.swift    — Enemy AI from JSON behaviors
      PlayerAction.swift         — Action enum + result types
    Config/
      DegradationRules.swift     — Region degradation config
      TwilightMarchesConfig.swift — Pressure, anchors, balance
    Data/Definitions/
      EnemyDefinition.swift      — Enemy stats + resonanceBehavior
    ContentPacks/
      ContentRegistry.swift      — Content loading + queries
  TwilightEngine/Tests/
    GateTests/                   — 56 gate tests (4 files)
    LayerTests/                  — Component integration tests
    Helpers/                     — Test fixtures
```
