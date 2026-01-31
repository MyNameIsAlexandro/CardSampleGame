# Epic 13: Post-Game Design — Bestiary, Statistics, Achievements, Meta Foundation

**Date:** 2026-01-31
**Status:** Implemented
**Type:** Feature Epic

---

## Vision

Epic 13 implements a cross-playthrough player progression system modeled after The Witcher 3's bestiary. Players progressively unlock creature knowledge through encounters, track lifetime combat statistics, and earn achievements. This system persists independently of individual game saves, providing meta-game continuity and replayability incentives.

**Core Experience:**
- Creatures start as "???" and progressively reveal stats, abilities, lore, and tactical data as knowledge levels increase
- Knowledge levels: `unknown` → `encountered` (1 encounter) → `studied` (3 encounters) → `mastered` (5 victories OR 3 pacifications)
- 15 static achievements across 4 categories (combat, exploration, knowledge, mastery)
- Lifetime combat statistics persist across all playthroughs
- MetaState placeholder reserved for future meta-game expansion

---

## Architecture

### Layer Separation

**App Layer** (`Models/`, `Views/`, `Managers/`)
- `PlayerProfile` — root data model (Codable)
- `ProfileManager` — singleton, ObservableObject, UserDefaults persistence
- `AchievementDefinition` — static 15-achievement catalog
- `AchievementEngine` — stateless evaluation logic
- All UI views (BestiaryView, CreatureDetailView, AchievementsView, StatisticsView)

**Engine Layer** (`Packages/TwilightEngine/`)
- `EnemyDefinition` — extended with 6 new optional fields:
  - `lore: LocalizableText?` — Witcher-style scholar quote
  - `tacticsNav/Yav/Prav: LocalizableText?` — faction-specific tactical recommendations
  - `weaknesses: [String]?` — keyword vulnerabilities (e.g., ["fire", "silver"])
  - `strengths: [String]?` — keyword resistances

### Persistence Strategy

**Separate Storage:** ProfileManager uses dedicated UserDefaults key `"twilight_profile"`, distinct from save-slot storage. This ensures:
- Profile survives save-slot deletion
- Works across multiple playthroughs
- Can be independently reset via ProfileManager.resetProfile()

**Recording Points:**
1. **CombatView.applyResultAndDismiss()** — records per-entity encounter outcomes (defeated, pacified, lost, fled)
2. **WorldMapView GameOverView callback** — records playthrough completion (daysSurvived)
3. Both trigger `AchievementEngine.evaluateNewUnlocks()` and persist unlocked achievements

---

## Files

### Data Models
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Models/PlayerProfile.swift`
  - `PlayerProfile` — root struct with creatureKnowledge, combatStats, achievements, totalPlaythroughs, longestSurvival, lastPlayedAt, metaState
  - `CreatureKnowledge` — per-enemy progress with timesEncountered, timesDefeated, timesPacified, timesLostTo, firstMetDay, lastMetDay, level, discoveredTraits
  - `KnowledgeLevel` enum — unknown=0, encountered=1, studied=2, mastered=3 (Comparable)
  - `CombatLifetimeStats` — totalFights, totalVictories, totalDefeats, totalFlees, totalPacifications, totalDamageDealt, totalDamageTaken, totalCardsPlayed, totalFateCardsDrawn
  - `AchievementRecord` — achievementId, unlockedAt timestamp
  - `MetaState` — empty placeholder struct
  - `EncounterOutcomeType` enum — defeated, pacified, lost, fled

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Models/ProfileManager.swift`
  - Singleton ObservableObject
  - `@Published private(set) var profile: PlayerProfile`
  - JSON encoding/decoding to UserDefaults key "twilight_profile"
  - Methods: recordEncounter(), recordPlaythroughEnd(), recordCombatStats(), recordAchievement(), knowledgeLevel(for:), knowledge(for:), resetProfile()

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Models/AchievementDefinition.swift`
  - Static catalog of 15 achievements
  - Categories: `.combat` (6), `.exploration` (3), `.knowledge` (3), `.mastery` (3)
  - Each definition includes: id, titleKey (L10n), descriptionKey (L10n), icon (SF Symbol), category, condition closure

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Models/AchievementEngine.swift`
  - Stateless evaluation: evaluateNewUnlocks(profile:) returns newly unlocked achievement IDs
  - definition(for:), achievements(in:), unlockedCount(profile:), totalCount

### Engine Extensions
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Packages/TwilightEngine/Sources/TwilightEngine/Data/Definitions/EnemyDefinition.swift`
  - Lines 70-87: 6 new optional bestiary fields
  - All backward-compatible (nil defaults)
  - Used by CreatureDetailView for progressive reveal

### UI Views
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Views/BestiaryView.swift`
  - NavigationView with search bar, grouped by EnemyType (beast, spirit, undead, demon, human, boss)
  - Discovery progress header: "X/Y discovered"
  - BestiaryRow: type icon, name, description, knowledge level dots (3 levels), chevron navigation

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Views/CreatureDetailView.swift`
  - Progressive reveal sections based on knowledge.level:
    - Always: headerSection (type, rarity, difficulty)
    - `.encountered`: descriptionSection, personalStatsSection
    - `.studied`: statsSection, abilitiesSection, loreSection
    - `.mastered`: combatInfoSection (weaknesses/strengths), tacticsSection (Nav/Yav/Prav)
    - Below `.mastered`: lockedSectionsHint
  - Witcher 3-style header with type icon, name, badges, difficulty stars

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Views/AchievementsView.swift`
  - Progress header: "X/15 Unlocked" with progress bar
  - Grouped by category (combat, exploration, knowledge, mastery)
  - LazyVGrid 2-column layout
  - AchievementCard shows icon, title, description, unlock date (if unlocked), locked state (grayscale + lock icon)

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Views/StatisticsView.swift`
  - Enhanced with 3 new sections: Combat Lifetime Stats, Knowledge Summary, Meta Progression
  - Uses ProfileManager.shared.profile for all data

### Integration Points
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Views/Combat/CombatView.swift`
  - Line 364-377: applyResultAndDismiss() calls ProfileManager.recordEncounter() per entity with outcome type

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Views/WorldMapView.swift`
  - Line 137-142: GameOverView callback records playthrough end and evaluates achievements

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/App/ContentView.swift`
  - Toolbar buttons: "pawprint.fill" → BestiaryView sheet, "trophy.fill" → AchievementsView sheet

### Tests
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/CardSampleGameTests/GateTests/ProfileGateTests.swift`
  - 13 gate tests (215 lines)
  - Coverage:
    1. PlayerProfile Codable round-trip
    2-5. CreatureKnowledge level progression (encountered, studied, mastered, victory path)
    6. DiscoveredTraits population
    7. AchievementEngine evaluation logic
    8. ProfileManager persistence
    9. Knowledge level ordering
    10. Default values
    11. Profile equality
    12. CombatStats accumulation
    13. MetaState encoding

### Localization
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Utilities/Localization.swift`
  - ~60 new L10n keys:
    - `bestiary.*` (19 keys: title, search, progress, knowledge levels, sections)
    - `achievement.*` (6 keys: unlocked, locked, progress, category names)
    - `enemyType.*` (6 keys: beast, spirit, undead, demon, human, boss)
    - `stats.*` (enhanced with lifetime, knowledge, meta sections)

- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/en.lproj/Localizable.strings`
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/ru.lproj/Localizable.strings`
  - Full bilingual support for all new keys

### Content Data
- `/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame/Packages/StoryPacks/Season1/TwilightMarchesActI/Sources/TwilightMarchesActIContent/Resources/TwilightMarchesActI/Enemies/enemies.json`
  - All 6 enemies updated with lore, tacticsNav, tacticsYav, tacticsPrav, weaknesses, strengths fields
  - Bilingual content using LocalizableText inline strings

---

## Key Design Decisions

### 1. App-Layer Profile, Not Engine
ProfileManager lives in app layer (`Models/`) rather than TwilightEngine. Rationale:
- Spans playthroughs (engine state resets per game)
- UI-centric (drives bestiary/achievements views)
- UserDefaults persistence (platform-specific, not engine concern)

### 2. Separate UserDefaults Key
Profile uses `"twilight_profile"` key, distinct from save-slot storage (`EngineSave`). Benefits:
- Survives save-slot deletion
- Independent reset capability
- Clear separation of concerns (meta-game vs. playthrough state)

### 3. All EnemyDefinition Fields Optional
Bestiary fields (`lore`, `tactics*`, `weaknesses`, `strengths`) use `LocalizableText?` with nil defaults. Benefits:
- Backward compatibility — existing enemies.json files work without migration
- Gradual content population
- Engine remains content-agnostic

### 4. MetaState Placeholder
Empty struct reserved for future meta-game systems (e.g., persistent unlocks, meta-currencies). Rationale:
- Architectural foresight
- No premature implementation
- Easy to extend without breaking Codable compatibility (add optional fields)

### 5. Knowledge Levels Drive UI Visibility
CreatureDetailView uses `if knowledge.level >= .mastered` guards for progressive reveal. Rationale:
- Clean declarative SwiftUI
- Witcher 3 parity (player earns knowledge by playing)
- No separate "unlocked sections" data structure needed

### 6. Faction Tactics Per Creature
Each enemy has 3 tactical recommendations (Nav/Yav/Prav) rather than generic advice. Rationale:
- Faction-specific playstyles (Nav = aggro, Yav = control, Prav = balance)
- Content richness
- Replayability incentive (try different factions to see all tactics)

### 7. Static Achievement Catalog
15 achievements defined at compile-time in `AchievementDefinition.all`, not data-driven. Rationale:
- Simple first implementation
- No JSON parsing overhead
- Easier testing (no content loading)
- Future: can migrate to data-driven if needed (new content packs with achievements)

### 8. Recording Per Entity, Not Per Combat
ProfileManager.recordEncounter() called once per enemy in `result.perEntityOutcomes`. Rationale:
- Multi-enemy combat tracking (3 goblin scouts = 3 separate encounters)
- Accurate knowledge progression (fought 2 scouts + 1 shaman = 2 scout encounters, 1 shaman encounter)
- Aligns with bestiary UX (each creature type progresses independently)

---

## Verification

### Test Coverage
- **ProfileGateTests:** 13 tests, all passing (219 total app tests)
- **Engine Tests:** 358 passing (no regressions from EnemyDefinition extension)

### Design System Compliance
- All views use `Spacing.*`, `Sizes.*`, `CornerRadius.*`, `AppColors.*`, `Opacity.*` tokens
- DesignSystemComplianceTests: 0 violations (tested via `/design-system` skill)

### Integration Points Verified
1. CombatView records encounters per entity ✓
2. WorldMapView records playthrough end ✓
3. Achievement evaluation triggers after combat and game over ✓
4. BestiaryView toolbar accessible from ContentView ✓
5. AchievementsView toolbar accessible from ContentView ✓

### Localization Verified
- All new L10n keys exist in en.lproj and ru.lproj
- BestiaryView, CreatureDetailView, AchievementsView use L10n.* exclusively
- enemies.json uses LocalizableText for bilingual content

### Backward Compatibility
- Existing save files load correctly (PlayerProfile separate storage)
- Existing enemies.json without bestiary fields decode successfully (all optional)
- No migration scripts required

---

## Future Extensions (Out of Scope)

1. **Meta-Currencies:** Add to MetaState for persistent unlock shop
2. **Data-Driven Achievements:** Move to JSON definitions in content packs
3. **Bestiary Filters:** Filter by knowledge level, enemy type, or defeated status
4. **Global Leaderboards:** Sync ProfileManager to CloudKit (requires multiplayer epic)
5. **Creature Animations:** Add animation previews to CreatureDetailView
6. **Tactics Effectiveness Tracking:** Record which faction tactics were most successful per enemy

---

## Notes

- All file paths are absolute (starting with `/Users/abondarenko/...`)
- Epic adheres to TDD gate-test philosophy: ProfileGateTests written before implementation
- No emoji usage per project style guide
- Design aligns with existing save-system architecture (EngineSave for playthrough, PlayerProfile for meta)
