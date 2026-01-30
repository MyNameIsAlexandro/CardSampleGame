# Architecture Map

> Strategic context for Claude sessions. Max 500 lines.
> Updated when an epic closes. Old specs remain as reference.

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
         │  ├─ QuestTriggerEngine (stub)       │
         │  └─ EventPipeline                   │
         └────────────────┬───────────────────┘
                          │
         ┌────────────────▼───────────────────┐
         │         EncounterEngine             │
         │  Standalone combat state machine    │
         │  Created per-encounter from context │
         │  Phases: intent→player→enemy→round  │
         │                                     │
         │  Uses:                              │
         │  ├─ BehaviorEvaluator (enemy AI)    │
         │  ├─ KeywordInterpreter (fate fx)    │
         │  └─ FateDeckManager (encounter copy)│
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
- **RNG**: `WorldRNG.shared` — TODO: normalize (Epic 1)

### EncounterEngine
- **Created**: `EncounterEngine(context: EncounterContext)`
- **Entry**: `performAction(_ action: PlayerAction) -> ActionResult`
- **Phases**: `EncounterPhase` enum, strict order
- **Result**: `finishEncounter() -> EncounterResult`
- **Integration**: `TwilightGameEngine.applyEncounterResult()`

### ContentRegistry
- **Singleton**: `ContentRegistry.shared`
- **Load**: `registerPack()` from binary .pack files
- **Query**: `getEnemy(id:)`, `getCard(id:)`, `getAvailableEvents(forRegion:)`, etc.
- **Immutable** at runtime

### Resonance
- **Range**: -100 (deep Nav) to +100 (deep Prav)
- **Zones**: deepNav / nav / yav / prav / deepPrav
- **Effects**: fate card modifiers, card costs, enemy behavior (TODO: Epic 3)

### Fate Deck
- **Structure**: FateCard with baseValue, suit, keyword, intensity
- **Flow**: draw → apply modifiers (resonance zone) → resolve keyword → discard
- **Keywords**: surge, focus, echo, shadow, ward (TODO: implement effects in Epic 3)

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
    → On finish: engine.applyEncounterResult()
```

## Known Architectural Debt

1. **RNG split**: WorldRNG.shared vs EncounterContext.rngSeed (Epic 1)
2. **Access control**: some engine state publicly mutable (Epic 2)
3. **Keyword stubs**: 5 keywords defined, effects not implemented (Epic 3)
4. **Red gate tests**: some depend on unimplemented components (Epic 4)
5. **World degradation**: inconsistent rules across docs (Epic 5)
6. **Legacy combat UI**: CombatView partially uses old bridge (Epic 6)

## File Layout

```
App/ContentView.swift          — Root navigation
Views/
  WorldMapView.swift           — Region map + detail sheets
  Combat/
    CombatView.swift           — Combat screen (uses EncounterViewModel)
    CombatSubviews.swift       — Combat UI components
    EncounterViewModel.swift   — Bridges EncounterEngine to SwiftUI
    EncounterBridge.swift      — Context builder + result applier
  Components/                  — Reusable UI components
  EventView.swift              — Event choice screen
Utilities/
  DesignSystem.swift           — AppColors, Spacing, Typography tokens
  Localization.swift           — L10n keys
Packages/
  TwilightEngine/Sources/TwilightEngine/
    Core/TwilightGameEngine.swift  — Main engine (2500+ lines)
    Encounter/EncounterEngine.swift — Combat state machine
    Encounter/BehaviorEvaluator.swift — Enemy AI
    Encounter/KeywordInterpreter.swift — Fate keyword effects
    ContentPacks/ContentRegistry.swift — Content loading
    Core/ResonanceEngine.swift — Resonance tracking
    Core/FateDeckManager.swift — Fate deck
```
