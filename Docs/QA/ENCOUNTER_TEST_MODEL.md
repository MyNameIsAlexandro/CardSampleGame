# Encounter System — Test Model

**Проект:** Сумрачные Пределы (Twilight Marches)
**Версия:** 1.0
**Дата:** 29 января 2026

> **📜 PROJECT_BIBLE.md — конституция проекта (Source of Truth).**
> ENGINE_ARCHITECTURE.md — SoT для кода/контрактов.

**Зависимости:**
- [ENCOUNTER_SYSTEM_DESIGN.md](../Design/ENCOUNTER_SYSTEM_DESIGN.md) — дизайн системы встреч
- [COMBAT_DIPLOMACY_SPEC.md](../Design/COMBAT_DIPLOMACY_SPEC.md) — спецификация боя/дипломатии
- [TESTING_GUIDE.md](./TESTING_GUIDE.md) — общее руководство по тестам

---

## 1. Файловая структура тестов

```
Packages/TwilightEngine/Tests/TwilightEngineTests/
├── GateTests/                      # Инварианты (блокируют merge)
│   ├── INV_ENC_GateTests.swift     # Encounter Engine invariants
│   ├── INV_FATE_GateTests.swift    # Fate Deck invariants
│   └── INV_BHV_GateTests.swift     # Behavior Runtime invariants
│
├── LayerTests/                     # Юнит-тесты по компонентам
│   ├── EncounterEngineTests.swift  # Turn loop, phases, outcomes
│   ├── KeywordInterpreterTests.swift # Context × Keyword matrix
│   ├── FateDeckEngineTests.swift   # Draw, shuffle, snapshot
│   ├── BehaviorRuntimeTests.swift  # Condition eval, intent selection
│   └── ModifierSystemTests.swift   # Modifier stacking, priorities
│
├── IntegrationTests/               # End-to-end сценарии
│   ├── EncounterIntegrationTests.swift  # Kill path, Pacify path, Flee
│   ├── SnapshotRoundTripTests.swift     # FateDeck/PlayerDeck snapshot
│   └── ContextBuilderTests.swift        # Region→Modifiers pipeline
│
└── TDD/                            # Инкубатор (RED tests, вне CI)
    └── (мигрирующие тесты)
```

### Правила

| Правило | Описание |
|---------|----------|
| **Gate < 2 секунды** | Каждый gate-тест обязан выполняться < 2 секунд. Если дольше — тест переносится в LayerTests/ или оптимизируется |
| **Gate = no RNG** | Gate-тесты запрещено использовать random. Все данные детерминированы (hardcoded fixtures) |
| **Gate = no XCTSkip** | Невозможность проверки = FAIL, не skip |
| **TDD/ = только RED** | В TDD/ директории запрещены GREEN тесты. Тест стал GREEN → немедленный перенос в LayerTests/ или IntegrationTests/ |
| **Один файл = один компонент** | LayerTests/ организованы по компоненту, не по фиче |
| **IntegrationTests/ = реальный ContentRegistry** | Integration-тесты используют реальный контент, не моки |

---

## 2. Gate Tests — Инварианты

Gate-тесты проверяют **архитектурные инварианты**, которые не должны ломаться никогда.
Каждый инвариант имеет уникальный ID формата `INV-{MODULE}-{NNN}`.

### 2.1 INV-ENC — Encounter Engine Invariants

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-ENC-001 | **Phase Order** | Вызовы фаз в неправильном порядке → Engine возвращает `.invalidPhaseOrder` error | Принятие действия вне очереди |
| INV-ENC-002 | **Dual Track Independence** | Physical attack → только HP меняется; Spirit → только WP | HP и WP меняются одновременно от одного действия |
| INV-ENC-003 | **Kill Priority** | HP=0 → outcome = .killed, независимо от WP | WP=0 && HP=0 → outcome != .killed |
| INV-ENC-004 | **Transaction Atomicity** | Abort mid-encounter → ни одно поле мира не изменено | Частичное применение transaction |
| INV-ENC-005 | **Determinism** | Одинаковый EncounterContext + одинаковый seed → побитово идентичный EncounterResult | Расхождение при повторном запуске |
| INV-ENC-006 | **No External State** | Encounter Engine не читает и не пишет ничего вне EncounterContext/EncounterResult | Обращение к глобальному состоянию (синглтонам, файлам) |
| INV-ENC-007 | **One Finish Action** | Попытка второго Finish Action за раунд → `.actionNotAllowed` error | Два Finish Action проходят без ошибки |

**Формат теста:**

```swift
// INV-ENC-001: Phase Order
func test_INV_ENC_001_PhaseOrderEnforced() {
    // Arrange: encounter в Phase 1 (Intent)
    let ctx = EncounterContextFixtures.standard()
    let engine = EncounterEngine(context: ctx)

    // Act: попытка Player Action до завершения Intent
    let result = engine.performPlayerAction(.attack(targetId: "enemy_1"))

    // Assert: ошибка, а не молчаливый пропуск
    XCTAssertEqual(result.error, .invalidPhaseOrder)
}
```

### 2.2 INV-FATE — Fate Deck Invariants

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-FATE-001 | **Conservation** | `drawPile.count + discardPile.count + removedPile.count + hand.count == initialTotal + addedSticky.count` | Карта появилась из ниоткуда или исчезла |
| INV-FATE-002 | **Snapshot Isolation** | Изменение snapshot внутри Encounter не влияет на оригинальный FateDeckManager до apply() | Изменение snapshot мутирует оригинал |
| INV-FATE-003 | **Reshuffle Trigger** | drawPile пустой → автоматический reshuffle (discard → draw, shuffle). Если и discard пустой → `.deckExhausted` error, не бесконечный цикл | Зависание или panic |
| INV-FATE-004 | **Draw Order Determinism** | Одинаковый seed → одинаковая последовательность draw. 100 итераций — 100 одинаковых результатов | Расхождение на любой итерации |
| INV-FATE-005 | **Sticky Card Persistence** | Sticky card (проклятие) остаётся в колоде после reshuffle. `removedPile` не содержит sticky cards | Sticky card исчезла после reshuffle |

### 2.3 INV-BHV — Behavior Runtime Invariants

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-BHV-001 | **Priority Determinism** | Два правила с одинаковым priority → стабильный порядок (по id: лексикографически) | Разный Intent при повторном запуске |
| INV-BHV-002 | **Unknown Condition Fail** | Неизвестный `condition.type` → hard fail при валидации, safe fallback (default intent) в runtime | Crash в runtime ИЛИ silent skip при валидации |
| INV-BHV-003 | **Default Intent Required** | Behavior без хотя бы одного `conditions: []` правила → validation error | Enemy без intent на раунд (deadlock) |
| INV-BHV-004 | **Formula Whitelist** | `value_formula` содержит hardcoded число → validation error. Допускаются только: `"power"`, `"influence"`, `"hp_percent"`, `"power * MULTIPLIER_ID"`, `"influence * MULTIPLIER_ID"` | Число прошло валидацию |

---

## 3. Layer Tests — Юнит-тесты по компонентам

Layer-тесты проверяют **поведение** конкретных компонентов в изоляции.

### 3.1 EncounterEngineTests

| Тест | Что проверяет | Mock/Stub |
|------|---------------|-----------|
| `testTurnLoopAdvancesPhases` | Phase 1→2→3→4→1 корректно | Stub participants |
| `testVictoryConditionKill` | HP=0 → outcome .killed | — |
| `testVictoryConditionPacify` | WP=0, HP>0 → outcome .pacified | — |
| `testFleeWithCost` | Flee → outcome .escaped, cost applied | — |
| `testCustomVictoryCondition` | survive(rounds: 5) → victory после 5 раундов | Stub encounterRules |
| `testEscalationResonanceShift` | Spirit→Body → resonance -= balancePack.escalationResonanceShift | Stub balance pack |
| `testDeEscalationRageShield` | Body→Spirit → RageShield = power × turns × rageShieldFactor | Stub balance pack |
| `testFinishActionLimit` | Второй Finish Action → error, не silent ignore | — |

**Принцип:** EncounterEngine тестируется через его публичный API (performAction, advancePhase). Внутренние структуры не мокаются. Mock допускается только для внешних протоколов (FateDeckProvider, participants).

### 3.2 KeywordInterpreterTests

| Тест | Что проверяет |
|------|---------------|
| `testSurgeInCombatPhysical` | surge + combatPhysical → конкретный эффект |
| `testSurgeInExploration` | surge + exploration → другой эффект |
| `testMatchBonusEnhanced` | Nav card + Nav action → enhanced effect |
| `testMismatchSuppressed` | Nav card + Prav action → keyword suppressed |
| `testAllKeywordsAllContexts` | 5 keywords × 5 contexts = 25 комбинаций, ни одна не nil |
| `testUnknownKeywordFallback` | Неизвестный keyword → safe fallback (value only, no effect) |

### 3.3 FateDeckEngineTests

| Тест | Что проверяет |
|------|---------------|
| `testDrawReducesPile` | draw() → drawPile.count -= 1 |
| `testReshuffleOnEmpty` | Пустой drawPile → auto reshuffle |
| `testSnapshotIsolation` | Изменение snapshot ≠ изменение оригинала |
| `testStickyCardSurvivesReshuffle` | Sticky card в draw pile после reshuffle |
| `testPeekDoesNotConsume` | peek(3) → drawPile.count не меняется |
| `testDeterministicDraw` | Одинаковый seed → одинаковая последовательность |
| `testRemovedPileNotReshuffled` | One-time карта из removedPile не возвращается при reshuffle |

### 3.4 BehaviorRuntimeTests

| Тест | Что проверяет |
|------|---------------|
| `testHighPriorityWins` | Rule с priority 10 выбирается над priority 1 |
| `testConditionEvaluation` | hp_below_percent(30) + enemy.hp=20% → true |
| `testDefaultFallback` | Ни одно условие не сработало → default intent |
| `testCompositeConditions` | AND из двух условий → оба должны быть true |
| `testUnknownConditionSafeFallback` | Неизвестный type → safe fallback в runtime (не crash) |
| `testHasFateCardSuit` | has_fate_card_suit("nav") + nav card в руке → true |
| `testLastPlayerAction` | last_player_action("attack") после атаки → true |

### 3.5 ModifierSystemTests

| Тест | Что проверяет |
|------|---------------|
| `testModifierApplied` | heal_mult: 0.5 → healing halved |
| `testModifierStacking` | Два модификатора на одну цель → оба применяются |
| `testModifierSourceUIName` | sourceUIName доступен для UI |
| `testNoModifiers` | Пустой список модификаторов → базовые значения |

---

## 4. Integration Tests — End-to-End сценарии

Integration-тесты проверяют **полный pipeline** от EncounterContext до EncounterResult. Используют **реальный ContentRegistry** (не моки).

### 4.1 EncounterIntegrationTests

| Тест | Сценарий | Ожидаемый результат |
|------|----------|---------------------|
| `testFullKillPath` | 1v1, физические атаки до HP=0 | outcome = .killed, WP > 0 |
| `testFullPacifyPath` | 1v1, духовные атаки до WP=0 | outcome = .pacified, HP > 0 |
| `testFleePath` | 1v1, Flee на 2-м раунде | outcome = .escaped, cost в transaction |
| `testEscalationFullCycle` | Spirit→Body→проверка resonance + damage | resonanceShift в transaction |
| `testMultiEnemy1vN` | 1v3, kill первого, pacify второго, flee от третьего | per-entity outcomes |
| `testCustomVictorySurvival` | survive(5) условие, выжить 5 раундов | outcome = .victory(.custom("survive")) |

**Правило:** Каждый тест включает проверку EncounterResult.transaction на полноту (все ожидаемые resourceChanges, worldFlags, resonanceShift присутствуют).

### 4.2 SnapshotRoundTripTests

| Тест | Что проверяет |
|------|---------------|
| `testFateDeckSnapshotRoundTrip` | makeSnapshot → encounter → updatedFateDeck → apply → состояние корректно |
| `testPlayerDeckSnapshotRoundTrip` | Аналогично для PlayerDeck |
| `testSnapshotAfterAbort` | Abort encounter → оригинальное состояние не изменено |
| `testSnapshotWithStickyCards` | Sticky cards сохраняются через round-trip |

**Принцип:** Snapshot = атомарная замена. `apply(snapshot)` полностью заменяет состояние, не merge-ит.

### 4.3 ContextBuilderTests

| Тест | Что проверяет |
|------|---------------|
| `testRegionToModifiers` | "Болото" → {heal_mult: 0.5} в modifiers |
| `testCursesToModifiers` | Active curse → modifier в context |
| `testResonanceZone` | WorldResonance=-80 → zone: "deep_nav" |
| `testEmptyContext` | Нет модификаторов → валидный context без modifiers |

---

## 5. TDD Migration — Перенос из инкубатора

### 5.1 Правила миграции

1. **Тест стал GREEN** → перенос из TDD/ в LayerTests/ или IntegrationTests/ в том же PR
2. **GREEN тесты запрещены в TDD/** — CI проверяет директорию TDD/ на отсутствие проходящих тестов. Проходящий тест в TDD/ = CI failure
3. **При переносе тест переименовывается** по конвенции целевой директории (INV-xxx для Gate, component_scenario для Layer)
4. **Skip-list обновляется** в том же PR (удаление из `.github/tdd-skip-list.yml`)
5. **Spec-to-Test Traceability Matrix** (TESTING_GUIDE.md §6) обновляется в том же PR

### 5.2 Первые 5 тестов для Gate (из текущих DualTrackCombatTests)

| Текущий тест | Целевой Gate ID | Целевой файл |
|-------------|----------------|--------------|
| `testPhysicalAttackReducesHPOnly` | INV-ENC-002 | INV_ENC_GateTests.swift |
| `testKillPriorityWhenBothZero` | INV-ENC-003 | INV_ENC_GateTests.swift |
| `testWaitHasNoHiddenFateDeckSideEffects` | INV-FATE-002 (Snapshot Isolation aspect) | INV_FATE_GateTests.swift |
| `testEscalationUsesBalancePackValue` | INV-BHV-004 (Formula Whitelist aspect) | INV_BHV_GateTests.swift |
| `testIntentGeneratedAtRoundStart` | INV-ENC-001 (Phase Order aspect) | INV_ENC_GateTests.swift |

### 5.3 Enforcement

- **CI job:** `check-tdd-green` сканирует TDD/ директорию. Если хотя бы один тест проходит — job fails
- **PR review checklist:** "Мигрированные тесты удалены из TDD/ и добавлены в целевую директорию"
- **Skip-list age:** см. TESTING_GUIDE.md §4.3 — максимум 30 дней без прогресса

---

## Appendix A: Fixture Conventions

```swift
// Стандартные фикстуры для gate-тестов
enum EncounterContextFixtures {
    /// Минимальный валидный контекст: 1 герой, 1 враг, 5 fate cards
    static func standard() -> EncounterContext { ... }

    /// Контекст с multi-enemy (1 vs 3)
    static func multiEnemy() -> EncounterContext { ... }

    /// Контекст с модификаторами среды
    static func withModifiers(_ mods: [EncounterModifier]) -> EncounterContext { ... }
}

enum FateDeckFixtures {
    /// Детерминированная колода: 5 карт с известными modifier/keyword/suit
    static func deterministic() -> [FateCard] { ... }

    /// Колода с одной sticky-картой
    static func withSticky() -> [FateCard] { ... }
}
```

---

**Связанные документы:**
- [TESTING_GUIDE.md](./TESTING_GUIDE.md) — общее руководство (ключевые правила)
- [TEST_MIGRATION_MAP.md](./TEST_MIGRATION_MAP.md) — карта миграции TDD-тестов
- [ENCOUNTER_SYSTEM_DESIGN.md](../Design/ENCOUNTER_SYSTEM_DESIGN.md) — дизайн системы
