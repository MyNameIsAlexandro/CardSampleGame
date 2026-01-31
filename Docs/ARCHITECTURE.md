# Architecture Map

> Strategic context for Claude sessions. Max 500 lines.
> Updated when an epic closes. Last update: WCAG contrast pass.

## Core Principle

**Engine-First**: UI never mutates state. All changes go through `TwilightGameEngine.performAction()` which returns `ActionResult` with state changes. After each action, autosave.

## Module Map

```
┌─────────────────────────────────────────────┐
│              SwiftUI (iOS App)               │
│  ContentView → WorldMapView → CombatView    │
│       │            │              │          │
│  SettingsView EngineRegion   EncounterVM     │
│  TutorialView  DetailView    (Observable)    │
│  GameOverView                                │
│       HapticManager  SoundManager            │
└──────────────────┬───────────────┬──────────┘
                   │               │
┌──────────────────┴───────────────┴──────────┐
│           PackEditor (macOS App)             │
│  NavigationSplitView: sidebar→list→detail   │
│  8 editors: Enemy, Card, Event, Region,     │
│    Hero, FateCard, Quest, Balance            │
│  CombatSimulator (N runs, win rate, histo)  │
│  PackValidator + PackCompiler toolbar       │
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
         │  Player actions (all implemented):  │
         │  ├─ Attack (physical, fate+keyword) │
         │  ├─ Influence (spirit/WP damage)    │
         │  ├─ Defend (+3 defense bonus)       │
         │  ├─ Wait (skip turn)                │
         │  ├─ Flee (fate check, canFlee rule) │
         │  ├─ UseCard (faith cost, abilities) │
         │  └─ Mulligan (pre-combat swap)      │
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
         │                                     │
         │  Flee system:                       │
         │  ├─ canFlee rule in EncounterRules  │
         │  ├─ Fate card draw: ≥5 escape       │
         │  └─ <5: fail + punishment damage    │
         │                                     │
         │  Loot system:                       │
         │  ├─ lootCardIds on EncounterEnemy   │
         │  ├─ faithReward per enemy           │
         │  ├─ Collected on victory (kill/pac) │
         │  └─ Applied via EncounterBridge     │
         │                                     │
         │  Summon system:                     │
         │  ├─ .summon intent with enemyId     │
         │  ├─ summonPool dict on context      │
         │  └─ Max 4 enemies cap               │
         │                                     │
         │  Multi-enemy:                       │
         │  ├─ Engine: enemies[] array          │
         │  ├─ VM: selectedTargetId for target │
         │  └─ Per-entity outcomes tracked     │
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
- **Save**: `EngineSave` captures full state + fate deck + optional encounter state, restored via `loadGame()`
- **Mid-combat save**: `pendingEncounterState: EncounterSaveState?` — saved/restored in EngineSave
- **Auto-save**: every 3 days + after combat (via WorldMapView onChange observers)
- **Game Over**: `isGameOver` / `gameResult` → `GameOverView` fullScreenCover → menu
- **RNG**: `WorldRNG.shared` — seeded, deterministic xorshift64
- **End conditions**: tension ≥ 100 → defeat, HP ≤ 0 → defeat, quest flag → victory
- **Loot helpers**: `applyFaithDelta()`, `addToDeck()` — called by EncounterBridge

### EncounterEngine
- **Created**: `EncounterEngine(context: EncounterContext)`
- **Entry**: `performAction(_ action: PlayerAction) -> EncounterActionResult`
- **Phases**: `EncounterPhase` enum: intent → playerAction → enemyResolution → roundEnd
- **Auto-intent**: intents generated at init and each new round
- **Result**: `finishEncounter() -> EncounterResult`
- **Integration**: `TwilightGameEngine.applyEncounterResult()`
- **Dual track**: physical (HP) + spiritual (WP), pacify when WP=0
- **Defend**: +3 `turnDefenseBonus`, cleared at `advancePhase()` (enemyResolution→roundEnd)
- **Flee**: checks `rules.canFlee`, draws fate card (≥5 succeed, <5 fail + punishment)
- **Loot**: `finishEncounter()` collects `lootCardIds` + `faithReward` from defeated enemies
- **Summon**: `.summon` intent resolves via `context.summonPool[id]`, capped at 4 enemies
- **Snapshot**: `createSaveState() -> EncounterSaveState` captures all mutable state
- **Restore**: `EncounterEngine.restore(from: EncounterSaveState)` rebuilds engine from snapshot

### EncounterContext
- **Hero**: EncounterHero (hp, maxHp, strength, armor, wisdom)
- **Enemies**: `[EncounterEnemy]` — each has lootCardIds, faithReward, behaviorId, resonanceBehavior
- **Rules**: `EncounterRules` (maxRounds, canFlee, customVictory)
- **Summon pool**: `[String: EncounterEnemy]` — enemies available for summon
- **RNG seed**: `WorldRNG.shared.next()` per encounter (unique per battle)

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
- **Flee check**: fate draw determines escape success (value ≥ 5)
- **Persistence**: `FateDeckState` (draw/discard piles) saved in `EngineSave.fateDeckState`

### Save System
- **SaveManager**: singleton, UserDefaults/JSON, 3 slots
- **EngineSave**: full state + fate deck + encounter state, backward-compatible Codable
- **Mid-combat save**: `EncounterSaveState` in `EngineSave.encounterState` (optional, nil = no active combat)
- **Resume**: ContentView detects `pendingEncounterState`, presents CombatView with saved state
- **Auto-save**: every 3 days + after combat ends (WorldMapView → onAutoSave callback)
- **Manual save**: on exit to menu (ContentView onExit)
- **Game Over**: `GameOverView` fullScreenCover, returns to menu via onExit

### Settings & Onboarding
- **Tutorial**: `@AppStorage("hasCompletedTutorial")`, 4-step overlay on first game start
- **Settings**: `SettingsView` — difficulty, language (iOS settings link), reset tutorial/data
- **Difficulty**: `DifficultyLevel` enum in engine package (easy/normal/hard) with HP/power multipliers
- **Difficulty wiring**: `EncounterBridge` reads `UserDefaults("gameDifficulty")`, applies multipliers to enemy hp/power

### Post-Game System
- **PlayerProfile**: persistent meta-progression layer, ProfileManager singleton, UserDefaults key `"twilight_profile"`
- **Bestiary**: Witcher-3 style progressive reveal system
  - `CreatureKnowledge` tracks bestiary state per enemy ID (encounters, kills, knowledge level, first/last seen)
  - `KnowledgeLevel` progression: unknown → glimpsed → studied → mastered (unlock at 1/3/7 encounters)
  - `BestiaryView` + `CreatureDetailView` — full lore, tactics, stats revealed at mastered
  - `EnemyDefinition` extensions: 6 new optional fields (bestiaryName, category, lore, tactics, habitat, weakness)
- **Achievements**: full system with 15 launch achievements across 4 categories
  - `AchievementDefinition` — id, title, desc, category, criteria (Codable)
  - `AchievementEngine` — evalAll(), partial-progress support, register hooks on game events
  - `AchievementsView` — grid display, category filter, completion % tracking
- **Statistics**: enhanced tracking in PlayerProfile (total encounters, kills, deaths, victories, playtime, resonance extremes)
- **Persistence**: ProfileManager syncs to disk after every encounter/achievement/stat update

### Pack Editor (macOS)
- **Target**: `PackEditor` — separate macOS app in same Xcode project
- **Architecture**: NavigationSplitView (sidebar → entity list → detail editor)
- **Open**: NSOpenPanel → pack source folder → PackLoader reads JSON
- **Save**: JSONEncoder writes back to original JSON paths
- **Validate**: PackValidator runs 6-phase validation, results in sheet
- **Compile**: PackCompiler → .pack binary, NSSavePanel for output
- **Simulate**: CombatSimulator runs N encounters via EncounterEngine with simple AI
- **Editors**: 8 read-only display forms (Enemy, Card, Event, Region, Hero, FateCard, Quest, Balance)
- **Dependencies**: TwilightEngine, PackAuthoring (both support macOS 13+)

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
      ├─ RNG seed from WorldRNG.shared.next()
      ├─ lootCardIds + faithReward from EnemyDefinition
      └─ summonPool (if applicable)
    → EncounterViewModel creates EncounterEngine
    → CombatView displays encounter
      ├─ ResonanceWidget (top)
      ├─ EnemyPanel(s) + DualHealthBar + EnemyIntentBadge
      ├─ HeroHealthBar
      ├─ ActionBar (Attack / Influence / Defend / Wait / Flee)
      ├─ FateCardRevealView (overlay on draw)
      └─ FateDeckWidget (bottom)
    → On finish: engine.applyEncounterResult()
      ├─ HP delta applied
      ├─ Resonance delta applied
      ├─ Faith reward applied (applyFaithDelta)
      ├─ Loot cards added to deck (addToDeck via CardFactory)
      ├─ World flags merged
      └─ Fate deck state restored
```

## Architectural Debt: RESOLVED

All audit findings have been addressed across 10 epics:

1. ~~RNG split~~ — WorldRNG 100% normalized, deterministic (Epic 1)
2. ~~Access control~~ — all `public private(set)`, no unprotected state (Epic 2)
3. ~~Keyword stubs~~ — all 5 keywords with specials in 3 combat paths (Epic 3)
4. ~~Red gate tests~~ — 347 tests, 0 failures, 0 skips (Epic 4)
5. ~~World degradation~~ — single source of truth in DegradationRules (Epic 5)
6. ~~Legacy combat UI~~ — CombatView fully on EncounterViewModel (Epic 6)
7. ~~Encounter stubs~~ — defend, flee, loot, summon, multi-enemy all implemented (Epic 7)
8. ~~Save safety~~ — fate deck persistence, auto-save, game over, tutorial, settings (Epic 8)
9. ~~UI/UX polish~~ — haptics, sound, floating damage, damage flash, 3D card flip, travel transition, ambient menu, game over animations (Epic 9)
10. ~~Design system audit~~ — full token compliance, CardSizes/AppShadows.glow, localized fate strings, 38 violations fixed across 14 files (Epic 10)
11. ~~Debt closure~~ — mid-combat save (SAV-03) + difficulty wiring (SET-02), Codable on 11 types, snapshot/restore, view-layer resume, 8 gate tests (Epic 11)
12. ~~Pack editor~~ — macOS SwiftUI content authoring tool, 8 editors, combat simulator, validate/compile toolbar, 17 source files (Epic 12)
13. ~~Post-game system~~ — PlayerProfile persistence, Witcher-3 bestiary (progressive reveal), 15 achievements (4 categories), enhanced statistics, 13 gate tests, 60 L10n keys (en+ru) (Epic 13)

### Remaining Debt
None — all debt items resolved.

## Gate Tests

| File | Count | Scope |
|------|-------|-------|
| INV_RNG_GateTests | 4 | Determinism, seed isolation, save/load |
| INV_TXN_GateTests | 8 | Contract tests, save round-trip |
| INV_KW_GateTests | 32 | Keywords, match, pacify, resonance, enemy mods, phases, critical, integration |
| INV_WLD_GateTests | 12 | Degradation, tension, anchors, 30-day simulation |
| INV_ENC7_GateTests | 11 | Defend, flee rules, loot, RNG seed, summon |
| INV_SAV8_GateTests | 3 | Fate deck save/load, round-trip, backward compat |
| INV_DEBT11_GateTests | 8 | VictoryType Codable, EncounterSaveState round-trip, snapshot/restore, backward compat, difficulty |
| AuditGateTests | 13 | PlayerProfile persistence, bestiary progression, achievement unlock/progress, statistics tracking, ProfileManager singleton |
| **Total** | **91** | |

## File Layout

```
App/ContentView.swift          — Root navigation + auto-save + tutorial + combat resume
Views/
  WorldMapView.swift           — Region map + detail sheets + game over + auto-save
  GameOverView.swift           — Victory/defeat screen + return to menu
  TutorialOverlayView.swift    — 4-step first-run tutorial
  SettingsView.swift           — Settings + difficulty picker
  BattleArenaView.swift        — Quick battle entry point
  Combat/
    CombatView.swift           — Combat screen + floating damage + damage flash
    CombatSubviews.swift       — EnemyPanel, ActionBar, CombatLog
    EncounterViewModel.swift   — Bridges EncounterEngine to SwiftUI + haptic/sound
    EncounterBridge.swift      — Context builder + result applier + difficulty multipliers
  Components/
    DualHealthBar.swift        — HP + WP bars
    EnemyIntentView.swift      — Intent icons + badge
    FateCardRevealView.swift   — Animated fate reveal + 3D card flip
    FateDeckWidget.swift       — Deck pile + discard
    ResonanceWidget.swift      — Resonance gauge
    EnemySelectionCard.swift   — Enemy picker card
  EventView.swift              — Event choice screen
Managers/
  HapticManager.swift          — Singleton, 7 haptic types (UIFeedbackGenerator)
  SoundManager.swift           — AVAudioPlayer, 20 effects, 3 music tracks
Utilities/
  DesignSystem.swift           — AppColors (WCAG AA ≥4.5:1 on dark bg), Spacing, Sizes, CardSizes, CornerRadius, AppShadows, AppAnimation, AppGradient, Opacity
  Localization.swift           — L10n keys
Views/PostGame/
  BestiaryView.swift           — Grid of all encountered creatures, category filter
  CreatureDetailView.swift     — Lore, tactics, stats (progressive reveal)
  AchievementsView.swift       — Grid of all achievements, category filter, completion %
Packages/
  TwilightEngine/Sources/TwilightEngine/
    Core/
      TwilightGameEngine.swift   — Main engine (2500+ lines)
      ResonanceEngine.swift      — Resonance tracking + zones
      FateCard.swift             — Fate card model + suits + keywords
      FateDeckManager.swift      — Draw/discard/shuffle
      WorldRNG.swift             — Deterministic xorshift64
      EngineSave.swift           — Full state serialization + fate deck + encounter state
      EnemyIntent.swift          — Intent types + summonEnemyId
      DifficultyLevel.swift      — Easy/normal/hard with HP/power multipliers
    Encounter/
      EncounterEngine.swift      — Combat state machine (all actions)
      EncounterContext.swift      — Context snapshot + summonPool (Codable)
      EncounterSaveState.swift   — Mid-combat serializable snapshot
      EncounterResult.swift      — Outcome + lootCardIds + faithDelta
      KeywordInterpreter.swift   — Keyword → effect matrix
      BehaviorEvaluator.swift    — Enemy AI from JSON behaviors
      PlayerAction.swift         — Action enum + result types
    Config/
      DegradationRules.swift     — Region degradation config
      TwilightMarchesConfig.swift — Pressure, anchors, balance
    Data/Definitions/
      EnemyDefinition.swift      — Enemy stats + lootCardIds + faithReward + bestiary extensions (6 optional fields)
    ContentPacks/
      ContentRegistry.swift      — Content loading + queries
    Meta/
      PlayerProfile.swift        — Meta-progression: bestiary, achievements, statistics
      ProfileManager.swift       — Singleton, UserDefaults persistence
      AchievementDefinition.swift — Achievement model + categories
      AchievementEngine.swift    — Achievement unlock + progress tracking
  TwilightEngine/Tests/
    GateTests/                   — 78 gate tests (7 files)
    LayerTests/                  — Component integration tests
    Helpers/                     — Test fixtures
PackEditor/                      — macOS content authoring tool
  PackEditorApp.swift            — @main, NavigationSplitView
  Models/
    PackEditorState.swift        — Central state: load/save/dirty tracking
  Views/
    ContentSidebar.swift         — Category list with icons + counts
    EntityListView.swift         — Searchable entity list
    Editors/                     — 8 editors (Enemy, Card, Event, Region, Hero, FateCard, Quest, Balance)
    Simulation/
      CombatSimulator.swift      — N-run combat simulation engine
      SimulationView.swift       — Config + results + Charts histogram
    Shared/
      LocalizedTextField.swift   — EN/RU side-by-side text fields
      ValidationBadge.swift      — Error/warning/info badges
  Toolbar/
    EditorToolbar.swift          — Save, Validate, Compile buttons
```
