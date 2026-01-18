# ENGINE v1.0 MIGRATION PLAN

> **Source of Truth:** Этот документ определяет план миграции к Engine v1.0.
> Статус задач обновляется по мере выполнения.

---

## Текущий статус

| Phase | Название | Статус |
|-------|----------|--------|
| Phase 1 | Core Protocols & Engine Foundation | ✅ Done |
| Phase 2 | Data Separation (Definitions + Runtime) | ✅ Done |
| Phase 3 | GameLoop Integration | 🔄 Next |
| Phase 4 | Economy Transactions Everywhere | ⬜ Planned |
| Phase 5 | Content Migration to JSON | ⬜ Planned |

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
| `JSONContentProvider` (заглушка) | JSONContentProvider.swift | ✅ Done |
| Content Validator | ContentProvider.swift (ContentValidator) | ✅ Done |

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

### Feature B1 — GameAction и единая точка входа

| Task | Файл | Статус |
|------|------|--------|
| `GameAction` enum (все действия) | GameAction.swift | ⬜ |
| `GameEngine.performAction(action)` по 11-step loop | GameEngine.swift | ⬜ |
| `ActionResult` с diff и ошибками | ActionResult.swift | ⬜ |

**Контракт GameAction:**
```swift
enum GameAction: TimedAction {
    case travel(to: String)
    case rest
    case strengthenAnchor
    case explore
    case choose(eventId: String, choiceId: String)
    case resolveMiniGame(result: MiniGameResult)

    var timeCost: Int { ... }
}

struct ActionResult {
    let success: Bool
    let error: ActionError?
    let stateChanges: [StateChange]
    let triggeredEvents: [String]
}
```

### Feature B2 — Legacy isolation

| Task | Файл | Статус |
|------|------|--------|
| `WorldState` → thin adapter/compat layer | WorldState.swift | ⬜ |
| Закрыть public `daysPassed += 1` | WorldState.swift | ⬜ |
| Пометить `processDayStart()` deprecated | WorldState.swift | ⬜ |
| Time advance через `TimeEngine.advance(cost:)` | GameEngine.swift | ⬜ |

### Feature B3 — Event Module подключение

| Task | Файл | Статус |
|------|------|--------|
| `EventPipeline` (selection + resolution) | EventPipeline.swift | ⬜ |
| Selection: filter → weight → seed | EventSelector.swift | ⬜ |
| Resolution: requirements → transaction → flags → diff | EventResolver.swift | ⬜ |
| `MiniGameDispatcher` | MiniGameDispatcher.swift | ⬜ |
| `CombatModule` интеграция | Engine/Modules/CombatModule.swift | ⬜ |

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

---

## TEST INFRASTRUCTURE

### Engine Contract Tests

> **Папка:** `CardSampleGameTests/Engine/`

| Test File | Что проверяет | Статус |
|-----------|---------------|--------|
| `EngineContractsTests.swift` | Core engine invariants | ⬜ |
| `EventModuleContractsTests.swift` | Event module contracts | ⬜ |
| `DataSeparationTests.swift` | Definition/Runtime separation | ⬜ |

**EngineContractsTests:**
```swift
func testUIDoesNotMutateStateDirectly()
func testPerformActionAdvancesTimeOnlyViaTimeEngine()
func testWorldTickTriggeredByTimeThresholds()
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
```

### Regression Harness

> **Цель:** "до/после миграции поведение одинаковое"

| Test File | Что проверяет | Статус |
|-----------|---------------|--------|
| `RegressionPlaythroughTests.swift` | Deterministic playthrough | ⬜ |

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

## Связанные документы

- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) — архитектура движка
- [EVENT_MODULE_ARCHITECTURE.md](./EVENT_MODULE_ARCHITECTURE.md) — Event Module
- [INDEX.md](./INDEX.md) — governance и карта документации

---

**Последнее обновление:** 18 января 2026
