# Testing Guide

**Project:** Сумрачные Пределы (Twilight Marches)
**Last Updated:** 2026-01-29

> **📜 PROJECT_BIBLE.md — конституция проекта (Source of Truth).**
> ENGINE_ARCHITECTURE.md — SoT для кода/контрактов.

---

## Table of Contents

1. [Test Architecture](#1-test-architecture)
2. [Test Categories](#2-test-categories)
3. [TDD Test Models](#3-tdd-test-models)
4. [Running Tests](#4-running-tests)
5. [Test File Reference](#5-test-file-reference)
6. [Spec-to-Test Traceability Matrix](#6-spec-to-test-traceability-matrix)
7. [Writing New Tests](#7-writing-new-tests)
8. [Test Coverage Goals](#8-test-coverage-goals)
9. [Encounter System Test Model](#9-encounter-system-test-model)

---

## 1. Test Architecture

Tests are organized in two locations:

```
CardSampleGame/
├── CardSampleGameTests/           # App-level tests
│   ├── GateTests/                 # Quality gates (must pass for merge)
│   ├── Unit/                      # Unit tests
│   └── Views/                     # View tests
│
└── Packages/TwilightEngine/
    └── Tests/
        ├── TwilightEngineTests/   # Engine core tests
        └── PackAuthoringTests/    # Pack compiler tests
```

### Test Targets

| Target | Purpose | Location |
|--------|---------|----------|
| `CardSampleGameTests` | App integration, UI, Gate tests | `CardSampleGameTests/` |
| `TwilightEngineTests` | Core engine logic, combat, content | `Packages/TwilightEngine/Tests/` |
| `PackAuthoringTests` | Pack validation, compilation | `Packages/TwilightEngine/Tests/` |

---

## 2. Test Categories

### 2.1 Gate Tests (Must Pass)

Gate tests are **blocking** — PRs cannot merge if these fail.

> **RULE: XCTSkip запрещён в gate tests.** Невозможность проверки = FAIL. Если тест не может выполниться (missing resource, unsupported platform) — это блокер, а не skip.

> **RULE: Gate tests запрещено помечать как flaky/optional.** Нестабильный gate = сломанный gate. Если тест flaky — его нужно починить или удалить, но не "смягчать".

| Test File | Purpose |
|-----------|---------|
| `AuditGateTests.swift` | Architecture rules, file hygiene |
| `DesignSystemComplianceTests.swift` | No magic numbers, use design tokens |
| `LocalizationValidatorTests.swift` | All strings localized |
| `ContentValidationTests.swift` | JSON content valid (см. §2.1.1) |
| `CodeHygieneTests.swift` | No TODOs in production, no debug code |
| `SaveLoadRoundTripTests.swift` | Save/Load integrity (см. §2.1.2) |

#### 2.1.1 ContentValidationTests Requirements

`ContentValidationTests` должен включать проверки для data-driven combat:

| Check | Description |
|-------|-------------|
| `enemies.behavior_id` exists | Все `behavior_id` в enemies.json ссылаются на существующие behaviors |
| Fate cards unique IDs | Все `id` в fate_deck уникальны |
| Fate card suit valid | `suit` ∈ {nav, prav, yav, neutral} |
| Choice cards complete | Карты с `type: "choice"` имеют оба варианта (safe/risk) |
| Conditions parsable | Все `condition` в behaviors.json парсятся без ошибок |

#### 2.1.2 SaveLoadRoundTripTests Requirements

Gate для offline sessions (Project Bible requirement):

| Check | Description |
|-------|-------------|
| Round-trip equality | `save → load → save` даёт идентичные данные по ключевым полям |
| Combat state preserved | Состояние боя (HP, WP, intent, phase) сохраняется |
| Fate deck order preserved | Точный порядок карт в draw pile и discard pile сохраняется (защита от save scumming) |
| RNG state preserved | WorldRNG seed/state сохраняется (для weighted selection и других random) |
| Resonance preserved | World resonance value сохраняется |
| PackSet preserved | Save хранит `packId` + `packVersion`; load отказывает при несовместимости |
| CoreVersion preserved | Save хранит `coreVersion`; load предупреждает/отказывает при major mismatch |

### 2.2 Unit Tests

| Test File | Covers |
|-----------|--------|
| `FateDeckManagerTests.swift` | Fate deck draw, shuffle, reshuffle |
| `FateAttackTests.swift` | Fate-based attack calculations |
| `FateSkillCheckTests.swift` | Skill checks with Fate |
| `CombatSpiritTests.swift` | Dual track spirit damage |
| `CombatEngineFirstTests.swift` | Combat lifecycle, effects |
| `ResonanceEngineTests.swift` | Resonance zones, modifiers |
| `EnemyDefinitionTests.swift` | Enemy loading, resonance modifiers |
| `TimeSystemTests.swift` | Day/night cycle, time costs |

### 2.3 TDD Test Models (New Features)

| Test File | Feature | Status |
|-----------|---------|--------|
| `DualTrackCombatTests.swift` | Dual Track + Active Defense combat | 🔴 RED (TDD) |

> **CI Exclusion:** TDD model tests (RED) **не запускаются в CI gate**, пока не переведены в GREEN. Механизм: фильтр `--skip DualTrackCombat` в CI pipeline (см. §4.3).

> **Definition of Done:** После перевода фичи в DONE соответствующие тесты **обязательно** переводятся из TDD-модели в обычные unit/integration и удаляются из skip-листа. Фича не считается завершённой, пока её тесты не в CI gate.

### 2.4 Integration Tests

| Test File | Covers |
|-----------|--------|
| `GameplayFlowTests.swift` | Full game flow scenarios |
| `Phase3ContractTests.swift` | API contract validation |
| `RegressionPlaythroughTests.swift` | Playthrough regression |

---

## 3. TDD Test Models

### 3.1 DualTrackCombatTests.swift

**Reference:** `Docs/Design/COMBAT_DIPLOMACY_SPEC.md`

This is a **TDD model** — tests are written BEFORE implementation.
Many tests will fail (RED) until the engine code is implemented.

#### Test Scenarios

| Test | Spec Section | Status |
|------|--------------|--------|
| `testEnemyHasDualTracks` | 1.2 Dual Track | 🟢 Should pass |
| `testPhysicalAttackReducesHPOnly` | 3.1 Attack Formula | 🔴 Needs E1 |
| `testSpiritualInfluenceReducesWPOnly` | 3.2 Influence Formula | 🟢 Existing |
| `testActiveDefenseUsesFateCard` | 3.3 Defense Formula | 🔴 Needs implementation |
| `testCriticalDefenseZeroDamage` | 3.3 Critical Defense | 🔴 Needs implementation |
| `testIntentGeneratedAtRoundStart` | 2 Enemy Intent | 🟢 Implemented |
| `testEscalationPenaltyOnSwitchToPhysical` | 5.2 Escalation | 🔴 Needs E6 |
| `testEscalationSurpriseDamageBonus` | 5.2 Escalation | 🔴 Needs E6 |
| `testDeEscalationRageShieldApplied` | 5.1 De-escalation | 🔴 Needs E6 |
| `testEscalationUsesBalancePackValue` | 5 Balance Pack | 🔴 Needs Balance Pack |
| `testKillPriorityWhenBothZero` | 1.2 Kill Priority | 🔴 Needs E4 |
| `testPacifyWhenWPZeroHPRemains` | 1.2 Pacify | 🟢 Existing |
| `testMultiEnemyPerEntityOutcome` | 1.2 Multi-Enemy | 🔴 Needs implementation |
| `testMultiEnemyAllPacifiedIsNonviolent` | 1.2 Multi-Enemy | 🔴 Needs implementation |
| `testWaitActionConservesFateCard` | 2 Wait Action | 🟢 Implemented |
| `testWaitHasNoHiddenFateDeckSideEffects` | 2 Wait (no side effects) | 🔴 Needs verification |
| `testMulliganReplacesSelectedCards` | 2 Mulligan | 🟢 Implemented |
| `testResonanceCostPenaltyInDeepZones` | 4.1 Zone Effects | 🔴 Needs E7 |
| `testIntentUpdatesOnConditionChange` | 6.2 Behaviors | 🔴 Needs E3 |

### 3.2 CombatContentValidationTests (Planned Gate / TDD Model)

> **Status Note:** Эти проверки считаются gate **только после реализации** ContentRegistry и ConditionParser. До этого они остаются TDD model и **не входят в CI gate**. После реализации — переносятся в `ContentValidationTests.swift` и становятся blocking.

| Test | Gate Requirement | Status |
|------|------------------|--------|
| `testAllBehaviorReferencesExist` | behavior_id refs exist | 🔴 Needs ContentRegistry |
| `testFateCardIdsUnique` | Unique IDs | 🔴 Needs ContentRegistry |
| `testFateCardSuitsValid` | Valid suit values | 🔴 Needs ContentRegistry |
| `testChoiceCardsHaveBothOptions` | Choice cards complete | 🔴 Needs ContentRegistry |
| `testValueFormulaWhitelist` | Formulas in whitelist | 🔴 Needs ContentRegistry |
| `testValueFormulaMultipliersExist` | MULTIPLIER_ID exists in balance | 🔴 Needs BalancePack |
| `testBehaviorConditionsParsable` | Conditions parse | 🔴 Needs ConditionParser |
| `testIntentTypesValid` | intent.type ∈ IntentType enum | 🔴 Needs ContentRegistry |
| `testFateCardKeywordsValid` | keyword ∈ FateKeyword enum | 🔴 Needs ContentRegistry |

### 3.3 UniversalFateKeywordTests (TDD Model)

> **Status Note:** Эти тесты определяют поведение Universal Fate Keyword системы. Они станут unit tests после реализации KeywordResolver.

| Test | Spec Section | Status |
|------|--------------|--------|
| `testKeywordInterpretationByContext` | §3.5.2 Interpretation Matrix | 🔴 Needs KeywordResolver |
| `testMatchBonusWhenSuitMatchesAction` | §3.5.3 Match Bonus | 🔴 Needs MatchBonus impl |
| `testMismatchGivesOnlyValue` | §3.5.3 Match Bonus | 🔴 Needs MatchBonus impl |
| `testAllKeywordsHaveAllContextEffects` | §3.5.4 Core Keywords | 🔴 Needs full matrix |

#### How to Use TDD Model

1. Run tests: `swift test --filter DualTrackCombat`
2. See RED failures
3. Implement engine code to make tests GREEN
4. Refactor while keeping tests GREEN

---

## 4. Running Tests

### 4.1 All Tests

```bash
# App tests (requires simulator)
xcodebuild test -scheme CardSampleGame \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Engine tests (no simulator needed)
cd Packages/TwilightEngine && swift test
```

### 4.2 Specific Test Categories

```bash
# Gate tests only
xcodebuild test -scheme CardSampleGame \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CardSampleGameTests/DesignSystemComplianceTests

# Combat tests
cd Packages/TwilightEngine && swift test --filter Combat

# Fate system tests
cd Packages/TwilightEngine && swift test --filter Fate

# TDD model tests
cd Packages/TwilightEngine && swift test --filter DualTrackCombat
```

### 4.3 CI Pipeline

Gate tests run automatically on every PR:

```yaml
# .github/workflows/tests.yml
- name: Gate Tests (App)
  run: |
    xcodebuild test \
      -only-testing:CardSampleGameTests/AuditGateTests \
      -only-testing:CardSampleGameTests/DesignSystemComplianceTests \
      -only-testing:CardSampleGameTests/LocalizationValidatorTests \
      -only-testing:CardSampleGameTests/ContentValidationTests \
      -only-testing:CardSampleGameTests/SaveLoadRoundTripTests

- name: Engine Tests (excluding TDD RED)
  run: |
    cd Packages/TwilightEngine && swift test \
      --skip DualTrackCombatTests \
      --skip DualTrackCombatIntegrationTests
```

> **TDD Model Policy:** Тесты с пометкой 🔴 RED исключены из CI через `--skip`. Когда тест переведён в GREEN, его удаляют из skip-листа и добавляют в обычный прогон.

> **SwiftPM Compatibility:** Синтаксис `--skip` зависит от версии SwiftPM. При обновлении toolchain необходимо проверить и обновить команды в §4.3. Формат: `--skip <TestSuiteName>` (swift 5.7+).

> **Skip List Hygiene:** CI обязан проверять, что skip-список пустеет по мере перевода тестов в GREEN. Правило: если тест в skip-листе более 30 дней без progress — это блокер для merge. Нельзя "держать" тесты в skip годами.

> **Enforcement:** CI job `check-skip-list-age` проверяет файл `.github/tdd-skip-list.yml`. Формат:
> ```yaml
> skipped_tests:
>   - name: DualTrackCombatTests
>     added: 2026-01-28
>     reason: "TDD model for Dual Track combat"
>     tracking_issue: "#123"
> ```
> Job валится если `(today - added) > 30 days` и нет обновления `tracking_issue`.
>
> **Required Artifact:** Workflow обязателен и хранится в `.github/workflows/check-skip-list-age.yml`. Отсутствие файла = CI failure.

> **Release Gate:** CI должен проверять, что `.github/workflows/check-skip-list-age.yml` существует в репозитории. Если файл отсутствует — PR не может быть замержен.

---

## 5. Test File Reference

### TwilightEngineTests/

| File | Tests | Spec Reference |
|------|-------|----------------|
| `CombatEngineFirstTests.swift` | Basic combat, effects | ENGINE_ARCHITECTURE.md |
| `CombatSpiritTests.swift` | Spirit track, pacification | COMBAT_DIPLOMACY_SPEC.md §1.2 |
| `DualTrackCombatTests.swift` | Full Dual Track system | COMBAT_DIPLOMACY_SPEC.md |
| `DataSeparationTests.swift` | Data/code separation | ENGINE_ARCHITECTURE.md |
| `EnemyDefinitionTests.swift` | Enemy loading | SPEC_CAMPAIGN_PACK.md |
| `FateAttackTests.swift` | Fate attack calc | COMBAT_DIPLOMACY_SPEC.md §3.1 |
| `FateDeckManagerTests.swift` | Deck mechanics | GDD Pillar 5 |
| `FateSkillCheckTests.swift` | Skill checks | EXPLORATION_CORE_DESIGN.md |
| `GameplayFlowTests.swift` | Game flow | GDD |
| `Phase3ContractTests.swift` | API contracts | ENGINE_ARCHITECTURE.md |
| `RegressionPlaythroughTests.swift` | Playthrough | QA_ACT_I_CHECKLIST.md |
| `ResonanceEngineTests.swift` | Resonance zones | COMBAT_DIPLOMACY_SPEC.md §4 |
| `TimeSystemTests.swift` | Day/night, time | EXPLORATION_CORE_DESIGN.md |

### CardSampleGameTests/GateTests/

| File | Gates | Failure = Blocker |
|------|-------|-------------------|
| `AuditGateTests.swift` | Architecture rules | Yes |
| `CodeHygieneTests.swift` | No debug code | Yes |
| `ConditionValidatorTests.swift` | Condition expressions | Yes |
| `ContentValidationTests.swift` | JSON validation | Yes |
| `DesignSystemComplianceTests.swift` | Design tokens | Yes |
| `ExpressionParserTests.swift` | Expression syntax | Yes |
| `LocalizationValidatorTests.swift` | L10n coverage | Yes |
| `SaveLoadRoundTripTests.swift` | Save/Load integrity | Yes |

---

## 6. Spec-to-Test Traceability Matrix

Critical spec requirements must have explicit test coverage. This matrix tracks the mapping.

### 6.1 COMBAT_DIPLOMACY_SPEC.md Traceability

| Spec Section | Requirement | Test File | Test Name |
|--------------|-------------|-----------|-----------|
| §1.2 Kill Priority | HP=0 → Kill (regardless of WP) | `DualTrackCombatTests` | `testKillPriorityWhenBothZero` |
| §1.2 Pacify | WP=0 && HP>0 → Pacify | `DualTrackCombatTests` | `testPacifyWhenWPZeroHPRemains` |
| §1.2 Multi-Enemy | Per-entity outcome tracking | `DualTrackCombatTests` | `testMultiEnemyPerEntityOutcome` |
| §1.2 Multi-Enemy | All pacified = nonviolent | `DualTrackCombatTests` | `testMultiEnemyAllPacifiedIsNonviolent` |
| §3.1 Attack Formula | Physical attack reduces HP only | `DualTrackCombatTests` | `testPhysicalAttackReducesHPOnly` |
| §3.2 Influence Formula | Spirit influence reduces WP only | `DualTrackCombatTests` | `testSpiritualInfluenceReducesWPOnly` |
| §3.3 Active Defense | Defense uses Fate card | `DualTrackCombatTests` | `testActiveDefenseUsesFateCard` |
| §3.3 Critical Defense | CRIT = 0 damage | `DualTrackCombatTests` | `testCriticalDefenseZeroDamage` |
| §5 Balance Pack | Values from config, not hardcoded | `DualTrackCombatTests` | `testEscalationUsesBalancePackValue` |
| §5.1 De-escalation | Rage shield applied | `DualTrackCombatTests` | `testDeEscalationRageShieldApplied` |
| §5.2 Escalation | -15 resonance penalty (default) | `DualTrackCombatTests` | `testEscalationPenaltyOnSwitchToPhysical` |
| §5.2 Escalation | x1.5 surprise damage (default) | `DualTrackCombatTests` | `testEscalationSurpriseDamageBonus` |
| §2 Intent | Intent generated at round start | `DualTrackCombatTests` | `testIntentGeneratedAtRoundStart` |
| §2 Wait Action | Wait conserves Fate card | `DualTrackCombatTests` | `testWaitActionConservesFateCard` |
| §2 Wait Action | No hidden FateDeck side effects | `DualTrackCombatTests` | `testWaitHasNoHiddenFateDeckSideEffects` |
| §2 Mulligan | Mulligan replaces cards | `DualTrackCombatTests` | `testMulliganReplacesSelectedCards` |
| §6.2 Behaviors | behavior_id refs exist | `CombatContentValidationTests` | `testAllBehaviorReferencesExist` |
| §6.2 Behaviors | value_formula whitelist | `CombatContentValidationTests` | `testValueFormulaWhitelist` |
| §6.2 Behaviors | MULTIPLIER_ID exists | `CombatContentValidationTests` | `testValueFormulaMultipliersExist` |
| §6.2 Behaviors | intent.type valid | `CombatContentValidationTests` | `testIntentTypesValid` |
| §6.2 Behaviors | Conditions parsable | `CombatContentValidationTests` | `testBehaviorConditionsParsable` |
| §6.3 Fate Cards | Unique IDs | `CombatContentValidationTests` | `testFateCardIdsUnique` |
| §6.3 Fate Cards | Valid suit values | `CombatContentValidationTests` | `testFateCardSuitsValid` |
| §6.3 Fate Cards | Choice cards complete | `CombatContentValidationTests` | `testChoiceCardsHaveBothOptions` |
| §6.4 Fate Cards | Valid keywords | `CombatContentValidationTests` | `testFateCardKeywordsValid` |
| §3.5.2 Keywords | Context interpretation | `UniversalFateKeywordTests` | `testKeywordInterpretationByContext` |
| §3.5.3 Keywords | Match Bonus | `UniversalFateKeywordTests` | `testMatchBonusWhenSuitMatchesAction` |
| §3.5.3 Keywords | Mismatch handling | `UniversalFateKeywordTests` | `testMismatchGivesOnlyValue` |
| §3.5.4 Keywords | All contexts covered | `UniversalFateKeywordTests` | `testAllKeywordsHaveAllContextEffects` |
| §4.1 Zone Effects | Deep zone cost modifiers | `DualTrackCombatTests` | `testResonanceCostPenaltyInDeepZones` |
| §6.2 Behaviors | Dynamic intent update | `DualTrackCombatTests` | `testIntentUpdatesOnConditionChange` |

### 6.2 ENGINE_ARCHITECTURE.md Traceability

| Spec Section | Requirement | Test File | Test Name |
|--------------|-------------|-----------|-----------|
| Engine-First | All actions via Engine | `Phase3ContractTests` | `testAllActionsReturnActionResult` |
| State Tracking | Changes tracked | `Phase3ContractTests` | `testStateChangesAreTracked` |
| Determinism | Same seed = same result | `Phase3ContractTests` | `testEngineDeterministicWithSeed` |
| Save/Load | Round-trip equality | `SaveLoadRoundTripTests` | `testSaveLoadRoundTrip` |

### 6.3 Adding New Traceability

When implementing a new spec requirement:
1. Add entry to this matrix BEFORE writing test
2. Write test with exact name from matrix
3. Update Status column when test is GREEN

---

## 7. Writing New Tests

### 7.1 Test Naming Convention

```swift
func test[Feature]_[Scenario]_[ExpectedResult]()

// Examples:
func testPhysicalAttack_ReducesHP_NotWP()
func testEscalation_SwitchToPhysical_ShiftsResonance()
func testKillPriority_BothZero_KillWins()
```

### 7.2 Test Structure (AAA Pattern)

```swift
func testSomething() {
    // Arrange (Given)
    let engine = TwilightGameEngine()
    engine.initializeNewGame()

    // Act (When)
    engine.performAction(.someAction)

    // Assert (Then)
    XCTAssertEqual(engine.someState, expectedValue)
}
```

### 7.3 TDD Workflow

1. **Write test** that describes expected behavior
2. **Run test** — it should fail (RED)
3. **Implement code** to make test pass
4. **Run test** — it should pass (GREEN)
5. **Refactor** while keeping test GREEN
6. **Repeat**

---

## 8. Test Coverage Goals

| Module | Target | Current |
|--------|--------|---------|
| Combat System | 80% | ~60% |
| Fate Deck | 90% | ~85% |
| Content Loading | 70% | ~70% |
| UI Components | 50% | ~30% |

---

## Appendix: Test Dependencies

### TestContentLoader

Utility for loading test content:

```swift
// In test setUp:
override class func setUp() {
    super.setUp()
    TestContentLoader.loadContentPacksIfNeeded()
}
```

### Mock Fate Deck

For deterministic tests:

```swift
let fateCards = [
    FateCard(id: "f1", modifier: 2, name: "Fortune")
]
engine.setupFateDeck(cards: fateCards)
```

---

---

## 9. Encounter System Test Model

> **Подробная документация:** [ENCOUNTER_TEST_MODEL.md](./ENCOUNTER_TEST_MODEL.md)
> **Карта миграции:** [TEST_MIGRATION_MAP.md](./TEST_MIGRATION_MAP.md)

Encounter System использует **гибридную модель тестирования:** Gate + Layer + Integration + TDD.

### 9.1 Ключевые правила

| Правило | Описание |
|---------|----------|
| **Gate < 2s, no RNG** | Gate-тесты выполняются < 2 секунд, используют только детерминированные фикстуры |
| **Gate = no XCTSkip** | Невозможность проверки = FAIL |
| **TDD/ = только RED** | GREEN тест в TDD/ = CI failure. Немедленный перенос в LayerTests/ или IntegrationTests/ |
| **INV-xxx ID** | Каждый gate-инвариант имеет уникальный ID: `INV-ENC-001`, `INV-FATE-001`, `INV-BHV-001` |
| **Snapshot = атомарная замена** | `apply(snapshot)` заменяет состояние целиком, не merge-ит |
| **Integration = реальный контент** | IntegrationTests/ используют реальный ContentRegistry, не моки |

### 9.2 Структура тестов

```
TwilightEngineTests/
├── GateTests/          # INV-ENC, INV-FATE, INV-BHV инварианты
├── LayerTests/         # Юнит-тесты по компонентам (EncounterEngine, FateDeck, Behavior, Keyword, Modifier)
├── IntegrationTests/   # E2E сценарии (Kill path, Pacify path, Flee, Multi-enemy)
└── TDD/                # Инкубатор (только RED тесты)
```

### 9.3 Инварианты (сводка)

- **INV-ENC-001..007** — Phase Order, Dual Track Independence, Kill Priority, Transaction Atomicity, Determinism, No External State, One Finish Action
- **INV-FATE-001..005** — Conservation, Snapshot Isolation, Reshuffle Trigger, Draw Order Determinism, Sticky Card Persistence
- **INV-BHV-001..004** — Priority Determinism, Unknown Condition Fail, Default Intent Required, Formula Whitelist

---

**Document maintained by:** QA Team
**Review schedule:** After each major feature implementation
