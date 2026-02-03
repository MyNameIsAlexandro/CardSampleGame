# Sprint Board

> Read this file at the start of every Claude session.
> Take the **Next Task**, complete it, update status, commit.

---

## ALL EPICS COMPLETE

Total: 14 epics, 123 tasks, 606 SPM tests + 96 PackEditorKit tests = 702+ total (0 failures), iOS + macOS builds clean.

---

## Closed Epics

1. ~~Epic 1: RNG Normalization~~ CLOSED — 100% WorldRNG, 4 gate tests
2. ~~Epic 2: Transaction Integrity~~ CLOSED — access locked, 8 gate tests, fatalError cleanup
3. ~~Epic 3: Encounter Engine Completion~~ CLOSED — 12 tasks, 31 gate tests (keywords, match, pacify, resonance, phase automation, critical defense, integration)
4. ~~Epic 4: Test Foundation Closure~~ CLOSED — 0 red, 0 skip, determinism verified (100 runs)
5. ~~Epic 5: World Consistency~~ CLOSED — degradation, tension, anchors, 12 gate tests, 30-day simulation
6. ~~Epic 6: Encounter UI Integration~~ CLOSED — CombatView + EncounterViewModel + all widgets, simulator build clean
7. ~~Epic 7: Encounter Module Completion~~ CLOSED — defend, flee, loot, multi-enemy, summon, RNG seed, 11 gate tests
8. ~~Epic 8: Save Safety + Onboarding + Settings~~ CLOSED — fate deck persistence, game over, auto-save, tutorial, settings, 3 gate tests
9. ~~Epic 9: UI/UX Polish~~ CLOSED — HapticManager, SoundManager, floating damage, damage flash, 3D card flip, travel transition, ambient menu, game over animations, AppAnimation + AppGradient tokens
10. ~~Epic 10: Design System Audit~~ CLOSED — 38 violations fixed across 14 files, CardSizes tokens, AppShadows.glow, localized fate strings (en+ru), full token compliance
11. ~~Epic 11: Debt Closure~~ CLOSED — mid-combat save (SAV-03), difficulty wiring (SET-02), Codable on 11 types, EncounterEngine snapshot/restore, view-layer resume, 8 gate tests
12. ~~Epic 12: Pack Editor~~ CLOSED — macOS SwiftUI content authoring tool, 17 source files, 8 editors (enemy/card/event/region/hero/fate/quest/balance), combat simulator with Charts histogram, validate + compile toolbar, NavigationSplitView
13. ~~Epic 13: Post-Game System~~ CLOSED — PlayerProfile persistence, Witcher-3 style bestiary (progressive reveal), 15 achievements (4 categories), enhanced statistics, 13 gate tests, 60 L10n keys (en+ru)
14. ~~Epic 14: Encounter Module — Production Completion~~ CLOSED — weakness/strength modifiers, enemy abilities, mid-combat save UI, legacy deprecation, 19 new tests

### Epic 14: Encounter Module — Production Completion
- **Status**: Complete
- **Commit**: 0282852
- EC-01: Weakness/Strength damage modifiers (×1.5/×0.67)
- EC-02: Enemy ability execution (bonusDamage, armor, regeneration)
- EC-03: Behavior content (6 patterns, already wired)
- EC-04: Mid-combat Save & Exit UI
- EC-05: Legacy combat code deprecated
- EC-06: 19 new tests (702+ total, 0 failures)

## Epic 13: Post-Game System — CLOSED (2026-01-31)

**Scope**: PlayerProfile persistence, Witcher-3 style bestiary with progressive reveal, 15 achievements across 4 categories, enhanced statistics, 13 gate tests, 60 L10n keys (en+ru)

**Tasks completed**: 16 tasks across 5 tiers
- Tier 1 (Foundation): PlayerProfile model, ProfileManager singleton, UserDefaults persistence
- Tier 2 (Bestiary): CreatureKnowledge, KnowledgeLevel progression (unknown→glimpsed→studied→mastered), BestiaryView + CreatureDetailView
- Tier 3 (Achievements): AchievementDefinition, AchievementEngine with unlock/progress tracking, AchievementsView, 15 launch achievements
- Tier 4 (Integration): EnemyDefinition bestiary extensions (6 optional fields), encounter hooks, statistics tracking
- Tier 5 (Testing): 13 gate tests in AuditGateTests

**Key deliverables**:
- ProfileManager singleton with UserDefaults key `twilight_profile`
- Bestiary unlock progression: 1 encounter = glimpsed, 3 = studied, 7 = mastered
- 15 achievements: First Steps (4), Combat Mastery (4), Resonance (4), Exploration (3)
- Enhanced statistics: encounters, kills, deaths, victories, playtime, resonance extremes
- 6 bestiary fields: bestiaryName, category, lore, tactics, habitat, weakness
- 60 localization keys (30 en + 30 ru)

**Test results**: 702+ total (606 SPM + 96 PackEditorKit), 0 failures
- 13 new gate tests in AuditGateTests
- Coverage: persistence, progression, achievement unlock, statistics tracking

**Files**: 8 new, 12 modified
- New: PlayerProfile.swift, ProfileManager.swift, AchievementDefinition.swift, AchievementEngine.swift, BestiaryView.swift, CreatureDetailView.swift, AchievementsView.swift, AuditGateTests.swift
- Modified: EnemyDefinition.swift, EncounterBridge.swift, WorldMapView.swift, Localization.swift, 2 .lproj files, 6 content pack files

## Post-Epic: WCAG Contrast Pass

- Brightened ~20 AppColors to meet WCAG AA 4.5:1 on dark backgrounds
- Replaced `.foregroundColor(.secondary)` → `AppColors.muted` across all Views
- Changed white button text to dark on gold (primary) buttons (2.2:1 → 7:1)
- Added ContrastComplianceTests: 7 gate tests (WCAG 2.1 math)

## Post-Epic: Stabilization Pass (2026-01-31)

**Dead code removal** (~1780 lines):
- GameLoop.swift (~330 lines) — moved EngineGamePhase and GameEndResult to EngineProtocols.swift, deleted unused GameLoopBase class and StandardAction enum
- Legacy combat code (~1450 lines) — removed 9 deprecated actions and 4 test files from pre-EncounterEngine era

**Test coverage expansion** (104 new tests):
- EconomyManager: 17 tests
- PressureEngine: 16 tests
- RequirementsEvaluator: 13 tests
- EventPipeline: 21 tests
- QuestTriggerEngine: 24 tests
- MiniGameDispatcher: 13 tests

**Final metrics**:
- Engine tests: 335 → 439
- Total tests: 702+ (606 SPM + 96 PackEditorKit), 0 failures
- Coverage: ~97% of engine source files (up from 87%)

## Remaining Debt

None — all debt items resolved.

## Gate Test Files

| File | Tests | Scope |
|------|-------|-------|
| INV_RNG_GateTests | 4 | RNG determinism, seed isolation, save/load |
| INV_TXN_GateTests | 8 | Contract tests, save round-trip |
| INV_KW_GateTests | 32 | Keywords, match/mismatch, pacify, resonance costs, enemy mods, phase automation, critical defense, integration, determinism |
| INV_WLD_GateTests | 12 | Degradation rules, state chains, tension game-over, escalation formula, 30-day simulation |
| INV_ENC7_GateTests | 11 | Defend, flee rules, loot distribution, RNG seed, summon |
| INV_SAV8_GateTests | 3 | Fate deck save/load, round-trip, backward compatibility |
| INV_DEBT11_GateTests | 8 | VictoryType Codable, EncounterSaveState round-trip, snapshot/restore, backward compat, difficulty |
| ContrastComplianceTests | 7 | WCAG AA 4.5:1 on cardBackground + backgroundSystem, button contrast, muted text, math validation |
| AuditGateTests | 13 | PlayerProfile persistence, bestiary progression, achievement unlock/progress, statistics tracking, ProfileManager singleton |

## Final Stats

- **SPM tests**: 606 (0 failures, 0 skips)
- **PackEditorKit tests**: 96 (0 failures)
- **Total tests**: 702+
- **Gate tests**: 98 across 9 files
- **iOS Simulator**: builds clean (iPhone 17 Pro)
- **macOS**: builds clean (PackEditor)
- **Architecture**: Engine-First, all state via performAction(), deterministic RNG

Full details:
- Epics 1-6: `docs/plans/2026-01-30-epic-driven-development-design.md`
- Epic 7: `docs/plans/2026-01-30-encounter-completion-design.md`
- Epic 8: `docs/plans/2026-01-30-save-onboarding-design.md`
- Epic 9: `Docs/plans/2026-01-30-ui-ux-polish-design.md`
- Epic 10: `Docs/plans/2026-01-31-design-system-audit-design.md`
- Epic 11: `Docs/plans/2026-01-31-debt-closure-design.md` (plan file)
- Epic 12: `Docs/plans/2026-01-31-pack-editor-design.md` (plan file)
- Epic 13: `Docs/plans/2026-01-31-post-game-system-design.md` (plan file)
- Epic 14: `Docs/plans/2026-01-31-encounter-completion-design.md`

## Milestone: PackEditor v2.3.0

- PackEditorKit extracted as standalone SPM package (96 tests)
- Fate Deck, Resonance, EnemyIntent systems fully integrated
- Total test coverage: 606 SPM + 96 PackEditorKit = 702+ tests

## Post-Epic: Tech Debt Closure (2026-02-03)

**F1) Legacy Adapters — CLOSED**
- WorldMapView uses pure Engine-First architecture
- No legacy init/branches/comments remain
- Gate test: `testNoLegacyInitializationInViews()` passes

**F2) AssetRegistry Safety — CLOSED**
- 3-level fallback chain: primary asset → fallback asset → SF Symbol
- No direct `UIImage(named:)` in Views/ViewModels
- Gate tests: `testMissingAssetHandling_returnsPlaceholder()`, `testAssetRegistry_returnsFallbackForMissingAssets()`, `testNoDirectUIImageNamedInViewsAndViewModels()` pass

**All technical debt from AUDIT_FIXLIST.md is now resolved.**
