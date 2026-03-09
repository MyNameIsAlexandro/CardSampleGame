# Game Engine v1.0: Technical Architecture Document

**Версия:** 1.11
**Статус:** Architecture Lock (Source of Truth)
**Дата:** 12 февраля 2026
**Last updated (ISO):** 2026-03-03
**Phase 2 checkpoint:** Epic 66
**Policy sync:** `CLAUDE.md` v4.1 engineering contract
**Назначение:** Техническая спецификация для реализации переиспользуемого игрового ядра.

**Последние изменения (v1.11):**
- Policy sync с `CLAUDE.md` v4.1:
  - закреплён транзакционный контракт внешнего боя (start/commit только через канонический engine-path),
  - закреплён runtime resume-l10n контракт: bridge обязан пере-локализовывать user-facing display строки по активному `ContentRegistry` + `LocalizationManager`,
  - закреплён запрет на отображение service/icon-токенов (`cross.fill`, `icon.*`) как plain text в UI.
- Runtime quality sync:
  - absolute hygiene-policy в QA/architecture контуре: first-party `<=600` строк/файл и engine `<=5` top-level типов/файл без legacy whitelist.
- Epic localization checkpoint:
  - resume-path relocalization проверяется регрессионным тестом `SaveLoadTests.testEchoEncounterBridgeRelocalizesResumeDeckCardsFromRegistry`.

**Предыдущие изменения (v1.10):**
- Epic 65: Documentation single-control-point hardening:
  - документ получил machine-readable метаданные (`Last updated (ISO)` и `Phase 2 checkpoint`),
  - docs-sync gate валидирует date/checkpoint parity между:
    - `Docs/Technical/ENGINE_ARCHITECTURE.md`,
    - `Docs/QA/QUALITY_CONTROL_MODEL.md`,
    - `Docs/QA/TESTING_GUIDE.md`,
    - `Docs/plans/2026-02-07-audit-refactor-phase2-epics.md`.
- Epic 66: Release hygiene hard-stop:
  - `.github/workflows/tests.yml` и `.github/ci/run_release_check.sh` используют `validate_repo_hygiene.sh --require-clean-tree`,
  - `validate_docs_sync.sh` блокирует drift, если hard-mode invocation отсутствует в workflow/release-runner контракте.

**Предыдущие изменения (v1.9):**
- Package decomposition wave expanded from app layer into first-party engine packages:
  - split `JSONContentProvider+SchemaQuests.swift` into focused schema files (`...SchemaQuests`, `...SchemaQuestConditions`, `...SchemaQuestChoiceCondition`, `...SchemaQuestResourceThresholdCondition`, `...SchemaQuestAvailabilityRewards`, `...SchemaChallenges`),
  - split `JSONContentProvider+SchemaEvents.swift` into focused modules (`...SchemaEvents`, `...SchemaRegionsAnchors`, `...SchemaEventAvailability`, `...SchemaEventChoices`, `...SchemaEventCombat`),
  - split `CodeContentProvider+JSONLoading.swift` into focused JSON-loading modules (`...JSONLoading`, `...JSONAvailabilityLoading`, `...JSONChoiceLoading`),
  - split `EncounterViewModel.swift` into bounded-context app modules (`...EncounterViewModel`, `...EncounterViewModel+PlayerActions`, `...EncounterViewModel+PhaseMachine`, `...EncounterViewModel+StateSyncAndLog`),
  - split monolithic `Localization.swift` into bounded key modules (`Localization+CoreAndRules`, `Localization+WorldAndNavigation`, `Localization+AdvancedSystems`, `Localization+RemainingKeys`) with full symbol-compatibility preserved,
  - reduced schema parsing coupling and lowered per-file type concentration in `Data/Providers`.
- Structural cleanup rules unified across app and first-party packages:
  - no legacy/type allowlists for first-party code hygiene checks,
  - vendor/build folders remain excluded only (`Packages/ThirdParty`, `/.build/`, `/.codex_home/`).
- Russian header comments adopted for key entry-point files during decomposition to reduce reverse-engineering overhead in maintenance.

**Предыдущие изменения (v1.8):**
- Epic 53 decomposition checkpoint progressed to stabilized baseline:
  - `TwilightGameEngine.swift` reduced to `520` lines (core mutation points remain explicit in engine core APIs),
  - action/read-only/persistence/query surfaces extracted into focused `TwilightGameEngine+*.swift` modules.
- Engine-first boundary contract is now hard-gated and green:
  - `BattleArenaView` remains sandboxed from world-engine mutation/RNG commit paths (architecture gate),
  - app-layer direct `engine.services.rng`/`nextSeed` usage is blocked by static gates,
  - direct app-layer mutation of critical engine fields is blocked by static gates.
- Quality model hardened and verified:
  - `CodeHygieneTests` enforces hard `<=600` lines per first-party Swift file (vendor/build excluded only),
  - `CodeHygieneTests` enforces hard engine type-limit (`<=5` public types per file) without legacy allowlist.
- Endgame error contract tightened:
  - defeat reason path uses typed reason codes (`GameEndDefeatReason`) with localization mapping at app layer.

**Предыдущие изменения (v1.6):**
- Epic 53 decomposition checkpoint #1:
  - extracted read-only query surface from `TwilightGameEngine.swift` into `Core/TwilightGameEngine+ReadOnlyQueries.swift`,
  - extracted world bootstrap defaults/model into `Core/EngineWorldBootstrapState.swift`,
  - reduced `TwilightGameEngine.swift` from `2139` to `2071` lines without widening app mutation permissions.

**Предыдущие изменения (v1.5):**
- Engine monolith decomposition wave started:
  - extracted engine world-state models (`EventTrigger`, `EngineRegionState`, `EngineAnchorState`, `CombatState`) into `Core/EngineWorldStateModels.swift`,
  - kept persistence mutations in `TwilightGameEngine.swift` to preserve `private` boundary integrity.
- Arena sandbox contract remains explicit:
  - arena uses local deterministic seed state (no world RNG service reads),
  - arena does not commit combat result into world save/action pipeline.
- Added architecture backlog epics (53+) for monolith decomposition and legacy cleanup governance.

**Предыдущие изменения (v1.4):**
- EchoEngine: Fate Resolution Service (keyword + suit matching)
- Diplomacy system: playerInfluence(), AttackTrack, escalation/de-escalation
- Dual victory: CombatOutcome.victory(.killed) / .victory(.pacified)
- CombatResult struct with resonance/faith deltas, loot, fate deck state
- EchoEncounterBridge: TwilightGameEngine ↔ EchoEngine integration
- 140 tests (100 EchoEngine + 19 EchoScenes + 21 TwilightEngine)

**Предыдущие изменения (v1.3):**
- EchoEngine: ECS-based combat system (FirebladeECS)
- Energy system, exhaust mechanic, enemy behavior patterns
- Card cost/exhaust fields, enemy pattern cycling
- PackValidator: enemy validation, cost/exhaust checks

**Предыдущие изменения (v1.2):**
- Phase 6: Card Economy v2.0, Combat UI v2.0
- Content Pack System полностью реализован
- Async loading для улучшения производительности

> **⚠️ Этот документ — каноническая точка правды** по архитектуре движка.
> Все остальные документы ссылаются сюда для технических решений.

**Документация проекта:**
- ⚙️ [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - этот файл (**source of truth**)
- 📖 [GAME_DESIGN_DOCUMENT.md](./GAME_DESIGN_DOCUMENT.md) - игровой дизайн
- 🔧 [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) - техническая документация
- ✅ [QA_ACT_I_CHECKLIST.md](./QA_ACT_I_CHECKLIST.md) - QA-контракт

---

## Содержание

1. [Философия и Границы](#1-философия-и-границы)
2. [Архитектура (Layered Cake)](#2-архитектура-layered-cake)
3. [Подсистемы Движка](#3-подсистемы-движка)
4. [Поток Данных (Game Loop)](#4-поток-данных-game-loop)
5. [Организация Данных (Definitions vs Runtime)](#5-организация-данных-definitions-vs-runtime)
6. [Инварианты Движка (Закон)](#6-инварианты-движка-закон)
7. [Extension Points](#7-extension-points)
8. [План Внедрения](#8-план-внедрения)
9. [Критерии Готовности v1.0](#9-критерии-готовности-v10)

---

## 1. Философия и Границы

### 1.1 Концепция: Процессор и Картридж

**Движок (GameEngine)** — это процессор. Он не знает сюжета, имён персонажей или названий локаций. Он знает только правила обработки данных.

**Конкретная игра** (например, "Сумрачные Пределы") — это картридж. Она предоставляет данные (Definitions), правила (Rules) и конфигурацию, которые движок обрабатывает.

```
┌─────────────────────────────────────────┐
│           GAME (Cartridge)              │
│  "Сумрачные Пределы" / "Другая игра"    │
│  - Сеттинг, нарратив, контент           │
│  - Конкретные правила и константы       │
├─────────────────────────────────────────┤
│           ENGINE (Processor)            │
│  - Время, давление, события             │
│  - Квесты, экономика, резолверы         │
│  - Инварианты и core loop               │
└─────────────────────────────────────────┘
```

### 1.2 Принцип разделения ответственности

Чтобы достичь переиспользуемости, мы **строго разделяем** три сущности:

| Сущность | Описание | Слой | Пример |
|----------|----------|------|--------|
| **Rules** | Логика изменений (формулы, инварианты, условия) | Картридж | `каждые 3 дня +3 tension` |
| **Data** | Статичные определения (контент) | Картридж | `RegionDefinition`, `EventDefinition` |
| **State** | Динамические данные (save/runtime) | Runtime | `currentHealth`, `completedQuests` |

### 1.3 Границы ответственности

**Движок ОТВЕЧАЕТ за:**
- Структуру хода и времени
- Состояние мира и игрока
- Экономику риска и награды
- Разрешение конфликтов (через протокол)
- Прогрессию и пути развития
- Условия победы и поражения
- Инварианты (что всегда верно)

**Движок НЕ ОТВЕЧАЕТ за:**
- Конкретный сеттинг
- Тексты и нарратив
- Визуалы и UI
- Конкретных персонажей
- Конкретный сюжет

---

## 2. Архитектура (Layered Cake)

Архитектура системы строится слоями. **Зависимости идут только сверху вниз.**

```
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Runtime State (Save Data)                      │
│   GameState, WorldRuntimeState, PlayerRuntimeState      │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Configuration (The Cartridge)                  │
│   GameRules, ContentProvider, ConflictResolver impl     │
├─────────────────────────────────────────────────────────┤
│ Layer 1: Engine Core (Reusable Framework)               │
│   GameEngine, TimeEngine, PressureEngine, Protocols     │
└─────────────────────────────────────────────────────────┘
```

### Layer 1: Engine Core (Reusable)

Скомпилированный код ядра. **Неизменен для разных игр.**

| Компонент | Ответственность |
|-----------|-----------------|
| `GameEngine` | Оркестратор, единая точка входа |
| `TimeEngine` | Управление временем и тиками |
| `PressureEngine` | Абстрактная машина эскалации |
| `EventEngine` | Выбор и обработка событий |
| `QuestEngine` | Машина состояний квестов |
| `EconomyManager` | Атомарные транзакции ресурсов |
| `RequirementsEvaluator` | Оценка требований выборов (отделён от Definitions) |
| `ConflictResolver` | Протокол для подключения механик |

### Layer 2: Configuration (Cartridge)

Код и данные, специфичные для конкретной игры.

| Компонент | Ответственность |
|-----------|-----------------|
| `GameRules` | Реализация протоколов правил |
| `ContentProvider` | Источник данных (JSON/Code) |
| `ConflictResolver impl` | Реализация боя/проверок |
| `Custom Delegates` | Специфичные эффекты |

### Layer 3: Runtime State (Save Data)

Данные, которые сохраняются и загружаются.

| Компонент | Содержимое |
|-----------|------------|
| `GameState` | Корневой объект состояния |
| `WorldRuntimeState` | Регионы, якоря, флаги |
| `PlayerRuntimeState` | Ресурсы, колода, проклятия |

---

## 3. Подсистемы Движка

### 3.1 Time & Turn Engine

**Идея:** Время — универсальный ресурс.

```swift
protocol TimeRules {
    var tickInterval: Int { get }  // Единиц времени в одном тике
}

protocol TimeEngineProtocol {
    var currentTime: Int { get }
    func advance(cost: Int)
    func checkThreshold(_ interval: Int) -> Bool
}
```

**Поведение:**
- Любое осмысленное действие имеет `timeCost`
- Время продвигается только через движок
- Продвижение времени вызывает `WorldTick`

**КРИТИЧНО: Multi-day actions:**
```swift
// ПРАВИЛЬНО: каждый день обрабатывается отдельно
func advanceTime(by days: Int) {
    for _ in 0..<days {
        daysPassed += 1
        processDayStart()  // tick на КАЖДЫЙ день
    }
}

// НЕПРАВИЛЬНО: пропуск дней
daysPassed += 2  // День 3 может быть пропущен!
```

**Инварианты:**
- ❌ Нет бесплатных действий (кроме редких `instant`)
- ❌ Время нельзя откатить или накопить
- ✅ Каждые N тиков → эскалация

### 3.2 Pressure & Escalation Engine

**Идея:** Давление толкает игру к финалу.

```swift
protocol PressureRuleSet {
    var maxPressure: Int { get }
    var initialPressure: Int { get }
    var escalationInterval: Int { get }
    var escalationAmount: Int { get }

    func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int
    func checkThresholds(pressure: Int) -> [WorldEffect]
}

protocol PressureEngineProtocol {
    var currentPressure: Int { get }
    var rules: PressureRuleSet { get }

    func escalate(at currentTime: Int)
    func adjust(by delta: Int)
    func currentEffects() -> [WorldEffect]
}
```

**Поведение:**
- Давление растёт со временем и решениями
- Пороговые значения вызывают `WorldEffect`
- Давление влияет на сложность, события, доступные опции

**Формула эскалации (v1.3):**
```
escalationAmount = 3 + (daysPassed / 10)
```
- День 1-9: +3 per tick
- День 10-19: +4 per tick
- День 20-29: +5 per tick
- Это создаёт нарастающую угрозу вместо линейного медленного роста

**Инварианты:**
- ✅ Давление в среднем растёт
- ✅ Игрок может замедлять, но не отменять
- ✅ Давление определяет фазы игры

**Save/Load Support (v1.0):**
```swift
// PressureEngine save/load methods
func setPressure(_ value: Int)                    // Restore pressure from save
func getTriggeredThresholds() -> Set<Int>         // Get triggered thresholds for save
func setTriggeredThresholds(_ thresholds: Set<Int>) // Restore thresholds from save
func syncTriggeredThresholdsFromPressure()        // Reconstruct thresholds from pressure value
```

**Важно для save/load:**
- `triggeredThresholds` отслеживает какие пороги уже сработали
- При загрузке вызывать `syncTriggeredThresholdsFromPressure()` чтобы избежать повторных событий
- TwilightGameEngine.syncFromLegacy() автоматически вызывает эту синхронизацию

### 3.3 Event Engine

**Идея:** Все взаимодействия проходят через события.

```swift
// Протокол (абстрактный интерфейс)
protocol EventDefinitionProtocol {
    associatedtype ChoiceType: ChoiceDefinitionProtocol
    var id: String { get }
    var title: String { get }      // Для UI — resolved string
    var description: String { get }
    var choices: [ChoiceType] { get }
    var isInstant: Bool { get }
    var isOneTime: Bool { get }
    func canOccur(in context: EventContext) -> Bool
}

// Конкретная реализация (использует inline LocalizedString)
struct EventDefinition: GameDefinition {
    let id: String
    let title: LocalizedString     // Inline локализованный текст
    let body: LocalizedString      // Inline локализованный текст
    let eventKind: EventKind       // .inline или .miniGame(...)
    let choices: [ChoiceDefinition]
    let isInstant: Bool
    let isOneTime: Bool
    // ... availability, poolIds, weight, cooldown
}

// LocalizedString - тип для inline локализации в JSON
// Позволяет добавлять контент без пересборки приложения ("Cartridge" подход)
struct LocalizedString: Codable, Hashable {
    let en: String  // Английский текст
    let ru: String  // Русский текст
    var localized: String { /* возвращает текст для текущей локали */ }
}

// КАНОН ЛОКАЛИЗАЦИИ (Audit B1):
// - Canonical scheme: Inline LocalizedString { "en": "...", "ru": "..." }
// - Запрещено: смешивание inline и StringKey в одном паке
// - Key-based локализация (StringKey + string tables) зарезервирована под будущую миграцию,
//   сейчас запрещена валидатором (LocalizationValidatorTests)
// - UI использует LocalizableText.resolved для получения строк

protocol EventSystemProtocol {
    associatedtype Event: EventDefinitionProtocol
    func getAvailableEvents(in context: EventContext) -> [Event]
    func markCompleted(eventId: String)
    func isCompleted(eventId: String) -> Bool
}
```

> **📦 Подробная архитектура Event Module:**
> См. [EVENT_MODULE_ARCHITECTURE.md](./EVENT_MODULE_ARCHITECTURE.md)
> - Pipeline (Selection → Resolution)
> - Inline vs Mini-Game Events
> - 5 типов событий (Combat, Choice, Narrative, Exploration, WorldShift)
> - Контракт Mini-Game Module

**Поток:**
1. Input: Текущий регион, состояние мира, фильтры
2. Process: Фильтрация по условиям → Взвешенный рандом → Выбор
3. Output: `EventDefinition` для презентации

**Инварианты:**
- ✅ У события всегда есть выбор
- ✅ Отказ — тоже выбор
- ✅ Каждый выбор имеет последствия

### 3.4 Resolution Engine (Конфликты)

**Идея:** Конфликт — универсальная сущность, не равная бою.

```swift
// Протокол для определения челленджей
protocol ChallengeDefinition {
    var type: ChallengeType { get }
    var difficulty: Int { get }
    var context: Any? { get }
}

// Общие типы челленджей (EngineProtocols.swift)
enum ChallengeType: String, Codable {
    case combat
    case skillCheck
    case socialEncounter
    case puzzle
    case tradeOff
    case sacrifice
}

// Типы Mini-Game (MiniGameChallengeDefinition.swift)
enum MiniGameChallengeKind: String, Codable {
    case combat, ritual, exploration, dialogue, puzzle
}

protocol ConflictResolverProtocol {
    associatedtype Challenge: ChallengeDefinition
    associatedtype Actor
    associatedtype Reward
    associatedtype Penalty
    func resolve(challenge: Challenge, actor: Actor) async -> ResolutionResult<Reward, Penalty>
}

enum ResolutionResult<Reward, Penalty> {
    case success(Reward)
    case failure(Penalty)
    case partial(reward: Reward, penalty: Penalty)
    case cancelled
}
```

**Варианты реализации (плагины):**
- `CardCombatResolver` — карточный бой
- `DiceResolver` — броски кубиков
- `StatComparisonResolver` — сравнение характеристик

**Инварианты:**
- ✅ Любой конфликт имеет цену
- ✅ Любой исход меняет состояние

### 3.5 Economy Engine (Транзакции)

**Идея:** Безопасное, атомарное изменение ресурсов.

```swift
struct Transaction {
    let costs: [String: Int]
    let gains: [String: Int]
    let description: String
}

protocol EconomyManagerProtocol {
    func canAfford(_ transaction: Transaction, resources: [String: Int]) -> Bool
    func process(_ transaction: Transaction, resources: inout [String: Int]) -> Bool
}
```

**Зачем нужно:**
- Убирает баги "в одном месте списали, в другом забыли"
- Атомарность: или всё применяется, или ничего
- Единая точка для аудита изменений

**Инварианты:**
- ✅ Нет бесплатных усилений
- ✅ Транзакции атомарны

### 3.6 Quest Engine

**Идея:** Квест = структура условий и последствий.

```swift
protocol QuestDefinitionProtocol {
    var id: String { get }
    var title: String { get }
    var isMain: Bool { get }
    var objectives: [QuestObjective] { get }
    var rewardTransaction: Transaction { get }
}

protocol QuestManagerProtocol {
    var activeQuests: [Quest] { get }
    var completedQuests: [String] { get }

    func checkProgress(flags: [String: Bool])
    func completeQuest(_ questId: String) -> Transaction?
}
```

**Инварианты:**
- ✅ Шаги открываются по флагам/состоянию
- ✅ Нет жёстких скриптов
- ✅ Квесты могут быть пропущены (кроме ключевых)

### 3.7 Progression & Path Engine

**Идея:** Прогресс — это выбор пути, а не только усиление.

```swift
protocol ProgressionPathProtocol {
    var currentPath: PathType { get }
    var pathValue: Int { get }

    func shift(by delta: Int)
    func unlockedCapabilities() -> [String]
    func lockedOptions() -> [String]
}
```

**Инварианты:**
- ✅ Усиление открывает и закрывает возможности
- ✅ Нельзя быть эффективным во всём
- ✅ Прогресс влияет на доступные решения и финалы

### 3.8 Encounter System

**Идея:** Data-driven AI поведение врагов.

| Компонент | Ответственность |
|-----------|-----------------|
| `BehaviorDefinition` | Декларативное описание паттернов AI |
| `ConditionParser` | Разбор условий активации поведений |
| `KeywordInterpreter` | Интерпретация ключевых слов действий |

Поведения врагов описываются в JSON и интерпретируются движком без хардкода логики.

### 3.9 Fate / Resonance System

**Идея:** Двухтрековый бой с колодой судьбы.

| Компонент | Ответственность |
|-----------|-----------------|
| `FateCard` | Определение карты судьбы (атака/защита/навык) |
| `FateDeckManager` | Управление колодой судьбы (тасовка, вытягивание, сброс) |
| `ResonanceEngine` | Расчёт резонанса между картами и стихиями |
| `EnemyIntent` | Отображение намерений врага перед ходом |

Disposition Combat: единая шкала -100…+100 (уничтожение ↔ подчинение). Карты судьбы модифицируют effective_power. Подробности: [Disposition Combat Design v2.5](../../docs/plans/2026-02-18-disposition-combat-design.md).

### 3.10 Player Progression

**Идея:** Пост-игровая прогрессия и коллекционирование.

| Компонент | Ответственность |
|-----------|-----------------|
| `PlayerProfile` | Мета-профиль игрока между запусками |
| `AchievementEngine` | Система достижений и наград |
| `BestiaryTracker` | Коллекция встреченных врагов |

Прогрессия сохраняется между прохождениями и открывает новый контент.

### 3.11 Victory / Defeat Engine

**Идея:** Финал — функция состояния мира и пути игрока.

```swift
protocol EndConditionDefinition {
    var type: EndConditionType { get }
    var id: String { get }
    var isVictory: Bool { get }

    func isMet(pressure: Int, resources: [String: Int], flags: [String: Bool], time: Int) -> Bool
}

enum EndConditionType {
    case objectiveBased   // Выполнены цели
    case pressureBased    // Давление достигло порога
    case resourceBased    // Ресурс достиг 0 или max
    case pathBased        // Путь игрока определяет финал
    case timeBased        // Лимит времени
}
```

**Инварианты:**
- ✅ Победа ≠ идеальный исход
- ✅ Поражение может быть постепенным

---

## 4. Поток Данных (Game Loop)

### 4.1 Ключевой принцип

**UI никогда не меняет State напрямую.**
UI отправляет `GameAction` в `GameEngine`.

```
┌────────┐     GameAction      ┌────────────┐
│   UI   │ ──────────────────> │ GameEngine │
│        │ <────────────────── │            │
└────────┘   State Changes     └────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
              TimeEngine    PressureEngine    EconomyManager
```

### 4.2 Канонический Core Loop

```
performAction(action):
  1. Validation     — Можно ли выполнить действие?
  2. Economy        — Списание ресурсов (если есть cost)
  3. AdvanceTime    — timeEngine.advance(cost)
  4. WorldTick      — pressure + degradation + world shifts
  5. ActionLogic    — Обновление состояния (travel/rest/explore)
  6. EventGenerate  — Генерация события (если нужно)
  7. Challenge      — if event has challenge -> resolver.resolve()
  8. Consequences   — Применение последствий (resources/flags/state)
  9. QuestTick      — Проверка триггеров и прогресса
  10. VictoryDefeat — Проверка условий окончания
  11. Save          — Автосохранение
```

### 4.3 Пример потока

```
UI: Пользователь нажимает "Путешествовать в Лес"
                    │
                    ▼
Action: GameAction.travel(to: "forest")
                    │
                    ▼
Engine: perform(action)
    │
    ├── 1. Validate: Лес — сосед? Игрок жив?
    ├── 2. Economy: Нет стоимости
    ├── 3. Time: advance(cost: 1)
    ├── 4. WorldTick: tension +3 (если 3й день)
    ├── 5. Logic: currentRegionId = "forest"
    ├── 6. Event: getAvailableEvents() -> "Волки в лесу"
    ├── 7. Challenge: resolver.resolve(wolfCombat)
    ├── 8. Consequences: health -3, faith +1
    ├── 9. QuestTick: check "explore_forest" objective
    ├── 10. VictoryDefeat: health > 0? tension < 100?
    └── 11. Save: autosave()
                    │
                    ▼
Output: StateChange notification
                    │
                    ▼
UI: Перерисовка интерфейса
```

---

## 5. Организация Данных (Definitions vs Runtime)

### 5.1 Ключевой принцип

**Чёткое разделение "Что это" и "В каком состоянии".**

### 5.2 Region (Пример)

**RegionDefinition** (Data/Content) — Лежит в JSON/Code, неизменяемо:

```swift
struct RegionDefinition: Codable {
    let id: String
    let nameKey: String           // Для локализации
    let type: RegionType
    let neighborIds: [String]
    let defaultAnchorId: String?
    let eventPoolIds: [String]
    let initialState: RegionState
}
```

**RegionRuntimeState** (State/Save) — Лежит в GameState, изменяемо:

```swift
struct RegionRuntimeState: Codable {
    let definitionId: String      // Ссылка на Definition
    var currentState: RegionState // stable/borderland/breach
    var anchorIntegrity: Int
    var isVisited: Bool
    var reputation: Int
    var activeModifiers: [String]
    var localFlags: [String: Bool]
}
```

### 5.3 Event (Пример)

**EventDefinition** (Data):
```swift
struct EventDefinition: Codable {
    let id: String
    let title: LocalizedString      // Inline локализованный текст
    let body: LocalizedString       // Inline локализованный текст
    let regionTypes: [RegionType]
    let regionStates: [RegionState]
    let tensionRange: ClosedRange<Int>?
    let requiredFlags: [String]
    let forbiddenFlags: [String]
    let choices: [ChoiceDefinition]
    let isOneTime: Bool
    let isInstant: Bool
    let weight: Int
}
```

**EventRuntimeState** (State):
```swift
struct EventRuntimeState: Codable {
    var completedEventIds: Set<String>
    var eventCooldowns: [String: Int]
}
```

### 5.4 Quest (Пример)

**QuestDefinition** (Data):
```swift
struct QuestDefinition: Codable {
    let id: String
    let title: LocalizedString      // Inline локализованный текст
    let description: LocalizedString
    let isMain: Bool
    let objectives: [ObjectiveDefinition]
    let rewardTransaction: Transaction
    let unlockFlags: [String]
}
```

**QuestRuntimeState** (State):
```swift
struct QuestRuntimeState: Codable {
    let definitionId: String
    var currentObjectiveIndex: Int
    var objectiveProgress: [String: Bool]
    var isCompleted: Bool
    var isActive: Bool
}
```

### 5.5 Преимущества разделения

| Аспект | До разделения | После разделения |
|--------|---------------|------------------|
| Новая игра | Переписывать код | Заменить JSON |
| Локализация | Хардкод строк | Ключи + файлы |
| Тестирование | Моки сложные | Definitions = данные |
| Save/Load | Всё сохранять | Только State |
| Баланс | Менять код | Менять данные |

---

## 6. Инварианты Движка (Закон)

Эти правила **должны всегда выполняться**. Тесты проверяют их.

| # | Инвариант | Тест |
|---|-----------|------|
| 1 | Нельзя стоять на месте без последствий | `testNoStagnationInvariant()` |
| 2 | Нет бесплатных усилений | `testNoFreeGains()` |
| 3 | Любой выбор имеет цену | `testChoicesHaveCost()` |
| 4 | Мир реагирует на бездействие | `testWorldDegrades()` |
| 5 | Финал зависит от пути и состояния мира | `testEndingsDependOnPath()` |
| 6 | Instant события не создают бесконечные цепочки | `testNoInfiniteInstantEventChain()` |
| 7 | Один seed (WorldRNG) → полностью идентичные результаты | `testDeterministicReproducibility()` |

### 6.1 Дополнительные архитектурные инварианты (Phase 2 hard gates)

- Изменение runtime state допускается только через action pipeline/facade в engine.
- `BattleArena` остаётся sandbox и не использует world RNG / world commit path.
- Resume/external-combat payload обязан релокализовываться перед рендером по активным registry/locale.
- UI не рендерит service/icon токены через `Text(...)`; иконки выводятся только как `Image(systemName:)`.

---

## 7. Extension Points

Точки, где движок расширяется **без изменения ядра**:

| Extension Point | Протокол | Примеры реализаций |
|-----------------|----------|-------------------|
| Pressure Model | `PressureRuleSet` | `TwilightTension`, `DoomClock` |
| Conflict Type | `ConflictResolverProtocol` | `CardCombat`, `DiceRoll`, `Comparison` |
| Progression | `ProgressionPathProtocol` | `DeckBuilding`, `TalentTree`, `Equipment` |
| Economy | `EconomyManagerProtocol` | `Market`, `Barter`, `Upgrade` |
| End Conditions | `EndConditionDefinition` | `Objective`, `Pressure`, `Moral` |

### 7.1 Статус экономических подсистем (v1.0)

> **Каноническая таблица** — все документы ссылаются сюда.

| Подсистема | Статус в v1.0 | Описание |
|------------|---------------|----------|
| **Reward Economy** | ✅ Core | Награды за события, бои, квесты. Работает. |
| **Resource Economy** | ✅ Core | Faith, Health, Balance — атомарные транзакции через `EconomyManager` |
| **Market Economy** | ⬜ Extension | Покупка/продажа карт. Не часть Act I. Точка расширения. |
| **Upgrade Economy** | 📋 Planned | Улучшение карт/предметов. Запланировано для будущих актов. |
| **Barter Economy** | 📋 Planned | Обмен с NPC. Запланировано как extension. |

### 7.2 Реализации ContentProvider (v1.0)

> **Status:** ✅ Implemented

ContentProvider — абстракция для загрузки игрового контента (регионы, якоря, события, квесты).

| Реализация | Описание | Файл |
|------------|----------|------|
| `ContentProvider` | Протокол, определяющий API для загрузки контента | `Engine/Data/Providers/ContentProvider.swift` |
| `CodeContentProvider` | Базовый класс для загрузки контента из Swift кода | `Engine/Data/Providers/CodeContentProvider.swift` |
| `TwilightMarchesCodeContentProvider` | Конкретная реализация для игры "Сумрачные Пределы" | `Models/WorldState.swift` |
| `JSONContentProvider` | Загрузка контента из JSON (для Phase 5) | `Engine/Data/Providers/JSONContentProvider.swift` |

**TwilightMarchesCodeContentProvider** — это "картридж" для конкретной игры:

```swift
final class TwilightMarchesCodeContentProvider: CodeContentProvider {
    override func loadRegions() {
        // 7 регионов Act I: village, oak, forest, swamp, mountain, breach, dark_lowland
        registerRegion(RegionDefinition(id: "village", ...))
        // ...
    }

    override func loadAnchors() {
        // 6 якорей с различными типами и influence
        registerAnchor(AnchorDefinition(id: "anchor_village_chapel", ...))
        // ...
    }

    // Локализация названий
    static func regionName(for id: String) -> String { ... }
    static func anchorName(for id: String) -> String { ... }
}
```

**Использование в WorldState:**
```swift
private func setupInitialWorld() {
    let provider = TwilightMarchesCodeContentProvider()
    regions = createRegionsFromProvider(provider)  // Data-Driven!
}
```

**Bridge методы** (преобразование Definition → Legacy Model):
- `createRegionsFromProvider(_:)` — RegionDefinition → Region
- `createAnchorFromDefinition(_:)` — AnchorDefinition → Anchor
- Маппинг функции: `mapRegionType()`, `mapAnchorType()`, `mapInfluence()`, `mapRegionState()`

---

## 8. План Внедрения

> **Статус:** ✅ Все фазы завершены (20 января 2026)
>
> Подробный отчёт о выполнении: [MIGRATION_PLAN.md](./MIGRATION_PLAN.md)

### Фаза 1: Подготовка Данных (Data Separation) ✅

**Цель:** Отделить статичные определения от runtime состояния.

- [x] Создать `*Definition` структуры рядом с текущими моделями
- [x] Создать `ContentProvider` (простой класс для загрузки)
- [x] В текущих моделях оставить только динамические данные + ID ссылки

**Созданные файлы:**
```
Engine/Data/Definitions/
├── RegionDefinition.swift
├── EventDefinition.swift
├── QuestDefinition.swift
├── AnchorDefinition.swift
├── EnemyDefinition.swift
└── *Adapter.swift (bridge to legacy models)
```

### Фаза 2: Выделение Правил (Rules Extraction) ✅

**Цель:** Вынести логику из `WorldState.swift` в конфигурируемые правила.

- [x] Создать протоколы `*Rules` (`PressureRules`, `DegradationRules`, `TimeRules`)
- [x] Реализовать для "Сумрачных Пределов" (`TwilightPressureRules`)
- [x] Внедрить через Dependency Injection

### Фаза 3: Внедрение Движка (Engine Core) ✅

**Цель:** Сделать `GameEngine` единственной точкой изменения состояния.

- [x] Создать `TwilightGameEngine` (центральный оркестратор)
- [x] Создать `CoreGameEngine` (generic engine для Content Packs)
- [x] Перенести логику из View/ViewModel в методы Engine
- [x] Заменить прямые мутации на `engine.performAction(...)`

### Фаза 4: Экономика и Резолверы ✅

**Цель:** Унифицировать работу с ресурсами и боем.

- [x] Внедрить `EconomyManager` для всех операций с ресурсами
- [x] Обернуть текущую боёвку в `CombatCalculator` / `CombatModule`
- [x] Создать `PackValidator` для валидации контента

### Фаза 5: Миграция контента в Data ✅

**Цель:** Перенести hardcoded события и квесты в data-файлы.

- [x] Экспортировать контент в JSON
- [x] Реализовать Content Pack System (PackManifest, PackLoader, ContentRegistry)
- [x] Создать `ContentPacks/TwilightMarches/` со всем контентом
- [x] Написать спецификации: SPEC_CAMPAIGN_PACK.md, SPEC_CHARACTER_PACK.md, SPEC_BALANCE_PACK.md
- [x] Создать DevTools/PackCompiler для разработки паков

---

## 9. Критерии Готовности v1.0

> **Статус:** ✅ Engine v1.0 готов (20 января 2026)

| # | Критерий | Статус |
|---|----------|--------|
| 1 | Нет бизнес-правил внутри `WorldState.swift` | ✅ Rules в Config |
| 2 | Правила в `RuleSet` (конфиги/формулы) | ✅ TwilightPressureRules |
| 3 | Контент в `Definitions` + `ContentProvider` | ✅ Content Pack System |
| 4 | UI не мутирует стейт напрямую (только через Engine) | ✅ TwilightGameEngine |
| 5 | Resolver заменяем (карты/кубики/сравнение) | ✅ CombatCalculator |
| 6 | Экономика транзакционная | ✅ EconomyManager |
| 7 | Тесты покрывают engine-инварианты | ✅ ContentPackTests |
| 8 | Content Pack валидация | ✅ PackValidator |
| 9 | Модульность: новый пак без изменения Engine | ✅ ContentRegistry |

**Документация системы контентных паков:**
- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) — гайд по созданию паков
- [SPEC_CAMPAIGN_PACK.md](./SPEC_CAMPAIGN_PACK.md) — спецификация Campaign паков
- [SPEC_CHARACTER_PACK.md](./SPEC_CHARACTER_PACK.md) — спецификация Character паков
- [SPEC_BALANCE_PACK.md](./SPEC_BALANCE_PACK.md) — спецификация Balance паков

**Pack Format (текущий vs планируемый):**
| Формат | v1.x (текущий) | v2.0 (план) |
|--------|----------------|-------------|
| Authoring | JSON | JSON |
| Runtime | JSON | Binary .pack |
| Валидация | Runtime | Compile-time |

> См. [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md#pack-format-roadmap) для деталей roadmap.

**Тестовый API boundary (runtime hygiene):**
- Тестовые helper-методы `ContentRegistry` (`resetForTesting`, `registerMockContent`, `loadMockPack`, `checkIdCollisions`) помечены как `@_spi(Testing)`.
- Обычные production-импорты `TwilightEngine` не видят эти методы; доступ разрешён только тестам через SPI.
- Контракт закреплён gate-проверкой `AuditArchitectureBoundaryGateTests.testContentRegistryTestingHelpersAreSpiOnly`.

---

## Приложение A: Текущая реализация

### Созданные файлы Engine Core

```
Engine/
├── Core/
│   ├── EngineProtocols.swift       # Core phase/result types
│   ├── EngineProtocols+*.swift     # Контракты по доменам (time/pressure/event/...)
│   ├── TimeEngine.swift            # Управление временем
│   ├── PressureEngine.swift        # Система давления
│   ├── EconomyManager.swift        # Транзакции ресурсов
│   ├── RequirementsEvaluator.swift # Оценка требований
│   ├── GameLoop.swift              # Оркестратор
│   ├── TwilightGameAction.swift    # Action enums/input/outcome
│   ├── TwilightGameActionResult.swift # Result/error/state-change модели
│   ├── EngineWorldStateModels.swift # Вынесенные world-state модели
│   ├── EngineWorldBootstrapState.swift # Bootstrap world defaults
│   ├── TwilightGameEngine+ReadOnlyQueries.swift # Read-only facade
│   ├── TwilightGameEngine.swift    # Центральный оркестратор
│   └── CoreGameEngine.swift        # Generic engine (Content Pack aware)
├── ContentPacks/                   # Content Pack инфраструктура (runtime)
│   ├── PackManifest.swift          # Pack metadata & versioning
│   ├── ContentRegistry.swift       # Runtime content registry
│   ├── ContentManager.swift        # Pack lifecycle management
│   ├── BinaryPack.swift            # Binary pack reader/writer
│   ├── PackTypes.swift             # Semantic version + base pack enums
│   └── PackTypes+*.swift           # LoadedPack/cache/error модели
├── Config/
│   ├── TwilightMarchesConfig.swift # Конфигурация игры
│   └── DegradationRules.swift      # Правила деградации
├── Heroes/                         # Модуль героев
│   ├── HeroDefinition.swift        # Протоколы определения героев
│   ├── HeroAbility.swift           # Основная модель способности
│   ├── HeroAbilityConditions.swift # Trigger/condition/cost type models
│   ├── HeroAbilityEffects.swift    # Effect models
│   ├── HeroRegistry.swift          # Реестр героев (загрузка из JSON)
│   └── HEROES_MODULE.md            # Документация модуля
├── Cards/                          # Модуль карт
│   ├── CardDefinition.swift        # Протоколы определения
│   ├── CardRegistry.swift          # Реестр карт
│   └── CARDS_MODULE.md             # Документация модуля
├── Combat/                         # Модуль боя
│   └── CombatCalculator.swift      # Калькулятор боя
├── Data/
│   ├── Definitions/                # Definition structures
│   │   ├── RegionDefinition.swift
│   │   ├── EventDefinition.swift
│   │   ├── EventDefinition+*.swift
│   │   ├── QuestDefinition.swift
│   │   ├── AnchorDefinition.swift
│   │   ├── EnemyDefinition.swift
│   │   ├── EnemyDefinitionAbility.swift
│   │   └── *Adapter.swift          # Bridge to legacy models
│   └── Providers/
│       ├── ContentProvider.swift   # Protocol
│       ├── CodeContentProvider.swift
│       ├── CodeContentProvider+JSON*.swift
│       └── JSONContentProvider.swift
├── Models/
│   ├── ExplorationModels.swift     # Region/anchor core models
│   ├── ExplorationModels+*.swift   # Event/quest/ending/main-quest модели
│   ├── CardType.swift
│   └── CardType+Campaign.swift
└── ENGINE_ARCHITECTURE.md          # Этот документ

ContentPacks/
└── TwilightMarches/                # "Сумрачные Пределы" Pack
    ├── manifest.json               # Pack metadata
    ├── Campaign/ActI/              # Regions, events, quests
    ├── Characters/              # Heroes, starting decks
    ├── Cards/                      # Player/enemy cards
    ├── Balance/                    # Game configuration
    └── Localization/               # en.json, ru.json

PackAuthoring/                      # Authoring tools (separate target)
├── PackLoader.swift                # Load/validate JSON packs
├── PackCompiler.swift              # Compile JSON → binary .pack
└── PackValidator.swift             # Cross-reference validation

PackEditorKit/                      # Editor & simulation toolkit (96 tests)
├── PackStore.swift                 # CRUD operations for pack content
├── ContentCategory.swift           # Content category abstraction
└── CombatSimulator.swift           # In-editor combat simulation

PackCompilerTool/                   # CLI for pack development
└── main.swift                      # imports PackAuthoring
```

### Конфигурация "Сумрачных Пределов"

| Параметр | Значение | Где задано |
|----------|----------|------------|
| Initial Pressure | 30 | `TwilightPressureRules` |
| Max Pressure | 100 | `TwilightPressureRules` |
| Escalation Interval | 3 дня | `TwilightPressureRules` |
| Escalation Amount | +3 base (+ daysPassed/10) | `TwilightPressureRules` |
| Initial Health | 10 | `TwilightResource` |
| Initial Faith | 3 | `TwilightResource` |
| Initial Balance | 50 | `TwilightResource` |
| **Initial Strength** | **5** | `Player.init` |
| ~~Combat Dice~~ | ~~d6~~ | ~~`TwilightCombatConfig`~~ | **LEGACY** — заменён Fate Deck |
| Actions per Turn | 3 | `TwilightCombatConfig` |

> **LEGACY:** Формула ниже — архивная (d6-система). Каноническая формула боя использует **Fate Deck**:
> `Attack = Strength + CardPower + Effort + FateCard.Modifier` (см. [COMBAT_DIPLOMACY_SPEC.md](../Design/COMBAT_DIPLOMACY_SPEC.md) §3.1–§3.3a, [EchoEngine §E.5](#e5-echoengine--ecs-combat-system-v14))
>
> ~~`attack = strength + d6 + bonusDice + bonusDamage`~~

---

## Приложение B: Система героев (Data-Driven)

### B.1 Архитектура

Герои загружаются из Content Pack (`heroes.json`) через `ContentRegistry.heroRegistry`:

```swift
let contentRegistry = ContentRegistry()
try contentRegistry.loadPacks(from: packURLs)

// Получение героя по ID
let hero = contentRegistry.heroRegistry.hero(id: "warrior_ragnar")
```

### B.2 Герои (из heroes.json)

| ID | Имя | HP | Сила | Вера | MaxFaith | Balance |
|----|-----|-----|------|------|----------|---------|
| warrior_ragnar | Рагнар | 12 | 7 | 2 | 8 | 50 |
| mage_elvira | Эльвира | 7 | 2 | 5 | 15 | 50 |
| ranger_thorin | Торин | 10 | 4 | 3 | 10 | 50 |
| priest_aurelius | Аврелий | 9 | 3 | 5 | 12 | 70 |
| shadow_umbra | Умбра | 8 | 4 | 4 | 10 | 30 |

### B.3 Особые способности героев

| Герой | Способность | ability_id |
|-------|-------------|------------|
| **Рагнар** | Ярость: +2 урон при HP < 50% | `warrior_rage` |
| **Эльвира** | Медитация: +1 вера в конце хода | `mage_meditation` |
| **Торин** | Выслеживание: +1 кубик при первой атаке | `ranger_tracking` |
| **Аврелий** | Благословение: -1 урон от тёмных источников | `priest_blessing` |
| **Умбра** | Засада: +3 урона по целям с полным HP | `shadow_ambush` |

---

## Приложение C: Эффекты карт в бою (AbilityEffect)

### C.1 ~~Полная формула боя~~ (LEGACY — d6-система, архив)

> **Каноническая формула:** см. [COMBAT_DIPLOMACY_SPEC.md](../Design/COMBAT_DIPLOMACY_SPEC.md) §3.1–§3.3a и [EchoEngine §E.5](#e5-echoengine--ecs-combat-system-v14).
> Боевая система заменена на Fate Deck (карточная механика вместо d6).

<details><summary>Архивная d6-формула (не используется в runtime)</summary>

```
1. Бросок кубиков: totalDice = 1 + bonusDice + rangerBonus
2. Сумма: total = strength + sum(diceRolls) + bonusDamage
3. Попадание: total >= enemyDefense
4. Урон: baseDamage = max(1, total - defense + 2)
5. Итоговый урон: damage = baseDamage + curseModifier + heroClassBonus
```

</details>

### C.2 ~~Реализованные эффекты карт~~ (LEGACY — d6-система, архив)

> **Каноническая система эффектов:** см. [EchoEngine §E.5](#e5-echoengine--ecs-combat-system-v14) — `AbilityEffect` через `CombatSystem`.

<details><summary>Архивная таблица эффектов (d6-эра)</summary>

| Эффект | Метод в CombatView | Действие |
|--------|-------------------|----------|
| `damage(amount, type)` | `applyCardEffects` | Урон врагу |
| `heal(amount)` | `applyCardEffects` | HP игроку |
| `drawCards(count)` | `applyCardEffects` | Взять карты |
| `gainFaith(amount)` | `applyCardEffects` | Получить веру |
| `addDice(count)` | `bonusDice += count` | +кубики к атаке |
| `reroll` | `bonusDice += 1` | +1 кубик |
| `shiftBalance(towards, amount)` | `player.shiftBalance()` | Сдвиг баланса |
| `applyCurse(type, duration)` | Урон врагу `duration*2` | Тёмная магия |
| `removeCurse(type)` | `player.removeCurse()` | Снять проклятие |
| `summonSpirit(power, realm)` | `summonedSpirits.append()` | Призыв духа |
| `sacrifice(cost, benefit)` | `-cost HP`, бонус | Жертва за силу |

</details>

### C.3 Призванные духи

- Атакуют **при призыве** (сразу)
- Атакуют **в конце хода** (performEndTurn)
- Исчезают после атаки в конце хода

---

## Приложение D: Ссылки на документацию

- [QA_ACT_I_CHECKLIST.md](./QA_ACT_I_CHECKLIST.md) — Тестирование Акта I
- [EXPLORATION_CORE_DESIGN.md](./EXPLORATION_CORE_DESIGN.md) — Дизайн исследования

---

## Приложение E: Модульная архитектура

### E.1 Принципы модульности

Модули движка проектируются для:
- **Независимости** — можно подключать/отключать без изменения ядра
- **Расширяемости** — легко добавлять новый контент через JSON или код
- **Тестируемости** — каждый модуль имеет свои тесты

### E.2 Модуль Heroes

**Путь:** `Engine/Heroes/`
**Документация:** [HEROES_MODULE.md](../Engine/Heroes/HEROES_MODULE.md)

Компоненты:
- `HeroDefinition` — протокол определения героя
- `HeroRegistry` — реестр героев (загрузка из heroes.json)
- `HeroAbility` — система способностей героев
- `HeroDefinition` — протокол определения героя
- `HeroAbility` — система способностей
- `HeroRegistry` — централизованный реестр героев

```swift
// Пример получения героя
let hero = contentRegistry.heroRegistry.hero(id: "warrior_ragnar")
let startingDeck = hero?.startingDeckCardIDs
```

### E.3 Модуль Cards

**Путь:** `Engine/Cards/`
**Документация:** [CARDS_MODULE.md](../Engine/Cards/CARDS_MODULE.md)

Компоненты:
- `CardDefinition` — протокол определения карты
- `CardOwnership` — система принадлежности (universal/class/hero)
- `CardRegistry` — централизованный реестр карт

Типы принадлежности карт:
| Тип | Описание | Пример |
|-----|----------|--------|
| universal | Доступна всем | Базовый удар |
| classSpecific | Только для класса | Яростный удар (Warrior) |
| heroSignature | Уникальная для героя | Топор предков (Рагнар) |
| expansion | Требует DLC | Карты дополнения |

```swift
// Пример получения карт из загруженных паков
let cards = contentRegistry.getAllCards()
let strike = contentRegistry.getCard(id: "strike_basic")
```

### E.4 ~~Модуль Combat (d6)~~ → LEGACY

> **Каноническая боевая система:** [EchoEngine §E.5](#e5-echoengine--ecs-combat-system-v14) — `CombatSimulation` + `FateResolutionService` + `CombatCalculator.calculateAttackWithFate()`.
> Ниже — архивный API (d6-эра), сохранён для backward compatibility reference.

<details><summary>Архивный Combat API (d6-эра)</summary>

**Путь:** `Engine/Combat/`

Компоненты:
- `CombatCalculator` — расчёт боя с полной разбивкой факторов
- `CombatResult` — результат с детализацией (hit/miss, факторы, урон)
- `AttackRoll` — бросок атаки с модификаторами
- `DamageCalculation` — расчёт урона

```swift
// Пример расчёта атаки (LEGACY — d6)
let result = CombatCalculator.calculatePlayerAttack(
    player: player,
    monsterDefense: 5,
    monsterCurrentHP: 10,
    monsterMaxHP: 10,
    bonusDice: bonusDice,
    bonusDamage: bonusDamage,
    isFirstAttack: true
)
// result.isHit, result.attackRoll, result.damageCalculation
```

</details>

### E.5 EchoEngine — ECS Combat System (v1.4)

**Пакет:** `Packages/EchoEngine`
**Фреймворк:** FirebladeECS (Entity-Component-System)
**UI:** `Packages/EchoScenes` (SpriteKit)

EchoEngine — параллельная реализация боевой системы на ECS-архитектуре. Работает независимо от TwilightGameEngine и предоставляет real-time карточный бой через SpriteKit. Интегрируется с основным движком через `EchoEncounterBridge`.

#### Компоненты (ECS)

| Компонент | Описание |
|-----------|----------|
| `HealthComponent` | HP + Will (текущее/максимальное) |
| `EnergyComponent` | Энергия за ход (current/max, default 3) |
| `DeckComponent` | drawPile, hand, discardPile, exhaustPile |
| `StatusEffectComponent` | Активные статус-эффекты (яд, щит, усиление) |
| `EnemyTagComponent` | Паттерн поведения, power, defense, faithReward, lootCardIds |
| `DiplomacyComponent` | AttackTrack (physical/spiritual), rageShield, surpriseBonus |
| `PlayerTagComponent` | Имя, сила, strength |

#### Системы и сервисы

| Система | Ответственность |
|---------|-----------------|
| `CombatSystem` | playerAttack(), playerInfluence(), resolveEnemyIntent(), victory check |
| `FateResolutionService` | Полный fate draw: keyword interpretation + suit matching |
| `AISystem` | Циклический паттерн врага: `pattern[(round-1) % count]` |
| `DeckSystem` | Тасовка, добор, сброс, exhaust |

#### Ключевые механики

- **Энергия:** 3/ход, `card.cost ?? 1` за карту, сброс в начале хода
- **Exhaust:** Карты с `exhaust: true` → exhaustPile (не возвращаются)
- **Disposition Track:** Единая шкала -100…+100. disposition → -100 = уничтожен, → +100 = подчинён.
- **Momentum:** streak_bonus, threat_bonus, switch_penalty — детерминистическая система без RNG.
- **Enemy Modes:** Survival (disposition < -threshold), Desperation (disposition > +threshold), Weakened (swing ±30).
- **Статус-эффекты:** poison, shield, buff — тикают каждый ход.
- **Fate Resolution:** FateResolutionService оборачивает FateDeckManager + KeywordInterpreter. Keyword эффекты (surge/focus/echo/shadow/ward) зависят от текущего disposition. Surge: +50% base_power. Echo: бесплатный повтор (не после Sacrifice).
- **Victory:** `CombatOutcome.victory(.destroyed)` при disposition=-100, `.victory(.subjugated)` при disposition=+100. Resonance delta: негативный за destroy (Nav), позитивный за subjugate (Prav).

#### CombatResult

```swift
public struct CombatResult {
    let outcome: CombatOutcome      // .victory(.destroyed), .victory(.subjugated), .defeat
    let finalDisposition: Int       // -100...+100
    let resonanceDelta: Int         // Nav за destroy, Prav за subjugate
    let faithDelta: Int
    let lootCardIds: [String]
    let updatedFateDeckState: FateDeckState?
    let combatSnapshot: CombatSnapshot  // для replay/аналитики
}
```

#### CombatSimulation (Фасад)

```swift
let sim = CombatSimulation.create(enemyDefinition: enemy, playerStrength: 10, seed: 42)
sim.beginCombat()
sim.strike(cardId: id, targetId: enemy)   // disposition -= effective_power
sim.influence(cardId: id)                  // disposition += effective_power
sim.sacrifice(cardId: id)                  // heal hero + enemy buff, exhaust card
sim.endTurn()
sim.resolveEnemyTurn()
let result = sim.combatResult  // CombatResult после завершения боя
```

#### Disposition Combat API (Phase 3)

> **Дизайн:** [Disposition Combat Design v2.5](../../docs/plans/2026-02-18-disposition-combat-design.md)

Формула effective_power:
```
surged_base     = fate.keyword == .surge ? (base_power * 3 / 2) : base_power
raw_power       = surged_base + streak_bonus + threat_bonus - switch_penalty + fate_modifier
effective_power = min(raw_power, 25)   // hard cap
```

**Инварианты:**
- `effective_power <= 25` (hard cap — четверть шкалы)
- Momentum — чистое число, не задействует RNG
- `disposition ∈ [-100, +100]`, clamped
- Sacrifice exhaust необратим (карта удаляется из колоды навсегда)

**Snapshot-контракт (mid-combat save):** `disposition`, `streakType`, `streakCount`, `enemyMode`, `heroHP`, `fateDeckState` обязательны в `CombatSnapshot`.

#### RitualCombatScene (Phase 3 — planned)

Единая SpriteKit-сцена для боя, заменяющая SwiftUI CombatView и Arena CombatScene. Работает поверх `CombatSimulation` через drag-and-drop:

- Карты перетаскиваются на врага → `strike()` (disposition -)
- Карты перетаскиваются на алтарь → `influence()` (disposition +)
- Карты перетаскиваются в костёр → `sacrifice()` (heal + exhaust)

**Архитектурный инвариант:** `ResonanceAtmosphereController` — read-only observer, не вызывает mutation-методы `CombatSimulation`.

#### EchoEncounterBridge (Интеграция)

```swift
let config = EchoEncounterBridge.makeCombatConfig(engine: engine) // собирает параметры из engine state
EchoCombatBridge.applyCombatResult(result, to: engine)            // commit через action pipeline
```

### E.6 Интеграция модулей (обновлено)

```
┌─────────────────────────────────────────────────────────┐
│                    GameEngine                            │
│                         │                                │
│     ┌──────────────────┼──────────────────┐              │
│     ▼                  ▼                  ▼              │
│ ┌──────────┐    ┌──────────┐      ┌──────────┐          │
│ │  Heroes  │    │  Cards   │      │  Combat  │          │
│ │ Registry │◄──►│ Registry │◄────►│Calculator│          │
│ └──────────┘    └──────────┘      └──────────┘          │
│     │                │                  │                │
│     ▼                ▼                  ▼                │
│ ┌──────────────────────────────────────────┐            │
│ │           Player / GameState              │            │
│ └──────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────┘
```

### E.7 Расширение модулей

**Добавление нового героя:**
1. Добавить запись в `heroes.json`
2. Добавить способность в `HeroAbility.forAbilityId()` (если новая)
3. Добавить стартовую колоду в `CardRegistry` (если особая)

**Добавление DLC пакета:**
```swift
let contentRegistry = ContentRegistry()

// DLC ships as a compiled `.pack` file (see pack-compiler in PackAuthoring).
try contentRegistry.loadPack(from: dlcPackURL)

// Heroes/cards from the DLC become part of the canonical registry immediately.
let dlcHeroes = contentRegistry.heroRegistry.allHeroes
let dlcCard = contentRegistry.getCard(id: "dark_strike")
```

---

**Конец документа**
