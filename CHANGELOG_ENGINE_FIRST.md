# CHANGELOG: Engine-First Architecture (Post-Audit v1.2)

> **Последний аудит:** `b2bd5d9 AUDIT: Mark all 8 issues as CLOSED`
> **Текущая версия:** v1.2 (20 января 2026)

---

## CHANGELOG v1.2 (20 января 2026)

### Новые фичи

#### Card Economy v2.0
Полная переработка экономики карт в боевой системе:
- **Ресурсные карты (5 шт):** стоят 0, дают +1 Веру при игре
- **Карты атаки (2-3 шт):** стоят 1 Веру
- **Карты защиты (1-2 шт):** стоят 1 Веру
- **Особые карты (1 шт):** стоят 2 Веры
- Все 4 стартовые колоды обновлены (Велеслава, Ратибор, Мирослав, Забава)
- Исключение: карта "Жертвоприношение" Мирослава бесплатна (стоит HP)

**Файлы:** `TwilightMarchesCards.swift`

#### Combat UI v2.0
Переработка экрана результата боя:
- Убран авто-dismiss после 1.5с
- Полноэкранный victory/defeat экран
- Статистика боя (ходы, урон нанесён/получен, карты сыграны)
- Кнопка "Продолжить" — игрок сам решает когда закрыть
- Градиентный фон (зелёный для победы, красный для поражения)

**Файлы:** `CombatView.swift`

#### Content Pack System (Phase 5)
Полная система модульных контент-паков:
- `PackManifest` — метаданные и версионирование
- `PackLoader` — загрузка из JSON
- `PackValidator` — валидация кросс-ссылок
- `ContentRegistry` — центральный реестр контента
- TwilightMarches content pack с полным Act I

**Файлы:** `Engine/ContentPacks/`, `ContentPacks/TwilightMarches/`

### Исправления багов

#### Performance & Stability
- **Async loading:** Контент-паки загружаются на фоновом потоке
- **Loading screen:** Экран загрузки с прогресс-баром
- **SemanticVersion:** Исправлен декодер для строкового формата "1.0.0"
- **Date decoder:** Поддержка форматов "2026-01-01" и ISO8601
- **SF Symbols:** Заменён несуществующий `sword.fill` на `bolt.fill`
- **ForEach:** Исправлены дублирующиеся ID в combat log

**Файлы:** `CardGameApp.swift`, `PackTypes.swift`, `PackManifest.swift`, `CombatView.swift`

#### Navigation
- **Routing hints:** Подсказки "через какой регион идти" для дальних локаций
- **Travel validation:** Кнопка "Отправиться" отключена для недоступных регионов
- **Race condition:** Исправлен баг с исчезающими регионами при быстром клике

**Файлы:** `TwilightGameEngine.swift`, `WorldMapView.swift`

#### Combat System
- **Combat initiation:** `setupCombatEnemy` перенесён из view builder в `initiateCombat`
- **Publishing crash:** Исправлен "Publishing changes from within view updates"
- **Button taps:** Исправлено распознавание нажатий на кнопки в EventView

**Файлы:** `CombatView.swift`, `EventView.swift`, `GameBoardView.swift`

### Новые тесты

| Тест | Файл | Описание |
|------|------|----------|
| Card Economy (8 тестов) | CardModuleTests.swift | Проверка стоимости карт по типам |
| Navigation (4 теста) | GameplayFlowTests.swift | isNeighbor, canTravelTo, routingHints |
| Performance (5 тестов) | GameplayFlowTests.swift | Engine init, region access, travel |
| UI Stability (3 теста) | GameplayFlowTests.swift | Duplicate cards, SF Symbols |

### Документация

- **GAME_DESIGN_DOCUMENT.md:** Обновлён до v2.5, добавлены секции 9.4 и 9.7
- **MIGRATION_PLAN.md:** Добавлен Phase 6 (Card Economy + Combat UI)
- **CONTENT_PACK_GUIDE.md:** Руководство по созданию контент-паков

---

## Статистика изменений (после аудита b2bd5d9)

| Метрика | Значение |
|---------|----------|
| Коммитов | 18 |
| Файлов изменено | 15 |
| Новых тестов | 20+ |
| Новых фич | 3 (Card Economy, Combat UI, Content Packs) |
| Исправленных багов | 10+ |

---

## CHANGELOG v1.1 (Предыдущий аудит)

> Изменения с момента коммита `133fd33 Resolve Audit v1.1: All 9 issues addressed`

## Обзор изменений

**Цель:** Полный переход на Engine-First архитектуру вместо временных решений (костылей).

**Принцип:** UI читает состояние ТОЛЬКО из `TwilightGameEngine`, пишет ТОЛЬКО через `engine.performAction()`.

---

## Решённые проблемы из Audit v1.1

| # | Проблема | Статус | Решение |
|---|----------|--------|---------|
| 1 | Legacy WorldState Object - UI привязан к WorldState | ✅ Решено | Engine-First Views читают из `engine.*` |
| 2 | Hardcoded Strings in UI | ✅ Решено | Все Views мигрированы на L10n (~300+ ключей) |
| 3 | Тесты "на двух стульях" | ✅ Решено | CI с RegressionPlaythroughTests |
| 4 | Phase 3 - единственная точка изменения state | ✅ Решено | Все действия через `performAction()` |
| 5 | Seed задаётся после WorldState() | ✅ Решено | Исправлено ранее |
| 6 | Дублирование day-start логики | ✅ Решено | `TwilightPressureRules` - single source |
| 7 | Singleton RNG без reset | ✅ Решено | `resetToSystem()` в tearDown |
| 8 | Legacy Adapters Overhead | ✅ Решено | Engine-First Views + adapter cleanup |

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

## Исправления после Engine-First (Post Phase 3.5)

### c8fb53f - Fix determinism: sort regions by name

**Проблема:** `testDeterministicReproducibility` падал с `XCTAssertEqual failed: ("4") is not equal to ("6")`

**Причина:** `Array(regionMap.values)` возвращает регионы в недетерминированном порядке (Dictionary не гарантирует порядок итерации).

**Решение:**
```swift
// Было:
return Array(regionMap.values)

// Стало:
return Array(regionMap.values).sorted { $0.name < $1.name }
```

### b762f56 - Remove misleading @available deprecated

**Проблема:** 37 warnings в тестах о deprecated методах `advanceTime(by:)` и `processDayStart()`.

**Причина:** Методы помечены как deprecated, но в документации указано "retained for tests and internal use only".

**Решение:** Удалены `@available(*, deprecated)` аннотации. Doc comments уже объясняют правильное использование.

---

## Тесты

- **Все тесты проходят** (562 тестов)
- **Сборка успешна** (0 warnings в production коде)
- Phase3ContractTests обновлены для новых actions
- JSONContentProviderTests добавлены (20+ тестов)

---

## ✅ Что завершено (Phase 4 & 5)

| Задача | Статус |
|--------|--------|
| ContentView Engine-First | ✅ Done |
| Adapter cleanup | ✅ Done (unused removed) |
| Content from JSON | ✅ Done (JSONContentProvider) |
| Localization (L10n) | ✅ Done (все Views) |
| JSONContentProvider tests | ✅ Done (20+ тестов) |

---

## Что осталось (Future)

| Задача | Приоритет |
|--------|-----------|
| Card system full migration | Low |
| RNG state persistence | Low |
| Trade/Market UI | Low |
| Remove WorldState/Player adapters | После EngineSave |

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
