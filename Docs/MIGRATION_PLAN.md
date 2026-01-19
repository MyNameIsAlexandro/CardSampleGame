# ENGINE v1.0 MIGRATION PLAN

> **Source of Truth:** Этот документ определяет план миграции к Engine v1.0.
> Статус задач обновляется по мере выполнения.

---

## Текущий статус

| Phase | Название | Статус |
|-------|----------|--------|
| Phase 1 | Core Protocols & Engine Foundation | ✅ Done |
| Phase 2 | Data Separation (Definitions + Runtime) | ✅ Done |
| Phase 3 | GameLoop Integration | ✅ Done |
| Phase 3.5 | **Engine-First Architecture** | ✅ Done |
| Phase 4 | Economy Transactions Everywhere | ⬜ Planned |
| Phase 5 | Content Migration to JSON | ⬜ Planned |

---

## ✅ Phase 3.5: Engine-First Architecture

**Цель:** UI читает состояние ТОЛЬКО из Engine, не из WorldState/Player напрямую.

### Выполнено

| Компонент | Файл | Статус |
|-----------|------|--------|
| Engine Published State | TwilightGameEngine.swift | ✅ Done |
| New Actions (dismiss events) | TwilightGameAction.swift | ✅ Done |
| EngineSave (persistence) | EngineSave.swift | ✅ Done |
| EngineRegionCardView | WorldMapView.swift | ✅ Done |
| EngineRegionDetailView | WorldMapView.swift | ✅ Done |
| EngineEventLogView | WorldMapView.swift | ✅ Done |
| WorldMapView Engine-First init | WorldMapView.swift | ✅ Done |

### Архитектура Engine-First

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│   WorldMapView, RegionDetailView, EventLogView              │
│   @ObservedObject engine: TwilightGameEngine                │
│   Reads: engine.* (published properties)                    │
│   Writes: engine.performAction()                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    TwilightGameEngine                        │
│   @Published: regions, playerHealth, currentDay, etc.       │
│   Actions: travel, rest, explore, dismissEvent, etc.        │
│   Save/Load: engine.createSave() / engine.loadFromSave()    │
└─────────────────────────────────────────────────────────────┘
```

### Engine Published Properties

```swift
// Player state
@Published var playerHealth, playerFaith, playerBalance: Int
@Published var playerName: String

// World state
@Published var currentDay, worldTension, lightDarkBalance: Int
@Published var publishedRegions: [UUID: EngineRegionState]
@Published var currentRegionId: UUID?

// Events & Quests
@Published var currentEvent: GameEvent?
@Published var lastDayEvent: DayEvent?
@Published var publishedActiveQuests: [Quest]
@Published var publishedEventLog: [EventLogEntry]
```

### Legacy Adapters Status

Adapters остаются для обратной совместимости во время постепенной миграции:
- `WorldStateEngineAdapter` - синхронизация с WorldState
- `PlayerEngineAdapter` - синхронизация с Player
- `GameStateEngineAdapter` - синхронизация с GameState

**Примечание:** Adapters будут удалены когда ВСЕ Views перейдут на Engine-First.

---

## ✅ РЕШЁННЫЙ РАЗРЫВ: Legacy vs Engine (Split Personality)

> **Статус:** Engine подключён через адаптеры, UI работает через GameViewModel → TwilightGameEngine

### Решение (Phase 3 ✅)

Архитектура теперь использует Engine через адаптеры:

| Слой | Компонент | Статус |
|------|----------|--------|
| **UI** | `GameViewModel` | ✅ Работает через Engine |
| **Engine** | `TwilightGameEngine` | ✅ Центральная точка входа |
| **Adapters** | `WorldStateEngineAdapter`, `PlayerEngineAdapter` | ✅ Синхронизируют Legacy ↔ Engine |
| **Legacy** | `WorldState.swift` | 🔶 Используется через адаптеры |

**Реализованные компоненты:**
- `TwilightGameEngine.performAction()` — единая точка входа
- `GameViewModel` — ViewModel для UI с Combine bindings
- `WorldStateEngineAdapter` — двусторонняя синхронизация
- `PlayerEngineAdapter` — адаптер игрока
- `EventPipeline` — обработка событий
- `CombatModule` — боевая система

### Что сделано

✅ **UI Adapter**: `GameViewModel` работает через `TwilightGameEngine`
✅ **Deprecation**: методы в `WorldState.swift` помечены deprecated
✅ **Connect Engine**: все действия идут через `performAction()`
✅ **Contract Tests**: 13 тестов в `Phase3ContractTests.swift`

### Оставшаяся работа (Phase 4+)

🔶 **Остаётся на Phase 4:**
- Полная миграция UI на GameViewModel
- Удаление прямых вызовов WorldState из Views
- Economy transactions через Engine

---

## EPIC A — Phase 2: Data Separation (Definitions + ContentProvider)

**Цель:** перейти от "Codable structs в коде" к Cartridge-модели: `*Definition` + `*RuntimeState`.

### Feature A1 — Definitions модели

> **Принцип:** Definition = иммутабельные данные, описывающие "что существует в игре".

| Task | Файл | Статус |
|------|------|--------|
| Создать `Engine/Data/Definitions/` | — | ✅ Done |
| `RegionDefinition` | RegionDefinition.swift | ✅ Done |
| `AnchorDefinition` | AnchorDefinition.swift | ✅ Done |
| `EventDefinition` + `ChoiceDefinition` | EventDefinition.swift | ✅ Done |
| `QuestDefinition` + `ObjectiveDefinition` | QuestDefinition.swift | ✅ Done |
| `MiniGameChallengeDefinition` | MiniGameChallengeDefinition.swift | ✅ Done |
| Ключи локализации `titleKey/bodyKey/labelKey` | Все Definition файлы | ✅ Done |

**Контракт Definition:**
```swift
// Definition = иммутабельный, нет runtime полей
protocol GameDefinition: Codable, Identifiable {
    var id: String { get }
}

struct RegionDefinition: GameDefinition {
    let id: String
    let titleKey: String           // Локализация
    let neighborIds: [String]
    let anchorId: String?
    let eventPoolIds: [String]
    let initialState: String       // "stable", "borderland", "breach"
}
```

### Feature A2 — RuntimeState модели

> **Принцип:** RuntimeState = мутабельное состояние игры в runtime.

| Task | Файл | Статус |
|------|------|--------|
| Создать `Engine/Runtime/` | — | ✅ Done |
| `WorldRuntimeState` | WorldRuntimeState.swift | ✅ Done |
| `EventRuntimeState` | EventRuntimeState.swift | ✅ Done |
| `QuestRuntimeState` | QuestRuntimeState.swift | ✅ Done |
| `PlayerRuntimeState` | PlayerRuntimeState.swift | ✅ Done |
| `GameRuntimeState` (combined) | GameRuntimeState.swift | ✅ Done |
| Migration adapter: `WorldState` → `WorldRuntimeState` | LegacyAdapters.swift | ✅ Done |
| Migration adapter: `GameSave` → `GameState(Runtime)` | LegacyAdapters.swift | ✅ Done |

**Контракт RuntimeState:**
```swift
// RuntimeState = мутабельный, ссылается на Definition по id
struct WorldRuntimeState: Codable {
    var currentRegionId: String
    var regionsState: [String: RegionRuntimeState]  // id → state
    var anchorsState: [String: AnchorRuntimeState]
    var flags: [String: Bool]
    var pressure: Int
    var currentTime: Int
}

struct RegionRuntimeState: Codable {
    let definitionId: String
    var currentState: String    // "stable" → "borderland" → "breach"
    var visitCount: Int
    var isDiscovered: Bool
}
```

### Feature A3 — ContentProvider (Code → JSON)

> **Принцип:** ContentProvider = абстракция загрузки контента.

| Task | Файл | Статус |
|------|------|--------|
| `ContentProvider` protocol | ContentProvider.swift | ✅ Done |
| `CodeContentProvider` (использует TwilightMarchesConfig) | CodeContentProvider.swift | ✅ Done |
| `TwilightMarchesCodeContentProvider` (конкретная реализация) | WorldState.swift | ✅ Done |
| `JSONContentProvider` (заглушка) | JSONContentProvider.swift | ✅ Done |
| Content Validator | ContentProvider.swift (ContentValidator) | ✅ Done |
| WorldState.setupInitialWorld() использует ContentProvider | WorldState.swift | ✅ Done |

**Реализация TwilightMarchesCodeContentProvider:**
- 7 регионов Act I: village, oak, forest, swamp, mountain, breach, dark_lowland
- 6 якорей с типами и influence (chapel, sacred_tree, stone_idol, spring, barrow, shrine)
- Bridge методы для преобразования Definition → Legacy Model
- Локализация через статические методы `regionName(for:)`, `anchorName(for:)`

**Контракт ContentProvider:**
```swift
protocol ContentProvider {
    // Regions
    func getAllRegionDefinitions() -> [RegionDefinition]
    func getRegionDefinition(id: String) -> RegionDefinition?

    // Events
    func getAllEventDefinitions() -> [EventDefinition]
    func getEventDefinitions(forRegion regionId: String) -> [EventDefinition]
    func getEventDefinitions(forPool poolId: String) -> [EventDefinition]

    // Quests
    func getAllQuestDefinitions() -> [QuestDefinition]
    func getQuestDefinition(id: String) -> QuestDefinition?

    // Validation
    func validate() -> [ContentValidationError]
}
```

**Валидация контента:**
- Уникальность id
- Ссылки (region → neighborIds существуют)
- Event → choice ids уникальны
- Quest links существуют
- Диапазоны pressure/balance корректны

---

## EPIC B — Phase 3: Engine GameLoop Integration

**Цель:** UI не мутирует state напрямую. Вся игра идёт через `GameEngine.performAction()`.

**Статус:** ✅ Done (все компоненты реализованы и протестированы)

### Feature B1 — GameAction и единая точка входа

| Task | Файл | Статус |
|------|------|--------|
| `TwilightGameAction` enum (все действия) | TwilightGameAction.swift | ✅ Done |
| `TwilightGameEngine.performAction(action)` по 11-step loop | TwilightGameEngine.swift | ✅ Done |
| `ActionResult` с diff и ошибками | TwilightGameAction.swift | ✅ Done |
| `StateChange` enum для отслеживания изменений | TwilightGameAction.swift | ✅ Done |
| `ActionError` enum для ошибок | TwilightGameAction.swift | ✅ Done |

**Реализованные действия:**
```swift
enum TwilightGameAction: TimedAction {
    case travel(toRegionId: UUID)
    case rest
    case explore
    case trade
    case strengthenAnchor
    case chooseEventOption(eventId: UUID, choiceIndex: Int)
    case resolveMiniGame(result: MiniGameResult)
    case startCombat(encounterId: UUID)
    case playCard(cardId: UUID, targetId: UUID?)
    case endCombatTurn
    case skipTurn
    case custom(id: String, timeCost: Int)
}
```

### Feature B2 — Legacy isolation

| Task | Файл | Статус |
|------|------|--------|
| `WorldStateEngineAdapter` для связи | EngineAdapters.swift | ✅ Done |
| `PlayerEngineAdapter` для связи | EngineAdapters.swift | ✅ Done |
| `GameStateEngineAdapter` для связи | EngineAdapters.swift | ✅ Done |
| `GameViewModel` для UI | GameViewModel.swift | ✅ Done |
| Deprecation warnings на прямые мутации | WorldState.swift | ✅ Done |
| Пометить `processDayStart()` deprecated | WorldState.swift | ✅ Done |

### Feature B3 — Event Module подключение

| Task | Файл | Статус |
|------|------|--------|
| `EventPipeline` (selection + resolution) | EventPipeline.swift | ✅ Done |
| `EventSelector`: filter → weight → seed | EventPipeline.swift | ✅ Done |
| `EventResolver`: requirements → flags → diff | EventPipeline.swift | ✅ Done |
| `MiniGameDispatcher` | MiniGameDispatcher.swift | ✅ Done |
| `CombatModule` интеграция | Engine/Modules/CombatModule.swift | ✅ Done |

### Feature B4 — Contract Tests

| Task | Файл | Статус |
|------|------|--------|
| Phase 3 Contract Tests | Phase3ContractTests.swift | ✅ Done |

### Новые файлы Phase 3:

```
Engine/
├── Core/
│   ├── TwilightGameAction.swift    # Actions + ActionResult + StateChange
│   └── TwilightGameEngine.swift    # Main game engine
├── Events/
│   ├── EventPipeline.swift         # EventSelector + EventResolver
│   └── MiniGameDispatcher.swift    # MiniGame challenge routing
├── Modules/
│   └── CombatModule.swift          # Combat system integration
└── Migration/
    └── EngineAdapters.swift        # Legacy adapters

ViewModels/
└── GameViewModel.swift             # UI ViewModel using Engine

CardSampleGameTests/Engine/
└── Phase3ContractTests.swift       # Contract tests
```

### Phase 3 Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
│  ┌─────────────────┐                                            │
│  │  GameViewModel  │  ← Единая точка входа для UI               │
│  └────────┬────────┘                                            │
└───────────│─────────────────────────────────────────────────────┘
            │ performAction()
            ▼
┌───────────────────────────────────────────────────────────────────┐
│                      Engine Layer                                  │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │              TwilightGameEngine                            │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌──────────────────────┐ │   │
│  │  │ TimeEngine  │ │ Pressure    │ │ EconomyManager       │ │   │
│  │  └─────────────┘ │ Engine      │ └──────────────────────┘ │   │
│  │                  └─────────────┘                          │   │
│  │  ┌──────────────────────────────────────────────────────┐ │   │
│  │  │ EventPipeline (Selector + Resolver)                  │ │   │
│  │  └──────────────────────────────────────────────────────┘ │   │
│  │  ┌─────────────────┐ ┌─────────────────────────────────┐  │   │
│  │  │ MiniGameDispatcher │ │ CombatModule                │  │   │
│  │  └─────────────────┘ └─────────────────────────────────┘  │   │
│  └───────────────────────────────────────────────────────────┘   │
│                              │                                    │
│                    Adapters  │                                    │
│  ┌───────────────────────────┴───────────────────────────────┐   │
│  │ WorldStateAdapter │ PlayerAdapter │ GameStateAdapter      │   │
│  └───────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
            │ sync
            ▼
┌───────────────────────────────────────────────────────────────────┐
│                      Legacy Layer (во время миграции)             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────────┐ │
│  │ WorldState  │ │   Player    │ │         GameState           │ │
│  │ (deprecated │ │ (deprecated │ │       (deprecated            │ │
│  │  for UI)    │ │  for UI)    │ │        for UI)              │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
```

---

## EPIC C — Phase 4: Economy Transactions Everywhere

**Цель:** убрать `player.faith -= X` из UI/моделей.

### Feature C1 — EconomyManager внедрение

| Task | Файл | Статус |
|------|------|--------|
| Все ресурсные изменения через `Transaction` | Все ViewModels | ⬜ |
| `canAfford + process` атомарно | EconomyManager.swift | ✅ Done |
| `ActionError` для UI | ActionError.swift | ⬜ |

### Feature C2 — Requirements унификация

| Task | Файл | Статус |
|------|------|--------|
| `ChoiceRequirements` проверяет всё | ChoiceRequirements.swift | ⬜ |
| Ресурсы (faith/health) | — | ⬜ |
| Флаги | — | ⬜ |
| Balance range | — | ⬜ |
| Pressure range | — | ⬜ |

---

## EPIC D — Phase 5: Content Migration to JSON (позже)

**Цель:** реальный cartridge-data-driven.

| Task | Файл | Статус |
|------|------|--------|
| Export Act I → JSON | Resources/Content/ActI/ | ⬜ |
| `JSONContentProvider` полноценно | JSONContentProvider.swift | ⬜ |
| Test: same seed → same outcome | RegressionTests | ⬜ |
| **UI icons from data** | Definition + UI | ⬜ |

### UI Data-Driven Icons

> **Текущее ограничение:** Иконки регионов/якорей определены как computed properties в enum'ах (ExplorationModels.swift). Это не позволяет добавлять новые типы через JSON без перекомпиляции.

**Что нужно сделать:**
1. Добавить поле `icon: String` в `RegionDefinition`, `AnchorDefinition`
2. UI берёт иконку из Definition, не из switch
3. JSON может определять новые типы регионов с кастомными иконками

---

## TEST INFRASTRUCTURE

### Engine Contract Tests

> **Папка:** `CardSampleGameTests/Engine/`

| Test File | Что проверяет | Статус |
|-----------|---------------|--------|
| `EngineContractsTests.swift` | Core engine invariants + PressureEngine save/load | ✅ Done |
| `EventModuleContractsTests.swift` | Event module contracts | ✅ Done |
| `DataSeparationTests.swift` | Definition/Runtime separation + TwilightMarchesCodeContentProvider | ✅ Done |
| `Phase2ContractTests.swift` | Phase 2 contracts (ContentProvider) | ✅ Done |
| `Phase3ContractTests.swift` | Phase 3 contracts (Engine integration) | ✅ Done |

**EngineContractsTests:**
```swift
func testUIDoesNotMutateStateDirectly()
func testPerformActionAdvancesTimeOnlyViaTimeEngine()
func testWorldTickTriggeredByTimeThresholds()
// NEW: PressureEngine save/load tests (Audit fix)
func testPressureEngineTriggeredThresholdsSaveLoad()
func testPressureEngineSyncTriggeredThresholdsFromPressure()
func testPressureEngineTriggeredThresholdsPreventDuplicates()
```

**EventModuleContractsTests:**
```swift
func testInlineEventDoesNotInvokeMiniGame()
func testMiniGameEventDispatchesChallengeAndReturnsDiff()
func testMiniGameDoesNotMutateState()
func testEventSelectionDeterministicWithSeed()
func testOneTimeEventsPersistAcrossSaveLoad()
func testCooldownRespected()
```

**DataSeparationTests:**
```swift
func testDefinitionsAreImmutable()
func testRuntimeReferencesValidDefinitions()
func testContentProviderValidationCatchesBrokenLinks()
// NEW: TwilightMarchesCodeContentProvider tests (Audit fix)
func testTwilightMarchesProviderLoadsAllRegions()
func testTwilightMarchesProviderLoadsAnchors()
func testTwilightMarchesProviderNeighborLinksValid()
func testTwilightMarchesLocalizationHelpers()
func testTwilightMarchesRegionInitialStates()
```

### Regression Harness

> **Цель:** "до/после миграции поведение одинаковое"

| Test File | Что проверяет | Статус |
|-----------|---------------|--------|
| `RegressionPlaythroughTests.swift` | Deterministic playthrough | ✅ Done |

```swift
func testFixedSeedPlaythroughProducesSameOutcome() {
    // Fixed seed
    // Fixed action sequence: travel → explore → choose → ...
    // Assert:
    // - final pressure
    // - visited regions count
    // - quest stage
    // - deck size
    // - flags set
    // - save/load roundtrip
}
```

---

## DoD: Migration Complete

Чтобы считать миграцию завершённой:

| Критерий | Описание |
|----------|----------|
| ✅ Single entry point | `GameEngine.performAction()` — единственная точка изменения state |
| ✅ Event Module contract | Inline vs Mini-Game работает по контракту |
| ✅ Economy transactions | Все ресурсные изменения через Transaction |
| ✅ Data separation | Definitions/Runtime разделены |
| ✅ Content validation | ContentProvider валидирует ссылки |
| ✅ Contract tests | Все engine-invariants покрыты |
| ✅ Regression green | Regression harness проходит |

---

## AUDIT v1.1 — Transitional Issues

> **Статус:** Документированы для будущей работы. Не блокируют текущий релиз.

### Исправлено в v1.1

| Issue | Описание | Статус |
|-------|----------|--------|
| #5 | Seed задаётся после WorldState() в тестах | ✅ Fixed |
| #7 | tearDown с resetToSystem() во всех тестах с seed | ✅ Already done |

### Transitional (приемлемо на данном этапе)

| Issue | Описание | Что делать | Приоритет |
|-------|----------|------------|-----------|
| #1 | **Legacy WorldState Object**: UI (WorldMapView) привязан к WorldState | Перевести UI на GameRuntimeState, удалить WorldStateEngineAdapter | Phase 4 |
| #2 | **Hardcoded Strings in UI**: RegionCardView использует computed properties вместо локализованных строк из ContentProvider | Добавить локализацию через ContentProvider | Phase 5 |
| #3 | **Тесты "на двух стульях"**: WorldStateTests тестируют deprecated методы | Убедиться что CI прогоняет integration tests | Phase 4 |
| #4 | **Phase 3 не завершён полностью**: UI может менять state не только через Engine | Полная миграция UI на Engine actions | Phase 4 |
| #6 | **Дублирование day-start логики**: WorldState.performDayStartLogic() и Engine имеют parallel implementation | Единый источник формулы (RuleSet/Config) | Phase 4 |
| #8 | **Legacy Adapters Overhead**: Синхронизация через адаптеры | Перевести UI на прямое чтение из Engine | Phase 4 |
| #9 | **Дублирование моделей**: Region (Legacy) и RegionDefinition + RegionRuntimeState (Engine) | Удалить legacy модели после миграции | Phase 5 |

### CI Configuration

> **Текущий статус:** CI не настроен.

**TODO для Phase 4:**
- [ ] Настроить GitHub Actions для iOS
- [ ] CI должен прогонять `CardSampleGameTests` (включая integration tests)
- [ ] Добавить badge в README

### Архитектурные принципы v1.1

1. **Seed Order**: `WorldRNG.shared.setSeed(seed)` ВСЕГДА вызывается ДО `WorldState()`
2. **Test Isolation**: Каждый тест-класс с seed имеет `tearDown { WorldRNG.shared.resetToSystem() }`
3. **Transitional API**: `advanceDayForUI()` существует пока Views не мигрированы на Engine

---

## Связанные документы

- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) — архитектура движка
- [EVENT_MODULE_ARCHITECTURE.md](./EVENT_MODULE_ARCHITECTURE.md) — Event Module
- [INDEX.md](./INDEX.md) — governance и карта документации

---

**Последнее обновление:** 19 января 2026 (Audit v1.1)
