# CHANGELOG: Engine-First Architecture (Post-Audit v1.1)

> Изменения с момента коммита `133fd33 Resolve Audit v1.1: All 9 issues addressed`

---

## Обзор изменений

**Цель:** Полный переход на Engine-First архитектуру вместо временных решений (костылей).

**Принцип:** UI читает состояние ТОЛЬКО из `TwilightGameEngine`, пишет ТОЛЬКО через `engine.performAction()`.

---

## Решённые проблемы из Audit v1.1

| # | Проблема | Статус | Решение |
|---|----------|--------|---------|
| 1 | Legacy WorldState Object - UI привязан к WorldState | ✅ Решено | Engine-First Views читают из `engine.*` |
| 2 | Hardcoded Strings in UI | ⏳ Phase 5 | Планируется с локализацией |
| 3 | Тесты "на двух стульях" | ✅ Частично | Phase3ContractTests через Engine |
| 4 | Phase 3 - единственная точка изменения state | ✅ Решено | Все действия через `performAction()` |
| 5 | Seed задаётся после WorldState() | ✅ Решено | Исправлено ранее |
| 6 | Дублирование day-start логики | ✅ Решено | `TwilightPressureRules` - single source |
| 7 | Singleton RNG без reset | ✅ Решено | `resetToSystem()` в tearDown |
| 8 | Legacy Adapters Overhead | ✅ Решено | Engine-First Views |

---

## Новые файлы

### Engine/Core/EngineSave.swift
Структура для сериализации состояния игры:
- `EngineSave` - полное состояние для save/load
- `RegionSaveState`, `AnchorSaveState`, `EventLogEntrySave` - вспомогательные
- Extension: `engine.createSave()`, `engine.loadFromSave()`

---

## Изменённые файлы

### Engine/Core/TwilightGameEngine.swift

**Добавлены Published Properties:**
```swift
@Published var playerHealth, playerFaith, playerBalance: Int
@Published var playerName: String
@Published var publishedRegions: [UUID: EngineRegionState]
@Published var currentEvent: GameEvent?
@Published var lastDayEvent: DayEvent?
@Published var publishedActiveQuests: [Quest]
@Published var publishedEventLog: [EventLogEntry]
@Published var lightDarkBalance, mainQuestStage: Int
```

**Добавлены UI Convenience Methods:**
- `canAffordFaith(_ cost: Int) -> Bool`
- `canRestInCurrentRegion() -> Bool`
- `canTradeInCurrentRegion() -> Bool`
- `playerBalanceDescription: String`
- `worldBalanceDescription: String`

**Добавлены Save/Load Methods:**
- `createSave(gameDuration:) -> EngineSave`
- `loadFromSave(_ save: EngineSave)`
- Getters/setters для internal state

**Добавлен Engine-First Init:**
- `initializeNewGame(playerName:)` - создаёт игру без legacy WorldState

### Engine/Core/TwilightGameAction.swift

**Новые Actions:**
```swift
case dismissCurrentEvent  // Закрыть текущее событие
case dismissDayEvent      // Закрыть уведомление о дне
```

### Views/WorldMapView.swift

**WorldMapView - Engine-First Init:**
```swift
// Новый способ (Engine-First):
init(engine: TwilightGameEngine, onExit: (() -> Void)?)

// Legacy способ (для обратной совместимости):
init(worldState: WorldState, player: Player, onExit: (() -> Void)?)
```

**Новые Engine-First компоненты:**
- `EngineRegionCardView` - карточка региона из `EngineRegionState`
- `EngineRegionDetailView` - детали региона через Engine
- `EngineEventLogView` - журнал событий через Engine

**Миграция на engine.*:**
- `worldState.regions` → `engine.regionsArray`
- `worldState.worldTension` → `engine.worldTension`
- `worldState.daysPassed` → `engine.currentDay`
- `player.health` → `engine.playerHealth`
- `player.faith` → `engine.playerFaith`
- `worldState.lastDayEvent = nil` → `engine.performAction(.dismissDayEvent)`

### CardSampleGameTests/Engine/Phase3ContractTests.swift

- Добавлены cases для новых actions в `describeAction()`

### Docs/MIGRATION_PLAN.md

- Добавлен Phase 3.5: Engine-First Architecture
- Обновлена архитектурная диаграмма
- Задокументированы Published Properties

---

## Что НЕ изменено (оставлено для обратной совместимости)

1. **Legacy Adapters** (`EngineAdapters.swift`) - используются для gradual migration
2. **WorldState.swift** - используется через adapters
3. **GameViewModel.swift** - использует `connectToLegacy()`

**Примечание:** Legacy код будет удалён когда ВСЕ компоненты перейдут на Engine-First.

---

## Тесты

- **Все тесты проходят** (170+ тестов)
- **Сборка успешна**
- Phase3ContractTests обновлены для новых actions

---

## Что осталось на Phase 4+

| Задача | Phase |
|--------|-------|
| Card system migration | Phase 4 |
| RNG state persistence | Phase 4 |
| Trade/Market UI | Phase 4 |
| Content from JSON | Phase 5 |
| Localization | Phase 5 |
| Remove Legacy Adapters | После полной миграции |

---

## Архитектура после изменений

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│   EngineRegionCardView, EngineRegionDetailView, ...         │
│   @ObservedObject engine: TwilightGameEngine                │
│   Reads: engine.* (published properties)                    │
│   Writes: engine.performAction()                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    TwilightGameEngine                        │
│   Single Source of Truth                                    │
│   @Published: regions, playerHealth, currentDay, etc.       │
│   Actions: travel, rest, explore, dismissEvent, etc.        │
│   Save/Load: createSave() / loadFromSave()                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (только для persistence)
┌─────────────────────────────────────────────────────────────┐
│                      EngineSave (Codable)                   │
│   Сериализуемое состояние для save/load                     │
└─────────────────────────────────────────────────────────────┘
```
