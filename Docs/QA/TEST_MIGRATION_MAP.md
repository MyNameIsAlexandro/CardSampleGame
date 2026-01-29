# TEST_MIGRATION_MAP — Карта миграции TDD-тестов

**Проект:** Сумрачные Пределы (Twilight Marches)
**Дата:** 29 января 2026

> **📜 PROJECT_BIBLE.md — конституция проекта (Source of Truth).**

**Источник:** `Packages/TwilightEngine/Tests/TwilightEngineTests/DualTrackCombatTests.swift`
**Модель:** [ENCOUNTER_TEST_MODEL.md](./ENCOUNTER_TEST_MODEL.md)

---

## Формат

**Статусы:** 🔴 RED (в TDD) → 🟡 GREEN (готов к миграции) → 🟢 MIGRATED (в целевой директории)

> **Правило:** Каждый тест маппится на **один** целевой ID или имя. Если тест покрывает несколько инвариантов — он должен быть split при миграции.

---

## DualTrackCombatTests (21 тестов)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 1 | `testEnemyHasDualTracks` | LayerTests/ | EncounterEngineTests | `testDualTrackInitialization` | 🔴 RED |
| 2 | `testPhysicalAttackReducesHPOnly` | GateTests/ | INV_ENC_GateTests | INV-ENC-002 | 🔴 RED |
| 3 | `testSpiritualInfluenceReducesWPOnly` | GateTests/ | INV_ENC_GateTests | INV-ENC-002 (split: second case) | 🔴 RED |
| 4 | `testActiveDefenseUsesFateCard` | LayerTests/ | EncounterEngineTests | `testActiveDefenseFateCard` | 🔴 RED |
| 5 | `testCriticalDefenseZeroDamage` | LayerTests/ | EncounterEngineTests | `testCriticalDefenseBlocksAll` | 🔴 RED |
| 6 | `testIntentGeneratedAtRoundStart` | LayerTests/ | EncounterEngineTests | `testIntentGeneratedInIntentPhase` | 🔴 RED |
| 7 | `testIntentVisibleBeforePlayerAction` | LayerTests/ | EncounterEngineTests | `testIntentVisibility` | 🔴 RED |
| 8 | `testEscalationPenaltyOnSwitchToPhysical` | LayerTests/ | EncounterEngineTests | `testEscalationResonanceShift` | 🔴 RED |
| 9 | `testEscalationSurpriseDamageBonus` | LayerTests/ | EncounterEngineTests | `testEscalationSurpriseDamage` | 🔴 RED |
| 10 | `testDeEscalationRageShieldApplied` | LayerTests/ | EncounterEngineTests | `testDeEscalationRageShield` | 🔴 RED |
| 11 | `testKillPriorityWhenBothZero` | GateTests/ | INV_ENC_GateTests | INV-ENC-003 | 🔴 RED |
| 12 | `testPacifyWhenWPZeroHPRemains` | LayerTests/ | EncounterEngineTests | `testPacifyOutcome` | 🔴 RED |
| 13 | `testResonanceCostModifierNavInPrav` | LayerTests/ | ModifierSystemTests | `testResonanceCostModifier` | 🔴 RED |
| 14 | `testWaitActionConservesFateCard` | LayerTests/ | FateDeckEngineTests | `testWaitNoFateDraw` | 🔴 RED |
| 15 | `testWaitHasNoHiddenFateDeckSideEffects` | GateTests/ | INV_FATE_GateTests | INV-FATE-002 | 🔴 RED |
| 16 | `testMulliganReplacesSelectedCards` | LayerTests/ | EncounterEngineTests | `testMulliganReplace` | 🔴 RED |
| 17 | `testMulliganOnlyOnce` | LayerTests/ | EncounterEngineTests | `testMulliganOnceOnly` | 🔴 RED |
| 18 | `testEscalationUsesBalancePackValue` | GateTests/ | INV_BHV_GateTests | INV-BHV-004 | 🔴 RED |
| 19 | `testMultiEnemyPerEntityOutcome` | IntegrationTests/ | EncounterIntegrationTests | `testMultiEnemy1vN` | 🔴 RED |
| 20 | `testMultiEnemyAllPacifiedIsNonviolent` | IntegrationTests/ | EncounterIntegrationTests | `testMultiEnemyAllPacified` | 🔴 RED |
| 21 | `testIntentUpdatesOnConditionChange` | LayerTests/ | BehaviorRuntimeTests | `testDynamicIntentUpdate` | 🔴 RED |

## DualTrackCombatIntegrationTests (3 теста)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 22 | `testFullCombatKillPath` | IntegrationTests/ | EncounterIntegrationTests | `testFullKillPath` | 🔴 RED |
| 23 | `testFullCombatPacifyPath` | IntegrationTests/ | EncounterIntegrationTests | `testFullPacifyPath` | 🔴 RED |
| 24 | `testEscalationResonancePenaltyApplied` | IntegrationTests/ | EncounterIntegrationTests | `testEscalationFullCycle` | 🔴 RED |

## CombatContentValidationTests (9 тестов)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 25 | `testAllBehaviorReferencesExist` | GateTests/ | INV_CNT_GateTests | INV-CNT-001 | 🔴 RED |
| 26 | `testFateCardIdsUnique` | GateTests/ | INV_CNT_GateTests | INV-CNT-002 | 🔴 RED |
| 27 | `testFateCardSuitsValid` | GateTests/ | INV_FATE_GateTests | INV-FATE-006 | 🔴 RED |
| 28 | `testChoiceCardsHaveBothOptions` | GateTests/ | INV_FATE_GateTests | INV-FATE-007 | 🔴 RED |
| 29 | `testValueFormulaWhitelist` | GateTests/ | INV_BHV_GateTests | INV-BHV-004 | 🔴 RED |
| 30 | `testValueFormulaMultipliersExist` | GateTests/ | INV_CNT_GateTests | INV-CNT-003 | 🔴 RED |
| 31 | `testBehaviorConditionsParsable` | GateTests/ | INV_BHV_GateTests | INV-BHV-002 | 🔴 RED |
| 32 | `testIntentTypesValid` | GateTests/ | INV_BHV_GateTests | INV-BHV-005 | 🔴 RED |
| 33 | `testFateCardKeywordsValid` | GateTests/ | INV_FATE_GateTests | INV-FATE-008 | 🔴 RED |

## UniversalFateKeywordTests (7 тестов)

| # | Текущий тест | Целевая директория | Целевой файл | Целевой ID/имя | Статус |
|---|-------------|-------------------|-------------|----------------|--------|
| 34 | `testKeywordInterpretationByContext` | LayerTests/ | KeywordInterpreterTests | `testSurgeInCombatPhysical` (split) | 🔴 RED |
| 35 | `testMatchBonusWhenSuitMatchesAction` | LayerTests/ | KeywordInterpreterTests | `testMatchBonusEnhanced` | 🔴 RED |
| 36 | `testMismatchGivesOnlyValue` | LayerTests/ | KeywordInterpreterTests | `testMismatchSuppressed` | 🔴 RED |
| 37 | `testAllKeywordsHaveAllContextEffects` | LayerTests/ | KeywordInterpreterTests | `testAllKeywordsAllContexts` | 🔴 RED |
| 38 | `testFateDeckStateGlobalAcrossContexts` | GateTests/ | INV_FATE_GateTests | INV-FATE-001 | 🔴 RED |
| 39 | `testFateCardResolutionOrder` | LayerTests/ | FateDeckEngineTests | `testResolutionOrder` | 🔴 RED |
| 40 | `testMatchBonusMultiplierFromBalancePack` | GateTests/ | INV_BHV_GateTests | INV-BHV-004 (split: matchMultiplier) | 🔴 RED |

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
