# Changelog

All notable changes to the CardSampleGame project.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
- **Стало:** `rngSeed: UInt64`, `rngState: UInt64` — обязательные поля, одна строка для restore: `WorldRNG.shared.restoreState(save.rngState)`
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
| SPEC_INVESTIGATOR_PACK.md | Character pack spec |
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
5. **Testable**: 189 tests with automated compliance/gate checks
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
