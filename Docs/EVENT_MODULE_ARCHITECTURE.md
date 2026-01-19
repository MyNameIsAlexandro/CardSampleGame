# Event Module v1.0
## Engine-Level Event System Architecture (Setting-Agnostic)

**Версия:** 1.0
**Статус:** Architecture Lock
**Дата:** Январь 2026

> **Это модуль движка.** Сеттинг, тексты и конкретные сущности (монстры/NPC/локации) сюда не входят.
> См. общую архитектуру: [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md)

---

## Содержание

1. [Назначение модуля](#1-назначение-модуля)
2. [Позиция в Engine v1.0](#2-позиция-в-engine-v10)
3. [Термины](#3-термины)
4. [Два класса событий: Inline vs Mini-Game](#4-два-класса-событий-inline-vs-mini-game)
5. [Канонический Pipeline](#5-канонический-pipeline)
6. [Контракты данных](#6-контракты-данных)
7. [Типы событий v1.0](#7-типы-событий-v10)
8. [Контракт Mini-Game Module](#8-контракт-mini-game-module)
9. [Инварианты](#9-инварианты)
10. [Тесты](#10-тесты)

---

## 1. Назначение модуля

Event Module — переиспользуемая подсистема движка, отвечающая за:
- Генерацию событий на основе контекста (регион, давление, флаги)
- Исполнение событий (выбор → последствия)
- Интеграцию с Mini-Game модулями (Combat, Puzzle, etc.)

### Ключевая идея

```
┌─────────────────────────────────────────────────────────────┐
│  Программировать один раз → Создавать тысячи вариаций      │
│                                                             │
│  • Логика CombatEvent написана один раз в ядре              │
│  • Дизайнер меняет JSON (враг, фон, награда) — не код       │
│  • Тестируется изолированно, без запуска всей игры          │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Позиция в Engine v1.0

```
┌─────────────────────────────────────────────────────────────┐
│                      ENGINE CORE                            │
│  TimeEngine │ PressureEngine │ QuestEngine │ EconomyManager │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     EVENT MODULE                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ EventPipeline│  │ EventResolver│  │ MiniGameDispatcher │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ CARTRIDGE│ │  RUNTIME │ │MINI-GAMES│
        │ (Content)│ │  (State) │ │ (Modules)│
        └──────────┘ └──────────┘ └──────────┘
```

**Связи:**
- **Engine Core:** TimeEngine (cost), PressureEngine (thresholds), QuestEngine (triggers), EconomyManager (transactions)
- **Cartridge:** ContentProvider (EventDefinitions), RuleSets (filters/weights)
- **Runtime:** EventRuntimeState (completed/cooldowns), WorldFlags, RegionFlags
- **Mini-Games:** CombatModule, SkillCheckModule, PuzzleModule, etc.

---

## 3. Термины

| Термин | Определение |
|--------|-------------|
| **EventDefinition** | Статичное определение события (JSON/Codable). Data layer. |
| **EventRuntimeState** | Динамика: completed, cooldown, seenCount. State layer. |
| **EventContext** | Контекст генерации: регион, давление, флаги, seed. |
| **Choice** | Вариант решения внутри события. |
| **Outcome / Consequence** | Результат выбора: транзакции, флаги, модификации мира. |
| **Challenge** | Формальная «проблема» для resolver (combat/check/puzzle). |
| **MiniGameChallenge** | Описание задачи для внешнего Mini-Game модуля. |
| **ResolutionResult** | Формальный результат Mini-Game (diff, не мутация). |

---

## 4. Два класса событий: Inline vs Mini-Game

> **Ключевое правило:** Событие становится Mini-Game только если содержит `MiniGameChallenge`.

### 4.1 Inline Events (внутри основного флоу)

Inline-события:
- НЕ требуют отдельного экрана/режима
- Разрешаются выбором и/или простым check
- Применяют последствия и возвращают управление в Core Loop

```
┌─────────────────────────────────────────┐
│           INLINE EVENT FLOW             │
│                                         │
│  WorldMap → Event → Choice → Outcome    │
│                         ↓               │
│                    Back to Map          │
└─────────────────────────────────────────┘
```

**Типы inline событий:**
- Narrative
- Simple Choice / Ritual
- Exploration (без challenge)
- WorldShift (системные)

### 4.2 Mini-Game Event Modules (отдельные режимы)

Mini-Game события:
- Переключают игрока с карты на **отдельный режим/экран**
- Имеют **собственный цикл/состояние**
- Возвращают **формальный результат** (не мутируют мир напрямую)

```
┌─────────────────────────────────────────────────────────────┐
│              MINI-GAME EVENT FLOW                           │
│                                                             │
│  WorldMap → Event → MiniGameChallenge                       │
│                           ↓                                 │
│              ┌────────────────────────┐                     │
│              │     MINI-GAME MODE     │  ← Отдельный экран  │
│              │  (Combat / Puzzle / …) │  ← Свой цикл        │
│              └───────────┬────────────┘                     │
│                          ↓                                  │
│               ResolutionResult + Diff                       │
│                          ↓                                  │
│              Engine applies outcomes                        │
│                          ↓                                  │
│                    Back to Map                              │
└─────────────────────────────────────────────────────────────┘
```

**Примеры Mini-Game модулей:**
- **CombatModule** — карточный/кубиковый бой
- **SkillCheckModule** — проверка навыков
- **PuzzleModule** — мини-головоломка
- **SocialModule** — переговоры как игра
- **CampModule** — улучшения/отдых (если отдельный режим)

### 4.3 Матрица: Inline или Mini-Game?

| Тип события | По умолчанию | Когда Mini-Game? |
|-------------|--------------|------------------|
| Combat | **Mini-Game** | Всегда |
| Choice/Ritual | Inline | Если содержит Challenge |
| Narrative | Inline | Никогда |
| Exploration | Inline | Если skill/puzzle challenge |
| WorldShift | Inline | Редко (ритуал мира) |

---

## 5. Канонический Pipeline

### 5.1 Генерация события (Selection)

**Вход:** `EventContext`

```json
{
  "regionId": "region_forest_01",
  "regionState": "Borderland",
  "regionType": "forest",
  "pressure": 42,
  "time": 17,
  "flags": {
    "world": ["met_stranger"],
    "region": ["explored_ruins"],
    "quest": ["quest_step_2"]
  },
  "activeQuests": ["main_quest_01"],
  "phase": "ActI",
  "rngSeed": 12345
}
```

**Процесс:**

```
1. ContentProvider.getEvents(regionId, regionType)
      ↓
2. RuleSet.filter(events, context)
   • regionState match
   • pressure in range
   • requiredFlags present
   • forbiddenFlags absent
   • !completed (если oneTime)
      ↓
3. WeightedSelection(filteredEvents, rngSeed)
   • base weight
   • pressure modifiers
   • quest priority boost
      ↓
4. ResolvedEvent
```

**Выход:** `ResolvedEvent` (выбранное событие + вычисленные модификаторы)

### 5.2 Исполнение события (Resolution)

**Вход:** `ResolvedEvent`

**Процесс (11 шагов):**

```
 1. Check instant flag → timeCost = 0 or 1
 2. TimeEngine.advance(timeCost)
 3. Display event (title, body, choices)
 4. Player selects choice
 5. Validate choice requirements (economy/flags/thresholds)
 6. If choice has MiniGameChallenge:
    └─→ Dispatch to MiniGameModule
        └─→ Receive ResolutionResult
 7. Build Transaction from outcome + resolutionResult
 8. EconomyManager.process(transaction)
 9. Apply flags (set/unset)
10. Apply world modifications (tension, anchor, region)
11. QuestEngine.tick() → check triggers
12. Mark completed / update cooldown
13. Check victory/defeat conditions
```

**Выход:** `EventResult`

```json
{
  "eventId": "evt_combat_01",
  "choiceId": "choice_fight",
  "appliedTransactions": [
    {"type": "cost", "resource": "health", "amount": -5},
    {"type": "gain", "resource": "faith", "amount": 10}
  ],
  "flagsChanged": {
    "set": ["defeated_wolf"],
    "unset": []
  },
  "worldDiff": {
    "tensionDelta": -2,
    "regionStateDelta": null,
    "anchorIntegrityDelta": 0
  },
  "questDiff": {
    "objectivesCompleted": ["kill_wolf"],
    "questsAdvanced": ["hunt_quest"]
  },
  "miniGameResult": {
    "outcome": "victory",
    "rewardMultiplier": 1.5
  }
}
```

---

## 6. Контракты данных

### 6.1 EventDefinition (Data Layer)

> **Примечание:** JSON-формат для Phase 5 (JSONContentProvider).
> Swift-код использует `eventKind: EventKind` вместо `type`.

```json
{
  "id": "evt_combat_wolf",
  "eventKind": {"miniGame": "combat"},
  "titleKey": "evt_combat_wolf_title",
  "bodyKey": "evt_combat_wolf_body",
  "isInstant": false,
  "isOneTime": false,
  "weight": 10,
  "cooldown": 0,
  "poolIds": ["forest_events", "combat_events"],

  "availability": {
    "regionStates": ["borderland", "breach"],
    "regionTypes": ["forest", "mountain"],
    "minPressure": 20,
    "maxPressure": 80,
    "requiredFlags": [],
    "forbiddenFlags": ["wolf_dead"],
    "questLinks": []
  },

  "choices": [
    {
      "id": "choice_fight",
      "labelKey": "evt_combat_wolf_fight",
      "tooltipKey": null,
      "requirements": {
        "minResources": {},
        "requiredFlags": [],
        "forbiddenFlags": [],
        "minBalance": null,
        "maxBalance": null
      },
      "consequences": {
        "resourceChanges": {"faith": 5},
        "setFlags": ["wolf_dead"],
        "clearFlags": [],
        "balanceDelta": -5,
        "regionStateChange": null,
        "questProgress": null,
        "triggerEventId": null,
        "resultKey": "evt_combat_wolf_victory"
      }
    },
    {
      "id": "choice_flee",
      "labelKey": "evt_combat_wolf_flee",
      "tooltipKey": null,
      "requirements": null,
      "consequences": {
        "resourceChanges": {"health": -3},
        "setFlags": [],
        "clearFlags": [],
        "balanceDelta": 0,
        "regionStateChange": null,
        "questProgress": null,
        "triggerEventId": null,
        "resultKey": "evt_combat_wolf_fled"
      }
    }
  ],

  "miniGameChallenge": {
    "id": "challenge_wolf_pack",
    "challengeKind": "combat",
    "difficulty": 3,
    "contextRef": "enemy_wolf_pack"
  }
}
```

### 6.2 EventRuntimeState (State Layer)

```json
{
  "completedEventIds": ["evt_intro_01", "evt_combat_wolf"],
  "cooldowns": {
    "evt_merchant": 3,
    "evt_wanderer": 5
  },
  "seenCounts": {
    "evt_exploration_forest": 2,
    "evt_random_encounter": 7
  }
}
```

### 6.3 MiniGameChallengeDefinition

> **Примечание:** Swift-код использует `MiniGameChallengeKind` вместо `type`.

```json
{
  "id": "challenge_wolf_pack",
  "challengeKind": "combat",
  "difficulty": 3,
  "contextRef": "enemy_wolf_pack",
  "titleKey": "challenge_wolf_title",
  "baseReward": {"faith": 10},
  "basePenalty": {"health": -5}
}
```

**Runtime modifiers (передаются в MiniGame Module):**
```json
{
  "pressure": 42,
  "regionState": "borderland",
  "playerBalance": 65
}
```

---

## 7. Типы событий v1.0

### 7.1 Combat Event — Mini-Game Module

**Класс:** Mini-Game (всегда)

**Цель:** Разрешать конфликт через подключаемый CombatModule.

```
┌─────────────────────────────────────────────────────────────┐
│                    COMBAT EVENT                             │
│                                                             │
│  Входы:                                                     │
│  • EventContext                                             │
│  • MiniGameChallenge(type: combat, ref: enemyId)           │
│  • PlayerState (health, cards, curses)                     │
│  • Modifiers (pressure, regionState)                       │
│                                                             │
│  Процесс:                                                   │
│  1. Event pipeline выбирает событие                        │
│  2. Движок вызывает CombatModule.run(challenge)            │
│  3. Игрок проходит бой (отдельный экран)                   │
│  4. CombatModule возвращает ResolutionResult               │
│  5. Движок применяет outcomes                              │
│                                                             │
│  Выходы:                                                    │
│  • ResolutionResult {outcome, rewardMult, damageDealt}     │
│  • EventResult {transactions, flags, worldDiff}            │
└─────────────────────────────────────────────────────────────┘
```

**Extension Point:** `CombatModule` protocol (карты/кубики/сравнение)

---

### 7.2 Choice / Ritual Event — Inline (default)

**Класс:** Inline (по умолчанию), Mini-Game если содержит Challenge

**Цель:** 2–3 значимых выбора с ценой.

```
┌─────────────────────────────────────────────────────────────┐
│                  CHOICE / RITUAL EVENT                      │
│                                                             │
│  Inline Flow:                                               │
│  Event → Show choices → Player picks → Apply outcome        │
│                                                             │
│  Mini-Game Flow (если есть Challenge):                      │
│  Event → Show choices → Player picks →                      │
│    → SkillCheckModule.run() → Apply outcome                 │
└─────────────────────────────────────────────────────────────┘
```

**Инвариант:** Нельзя иметь "правильный" выбор без цены.

---

### 7.3 Narrative Event — Inline

**Класс:** Inline (всегда)

**Цель:** Продвижение флагов/квестов/репутации без мини-игры.

```
┌─────────────────────────────────────────────────────────────┐
│                   NARRATIVE EVENT                           │
│                                                             │
│  Признаки:                                                  │
│  • Развивает историю / раскрывает персонажей               │
│  • Не требует решения-головоломки                          │
│  • Всегда оставляет след (флаг/репутация/квест)            │
│                                                             │
│  НЕ делает:                                                 │
│  • Не объясняет механику                                    │
│  • Не содержит Challenge                                    │
└─────────────────────────────────────────────────────────────┘
```

---

### 7.4 Exploration Event — Inline + optional Mini-Game

**Класс:** Inline (default), Mini-Game если skill/puzzle challenge

**Цель:** Риск → награда.

```
┌─────────────────────────────────────────────────────────────┐
│                  EXPLORATION EVENT                          │
│                                                             │
│  Inline:                                                    │
│  "Исследовать пещеру?" → [Да/Нет] → Outcomes                │
│                                                             │
│  Mini-Game (с Challenge):                                   │
│  "Исследовать пещеру?" → [Да] →                            │
│    → PuzzleModule.run() или SkillCheckModule.run()         │
│    → Apply outcome based on result                         │
└─────────────────────────────────────────────────────────────┘
```

**Инвариант:** Нельзя бесконечно фармить exploration без роста давления.

---

### 7.5 World Shift Event — Inline (системное)

**Класс:** Inline (почти всегда)

**Цель:** Глобально менять правила/состояние мира при порогах давления.

```
┌─────────────────────────────────────────────────────────────┐
│                   WORLD SHIFT EVENT                         │
│                                                             │
│  Триггеры:                                                  │
│  • pressure >= threshold                                   │
│  • time >= day_X                                           │
│  • flag combination                                        │
│                                                             │
│  Эффекты:                                                   │
│  • Изменение regionState (Stable → Borderland → Breach)    │
│  • Глобальные модификаторы                                 │
│  • Разблокировка контента                                  │
│                                                             │
│  Mini-Game (редко):                                         │
│  Только для "ритуалов мира" — сценарных событий             │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Контракт Mini-Game Module

### 8.1 Protocol (концептуально)

```swift
protocol MiniGameModule {
    /// Тип модуля
    static var moduleType: MiniGameType { get }

    /// Запуск мини-игры
    /// - Returns: Формальный результат (НЕ мутирует state)
    func run(
        challenge: MiniGameChallenge,
        playerState: PlayerStateSnapshot,
        worldState: WorldStateSnapshot
    ) -> ResolutionResult
}
```

### 8.2 Жёсткое правило

> **Mini-Game модуль НИКОГДА не меняет мир напрямую.**
> Он возвращает `ResolutionResult` + `Diff`, движок применяет.

Это позволяет:
- Заменить карточный бой на кубики без изменения ядра
- Добавить puzzle / social модуль без рефакторинга
- Тестировать модули изолированно

### 8.3 ResolutionResult

```json
{
  "outcome": "victory|defeat|draw|partial",
  "score": 85,
  "rewardMultiplier": 1.5,
  "penaltyMultiplier": 1.0,
  "bonusFlags": ["critical_hit", "no_damage_taken"],
  "playerDiff": {
    "healthDelta": -5,
    "faithDelta": 0
  },
  "customData": {}
}
```

---

## 9. Инварианты

### 9.1 Event Selection

| # | Инвариант |
|---|-----------|
| 1 | При фиксированном seed выбор событий детерминирован |
| 2 | OneTime события не повторяются после completion |
| 3 | Cooldown события недоступны до истечения времени |
| 4 | Фильтрация по flags строгая (AND для required, OR для forbidden) |

### 9.2 Event Resolution

| # | Инвариант |
|---|-----------|
| 5 | Каждый choice имеет outcome (нет пустых выборов) |
| 6 | Нельзя получить reward без cost или risk |
| 7 | Instant события не тратят время |
| 8 | Non-instant события тратят ровно 1 единицу времени |

### 9.3 Mini-Game Integration

| # | Инвариант |
|---|-----------|
| 9 | Mini-Game модуль не мутирует state напрямую |
| 10 | Движок применяет diff после получения результата |
| 11 | Combat запускается только через Event pipeline |

---

## 10. Тесты

### 10.1 Event Selection Tests

```swift
func testEventFilteringByRegionState()
func testEventFilteringByPressureRange()
func testEventFilteringByFlags()
func testOneTimeEventsNotRepeated()
func testCooldownEventsRespected()
func testDeterministicSelectionWithSeed()
func testWeightedSelectionDistribution()
```

### 10.2 Event Resolution Tests

```swift
func testNoFreeGains()
func testNoEmptyChoices()
func testInstantEventsZeroTimeCost()
func testNonInstantEventsOneTimeCost()
func testFlagsAppliedCorrectly()
func testTransactionsAppliedAtomically()
```

### 10.3 Mini-Game Integration Tests

```swift
func testMiniGameReturnsDiffOnly()
func testMiniGameDoesNotMutateState()
func testCombatOnlyThroughEventPipeline()
func testResolutionResultAppliedByEngine()
```

### 10.4 System Tests

```swift
func testNoInfiniteInstantEventChain()
func testOneTimeEventsPersistAcrossSaveLoad()
func testEventContextSerializable()
```

---

## Roadmap

### v1.0 (текущий)
- [x] Event pipeline (selection + resolution)
- [x] 5 базовых типов событий
- [x] Inline vs Mini-Game разделение
- [x] CombatModule интеграция

### v1.1 (планируется)
- [ ] SkillCheckModule
- [ ] Cooldown system refinement
- [ ] Event chains (linked events)

### v2.0 (future)
- [ ] PuzzleModule
- [ ] SocialModule
- [ ] Dynamic event generation

---

**Связанные документы:**
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) — Общая архитектура
- [EXPLORATION_CORE_DESIGN.md](./EXPLORATION_CORE_DESIGN.md) — Механики (сеттинг-специфичные)
- [QA_ACT_I_CHECKLIST.md](./QA_ACT_I_CHECKLIST.md) — Тесты
