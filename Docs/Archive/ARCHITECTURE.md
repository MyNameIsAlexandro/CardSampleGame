# CardSampleGame Architecture

## Overview

CardSampleGame использует **Engine-First Architecture** где TwilightGameEngine является единственным источником истины для всего игрового состояния.

```
┌─────────────────────────────────────────────────────────────────┐
│                        CardSampleGame                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │    App/     │     │   Views/    │     │   Models/   │       │
│  │ CardGameApp │────▶│ CombatView  │────▶│   Player    │       │
│  │ ContentView │     │ EventView   │     │  WorldState │       │
│  └─────────────┘     │ WorldMapView│     │  (LEGACY)   │       │
│                      └──────┬──────┘     └─────────────┘       │
│                             │                                    │
│                             │ @ObservedObject                    │
│                             ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Engine/ (LEGACY)                         │  │
│  │  TwilightGameEngine, CombatCalculator, etc.              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                             │                                    │
│                             │ Duplicated in                      │
│                             ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        Packages/TwilightEngine (Swift Package)            │  │
│  │  ✓ Isolated, testable                                     │  │
│  │  ✓ No SwiftUI dependency                                  │  │
│  │  ✓ Pure game logic                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Current State (January 2025)

### What's Done
- ✅ TwilightEngine Swift Package created at `Packages/TwilightEngine/`
- ✅ Package builds independently with `swift build`
- ✅ Package integrated into Xcode project
- ✅ Main app builds with package dependency
- ✅ Tests build with package dependency (714 tests pass)
- ✅ Package is self-contained (no Player/WorldState dependencies)
- ✅ CombatPlayerContext replaces Player in combat calculations
- ✅ L10nStub provides localization for package

### What's NOT Done (Epic 8.2 - Future Work)
- ❌ Views don't use `import TwilightEngine` yet
- ❌ Legacy `Engine/` folder still exists and is compiled into app
- ❌ Legacy `Models/` folder still exists and is compiled into app
- ❌ Package types are not `public` (can't be imported from Views)

## Directory Structure

```
CardSampleGame/
├── App/                          # App entry point
│   ├── CardGameApp.swift
│   └── ContentView.swift
│
├── Views/                        # SwiftUI Views (stay in app)
│   ├── CombatView.swift
│   ├── EventView.swift
│   ├── WorldMapView.swift
│   └── Components/
│       └── HeroPanel.swift
│
├── Models/                       # LEGACY - to be removed
│   ├── Card.swift               # → Packages/TwilightEngine/Models/
│   ├── CardType.swift           # → Packages/TwilightEngine/Models/
│   ├── Player.swift             # → Remove (Engine-First)
│   ├── WorldState.swift         # → Remove (Engine-First)
│   └── ExplorationModels.swift  # → Packages/TwilightEngine/Models/
│
├── Engine/                       # LEGACY - to be removed
│   ├── Core/                    # → Packages/TwilightEngine/Core/
│   ├── Combat/                  # → Packages/TwilightEngine/Combat/
│   ├── Heroes/                  # → Packages/TwilightEngine/Heroes/
│   └── ...
│
├── Packages/
│   └── TwilightEngine/          # ✅ Swift Package (isolated engine)
│       ├── Package.swift
│       ├── Sources/TwilightEngine/
│       │   ├── Core/            # TwilightGameEngine, Actions
│       │   ├── Combat/          # CombatCalculator, CombatModule
│       │   ├── Models/          # Card, CardType, ExplorationModels
│       │   ├── Heroes/          # HeroDefinition, HeroAbility
│       │   ├── Cards/           # CardDefinition, CardFactory
│       │   └── Data/Definitions/
│       └── Tests/TwilightEngineTests/
│
└── Docs/
    └── ARCHITECTURE.md          # This file
```

## Development Workflow

### Working on Engine (Pure Logic)

```bash
cd Packages/TwilightEngine
swift build          # Quick compilation check
swift test           # Run unit tests
```

**Rules:**
- Engine must NOT import SwiftUI/UIKit
- All types that Views need must be `public`
- All state mutations through `StateChange` diffs
- No direct state mutation from outside

### Working on Views (UI)

Views are in the main app target and use engine via `@ObservedObject`.

**Current pattern (legacy):**
```swift
struct CombatView: View {
    @ObservedObject var engine: TwilightGameEngine  // From Engine/
    ...
}
```

**Target pattern (after migration):**
```swift
import TwilightEngine  // From package

struct CombatView: View {
    @ObservedObject var engine: TwilightGameEngine  // From package
    ...
}
```

## Migration Plan

### Phase 1: Make Package API Public (Epic 8.2)

Add `public` modifier to all types used by Views:

```swift
// Before
final class TwilightGameEngine: ObservableObject { ... }
struct EngineRegionState: Identifiable { ... }
enum GameEndResult: Equatable { ... }

// After
public final class TwilightGameEngine: ObservableObject { ... }
public struct EngineRegionState: Identifiable { ... }
public enum GameEndResult: Equatable { ... }
```

**Files to modify:**
- `Core/TwilightGameEngine.swift` - main engine class
- `Core/TwilightGameAction.swift` - ActionResult, StateChange
- `Core/GameLoop.swift` - GameEndResult, EngineGamePhase
- `Models/ExplorationModels.swift` - GameEvent, Quest, etc.
- `Heroes/HeroDefinition.swift` - HeroDefinition
- `Combat/CombatCalculator.swift` - CombatResult

### Phase 2: Update Views to Import Package

```swift
// Views/CombatView.swift
import SwiftUI
import TwilightEngine  // Add this

struct CombatView: View {
    @ObservedObject var engine: TwilightGameEngine
    ...
}
```

### Phase 3: Remove Legacy Files

1. Remove `Engine/` from Xcode target (Build Phases → Sources)
2. Remove `Models/` from Xcode target (except GameSave.swift if needed)
3. Verify build succeeds
4. Delete physical files

### Phase 4: Verify

```bash
# Package builds independently
cd Packages/TwilightEngine && swift build

# App builds with package only
cd ../.. && xcodebuild -scheme CardSampleGame build

# All tests pass
xcodebuild -scheme CardSampleGame test
```

## Architecture Principles

### 1. Engine-First
- `TwilightGameEngine` is the single source of truth
- Views read from engine, never mutate directly
- All changes through `performAction()`

### 2. No Legacy Models in Engine
- `Player` model replaced by engine properties (`playerHealth`, etc.)
- `WorldState` replaced by engine state
- Use `CombatPlayerContext` for combat calculations

### 3. Separation of Concerns
- **Package**: Pure game logic, no UI dependencies
- **Views**: UI only, read state from engine
- **App**: Wiring, navigation, app lifecycle

### 4. Testability
- Package tested independently with `swift test`
- No UI dependencies in engine tests
- Deterministic RNG (`WorldRNG`) for reproducible tests

## Build Commands

```bash
# Build package only
cd Packages/TwilightEngine
swift build

# Build main app (includes package)
xcodebuild -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination 'platform=iOS Simulator,id=C73C1188-03DC-42D9-9B13-AD10BEF459FA' \
  build

# Run tests
xcodebuild -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination 'platform=iOS Simulator,id=C73C1188-03DC-42D9-9B13-AD10BEF459FA' \
  test

# Find available simulators
xcrun simctl list devices available | grep iPhone
```

## CI/CD Checks

Recommended CI workflow:

```yaml
jobs:
  build-engine:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Engine Package
        run: |
          cd Packages/TwilightEngine
          swift build
          swift test

  build-app:
    runs-on: macos-latest
    needs: build-engine
    steps:
      - uses: actions/checkout@v4
      - name: Build App
        run: |
          xcodebuild -scheme CardSampleGame \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            build
```

## Verification Checklist

After migration, verify:

- [ ] `swift build` succeeds in `Packages/TwilightEngine/`
- [ ] `swift test` passes in `Packages/TwilightEngine/`
- [ ] No files in `Engine/` folder
- [ ] No files in `Models/` folder (except GameSave.swift)
- [ ] All Views have `import TwilightEngine`
- [ ] `xcodebuild build` succeeds
- [ ] `xcodebuild test` passes
- [ ] App runs correctly on simulator
