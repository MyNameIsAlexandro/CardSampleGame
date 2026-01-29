# TEST_MIGRATION_MAP — Карта миграции TDD-тестов

**Проект:** Сумрачные Пределы (Twilight Marches)
**Дата:** 29 января 2026

> **📜 PROJECT_BIBLE.md — конституция проекта (Source of Truth).**

**Источник:** `Packages/TwilightEngine/Tests/TwilightEngineTests/DualTrackCombatTests.swift`
**Модель:** [ENCOUNTER_TEST_MODEL.md](./ENCOUNTER_TEST_MODEL.md)

---

## Формат

**Статусы:** 🟢 MIGRATED (в TDD) → 🟡 GREEN (готов к миграции) → 🟢 MIGRATED (в целевой директории)

> **Правило:** Каждый тест маппится на **один** целевой ID или имя. Если тест покрывает несколько инвариантов — он должен быть split при миграции.

---

## DualTrackCombatTests (21 тестов)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 1 | `testEnemyHasDualTracks` | LayerTests/ | EncounterEngineTests | `testDualTrackInitialization` | 🟢 MIGRATED |
| 2 | `testPhysicalAttackReducesHPOnly` | GateTests/ | INV_ENC_GateTests | INV-ENC-002 | 🟢 MIGRATED |
| 3 | `testSpiritualInfluenceReducesWPOnly` | GateTests/ | INV_ENC_GateTests | INV-ENC-002 (split: second case) | 🟢 MIGRATED |
| 4 | `testActiveDefenseUsesFateCard` | LayerTests/ | EncounterEngineTests | `testActiveDefenseFateCard` | 🟢 MIGRATED |
| 5 | `testCriticalDefenseZeroDamage` | LayerTests/ | EncounterEngineTests | `testCriticalDefenseBlocksAll` | 🟢 MIGRATED |
| 6 | `testIntentGeneratedAtRoundStart` | LayerTests/ | EncounterEngineTests | `testIntentGeneratedInIntentPhase` | 🟢 MIGRATED |
| 7 | `testIntentVisibleBeforePlayerAction` | LayerTests/ | EncounterEngineTests | `testIntentVisibility` | 🟢 MIGRATED |
| 8 | `testEscalationPenaltyOnSwitchToPhysical` | LayerTests/ | EncounterEngineTests | `testEscalationResonanceShift` | 🟢 MIGRATED |
| 9 | `testEscalationSurpriseDamageBonus` | LayerTests/ | EncounterEngineTests | `testEscalationSurpriseDamage` | 🟢 MIGRATED |
| 10 | `testDeEscalationRageShieldApplied` | LayerTests/ | EncounterEngineTests | `testDeEscalationRageShield` | 🟢 MIGRATED |
| 11 | `testKillPriorityWhenBothZero` | GateTests/ | INV_ENC_GateTests | INV-ENC-003 | 🟢 MIGRATED |
| 12 | `testPacifyWhenWPZeroHPRemains` | LayerTests/ | EncounterEngineTests | `testPacifyOutcome` | 🟢 MIGRATED |
| 13 | `testResonanceCostModifierNavInPrav` | LayerTests/ | ModifierSystemTests | `testResonanceCostModifier` | 🟢 MIGRATED |
| 14 | `testWaitActionConservesFateCard` | LayerTests/ | FateDeckEngineTests | `testWaitNoFateDraw` | 🟢 MIGRATED |
| 15 | `testWaitHasNoHiddenFateDeckSideEffects` | GateTests/ | INV_FATE_GateTests | INV-FATE-002 | 🟢 MIGRATED |
| 16 | `testMulliganReplacesSelectedCards` | LayerTests/ | EncounterEngineTests | `testMulliganReplace` | 🟢 MIGRATED |
| 17 | `testMulliganOnlyOnce` | LayerTests/ | EncounterEngineTests | `testMulliganOnceOnly` | 🟢 MIGRATED |
| 18 | `testEscalationUsesBalancePackValue` | GateTests/ | INV_BHV_GateTests | INV-BHV-004 | 🟢 MIGRATED |
| 19 | `testMultiEnemyPerEntityOutcome` | IntegrationTests/ | EncounterIntegrationTests | `testMultiEnemy1vN` | 🟢 MIGRATED |
| 20 | `testMultiEnemyAllPacifiedIsNonviolent` | IntegrationTests/ | EncounterIntegrationTests | `testMultiEnemyAllPacified` | 🟢 MIGRATED |
| 21 | `testIntentUpdatesOnConditionChange` | LayerTests/ | BehaviorRuntimeTests | `testDynamicIntentUpdate` | 🟢 MIGRATED |

## DualTrackCombatIntegrationTests (3 теста)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 22 | `testFullCombatKillPath` | IntegrationTests/ | EncounterIntegrationTests | `testFullKillPath` | 🟢 MIGRATED |
| 23 | `testFullCombatPacifyPath` | IntegrationTests/ | EncounterIntegrationTests | `testFullPacifyPath` | 🟢 MIGRATED |
| 24 | `testEscalationResonancePenaltyApplied` | IntegrationTests/ | EncounterIntegrationTests | `testEscalationFullCycle` | 🟢 MIGRATED |

## CombatContentValidationTests (9 тестов)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 25 | `testAllBehaviorReferencesExist` | GateTests/ | INV_CNT_GateTests | INV-CNT-001 | 🟢 MIGRATED |
| 26 | `testFateCardIdsUnique` | GateTests/ | INV_CNT_GateTests | INV-CNT-002 | 🟢 MIGRATED |
| 27 | `testFateCardSuitsValid` | GateTests/ | INV_FATE_GateTests | INV-FATE-006 | 🟢 MIGRATED |
| 28 | `testChoiceCardsHaveBothOptions` | GateTests/ | INV_FATE_GateTests | INV-FATE-007 | 🟢 MIGRATED |
| 29 | `testValueFormulaWhitelist` | GateTests/ | INV_BHV_GateTests | INV-BHV-004 | 🟢 MIGRATED |
| 30 | `testValueFormulaMultipliersExist` | GateTests/ | INV_CNT_GateTests | INV-CNT-003 | 🟢 MIGRATED |
| 31 | `testBehaviorConditionsParsable` | GateTests/ | INV_BHV_GateTests | INV-BHV-002 | 🟢 MIGRATED |
| 32 | `testIntentTypesValid` | GateTests/ | INV_BHV_GateTests | INV-BHV-005 | 🟢 MIGRATED |
| 33 | `testFateCardKeywordsValid` | GateTests/ | INV_FATE_GateTests | INV-FATE-008 | 🟢 MIGRATED |

## UniversalFateKeywordTests (7 тестов)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 34 | `testKeywordInterpretationByContext` | LayerTests/ | KeywordInterpreterTests | `testSurgeInCombatPhysical` (split) | 🟢 MIGRATED |
| 35 | `testMatchBonusWhenSuitMatchesAction` | LayerTests/ | KeywordInterpreterTests | `testMatchBonusEnhanced` | 🟢 MIGRATED |
| 36 | `testMismatchGivesOnlyValue` | LayerTests/ | KeywordInterpreterTests | `testMismatchSuppressed` | 🟢 MIGRATED |
| 37 | `testAllKeywordsHaveAllContextEffects` | LayerTests/ | KeywordInterpreterTests | `testAllKeywordsAllContexts` | 🟢 MIGRATED |
| 38 | `testFateDeckStateGlobalAcrossContexts` | GateTests/ | INV_FATE_GateTests | INV-FATE-001 | 🟢 MIGRATED |
| 39 | `testFateCardResolutionOrder` | LayerTests/ | FateDeckEngineTests | `testResolutionOrder` | 🟢 MIGRATED |
| 40 | `testMatchBonusMultiplierFromBalancePack` | GateTests/ | INV_BHV_GateTests | INV-BHV-004 (split: matchMultiplier) | 🟢 MIGRATED |

---

## Сводка по целевым директориям

| Директория | Файл | Количество тестов |
|-----------|------|------------------|
| GateTests/ | INV_ENC_GateTests | 3 |
| GateTests/ | INV_FATE_GateTests | 5 |
| GateTests/ | INV_BHV_GateTests | 5 |
| GateTests/ | INV_CNT_GateTests | 3 |
| LayerTests/ | EncounterEngineTests | 12 |
| LayerTests/ | KeywordInterpreterTests | 4 |
| LayerTests/ | FateDeckEngineTests | 2 |
| LayerTests/ | BehaviorRuntimeTests | 1 |
| LayerTests/ | ModifierSystemTests | 1 |
| IntegrationTests/ | EncounterIntegrationTests | 4 |
| **Итого** | | **40** |

---

**Связанные документы:**
- [ENCOUNTER_TEST_MODEL.md](./ENCOUNTER_TEST_MODEL.md) — тестовая модель
- [TESTING_GUIDE.md](./TESTING_GUIDE.md) — общее руководство
