# Engine Package Migration Guide

## Current Status

**Package:** `Packages/TwilightEngine/` - builds and is linked to app
**Legacy:** `Engine/` and `Models/` - still compiled into app target

Views currently use types from legacy folders, not from package.

## Why Migrate?

1. **Isolation**: Package can be tested independently
2. **Clean Architecture**: Clear boundary between engine and UI
3. **Reusability**: Engine can be used in other targets (watchOS, tests)
4. **Build Times**: Incremental builds when engine unchanged

## Step-by-Step Migration

### Step 1: Make Package Types Public

The package types need `public` access modifier to be used from outside.

**Key files to modify:**

#### `Core/TwilightGameEngine.swift`
```swift
// Change:
final class TwilightGameEngine: ObservableObject {
    @Published private(set) var playerHealth: Int = 10
    ...
}

// To:
public final class TwilightGameEngine: ObservableObject {
    @Published public private(set) var playerHealth: Int = 10
    ...

    public init() { ... }
    public func performAction(_ action: TwilightGameAction) -> ActionResult { ... }
}
```

#### `Core/TwilightGameAction.swift`
```swift
public enum TwilightGameAction: TimedAction, Equatable { ... }
public struct ActionResult: Equatable { ... }
public enum ActionError: Error, Equatable { ... }
public enum StateChange: Equatable { ... }
```

#### `Core/GameLoop.swift`
```swift
public enum EngineGamePhase: String, Codable { ... }
public enum GameEndResult: Equatable { ... }
```

#### `Models/ExplorationModels.swift`
Already has `public` modifiers - verify they're all present.

#### `Heroes/HeroDefinition.swift`
```swift
public struct HeroDefinition: Identifiable, Codable { ... }
public struct HeroAbility: Codable, Equatable { ... }
```

#### `Combat/CombatCalculator.swift`
```swift
public struct CombatResult { ... }
public struct CombatCalculator { ... }
```

### Step 2: Add `import TwilightEngine` to Views

After making types public, add import to each View:

```swift
// Views/CombatView.swift
import SwiftUI
import TwilightEngine  // <-- Add this

struct CombatView: View {
    @ObservedObject var engine: TwilightGameEngine
    ...
}
```

**Views to update:**
- [ ] `Views/CombatView.swift`
- [ ] `Views/EventView.swift`
- [ ] `Views/WorldMapView.swift`
- [ ] `Views/HeroSelectionView.swift`
- [ ] `Views/Components/HeroPanel.swift`
- [ ] `App/ContentView.swift`
- [ ] `App/CardGameApp.swift`

### Step 3: Remove Legacy Files from Target

In Xcode:
1. Select project in navigator
2. Select "CardSampleGame" target
3. Go to "Build Phases" tab
4. Expand "Compile Sources"
5. Remove all files from `Engine/` folder
6. Remove `Player.swift`, `WorldState.swift`, `ExplorationModels.swift` from `Models/`
7. Keep: `Card.swift`, `CardType.swift`, `GameSave.swift` if needed

### Step 4: Build and Fix

```bash
xcodebuild -scheme CardSampleGame build 2>&1 | grep error:
```

Common fixes:
- Missing `public` on type → add to package
- Type mismatch → ensure using package type, not legacy
- Missing init → add `public init()` to package types

### Step 5: Delete Legacy Folders

After successful build:

```bash
cd "/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame"
rm -rf Engine/
rm Models/Player.swift Models/WorldState.swift Models/ExplorationModels.swift
```

### Step 6: Verify

```bash
# Package builds
cd Packages/TwilightEngine && swift build && swift test

# App builds
cd ../.. && xcodebuild -scheme CardSampleGame build

# Tests pass
xcodebuild -scheme CardSampleGame test
```

## Types Reference

### Types that MUST be public (used by Views)

| Type | File | Used By |
|------|------|---------|
| `TwilightGameEngine` | Core/TwilightGameEngine.swift | All Views |
| `EngineRegionState` | Core/TwilightGameEngine.swift | WorldMapView |
| `GameEvent` | Models/ExplorationModels.swift | EventView |
| `EventChoice` | Models/ExplorationModels.swift | EventView |
| `Quest` | Models/ExplorationModels.swift | WorldMapView |
| `ActiveCurse` | Models/ExplorationModels.swift | HeroPanel |
| `CurseType` | Models/CardType.swift | HeroPanel, CombatView |
| `GameEndResult` | Core/GameLoop.swift | ContentView |
| `ActionResult` | Core/TwilightGameAction.swift | Various |
| `CombatResult` | Combat/CombatCalculator.swift | CombatView |
| `Card` | Models/Card.swift | CombatView |
| `CardType` | Models/CardType.swift | Various |

### Types that stay internal

| Type | Reason |
|------|--------|
| `TimeEngine` | Internal subsystem |
| `PressureEngine` | Internal subsystem |
| `EconomyManager` | Internal subsystem |
| `CombatModule` | Internal, exposed via engine methods |

## Troubleshooting

### "Cannot find type 'X' in scope"

1. Check if type exists in package
2. Check if type has `public` modifier
3. Check if `import TwilightEngine` is present

### "Property cannot be declared public because its type uses an internal type"

The property type must also be public:

```swift
// Error: EngineRegionState is internal
@Published public private(set) var regions: [EngineRegionState] = []

// Fix: Make EngineRegionState public
public struct EngineRegionState { ... }
```

### Build works but runtime crash

Check that all `public init()` methods exist. Swift doesn't synthesize public initializers.

```swift
public struct Foo {
    public let value: Int

    // Must add explicitly:
    public init(value: Int) {
        self.value = value
    }
}
```

## Rollback Plan

If migration fails:

1. Revert changes to package (remove `public` modifiers)
2. Revert changes to Views (remove `import TwilightEngine`)
3. Add legacy files back to target

```bash
git checkout -- Packages/TwilightEngine/
git checkout -- Views/
git checkout -- App/
```

## Timeline Estimate

| Phase | Effort |
|-------|--------|
| Make types public | 1-2 hours |
| Update Views | 30 min |
| Remove legacy | 15 min |
| Fix issues | 1-2 hours |
| **Total** | **3-5 hours** |

## Future Improvements

After migration complete:

1. Add more unit tests to package
2. Split package into sub-packages (TwilightEngine, TwilightModels)
3. Add documentation comments to public API
4. Consider making engine actor for thread safety
