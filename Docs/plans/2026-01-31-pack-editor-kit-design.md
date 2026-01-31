# PackEditorKit Extraction Design

## Goal
Extract business logic from PackEditor macOS app into a testable Swift Package `PackEditorKit`, keeping UI in the app target.

## Architecture

### PackEditorKit (new package: `Packages/PackEditorKit/`)
Foundation-only logic, no SwiftUI dependency.

**Files:**
- `PackStore.swift` — load/save/validate packs, entity dictionaries, dirty tracking
- `CombatSimulator.swift` — async combat simulation with AI heuristics
- `SimulationModels.swift` — SimulationConfig, SimulationResult, SingleCombatResult
- `ContentCategory.swift` — enum with 8 content categories + helpers

**Dependencies:** TwilightEngine, PackAuthoring, Foundation

### PackEditor app (unchanged target)
Imports PackEditorKit. All SwiftUI views stay here.

**Change:** `PackEditorState` becomes thin `@Observable` wrapper over `PackStore`, adds only UI state (`selectedCategory`, `selectedEntityId`).

## PackStore API

```swift
public class PackStore {
    public private(set) var packURL: URL?
    public private(set) var manifest: PackManifest?
    public private(set) var enemies: [String: EnemyDefinition]
    public private(set) var cards: [String: StandardCardDefinition]
    public private(set) var events: [String: EventDefinition]
    public private(set) var regions: [String: RegionDefinition]
    public private(set) var heroes: [String: StandardHeroDefinition]
    public private(set) var fateCards: [String: FateCard]
    public private(set) var quests: [String: QuestDefinition]
    public private(set) var balanceConfig: BalanceConfiguration?
    public private(set) var isDirty: Bool
    public private(set) var validationSummary: PackValidator.ValidationSummary?

    public func loadPack(from url: URL) throws
    public func savePack() throws
    public func validate() -> PackValidator.ValidationSummary
    public func entityCount(for category: ContentCategory) -> Int
    public func entityIds(for category: ContentCategory) -> [String]
}
```

## CombatSimulator API

```swift
public actor CombatSimulator {
    public func run(config: SimulationConfig, progress: @Sendable (Double) -> Void) async -> SimulationResult
}
```

## Test Plan

### PackStoreTests (~10 tests)
- Load pack from fixture directory -> dictionaries populated
- Load from nonexistent path -> throws
- Entity count/ids correct after load
- Validate returns summary
- isDirty defaults false

### CombatSimulatorTests (~5 tests)
- Basic simulation returns results with correct iteration count
- Zero iterations -> empty results
- Win rate between 0 and 1
- Avg rounds > 0

### Test Fixtures
Minimal pack in `Tests/PackEditorKitTests/Fixtures/TestPack/`:
- manifest.json, Enemies/enemies.json, Events/events.json, Regions/regions.json

## Migration Steps
1. Create `Packages/PackEditorKit/Package.swift`
2. Extract PackStore from PackEditorState (logic only)
3. Move CombatSimulator + models to kit
4. Create ContentCategory enum in kit
5. Add test fixtures + tests
6. Update PackEditor app: thin wrapper + import PackEditorKit
7. Update project.pbxproj: add PackEditorKit dependency
8. Verify build + tests

## Principles
- New content type -> update engine + editor in one PR
- TDD: tests before or alongside implementation
- No SwiftUI in kit — pure Foundation + Concurrency
