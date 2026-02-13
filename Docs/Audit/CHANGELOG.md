# Changelog

All notable changes to the CardSampleGame project.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.7.0] - 2026-02-02 - Region Alignment: Anchor Polarity System

### Summary

Regions gain a second dimension: alongside health (stable/borderland/breach), anchors now track **alignment** (light/neutral/dark). Dark heroes can defile anchors or strengthen them with HP instead of Faith, shifting alignment toward dark. Creates a 3×3 state matrix for strategic depth.

---

### Features

#### Anchor Alignment
- **`EngineAnchorState.alignment`** — runtime alignment field (light/neutral/dark), initialized from `AnchorDefinition.initialInfluence`
- **`EngineRegionState.alignment`** — computed property derived from anchor (neutral if no anchor)
- **Save/Load** — `RegionSaveState.anchorAlignment` persists alignment; old saves default to neutral
- **`AnchorRuntimeState.alignment`** — alignment field added to WorldRuntimeState model

#### Dark Hero Strengthen
- Dark heroes (balance < 30) pay **HP** instead of Faith to strengthen anchors
- Each strengthen shifts anchor alignment one step toward dark (light→neutral→dark)
- Cost configurable via `AnchorBalanceConfig.darkStrengthenCostHP` (default: 3)

#### Defile Anchor Action
- **`TwilightGameAction.defileAnchor`** — new action for dark-aligned heroes
- Instantly sets anchor alignment to dark, costs HP
- Validation: requires nav alignment, anchor must not already be dark
- Cost configurable via `AnchorBalanceConfig.defileCostHP` (default: 5)

#### StateChange
- **`anchorAlignmentChanged(anchorId:newAlignment:)`** — new state change event

### Docs
- Updated EXPLORATION_CORE_DESIGN.md §6.4-6.5 (anchor actions, 3×3 state matrix)
- Updated SPEC_BALANCE_PACK.md / SPEC_BALANCE_PACK_RU.md (defile_cost_hp, dark_strengthen_cost_hp)

### Tests
- 9 new tests in INV_WLD_GateTests (alignment init, strengthen light/dark, defile, save/load)

---

## [2.6.0] - 2026-02-01 - Combat Ecosystem: Loot UI, Validator, CardEditor

### Summary

Combat results screen now shows faith reward, resonance shift, and loot cards earned. PackValidator extended with enemy field validations (defense, will, faithReward, difficulty, lootCardIds cross-refs). CardEditor enhanced with health, curse type fields and structured AbilityEffect editor. DamageType, CardBalance, Realm enums now CaseIterable.

---

### Features

#### CombatOverView — Loot & Rewards
- **Faith reward display** — sparkle icon + faith delta on victory
- **Resonance shift indicator** — Nav/Prav arrow with color
- **Loot cards list** — card names with rarity-colored icons from ContentRegistry
- ScrollView wrapper for long reward lists

#### PackValidator — Enemy Field Validations
- Validates `defense >= 0`, `will >= 0`, `faithReward >= 0`
- Validates `difficulty` in range 1–5
- Cross-references `lootCardIds` against pack cards
- 5 new tests (19 total PackValidator tests)

#### CardEditor — Missing Fields + AbilityEffectEditor
- **Health** and **Curse Type** fields added to Combat section
- **AbilityEffectEditor** — structured editor replaces read-only effect display
  - Type picker for all 16 AbilityEffect cases
  - Dynamic parameter fields per effect type (amount, duration, damage type, etc.)
- `DamageType`, `CardBalance`, `Realm` enums now `CaseIterable`

### Tests
- 140 tests passing (100 EchoEngine + 19 EchoScenes + 21 TwilightEngine)

---

## [2.5.0] - 2026-02-01 - EchoEngine: Fate Resolution, Diplomacy, Integration

### Summary

Full Fate Deck resolution with keyword interpretation and suit matching. Diplomacy system with dual victory paths (kill vs pacify). CombatResult struct carries resonance/faith/loot deltas. EchoEncounterBridge connects EchoEngine combat to TwilightGameEngine. CombatScene updated with Influence button, WP bar, and enhanced fate card overlay. 140 tests passing.

---

### Features

#### Fate Resolution Service
- **FateResolutionService** — wraps FateDeckManager + KeywordInterpreter for full fate card resolution
- **Keyword effects** — surge (bonus damage), focus (precision), ward (extra block), shadow (evade), echo (repeat)
- **Suit matching** — Nav suit ↔ physical context (×2 amplify), Prav suit ↔ spiritual context; mismatch nullifies keyword
- **ActionContext** — .combatPhysical, .combatSpiritual, .defense determine keyword interpretation

#### Diplomacy System
- **playerInfluence()** — spiritual attack damages Will instead of HP
- **AttackTrack** — physical / spiritual with escalation mechanics
- **Surprise bonus** — switching physical→spiritual grants extra spirit damage
- **Rage shield** — switching spiritual→physical grants enemy extra defense
- **Escalation decay** — bonuses/penalties decrease each round

#### Dual Victory & CombatResult
- **CombatOutcome** — `.victory(.killed)` when HP=0, `.victory(.pacified)` when Will=0, `.defeat`
- **CombatResult** — outcome, resonanceDelta (-5 kill / +5 pacify), faithDelta, lootCardIds, updatedFateDeckState

#### EchoEncounterBridge
- `makeEchoCombatConfig()` — builds config from TwilightGameEngine state
- `applyEchoCombatResult()` — applies resonance, faith, loot, fate deck back to engine

#### CombatScene (SpriteKit)
- **Influence button** — shown when enemy has Will > 0
- **performPlayerInfluence()** — spirit-themed animations (cyan flash, pulse)
- **Enhanced fate card overlay** — keyword name + suit match indicator (★)

### Tests
- 30 new tests: FateResolutionTests (15), DiplomacyTests (9), IntegrationTests (6)
- Total: 140 tests (100 EchoEngine + 19 EchoScenes + 21 TwilightEngine)

### Documentation
- ENGINE_ARCHITECTURE.md updated to v1.4 (E.5 rewritten)

---

## [2.4.0] - 2026-02-01 - EchoEngine Combat: Energy, Exhaust, Enemy Patterns

### Summary

EchoEngine ECS combat system now features energy cost per card, exhaust mechanic, and cyclic enemy behavior patterns. CardDefinition protocol extended with `cost` and `exhaust` fields (backward-compatible Codable). PackValidator validates enemy health/patterns and card cost/exhaust. PackEditor updated with Combat section (energy cost, exhaust toggle) and Behavior Pattern editor. Specs and documentation updated to v1.1.

---

### Features

#### EchoEngine (ECS Combat)
- **Energy system** — 3 energy/turn, `card.cost ?? 1` per play, reset on new turn
- **Exhaust mechanic** — `exhaust: true` cards go to exhaustPile, never reshuffled
- **Enemy patterns** — Cyclic `EnemyPatternStep[]` for simple AI behavior
- **Will depletion** — Mental damage as alternative victory condition
- **Status effects** — Poison, shield, buff components with per-turn ticking
- **CombatEvent.insufficientEnergy** — Returned when card cost > current energy

#### CardDefinition Protocol
- Added `cost: Int?` (energy cost, default 1) and `exhaust: Bool` (default false)
- Custom `init(from:)` with `decodeIfPresent` for backward-compatible binary .pack loading

#### PackValidator
- Card validation: negative cost (error), exhaust without abilities (warning)
- Enemy validation: empty name, non-positive health, negative power, empty/invalid patterns

#### PackEditor
- **CardEditor** — New "Combat" section with Energy Cost field and Exhaust toggle
- **EnemyEditor** — New "Behavior Pattern" section with add/edit/delete pattern steps

#### Content JSON
- `cards.json` — Added cost/exhaust to rage_strike and poison_blade
- `enemies.json` — Added patterns to risen_dead and swamp_hag

### Documentation
- **SPEC_CHARACTER_PACK.md** v1.1 — FR-CRD-008 (energy cost), FR-CRD-009 (exhaust)
- **SPEC_CAMPAIGN_PACK.md** v1.1 — FR-ENM-006 (Will), FR-ENM-007 (pattern), FR-ENM-008 (resonance)
- **CONTENT_PACK_GUIDE.md** v2.1 — Card cost/exhaust fields, new validation errors
- **COMBAT_DIPLOMACY_SPEC.md** v1.1 — Energy system, exhaust, enemy patterns
- **ENGINE_ARCHITECTURE.md** v1.3 — EchoEngine ECS combat section

### Tests
- PackValidatorTests: +4 tests (card cost, exhaust warnings, enemy health, enemy patterns)
- EchoEngine: 70 tests including 4 energy-specific tests
- EchoScenes: 19 tests including CardNode cost/exhaust label tests

---

## [2.3.0] - 2026-01-31 - PackEditor: Full Read-Write CRUD + ManifestEditor + Import/Export

### Summary

PackEditor macOS app now supports full read-write editing of all 10 content categories, manifest editing, entity import/export via clipboard, drag-reorder, JSON preview, and compilation to .pack binary. Added 82 unit tests for PackEditorKit. User guides in RU and EN.

---

### Features

#### PackEditorKit Library
- **PackStore** — CRUD operations for all 10 categories (enemies, cards, events, regions, heroes, fateCards, quests, behaviors, anchors, balance)
- **Templates** — Pre-built templates for enemies (beast/undead/boss), cards (attack/defense/spell/item), regions (settlement/wilderness/dungeon)
- **Import/Export** — `importEntity(json:for:)` and `exportEntityJSON(id:for:)` for clipboard/file workflows
- **Manifest editing** — `saveManifest()` writes manifest.json back to pack directory
- **Entity ordering** — `orderedEntityIds(for:)` with `_editor_order.json` persistence for drag-reorder
- **Validation** — PackValidator integration with summary

#### PackEditor App (macOS)
- **10 specialized editors** — EnemyEditor, CardEditor, EventEditor, RegionEditor, HeroEditor, FateCardEditor, QuestEditor, BehaviorEditor, AnchorEditor, BalanceEditor
- **ManifestEditor** — Edit pack metadata (identity, compatibility, story settings, organization, content paths)
- **JSON Preview** — View any entity as formatted JSON with copy button
- **Import from Clipboard** — Paste JSON entities via "+" menu
- **Export to Clipboard** — Copy selected entity as JSON
- **Drag & Reorder** — Manual entity ordering in list view
- **Global Search** — Search across all categories
- **Shared components** — LocalizedTextField, IntField, StringListEditor, DictEditor, FieldValidation, ValidationBadge

#### Documentation
- **PACK_EDITOR_GUIDE.md** — User guide (Russian)
- **PACK_EDITOR_GUIDE_EN.md** — User guide (English)
- **INDEX.md** — Updated with PackEditor guide links

### Tests

**PackEditorKit: 82 tests (all passing)**
- PackStore CRUD for all categories
- Template creation
- isDirty lifecycle
- Save round-trip for all entity types
- Legacy card format backward compatibility
- JSON encoding round-trip
- Edge cases (duplicate, delete nonexistent, empty state)

---

## [2.2.0] - 2026-01-27 - PackAuthoring Extraction & UUID→String Migration

### Summary

Module extraction release. Moved authoring tools (PackLoader, PackCompiler, PackValidator — 1502 lines) into a separate `PackAuthoring` library target with its own test target (`PackAuthoringTests`), making TwilightEngine runtime-only. Migrated all content-driven model IDs from `UUID` to `String`. Added 24 new tests, hardened gate tests against false-green scenarios. Fixed HeroPanel health color.

**Test Count:** 199 Xcode + 141 SPM (all passing, 0 skipped, total 340)
**Build Status:** SUCCESS

---

### 1) PackAuthoring Module Extraction

#### Architecture Change

```
Packages/TwilightEngine/
├── Sources/
│   ├── TwilightEngine/          ← Runtime-only (no JSON loading)
│   │   └── ContentPacks/
│   │       ├── ContentRegistry.swift
│   │       ├── ContentManager.swift
│   │       ├── BinaryPack.swift
│   │       └── (PackLoader, PackCompiler, PackValidator REMOVED)
│   ├── PackAuthoring/           ← NEW library target
│   │   ├── PackLoader.swift
│   │   ├── PackCompiler.swift
│   │   └── PackValidator.swift
│   └── PackCompilerTool/
│       └── main.swift           ← imports PackAuthoring
├── Tests/
│   ├── TwilightEngineTests/     ← 122 engine tests
│   └── PackAuthoringTests/      ← NEW: 19 authoring tests
│       ├── PackAuthoringTestHelper.swift
│       ├── PackCompilerTests.swift
│       └── PackValidatorTests.swift
```

#### Changed
- **Package.swift** — Added `PackAuthoring` library product and target (depends on `TwilightEngine`)
- **PackCompilerTool** — Dependency changed from `TwilightEngine` to `PackAuthoring`
- **GameDefinition.swift** — Made `Availability` struct properties and init `public` (cross-module access)
- **LocalizationManager.swift** — Made `loadStringTables()` `public` (used by PackLoader)

#### Gate Test
- `testRuntimeDoesNotUsePackLoader()` — now passes structurally (PackLoader not in engine Sources)

---

### 2) UUID→String Migration

All content-driven model IDs changed from `UUID` to `String` for stable, human-readable identifiers.

#### Changed (20+ files)
- **Card.swift** — `id: UUID` → `id: String`
- **ExplorationModels.swift** — `EventChoice.id`, `Region.id`, etc. → `String`
- **TwilightGameAction.swift** — All associated values with IDs → `String`
- **TwilightGameEngine.swift** — All internal ID handling → `String`
- **EngineSave.swift** — Save format uses `String` IDs
- **Adapters** — Removed `md5UUID()`, `stableUUID()`, `definitionId` bridge code
- **All engine tests** — Updated to use `String` IDs

---

### 3) New Tests (+24)

#### Added
- **PackCompilerTests.swift** (10 tests) — Compile story/character packs, validate output, error paths
- **PackValidatorTests.swift** (10 tests) — Validate packs, cross-references, error detection
- **PackLoaderTests.swift** (+4 tests) — Corrupted JSON, SHA256 consistency/difference/missing

#### Test Summary — Xcode (199 tests)

| Suite | Tests | Status |
|-------|-------|--------|
| AuditGateTests | 48 | OK |
| CodeHygieneTests | 4 | OK |
| ConditionValidatorTests | 10 | OK |
| ContentManagerTests | 27 | OK |
| ContentRegistryTests | 25 | OK |
| ContentValidationTests | 8 | OK |
| DesignSystemComplianceTests | 5 | OK |
| HeroPanelTests | 7 | OK |
| HeroRegistryTests | 8 | OK |
| LocalizationValidatorTests | 8 | OK |
| PackLoaderTests | 25 | OK |
| SaveLoadTests | 24 | OK |
| **Xcode Total** | **199** | OK |

#### Test Summary — SPM (141 tests)

| Suite | Tests | Target |
|-------|-------|--------|
| CombatEngineFirstTests | 20 | TwilightEngineTests |
| DataSeparationTests | 8 | TwilightEngineTests |
| EnemyDefinitionTests | 9 | TwilightEngineTests |
| GameplayFlowTests | 56 | TwilightEngineTests |
| Phase3ContractTests | 9 | TwilightEngineTests |
| RegressionPlaythroughTests | 12 | TwilightEngineTests |
| TimeSystemTests | 8 | TwilightEngineTests |
| PackCompilerTests | 9 | PackAuthoringTests |
| PackValidatorTests | 10 | PackAuthoringTests |
| **SPM Total** | **141** | OK |

---

### 4) Gate Test Hardening (False-Green Prevention)

Added directory/file existence assertions to 5 gate tests. If the repo structure changes and scanned directories disappear, tests now fail instead of silently passing.

#### Changed
- `testCardFactoryIsThePrimaryInterface` — asserts `dirsFound > 0`
- `testAllPrintStatementsAreDebugOnly` — asserts `dirsFound > 0`
- Asset image test — asserts `dirsFound > 0`
- `testRuntimeDoesNotUsePackLoader` — asserts `filesFound > 0`
- `testNoXCTSkipInAnyTests` — asserts `dirsFound > 0`

---

### 5) Comment Cleanup

Removed 18 "twilight-marches" references from engine doc-comments and section markers. Replaced with neutral examples (`"my-campaign-act1"`, `"dark-forest"`, `"Game Actions"`, etc.). Actual code/config references (enum cases, resource paths) left intact.

#### Files
- `PackManifest.swift` — 4 replacements
- `ContentRegistry.swift` — 1 replacement
- `PackTypes.swift` — 1 replacement
- `CardType.swift` — 5 replacements
- `Card.swift` — 2 replacements
- `AnchorDefinition.swift` — 1 replacement
- `TwilightGameAction.swift` — 2 replacements
- `TwilightGameEngine.swift` — 2 replacements

---

### 6) Test Modularity: PackAuthoringTests SPM Target

PackCompilerTests and PackValidatorTests moved from Xcode app tests into a dedicated SPM test target `PackAuthoringTests`, preserving module boundaries.

#### Added
- **Package.swift** — `PackAuthoringTests` test target (depends on `PackAuthoring`, `TwilightEngine`)
- **Tests/PackAuthoringTests/PackAuthoringTestHelper.swift** — Locates pack JSON directories via `#filePath`
- **Tests/PackAuthoringTests/PackCompilerTests.swift** — 9 tests
- **Tests/PackAuthoringTests/PackValidatorTests.swift** — 10 tests

#### Removed
- `CardSampleGameTests/Unit/ContentPackTests/PackCompilerTests.swift` — moved to SPM
- `CardSampleGameTests/Unit/ContentPackTests/PackValidatorTests.swift` — moved to SPM

---

### 7) HeroPanel: Health Color Fix

Health icon always shows `AppColors.health` (red) instead of computed green/yellow/red based on percentage.

#### Changed
- **HeroPanel.swift** — Replaced `healthColor` computed property with `AppColors.health` on line 55
- Removed unused `healthColor` computed property (lines 239-248)

---

### Full File List

**Moved (3):** PackLoader.swift, PackCompiler.swift, PackValidator.swift → `Sources/PackAuthoring/`
**Moved to SPM (2):** PackCompilerTests.swift, PackValidatorTests.swift → `Tests/PackAuthoringTests/`
**New (3):** PackAuthoringTestHelper.swift, PackCompilerTests.swift (SPM), PackValidatorTests.swift (SPM)
**Modified (20+):** Package.swift, Card.swift, ExplorationModels.swift, TwilightGameAction.swift, TwilightGameEngine.swift, EngineSave.swift, GameDefinition.swift, LocalizationManager.swift, AuditGateTests.swift, PackLoaderTests.swift, CodeHygieneTests.swift, TestContentLoader.swift, project.pbxproj, CardRegistry.swift, EnemyDefinition.swift, PackManifest.swift, ContentRegistry.swift, PackTypes.swift, CardType.swift, AnchorDefinition.swift, HeroPanel.swift

---

## [2.1.1] - 2026-01-27 - Stage Acceptance: All Audit v2.1 Blockers Resolved

### Summary

Full stage acceptance for Audit v2.1. Every blocker from `AUDIT_FIXLIST_v2_1_ACCEPTANCE.md` resolved and enforced by gate tests. No XCTSkip, no system RNG, no game-specific IDs in engine, no UUID fallbacks, non-optional RNG state in saves, doc comments on all public API.

**Test Count:** 194 Xcode + 122 SPM (all passing, 0 skipped)
**Build Status:** SUCCESS
**Commit:** `a0225b8`

---

### 1) BLOCKERS — все закрыты

#### 1.1 XCTSkip = 0
- **Было:** 126 вызовов `XCTSkip`/`XCTSkipIf` в 7 файлах тестов
- **Стало:** 0 реальных вызовов. Все заменены на `XCTFail` + `return`
- **Gate test:** `testNoXCTSkipInAnyTests()` — сканирует ВСЕ директории тестов
- **Файлы:** `GameplayFlowTests.swift`, `Phase3ContractTests.swift`, `TimeSystemTests.swift`, `PackLoaderTests.swift`, `ContentRegistryTests.swift`, `ContentManagerTests.swift`, `HeroPanelTests.swift`, `ContentValidationTests.swift`

#### 1.2 Engine без game-specific IDs
- **Было:** `mapHeroNameToId` с "велеслава"→"veleslava", hardcoded card IDs в `createGenericStarterDeck()`, `"act1_completed"` в `checkEndConditions()`, `TwilightMarchesRegionType` enum, `"forest"` defaults
- **Стало:** Мёртвый код удалён, `checkEndConditions()` читает `balanceConfig.endConditions.mainQuestCompleteFlag`, `RegionType(rawValue:)` вместо switch-case, defaults `"unknown"` вместо `"forest"`
- **Gate test:** `testEngineContainsNoGameSpecificIds()` — статический скан исходников Engine
- **Файлы:** `CardFactory.swift`, `TwilightGameEngine.swift`, `RegionDefinition.swift`, `EventDefinitionAdapter.swift`, `CodeContentProvider.swift`, `JSONContentProvider.swift`

#### 1.3 Запрет системного RNG
- **Было:** `resetToSystem()` в WorldRNG использовал `UInt64.random(in:)`, `seed` был optional в `GameRuntimeState.newGame()`
- **Стало:** `resetToSystem()` удалён полностью, `seed: UInt64` обязательный параметр, legacy `Utilities/WorldRNG.swift` удалён
- **Gate test:** `testNoSystemRandomInEngineCore()` — 0 исключений, рекурсивный скан всего Engine
- **Файлы:** `WorldRNG.swift`, `GameRuntimeState.swift`, deleted `Utilities/WorldRNG.swift`

#### 1.4 Stable IDs — нет UUID fallback
- **Было:** `EventChoice.id` имел default `UUID().uuidString`, `EventPipeline` использовал `event.id.uuidString`
- **Стало:** `EventChoice.id` — обязательный параметр, `EventPipeline` использует `definitionId`
- **Gate test:** `testDefinitionIdIsNonOptional()` + `testDefinitionIdNeverNilForPackEntities()`
- **Файлы:** `ExplorationModels.swift`, `EventPipeline.swift`, `EventView.swift`, `GameplayFlowTests.swift`

#### 1.5 RNG state в Save/Load
- **Было:** `rngSeed: UInt64?`, `rngState: UInt64?` — optional с fallback
- **Стало:** `rngSeed: UInt64`, `rngState: UInt64` — обязательные поля, restore через `services.rng.restoreState(save.rngState)`
- **Gate test:** `testEngineSaveContainsRNGState()` — проверяет non-optional типы в исходнике
- **Файлы:** `EngineSave.swift`, `TwilightGameEngine.swift`, `SaveLoadTests.swift`

---

### 2) UI

#### 2.1 Legacy Comments — WorldMapView чист
- **Gate test:** `testNoLegacyInitializationCommentsInWorldMapView()`

#### 2.2 SafeImage везде
- **Было:** Потенциально `Image("...")` напрямую
- **Стало:** 0 вхождений `Image("...")` в Views/
- **Gate test:** `testNoDirectImageNamedInViews()`

---

### 3) Content Validation

#### 3.1 ExpressionParser
- **Добавлен:** `ExpressionParser.swift` — whitelist переменных (`WorldTension`, `lightDarkBalance`, `playerHealth` и др.) и функций
- **Добавлен:** `ContentValidationError.ErrorType.invalidExpression`
- **Gate tests:** `testRejectsUnknownVariables()`, `testRejectsUnknownFunctions()`, `testRejectsInvalidSyntax()`, `testAllPackConditionsAreValid()`
- **Файлы:** `ExpressionParser.swift`, `ExpressionParserTests.swift`, `ContentProvider.swift`

---

### 4) Pack System

#### 4.1 Локализация — единый канон
- **Gate test:** `testNoMixedLocalizationSchema()` — inline `LocalizedString` с ru/en

#### 4.2 Binary Pack round-trip
- **Gate test:** `testPackCompilerRoundTrip()` — load → BinaryPackWriter → BinaryPackReader → сравнение

---

### 5) Code Hygiene

#### 5.1 Doc Comments
- **Добавлены `///`** ко всем public API в: `TwilightGameEngine.swift` (~35), `PackCompiler.swift` (22), `WorldRNG.swift` (6), `CardFactory.swift` (2)
- **Уже задокументированы:** `ContentRegistry.swift`, `ExpressionParser.swift`

#### 5.2 SwiftLint
- `.swiftlint.yml`: `force_cast` error, `force_try` error, `cyclomatic_complexity` 15/25, `function_body_length` 60/100

---

### Definition of Done — Stage Accepted ✅

| Критерий | Статус |
|----------|--------|
| Все BLOCKERS закрыты и подтверждены тестами | ✅ |
| UI не содержит legacy закомментированного кода | ✅ |
| SafeImage используется во всех местах | ✅ |
| ExpressionParser валидирует conditions во всех pack'ах | ✅ |
| Gate tests не skip'аются и реально падают при нарушениях | ✅ |

---

### Полный список изменённых файлов (35 файлов)

**Engine (15 файлов):**
- `Cards/CardFactory.swift` — удалён мёртвый код, doc comments
- `Config/DegradationRules.swift` — minor fix
- `ContentPacks/ContentManager.swift` — XCTSkip fixes в тестах
- `ContentPacks/ContentRegistry.swift` — minor
- `ContentPacks/ExpressionParser.swift` — **NEW**
- `ContentPacks/PackCompiler.swift` — doc comments
- `Core/EngineSave.swift` — non-optional rngSeed/rngState
- `Core/TwilightGameEngine.swift` — endConditions config, doc comments, mapRegionType fix
- `Data/Definitions/RegionDefinition.swift` — удалён TwilightMarchesRegionType
- `Data/Providers/CodeContentProvider.swift` — default "unknown"
- `Data/Providers/ContentProvider.swift` — invalidExpression error type
- `Data/Providers/JSONContentProvider.swift` — default "unknown"
- `Events/EventPipeline.swift` — definitionId вместо uuidString
- `Migration/EventDefinitionAdapter.swift` — RegionType(rawValue:)
- `Models/ExplorationModels.swift` — EventChoice.id required
- `Runtime/GameRuntimeState.swift` — seed required
- `Utilities/WorldRNG.swift` — удалён resetToSystem(), doc comments

**Tests (11 файлов):**
- `AuditGateTests.swift` — +390 строк новых gate tests
- `ContentValidationTests.swift` — XCTSkip → XCTFail
- `ExpressionParserTests.swift` — **NEW**
- `ContentManagerTests.swift` — XCTSkip → XCTFail
- `ContentRegistryTests.swift` — XCTSkip → XCTFail
- `PackLoaderTests.swift` — XCTSkip → XCTFail
- `SaveLoadTests.swift` — rng non-optional
- `HeroPanelTests.swift` — XCTSkip → XCTFail
- `GameplayFlowTests.swift` — XCTSkip → XCTFail, explicit IDs
- `Phase3ContractTests.swift` — XCTSkip → XCTFail
- `TimeSystemTests.swift` — XCTSkip → XCTFail

**App (2 файла):**
- `Views/EventView.swift` — explicit choice IDs in preview
- `Utilities/WorldRNG.swift` — **DELETED** (legacy duplicate)

**Config (1 файл):**
- `.swiftlint.yml` — **NEW**

---

## [2.1.0] - 2026-01-27 - Audit Verification & Content Manager

### Summary

Post-audit verification release with Content Manager for hot-reload, Binary Pack format, improved test organization, and comprehensive gate tests for all audit requirements.

**Test Count:** 189 tests (all passing)
**Build Status:** SUCCESS

---

### Binary Pack System (v2.0-v3.0)

#### Added
- **Pack Compiler CLI** (`pack-compiler`) - Compiles JSON to binary .pack
- **Binary Pack Format** - Optimized runtime format with checksums
- **BinaryPackReader/Writer** - Low-level pack I/O
- **Production Binary-Only** - Runtime rejects raw JSON

#### Structure
```
.pack file format:
┌────────────────────────────────┐
│ MAGIC: "TWPK" (4 bytes)        │
│ VERSION: UInt32                │
│ CHECKSUM: SHA256 (32 bytes)    │
├────────────────────────────────┤
│ MANIFEST_SIZE: UInt64          │
│ MANIFEST_DATA: JSON bytes      │
├────────────────────────────────┤
│ CONTENT_SIZE: UInt64           │
│ CONTENT_DATA: Compressed JSON  │
└────────────────────────────────┘
```

#### Gate Test
- `testRuntimeRejectsRawJSON()` - Ensures production uses .pack only

---

### Content Manager UI

#### Added
- **ContentManager.swift** (`TwilightEngine/ContentPacks/`) - Pack lifecycle management
- **ContentManagerVM.swift** (`ViewModels/`) - ViewModel for UI
- **ContentManagerView.swift** (`Views/`) - SwiftUI management interface

#### Features
- View loaded/available packs with status indicators
- Validate packs before loading (detect errors without crashing)
- Hot-reload external packs from Documents/Packs/
- Atomic reload with rollback on failure

#### Localization
- Full Russian/English support for Content Manager UI
- 50+ new L10n keys for pack status, content types, errors

---

### Gate Tests Reorganization

#### Changed
- **Renamed:** `CardSampleGameTests/Engine/` → `CardSampleGameTests/GateTests/`
- More accurate naming reflecting purpose (compliance/gate tests, not engine tests)

#### Updated Files
- `project.pbxproj` - Xcode project reference
- `DesignSystemComplianceTests.swift` - Path comments
- `AuditGateTests.swift` - Directory references
- Documentation files with old paths

#### Test Structure
```
CardSampleGameTests/
├── TestHelpers/             # Test utilities
├── Unit/                    # Module unit tests
│   ├── ContentPackTests/    # ContentPacks system
│   ├── SaveLoadTests
│   └── HeroRegistryTests
├── GateTests/               # Gate/Compliance tests
│   ├── AuditGateTests       # Architecture requirements
│   ├── DesignSystemComplianceTests
│   ├── CodeHygieneTests
│   ├── ContentValidationTests
│   ├── ConditionValidatorTests
│   └── LocalizationValidatorTests
└── Views/                   # UI tests
```

---

### Audit Verification (AUDIT_FIXLIST.md)

#### Section C: Test Model Blockers
- **C1:** ✅ No XCTSkip in gate tests (`testNoXCTSkipInEngineTests`)
- **C2:** ✅ definitionId non-optional, no UUID fallback

#### Section D: NO-GO Summary
- ✅ All 4 critical gate tests passing

#### Section E: Minimum Tasks
- **E1:** ✅ No XCTSkip
- **E2:** ✅ No optional definitionId
- **E3:** ✅ RNG state saved/restored
- **E4:** ✅ unitsPerDay removed

#### Section F: UI Safety
- **F1:** ✅ No legacy patterns in Views (`testNoLegacyInitializationInViews`)
- **F2:** ✅ AssetRegistry safety (`testNoDirectUIImageNamedInViewsAndViewModels`)

#### Section G: Expression Conditions
- **G1:** ✅ Typed enums for conditions (`ConditionValidatorTests`)

#### Section H: Definition of Done
- ✅ All criteria met

#### Section I: Non-Blocking Tasks
- **B2:** ✅ Binary pack implemented
- **F1:** ✅ Legacy removed + gate test
- **F2:** ✅ AssetRegistry + gate test

---

### New Gate Tests

#### Added
- `testNoLegacyInitializationInViews()` - Scans Views/ for legacy patterns
- `testNoDirectUIImageNamedInViewsAndViewModels()` - Enforces AssetRegistry usage
- `testNoXCTSkipInEngineTests()` - Updated for GateTests/ path

#### ConditionValidatorTests (10 tests)
- `testValidAbilityConditionTypesExist()` - Whitelist not empty
- `testRejectsUnknownConditionType()` - "WorldResonanse" rejected
- `testRejectsUnknownTrigger()` - "onDamageRecieved" rejected
- `testConditionsUseTypedEnumsNotStrings()` - DecodingError for unknown
- `testAllPackConditionsAreValid()` - Integration validation

---

### Bug Fixes

- Fixed anchor name localization when loading from save
- Fixed Content Manager localization (was showing English keys)
- Removed legacy comment in WorldMapView.swift

---

### Documentation Updates

- Updated `INDEX.md` with test structure
- Updated `CHANGELOG.md` with GateTests/ paths
- Updated `QA_ACT_I_CHECKLIST.md` with new structure
- Updated audit reports with correct paths

---

### Test Summary

| Suite | Tests | Status |
|-------|-------|--------|
| AuditGateTests | 42 | ✅ |
| CodeHygieneTests | 4 | ✅ |
| ConditionValidatorTests | 10 | ✅ |
| ContentManagerTests | 27 | ✅ |
| ContentRegistryTests | 25 | ✅ |
| ContentValidationTests | 8 | ✅ |
| DesignSystemComplianceTests | 5 | ✅ |
| HeroPanelTests | 7 | ✅ |
| HeroRegistryTests | 8 | ✅ |
| LocalizationValidatorTests | 8 | ✅ |
| PackLoaderTests | 21 | ✅ |
| SaveLoadTests | 24 | ✅ |
| **Total** | **189** | ✅ |

---

## [2.0.0] - 2026-01-25 - Audit Complete Release

### Summary

Complete architectural overhaul following comprehensive audit. Project now uses Engine-First architecture with modular Content Pack system, automated compliance testing, and full documentation.

**Test Count:** 256 tests (134 app + 122 engine)
**Build Status:** SUCCESS

---

### Epic 0-3: Engine Architecture

#### Added
- **AssetRegistry** (`Utilities/AssetRegistry.swift`) - Centralized asset management
- **TwilightEngine Swift Package** (`Packages/TwilightEngine/`) - Isolated game engine
  - `Core/` - TwilightGameEngine, GameLoop, TimeEngine, PressureEngine
  - `Cards/` - CardRegistry, CardFactory, CardDefinition
  - `Heroes/` - HeroRegistry, HeroAbility, AbilityRegistry
  - `Combat/` - CombatCalculator, CombatModule
  - `ContentPacks/` - ContentRegistry, PackLoader, PackValidator
  - `Data/` - Definitions, Providers
  - `Events/` - EventPipeline, MiniGameDispatcher
  - `Runtime/` - GameRuntimeState, PlayerRuntimeState, WorldRuntimeState
  - `Localization/` - LocalizableText, StringKey, LocalizedString

#### Changed
- Engine isolated from app target via Swift Package
- All game logic moved to TwilightEngine
- Views only read from Engine, never mutate directly

#### Commits
- `4c11d32` Migrate engine to TwilightEngine Swift Package
- `b9d30d1` Add AssetRegistry for Epic 0.1 compliance

---

### Epic 4-5: Content Pack System

#### Added
- **CharacterPacks** (`Packages/CharacterPacks/`)
  - `CoreHeroes/` - Base hero definitions (JSON)
- **StoryPacks** (`Packages/StoryPacks/`)
  - `Season1/TwilightMarchesActI/` - Act I campaign content
- **Pack Validation** - Checksum verification, schema validation
- **Content Caching** - FileSystemCache, CacheValidator

#### Pack Structure
```
manifest.json       # Pack metadata, version, dependencies
Characters/         # Hero definitions
  heroes.json
  hero_abilities.json
Campaign/
  ActI/
    regions.json
    events.json
    quests.json
    anchors.json
  Enemies/
    enemies.json
Cards/
  cards.json
Balance/
  balance.json
Localization/
  en.json
  ru.json
```

#### Commits
- `6747c2e` Phase 1: Add content pack infrastructure
- `aa5ae01` Phase 2: Add TwilightMarches content pack
- `0bdb926` Phase 3: Decouple Engine from game-specific code
- `65e5341` Phase 4: Add PackValidator and DevTools
- `5db00c2` Phase 5: Add tests and documentation
- `3a81314` Add Act I campaign content

---

### Epic 6-8: Combat & Gameplay

#### Added
- **Engine-First Combat** - All combat through TwilightGameAction
- **Deterministic RNG** - WorldRNG for reproducible gameplay
- **Data-Driven Heroes** - Heroes loaded from JSON, not Swift enums
- **Event System** - EventPipeline with Inline/MiniGame support

#### Changed
- Combat calculations moved to CombatCalculator
- Enemy definitions from JSON (EnemyDefinition)
- Player state managed by PlayerRuntimeState

#### Fixed
- `6f513ae` Player.shuffleDeck() now uses WorldRNG for determinism
- `2156871` Fix combat: expose legacyPlayer for CombatView
- `10cb908` Move setupCombatEnemy from view to initiateCombat
- `6bb92f4` Fix EventView button tap detection

#### Commits
- `ef5d8fc` Engine-First combat system + Content caching
- `723579c` Migrate to data-driven hero system
- `db246be` Audit 2.0: Engine Core Scrubbing & Determinism
- `a5ea153` Fix Act I gameplay: regions, events, combat

---

### Epic 9: UI & Design System

#### Added
- **DesignSystem.swift** (`Utilities/DesignSystem.swift`)
  - `Spacing` - xs(4), sm(8), md(16), lg(24), xl(32), xxl(48)
  - `Sizes` - icon, button, card, avatar dimensions
  - `CornerRadius` - sm(4), md(8), lg(12), xl(16), card(12)
  - `AppColors` - semantic colors (primary, background, text, etc.)
  - `Opacity` - disabled(0.5), overlay(0.3), subtle(0.7)
- **DesignSystemComplianceTests** - Automated enforcement

#### Changed
- All View files migrated to use DesignSystem tokens
- No hardcoded spacing, sizes, or colors in Views

#### Files Modified
- `Views/CardView.swift`
- `Views/CombatView.swift`
- `Views/EventView.swift`
- `Views/HeroSelectionView.swift`
- `Views/PlayerHandView.swift`
- `Views/StatisticsView.swift`
- `Views/WorldMapView.swift`
- `Views/Components/HeroPanel.swift`

#### Commits
- `537c576` Add DesignSystem.swift for Epic 9.1 compliance
- `f1f6b53` Migrate all View files to use DesignSystem constants
- `f3a043e` Add AccentColor to Assets.xcassets
- `86c388e` Add DesignSystem compliance tests
- `d0e75e9` Enable strict DesignSystem compliance

---

### Epic 10: Documentation & Code Hygiene

#### Added
- **CodeHygieneTests** (`CardSampleGameTests/GateTests/CodeHygieneTests.swift`)
  - `testPublicMethodsHaveDocComments()` - Enforces `///` on public methods
  - `testPublicPropertiesHaveDocComments()` - Enforces `///` on public properties
  - `testFilesDoNotExceedLineLimit()` - Max 600 lines for new files
  - `testFilesDoNotHaveTooManyTypes()` - Max 5 types per file

#### Changed
- **CardRegistry.swift** - Added doc comments to all public API
- **HeroRegistry.swift** - Added doc comments to all public API
- **ContentRegistry.swift** - Added doc comments to ContentProvider methods
- **PackLoader.swift** - Extracted BalanceConfiguration (924→583 lines)
- **BalanceConfiguration.swift** - New file with balance config types (365 lines)

#### Legacy Files (Grandfathered)
Files exceeding limits but stable:
- `TwilightGameEngine.swift` (2247 lines)
- `JSONContentProvider.swift` (969 lines)
- `ExplorationModels.swift` (872 lines)
- `ContentRegistry.swift` (844 lines)
- `PackValidator.swift` (699 lines)

#### Commits
- `76a89c4` Epic 10: Documentation & Code Hygiene
- `597da9b` Add CodeHygieneTests for Epic 10 enforcement

---

### Epic 11: QA & Testing

#### Added
- **AuditGateTests** (`CardSampleGameTests/GateTests/AuditGateTests.swift`)
  - Critical engine invariants
  - Determinism verification
  - Save/load round-trip
- **ContentValidationTests** (`CardSampleGameTests/GateTests/ContentValidationTests.swift`)
  - `testAllReferencedFlagsAreKnown` - Catches typos in flag names
  - `testAllReferencedRegionIdsExist` - Validates region references
  - `testAllReferencedQuestIdsExist` - Validates quest references
  - `testAllReferencedEventIdsExist` - Validates event trigger references
  - `testAllReferencedResourceIdsAreKnown` - Validates resource IDs
  - `testAllReferencedRegionStatesAreKnown` - Validates state names
  - `testAllReferencedCardIdsExist` - Validates card references
  - `testContentIntegrityReport` - Diagnostic summary
- **Negative Tests**
  - `testBrokenJSONFailsToLoad()` - Malformed JSON handling
  - `testMissingRequiredFieldsFailsValidation()` - Schema validation
- **Round-Trip Test**
  - `testStateRoundTripSerialization()` - State persistence integrity

#### Removed
- Legacy WorldState tests (superseded by Engine tests)
- Obsolete integration tests

#### Commits
- `66ca6c9` Add gate tests for critical game guarantees
- `4cd3291` Add comprehensive determinism test
- `dd0fa76` Add ContentValidationTests to prevent silent JSON failures

---

### Documentation

#### Added
- `Docs/AUDIT_REPORT_v2.0.md` - Comprehensive audit report
- `Docs/CHANGELOG.md` - This file
- `Docs/INDEX.md` - Documentation navigation

#### Organized
- Active docs in `Docs/`
- Historical docs moved to `Docs/Archive/`

#### Active Documents
| Document | Purpose |
|----------|---------|
| ENGINE_ARCHITECTURE.md | Architecture law |
| EVENT_MODULE_ARCHITECTURE.md | Event system |
| SPEC_CAMPAIGN_PACK.md | Campaign pack spec |
| SPEC_BALANCE_PACK.md | Balance pack spec |
| SPEC_CHARACTER_PACK.md | Character pack spec |
| QA_ACT_I_CHECKLIST.md | QA checklist |
| AUDIT_REPORT_v2.0.md | Audit report |
| CHANGELOG.md | Change history |
| INDEX.md | Navigation |

#### Commits
- `2249e1f` Documentation cleanup: organize into constitution + archive
- `5f7477c` Add Audit Report v2.0

---

### Bug Fixes

- `e03b003` Fix Card initializer argument order in tests
- `8547ab8` Add missing test files to Xcode project
- `0c3c9f6` Remove debug logging from content loading
- `1a713eb` Fix Publishing changes from within view updates crash
- `6bb92f4` Fix EventView button tap detection
- `f806720` Fix critical UI bugs: exploration events, travel errors

---

### Test Summary (v2.0.0)

| Suite | Tests | Status |
|-------|-------|--------|
| AuditGateTests | 4 | ✅ |
| CodeHygieneTests | 4 | ✅ |
| ContentRegistryTests | 35 | ✅ |
| ContentValidationTests | 8 | ✅ |
| DesignSystemComplianceTests | 4 | ✅ |
| HeroPanelTests | 3 | ✅ |
| HeroRegistryTests | 9 | ✅ |
| PackLoaderTests | 44 | ✅ |
| SaveLoadTests | 23 | ✅ |
| **Total** | **134** | ✅ |

*Note: v2.1.0 consolidated tests to 189 with expanded gate tests.*

---

## [1.0.0] - Engine-First Architecture (Baseline)

Initial Engine-First implementation before audit.

### Added
- TwilightGameEngine as single source of truth
- ContentRegistry for pack-based content loading
- CardRegistry and HeroRegistry for runtime content
- AbilityRegistry for hero abilities
- EngineSave for deterministic save/load
- WorldRNG for reproducible randomness

### Changed
- Views read from Engine, not WorldState
- All game data loaded from Content Packs (JSON)
- Heroes defined in JSON, not Swift enums

### Removed
- Direct WorldState manipulation in Views
- Hardcoded hero classes (HeroClass enum)
- Hardcoded card definitions

---

## Architecture Principles

1. **Engine-First**: TwilightGameEngine is the single source of truth
2. **Data-Driven**: All content from Binary .pack files (compiled from JSON)
3. **Deterministic**: WorldRNG ensures reproducible gameplay
4. **Modular**: TwilightEngine as separate Swift Package
5. **Testable**: 340 tests (199 Xcode + 141 SPM) with automated compliance/gate checks
6. **Documented**: All public API has doc comments
7. **Safe**: AssetRegistry fallbacks, typed conditions, no silent failures

---

## Automated Compliance (GateTests/)

| Test Suite | Enforces |
|------------|----------|
| AuditGateTests | Engine invariants, architecture requirements (42 tests) |
| DesignSystemComplianceTests | DesignSystem tokens in Views |
| CodeHygieneTests | Doc comments, file size limits |
| ContentValidationTests | Cross-references in JSON content |
| ConditionValidatorTests | Typed conditions (prevents typos) |
| LocalizationValidatorTests | Canonical localization approach |

New code must pass all compliance tests before merge.

---

See [INDEX.md](INDEX.md) for full documentation map.
See [AUDIT_REPORT_v2.0.md](AUDIT_REPORT_v2.0.md) for detailed audit results.
