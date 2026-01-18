# Game Engine v1.0: Technical Architecture Document

**Версия:** 1.0
**Статус:** Architecture Lock
**Дата:** Январь 2026
**Назначение:** Техническая спецификация для реализации переиспользуемого игрового ядра.

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
| **Rules** | Логика изменений (формулы, инварианты, условия) | Картридж | `каждые 3 дня +2 tension` |
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

**Инварианты:**
- ✅ Давление в среднем растёт
- ✅ Игрок может замедлять, но не отменять
- ✅ Давление определяет фазы игры

### 3.3 Event Engine

**Идея:** Все взаимодействия проходят через события.

```swift
protocol EventDefinition {
    var id: String { get }
    var title: String { get }
    var choices: [ChoiceDefinition] { get }
    var isInstant: Bool { get }
    var isOneTime: Bool { get }

    func canOccur(in context: EventContext) -> Bool
}

protocol EventSystemProtocol {
    func getAvailableEvents(in context: EventContext) -> [EventDefinition]
    func markCompleted(eventId: String)
    func isCompleted(eventId: String) -> Bool
}
```

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
protocol ChallengeDefinition {
    var type: ChallengeType { get }
    var difficulty: Int { get }
    var context: Any? { get }
}

enum ChallengeType {
    case combat
    case skillCheck
    case socialEncounter
    case puzzle
    case tradeOff
    case sacrifice
}

protocol ConflictResolverProtocol {
    func resolve(challenge: ChallengeDefinition, actor: Player) async -> ResolutionResult
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

### 3.8 Victory / Defeat Engine

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
    ├── 4. WorldTick: tension +2 (если 3й день)
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
    let titleKey: String
    let descriptionKey: String
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
    let titleKey: String
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
| 7 | Один seed даёт идентичные результаты | `testDeterministicReproducibility()` |

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

---

## 8. План Внедрения

### Фаза 1: Подготовка Данных (Data Separation)

**Цель:** Отделить статичные определения от runtime состояния.

- [ ] Создать `*Definition` структуры рядом с текущими моделями
- [ ] Создать `ContentProvider` (простой класс для загрузки)
- [ ] В текущих моделях оставить только динамические данные + ID ссылки

**Файлы:**
```
Engine/Data/
├── RegionDefinition.swift
├── EventDefinition.swift
├── QuestDefinition.swift
├── AnchorDefinition.swift
└── ContentProvider.swift
```

### Фаза 2: Выделение Правил (Rules Extraction)

**Цель:** Вынести логику из `WorldState.swift` в конфигурируемые правила.

- [ ] Создать протоколы `*Rules` (`PressureRules`, `DegradationRules`, `TimeRules`)
- [ ] Реализовать для "Сумрачных Пределов" (`TwilightPressureRules`)
- [ ] Внедрить через Dependency Injection

**Файлы:**
```
Engine/Config/
├── TwilightPressureRules.swift
├── TwilightDegradationRules.swift
├── TwilightCombatRules.swift
└── TwilightMarchesConfig.swift  # Уже создан
```

### Фаза 3: Внедрение Движка (Engine Core)

**Цель:** Сделать `GameEngine` единственной точкой изменения состояния.

- [ ] Создать `TwilightMarchesEngine` (наследник `GameLoopBase`)
- [ ] Перенести логику из View/ViewModel в методы Engine
- [ ] Заменить прямые мутации на `engine.performAction(...)`

**Критерий:** UI не содержит `worldState.daysPassed += 1`.

### Фаза 4: Экономика и Резолверы

**Цель:** Унифицировать работу с ресурсами и боем.

- [ ] Внедрить `EconomyManager` для всех операций с ресурсами
- [ ] Обернуть текущую боёвку в `CardCombatResolver`
- [ ] Убрать прямые изменения `player.faith -= 5` из UI

### Фаза 5: Миграция контента в Data

**Цель:** Перенести hardcoded события и квесты в data-файлы.

- [ ] Экспортировать текущие события в JSON
- [ ] Реализовать `JSONContentProvider`
- [ ] Убрать `createInitialEvents()` из кода

---

## 9. Критерии Готовности v1.0

Чтобы честно назвать Engine v1.0 готовым:

| # | Критерий | Статус |
|---|----------|--------|
| 1 | Нет бизнес-правил внутри `WorldState.swift` | ⬜ |
| 2 | Правила в `RuleSet` (конфиги/формулы) | ⬜ |
| 3 | Контент в `Definitions` + `ContentProvider` | ⬜ |
| 4 | UI не мутирует стейт напрямую (только через Engine) | ⬜ |
| 5 | Resolver заменяем (карты/кубики/сравнение) | ⬜ |
| 6 | Экономика транзакционная | ⬜ |
| 7 | Тесты покрывают engine-инварианты | ✅ |

---

## Приложение A: Текущая реализация

### Созданные файлы Engine Core

```
Engine/
├── Core/
│   ├── EngineProtocols.swift    # Все контракты
│   ├── TimeEngine.swift         # Управление временем
│   ├── PressureEngine.swift     # Система давления
│   ├── EconomyManager.swift     # Транзакции ресурсов
│   └── GameLoop.swift           # Оркестратор
├── Config/
│   └── TwilightMarchesConfig.swift  # Конфигурация игры
└── ENGINE_ARCHITECTURE.md       # Этот документ
```

### Конфигурация "Сумрачных Пределов"

| Параметр | Значение | Где задано |
|----------|----------|------------|
| Initial Pressure | 30 | `TwilightPressureRules` |
| Max Pressure | 100 | `TwilightPressureRules` |
| Escalation Interval | 3 дня | `TwilightPressureRules` |
| Escalation Amount | +2 | `TwilightPressureRules` |
| Initial Health | 10 | `TwilightResource` |
| Initial Faith | 3 | `TwilightResource` |
| Initial Balance | 50 | `TwilightResource` |
| Combat Dice | d6 | `TwilightCombatConfig` |
| Actions per Turn | 3 | `TwilightCombatConfig` |

---

## Приложение B: Ссылки на документацию

- [QA_ACT_I_CHECKLIST.md](./QA_ACT_I_CHECKLIST.md) — Тестирование Акта I
- [EXPLORATION_CORE_DESIGN.md](./EXPLORATION_CORE_DESIGN.md) — Дизайн исследования

---

**Конец документа**
