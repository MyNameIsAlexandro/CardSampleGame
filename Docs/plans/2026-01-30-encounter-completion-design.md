# Epic 7: Encounter Module Completion

Date: 2026-01-30
Status: **CLOSED**

## Goal

Close all TODO/stub/partial implementations in the encounter module. After this epic, the encounter system is production-ready.

## Tasks

| ID | Task | Status | Result |
|---|---|---|---|
| ENC-D01 | Defend action: apply defense bonus for the turn | DONE | +3 defense bonus, cleared at roundEnd, 2 gate tests |
| ENC-D02 | Flee rules: enforce canFlee + fate card check | DONE | canFlee check, fate ≥5 escape, <5 punishment damage, 3 gate tests |
| ENC-D03 | Loot distribution: populate lootCardIds on victory | DONE | Loot from killed/pacified enemies, faithReward, 3 gate tests |
| ENC-D04 | Loot integration: add loot cards to player deck | DONE | applyFaithDelta() + addToDeck() in engine, CardFactory lookup in bridge |
| ENC-D05 | Multi-enemy UI: ViewModel + target selection | DONE | enemies array, selectedTargetId, multi-enemy resolve, checkEncounterEnd |
| ENC-D06 | RNG seed from world state | DONE | WorldRNG.shared.next() per encounter, 1 gate test |
| ENC-D07 | Summon intent: enemy spawns ally mid-combat | DONE | summonPool dict, 4 enemy cap, overrideIntentForTest(), 2 gate tests |

## Gate Tests: INV_ENC7_GateTests — 11 tests

| Test | Scope |
|------|-------|
| testDefend_grantsDefenseBonus | +3 bonus applied |
| testDefend_bonusClearedNextRound | Reset after round |
| testFlee_blockedWhenNotAllowed | canFlee=false → error |
| testFlee_successWithHighFate | Fate ≥5 → escaped |
| testFlee_failureDealsDamage | Fate <5 → punishment |
| testLoot_awardedOnVictory | Kill → lootCardIds + faithDelta |
| testLoot_emptyOnEscape | Escape → no loot |
| testLoot_awardedOnPacify | Pacify → lootCardIds + faithDelta |
| testRNGSeed_differentSeedsProduceDifferentResults | Seed variation |
| testSummon_addsEnemy | Enemy count +1 |
| testSummon_cappedAt4 | Max 4 enemies |

## Final Stats

- **347 engine tests**: 0 failures, 0 skips
- **67 gate tests**: across 5 INV_ files
- **Simulator**: builds clean (iPhone 17 Pro)

## Files Modified

### Engine:
- `EncounterEngine.swift` — defend bonus, flee logic, loot collection, summon resolution, overrideIntentForTest
- `EncounterContext.swift` — lootCardIds, faithReward on EncounterEnemy; summonPool on EncounterContext
- `PlayerAction.swift` — new state changes (playerDefended, fleeAttempt, enemySummoned), fleeNotAllowed error
- `EnemyIntent.swift` — summonEnemyId field, .summon() factory
- `TwilightGameEngine.swift` — applyFaithDelta(), addToDeck()

### App:
- `EncounterBridge.swift` — RNG seed from WorldRNG, lootCardIds/faithReward from EnemyDefinition, loot+faith integration
- `EncounterViewModel.swift` — enemies array, selectedTargetId, multi-enemy resolve/intent/checkEnd, flee logic, new state changes
- `Localization.swift` — 6 new L10n keys
- `en.lproj/Localizable.strings` — 6 new strings
- `ru.lproj/Localizable.strings` — 6 new strings

### Tests:
- `INV_ENC7_GateTests.swift` — 11 gate tests
