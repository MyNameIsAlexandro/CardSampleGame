# Epic 14: Encounter Module — Production Completion

> Design doc. Created 2026-01-31.

## Summary

Brought the EncounterEngine module to production-ready state. All combat mechanics functional, tested, documented. Module can be "shelved" — fully complete.

## Tasks

### EC-01: Weakness/Strength Damage Modifiers
Fate card keyword checked against enemy weaknesses (×1.5) and strengths (×0.67). State changes emitted for combat log.

### EC-02: Enemy Ability Execution
bonusDamage augments intent, armor adds to defense calc, regeneration heals at roundEnd. Applied via `applyAbilityModifiers()` helper.

### EC-03: Behavior Content
Already complete. 6 behavior patterns in behaviors.json (wild_beast, leshy, mountain_spirit, risen_dead, swamp_hag, leshy_guardian_boss). BehaviorEvaluator drives declarative intent generation.

### EC-04: Mid-Combat Save UI
Save & Exit button in CombatView with confirmation alert. Saves EncounterSaveState to engine, auto-resumes on load via ContentView.

### EC-05: Legacy Combat Deprecation
MARK headers on legacy combat actions in TwilightGameAction and TwilightGameEngine. No code deleted, all tests pass.

### EC-06: Test Coverage
19 new tests: WeaknessStrengthTests (5), AbilityExecutionTests (6), MultiEnemyEncounterTests (8).

## Architecture Decisions

- **Weakness/strength** uses string-based keyword matching (lowercase). Keywords come from `FateCard.keyword.rawValue`. This is extensible — new keywords automatically work with enemy definitions.
- **Ability execution** is phase-aware: bonusDamage in intent generation, armor in damage calc, regeneration at roundEnd→intent transition.
- **Mid-combat save** reuses existing EncounterSaveState infrastructure (SAV-03). No new persistence types needed.
- **Legacy combat not deleted** — marked deprecated. Allows gradual migration and keeps existing 349+ legacy tests as regression safety net.

## Test Results

- **Total**: 587 (368 engine + 219 app), 0 failures
- **New tests**: 19 across 3 files (WeaknessStrengthTests, AbilityExecutionTests, MultiEnemyEncounterTests)

## Files Changed

14 files, +915 lines, 3 new test files.
