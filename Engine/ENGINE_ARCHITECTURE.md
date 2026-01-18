# Game Engine v1.0 Architecture

**Version:** 1.0
**Date:** January 2026

## Overview

This document describes the architecture of the setting-agnostic game engine.
The engine is the "processor" - specific games (like Twilight Marches) are "cartridges".

## Directory Structure

```
Engine/
├── Core/                    # Reusable engine core
│   ├── EngineProtocols.swift    # All contracts/protocols
│   ├── TimeEngine.swift         # Time management
│   ├── PressureEngine.swift     # Pressure/tension system
│   ├── EconomyManager.swift     # Resource transactions
│   └── GameLoop.swift           # Main orchestrator
├── Config/                  # Game-specific configuration
│   └── TwilightMarchesConfig.swift  # Twilight Marches settings
└── Modules/                 # Pluggable modules (future)
    └── (CardCombatModule, etc.)
```

## Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Runtime State (Save Data)                     │
│   GameState, WorldState, Player                        │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Configuration (The Cartridge)                 │
│   TwilightMarchesConfig, JSON content, Delegates       │
├─────────────────────────────────────────────────────────┤
│ Layer 1: Engine Core (Reusable)                        │
│   TimeEngine, PressureEngine, GameLoop, Protocols      │
└─────────────────────────────────────────────────────────┘
```

## Core Subsystems

### 1. Time Engine

**Purpose:** Universal time resource management.

**Contract:**
```swift
protocol TimeEngineProtocol {
    var currentTime: Int { get }
    func advance(cost: Int)
    func checkThreshold(_ interval: Int) -> Bool
}
```

**Invariants:**
- No free actions (except instant)
- Time cannot go backwards
- Every N ticks → escalation

### 2. Pressure Engine

**Purpose:** Drive game toward conclusion through escalating tension.

**Contract:**
```swift
protocol PressureEngineProtocol {
    var currentPressure: Int { get }
    var rules: PressureRuleSet { get }
    func escalate(at currentTime: Int)
    func adjust(by delta: Int)
    func currentEffects() -> [WorldEffect]
}
```

**Invariants:**
- Pressure grows on average
- Player can slow, not stop
- Thresholds trigger WorldEffects

### 3. Economy Manager

**Purpose:** Consistent resource transaction handling.

**Contract:**
```swift
protocol EconomyManagerProtocol {
    func canAfford(_ transaction: Transaction, resources: [String: Int]) -> Bool
    func process(_ transaction: Transaction, resources: inout [String: Int]) -> Bool
}
```

**Invariants:**
- No free gains without action
- Transactions are atomic

### 4. Game Loop (Orchestrator)

**Purpose:** Coordinate all subsystems in canonical order.

**Canonical Core Loop:**
```
1. AdvanceTime
2. WorldTick (pressure, shifts)
3. SelectTarget (region / quest)
4. ResolveEvent
5. ResolveChallenge (optional)
6. ApplyConsequences
7. UpdateQuests
8. CheckVictoryDefeat
9. Save
```

## Extension Points

The engine can be extended without modifying core:

| Extension Point | Description |
|-----------------|-------------|
| `PressureRuleSet` | Custom pressure escalation |
| `ConflictResolverProtocol` | Card combat, dice, etc. |
| `EndConditionDefinition` | Custom victory/defeat |
| `WorldEffect` | Custom world changes |

## Configuration (Twilight Marches)

The `TwilightMarchesConfig.swift` file contains all game-specific values:

- **Resources:** health, faith, balance
- **Pressure Rules:** 30 initial, +2 every 3 days, max 100
- **Region States:** stable, borderland, breach
- **Curses:** weakness, fear, exhaustion, etc.
- **Combat:** d6 dice, damage formula, actions per turn
- **Anchors:** integrity thresholds
- **Victory/Defeat:** flag-based conditions

## Migration Path

### Current State (Before)
- Logic, data, and state mixed in WorldState.swift
- Combat logic in CombatView.swift (UI layer)
- Hardcoded values throughout

### Target State (After)
- Engine core handles flow
- Config file contains all constants
- State models are pure data
- UI only renders, doesn't compute

### Migration Steps

1. **✓ Phase 1:** Create engine protocols and core implementations
2. **Phase 2:** Create adapters to connect existing code to engine
3. **Phase 3:** Migrate WorldState methods to engine subsystems
4. **Phase 4:** Extract combat logic to ConflictResolver module
5. **Phase 5:** Move events to JSON data files
6. **Phase 6:** Clean up and remove deprecated code

## Engine Invariants (Law)

These must always be true:

1. **No stagnation:** World degrades on inaction
2. **No free power:** Every gain has a cost
3. **Every choice costs:** Actions have consequences
4. **World reacts:** Inaction has consequences
5. **Path matters:** Ending depends on journey

## Usage Example

```swift
// Create engine with game-specific rules
let engine = TwilightMarchesEngine(
    pressureRules: TwilightMarchesFactory.createPressureRules()
)

// Start game
engine.startGame()

// Perform action
await engine.performAction(StandardAction.travel(
    from: "village",
    to: "forest",
    isNeighbor: true
))

// Check state
let tension = engine.pressureEngine.currentPressure
let health = engine.getResource("health")
```

## Testing

Engine tests should verify:

1. **Time advances correctly** (testTimeAdvancement)
2. **Pressure escalates** (testPressureEscalation)
3. **Transactions are atomic** (testTransactionAtomicity)
4. **End conditions trigger** (testEndConditions)
5. **Invariants hold** (testNoStagnation, etc.)

See: `CardSampleGameTests/Integration/MetricsDistributionTests.swift`
