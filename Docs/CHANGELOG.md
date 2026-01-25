# Changelog

All notable changes to the CardSampleGame project.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.0.0] - 2026-01-25 - Audit Complete Release

### Summary

Complete architectural overhaul following comprehensive audit. Project now uses Engine-First architecture with modular Content Pack system, automated compliance testing, and full documentation.

**Test Count:** 248 tests (126 app + 122 engine)
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
- **CodeHygieneTests** (`CardSampleGameTests/Engine/CodeHygieneTests.swift`)
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
- **AuditGateTests** (`CardSampleGameTests/Engine/AuditGateTests.swift`)
  - Critical engine invariants
  - Determinism verification
  - Save/load round-trip
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

### Test Summary

| Suite | Tests | Status |
|-------|-------|--------|
| AuditGateTests | 4 | ✅ |
| CodeHygieneTests | 4 | ✅ |
| ContentRegistryTests | 35 | ✅ |
| DesignSystemComplianceTests | 4 | ✅ |
| HeroPanelTests | 3 | ✅ |
| HeroRegistryTests | 9 | ✅ |
| PackLoaderTests | 44 | ✅ |
| SaveLoadTests | 23 | ✅ |
| **App Total** | **126** | ✅ |
| TwilightEngineTests | 122 | ✅ |
| **Grand Total** | **248** | ✅ |

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
2. **Data-Driven**: All content from JSON Content Packs
3. **Deterministic**: WorldRNG ensures reproducible gameplay
4. **Modular**: TwilightEngine as separate Swift Package
5. **Testable**: 248 tests with automated compliance checks
6. **Documented**: All public API has doc comments

---

## Automated Compliance

| Test Suite | Enforces |
|------------|----------|
| DesignSystemComplianceTests | DesignSystem tokens in Views |
| CodeHygieneTests | Doc comments, file size limits |
| AuditGateTests | Engine invariants |

New code must pass all compliance tests before merge.

---

See [INDEX.md](INDEX.md) for full documentation map.
See [AUDIT_REPORT_v2.0.md](AUDIT_REPORT_v2.0.md) for detailed audit results.
