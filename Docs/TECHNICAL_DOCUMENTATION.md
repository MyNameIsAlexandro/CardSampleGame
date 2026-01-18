# Техническая документация проекта
# Twilight Marches (Сумрачные Пределы)

**Версия:** 0.7.0
**Последнее обновление:** 18 января 2026
**Платформа:** iOS (SwiftUI)
**Статус:** Engine Architecture v1.0 ✅

---

## КАНОНИЧЕСКОЕ ОПИСАНИЕ ИГРЫ

> **Сумрачные Пределы** — это сюжетная карточная RPG-кампания в славянском тёмном фэнтези, где игрок исследует мир Яви, реагирующий на течение времени и решения игрока, удерживает вторжения Нави и влияет на баланс трёх миров, продвигаясь к устранению источника разлома.

**Каноническая декомпозиция дизайна:** См. [GAME_DESIGN_DOCUMENT.md](./GAME_DESIGN_DOCUMENT.md) (уровни 0-8)

**Каноническая версия Definition of Done:** См. [EXPLORATION_CORE_DESIGN.md, раздел 18.10](./EXPLORATION_CORE_DESIGN.md#1810-definition-of-done-core-loop)

### Канонические шкалы (ЖЁСТКО)

| Параметр | Шкала | Комментарий |
|----------|-------|-------------|
| **WorldTension** | 0-100 | 0=спокойствие, 100=Game Over |
| **Light/Dark Balance** | 0-100 | 0=Тьма, 50=Нейтрально, 100=Свет |
| **Anchor Integrity** | 0-100 | 0=разрушен, 100=полная сила |
| **Reputation** | -100 до +100 | Отношение региона к игроку |

> **ЗАПРЕЩЕНО:** Использовать отрицательные значения для Balance и Tension.

---

## 📋 Содержание

1. [Обзор проекта](#обзор-проекта)
2. [Архитектура](#архитектура)
3. [Структура проекта](#структура-проекта)
4. [Модели данных](#модели-данных)
5. [View компоненты](#view-компоненты)
6. [Системы и менеджеры](#системы-и-менеджеры)
7. [Потоки данных](#потоки-данных)
8. [Интеграционные точки](#интеграционные-точки)
9. [Сохранения](#сохранения)
10. [Будущие задачи](#будущие-задачи)

---

## Обзор проекта

**Twilight Marches** — сюжетная карточная RPG-кампания с deck-building элементами, вдохновленная славянской мифологией.

### Технологический стек

- **Язык:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Min iOS:** 16.0+
- **Архитектура:** MVVM + ObservableObject
- **Персистентность:** UserDefaults (JSON)
- **Управление состоянием:** Combine (@Published)

### Ключевые особенности

- ✅ Deck-building механика (Dominion-like)
- ✅ Система исследования мира (state-driven regions)
- ✅ События с выборами и последствиями
- ✅ Система балансов (Light/Dark)
- ✅ Автосохранение
- ✅ 3 слота сохранений
- ✅ Русская локализация

---

## Архитектура

### Общая архитектура

> **Каноническая архитектура движка:** См. [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md)
>
> Проект использует архитектуру **"Processor + Cartridge"**:
> - **Engine (Layer 1)** — переиспользуемый движок (TimeEngine, PressureEngine, EconomyManager)
> - **Config (Layer 2)** — конфигурация игры "Сумрачные Пределы" (`TwilightMarchesConfig.swift`)
> - **Runtime (Layer 3)** — состояние конкретной партии (GameState, WorldState)

```
┌─────────────────────────────────────────────┐
│           ContentView (Root)                │
│  (Navigation + State Management)            │
└──────────────┬──────────────────────────────┘
               │
      ┌────────┴─────────┐
      │                  │
      ▼                  ▼
┌──────────────┐  ┌──────────────────┐
│ Hero Select  │  │  WorldMapView    │
│   Screen     │  │  (Main Game)     │
└──────┬───────┘  └────────┬─────────┘
       │                   │
       ▼                   ├──► RegionDetailView
┌──────────────┐           │      │
│ Save Slots   │           │      └──► EventView
│   Screen     │           │             │
└──────────────┘           │             └──► GameBoardView (Combat)
                           │
                           └──► PlayerInfoBar
                                WorldInfoBar
```

### Миграция на Engine v1.0

> **Статус миграции:** В процессе (Phase 1 из 5)

| Компонент | Статус | Описание |
|-----------|--------|----------|
| Engine/Core/ | ✅ Создан | Протоколы и базовые реализации |
| Engine/Config/ | ✅ Создан | TwilightMarchesConfig.swift |
| Definitions (ContentProvider) | ⬜ Планируется | Следующая фаза (Phase 2) |
| Runtime миграция | ⬜ Планируется | Models/* пока используют старую структуру |
| GameLoop интеграция | ⬜ Планируется | Phase 3-4 |

**Текущее состояние:**
- `Engine/Core/` и `Engine/Config/` уже созданы с протоколами и конфигурацией
- Runtime всё ещё основан на старых `Models/*` (GameState, WorldState, Player)
- Definitions/ContentProvider — следующая фаза внедрения

**Подробный план миграции:** См. [ENGINE_ARCHITECTURE.md, раздел 8](./ENGINE_ARCHITECTURE.md)

### MVVM Pattern

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│     Models      │────▶│  ObservableObject │────▶│    Views    │
│  (Data Layer)   │     │   (View Models)   │     │  (UI Layer) │
└─────────────────┘     └──────────────────┘     └─────────────┘
  • Player              • GameState                 • ContentView
  • Card                • WorldState                • WorldMapView
  • Region              • SaveManager               • EventView
  • GameEvent                                       • GameBoardView
```

### Поток управления

```
User Action → View → ViewModel (@Published) → Model Update → View Update
                ↓
           Side Effects:
           • Auto-save
           • State changes
           • Event triggers
```

---

## Структура проекта

### Директории

```
CardSampleGame/
├── Docs/                    # Вся документация проекта
│   ├── ENGINE_ARCHITECTURE.md      # Архитектура движка (source of truth)
│   ├── TECHNICAL_DOCUMENTATION.md  # Техническая документация (этот файл)
│   ├── GAME_DESIGN_DOCUMENT.md     # Игровой дизайн
│   ├── EXPLORATION_CORE_DESIGN.md  # Система исследования
│   ├── QA_ACT_I_CHECKLIST.md       # QA-чеклист Акта I
│   └── CAMPAIGN_IMPLEMENTATION_REPORT.md  # Отчёт о реализации
│
├── Engine/                  # Переиспользуемый игровой движок (v1.0)
│   ├── Core/                # Ядро движка (Layer 1)
│   │   ├── EngineProtocols.swift   # Все контракты
│   │   ├── TimeEngine.swift        # Управление временем
│   │   ├── PressureEngine.swift    # Система давления/напряжения
│   │   ├── EconomyManager.swift    # Транзакции ресурсов
│   │   └── GameLoop.swift          # Главный цикл игры
│   ├── Config/              # Конфигурация игры (Layer 2)
│   │   └── TwilightMarchesConfig.swift  # "Картридж" Сумрачных Пределов
│   └── Modules/             # Опциональные подсистемы
│
├── Models/                   # Модели данных (Runtime, Layer 3)
│   ├── Card.swift           # Модель карты
│   ├── CardType.swift       # Типы карт и редкость
│   ├── Player.swift         # Модель игрока
│   ├── GameState.swift      # Состояние игры
│   ├── GameSave.swift       # Система сохранений
│   ├── ExplorationModels.swift  # Регионы, события, квесты
│   └── WorldState.swift     # Глобальное состояние мира
│
├── Views/                   # UI компоненты
│   ├── GameBoardView.swift  # Боевой экран (карточная битва)
│   ├── PlayerHandView.swift # Рука игрока
│   ├── CardView.swift       # Отображение карт
│   ├── WorldMapView.swift   # Карта мира (основной экран)
│   ├── EventView.swift      # События с выборами
│   └── RulesView.swift      # Правила игры
│
├── Data/                    # Игровые данные
│   └── TwilightMarchesCards.swift  # Все карты, герои, события
│
├── Utilities/               # Утилиты
│   └── Localization.swift   # Русская локализация
│
└── ContentView.swift        # Корневой View (меню, выбор героя)
```

---

## Модели данных

### 1. Card (Карта)

**Файл:** `Models/Card.swift`

```swift
struct Card: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: CardType          // .blessing, .creature, .curse, etc.
    let rarity: CardRarity      // .common, .uncommon, .rare, .legendary
    let description: String
    let cost: Int?              // Стоимость покупки (вера)
    let abilities: [CardAbility]
    let balance: CardBalance    // .light, .neutral, .dark
    let realm: Realm            // .yav, .nav, .prav

    // Опционально
    let health: Int?
    let power: Int?
    let defense: Int?
    let curseType: CurseType?
}
```

**Связи:**
- Используется в `Player.deck`, `Player.hand`, `Player.discard`
- Создается в `TwilightMarchesCards`

---

### 2. Player (Игрок)

**Файл:** `Models/Player.swift`

```swift
class Player: ObservableObject {
    @Published var name: String
    @Published var health: Int
    @Published var maxHealth: Int
    @Published var hand: [Card]
    @Published var deck: [Card]
    @Published var discard: [Card]
    @Published var buried: [Card]
    @Published var faith: Int           // Ресурс для покупки карт
    @Published var maxFaith: Int
    @Published var balance: Int         // 0 (dark) to 100 (light), 50 = neutral
    @Published var activeCurses: [ActiveCurse]

    func drawCards(_ count: Int)
    func playCard(_ card: Card)
    func discardHand()
    func shuffleDeck()
}
```

**Связи:**
- Управляется `GameState.currentPlayer`
- Используется в `WorldMapView`, `EventView`, `GameBoardView`

---

### 3. GameState (Состояние игры)

**Файл:** `Models/GameState.swift`

```swift
class GameState: ObservableObject {
    @Published var players: [Player]
    @Published var currentPhase: GamePhase
    @Published var turnNumber: Int
    @Published var encountersDefeated: Int
    @Published var activeEncounter: Card?
    @Published var encounterDeck: [Card]
    @Published var marketCards: [Card]
    @Published var worldState: WorldState  // Система исследования

    var currentPlayer: Player

    func startGame()
    func nextPhase()
    func purchaseCard(_ card: Card)
    func endTurn()
}
```

**Связи:**
- Главный ViewModel приложения
- Содержит `WorldState` для исследования
- Используется в `ContentView`, `GameBoardView`

---

### 4. WorldState (Мир исследования)

**Файл:** `Models/WorldState.swift`

```swift
class WorldState: ObservableObject {
    @Published var regions: [Region]
    @Published var worldTension: Int        // 0-100
    @Published var lightDarkBalance: Int    // 0-100
    @Published var mainQuestStage: Int      // 1-5
    @Published var activeQuests: [Quest]
    @Published var completedQuests: [String]
    @Published var worldFlags: [String: Bool]
    @Published var allEvents: [GameEvent]
    @Published var currentRegionId: UUID?
    @Published var daysPassed: Int

    func getAvailableEvents(for region: Region) -> [GameEvent]
    func applyConsequences(_ cons: EventConsequences, to player: Player, in regionId: UUID)
    func strengthenAnchor(in regionId: UUID, amount: Int) -> Bool
}
```

**Связи:**
- Вложен в `GameState.worldState`
- Управляет регионами, событиями, квестами
- Используется в `WorldMapView`, `EventView`

---

### 5. ExplorationModels

**Файл:** `Models/ExplorationModels.swift`

Содержит:
- `Region` - игровой регион с состоянием
- `Anchor` - якорь Яви (sacred object)
- `GameEvent` - событие с выборами
- `EventChoice` - выбор в событии
- `EventRequirements` - требования для выбора
- `EventConsequences` - последствия выбора
- `Quest` - квест (главный/побочный)

**Ключевые структуры:**

```swift
struct Region: Identifiable {
    let id: UUID
    let name: String
    let type: RegionType  // .forest, .swamp, .mountain, etc.
    var state: RegionState  // .stable, .borderland, .breach
    var anchor: Anchor?
    var availableEvents: [String]
    var activeQuests: [String]
    var reputation: Int
}

struct GameEvent: Identifiable {
    let id: UUID
    let eventType: EventType  // .combat, .ritual, .narrative, etc.
    let title: String
    let description: String
    let choices: [EventChoice]
    var oneTime: Bool
    var completed: Bool
}

struct EventConsequences {
    var faithChange: Int?
    var healthChange: Int?
    var balanceChange: Int?
    var tensionChange: Int?
    var reputationChange: Int?
    var addCards: [String]?
    var addCurse: String?
    var anchorIntegrityChange: Int?
    var message: String?
}
```

---

## View компоненты

### Иерархия View

```
ContentView (Root)
├── characterSelectionView
│   ├── CompactCardView (hero cards)
│   └── Continue / New Game buttons
├── saveSlotSelectionView
│   └── SaveSlotCard (x3)
├── loadSlotSelectionView (Continue flow)
│   └── LoadSlotCard (existing saves)
└── WorldMapView (main game screen)
    ├── playerInfoBar (health, faith, balance)
    ├── worldInfoBar (tension, balance, days)
    ├── RegionCardView (region list)
    └── RegionDetailView (sheet)
        ├── regionHeader
        ├── anchorSection
        ├── actionsSection
        └── EventView (sheet)
            ├── eventHeader
            ├── choiceButton
            └── consequencesPreview
```

---

### 1. ContentView

**Файл:** `ContentView.swift`

**Ответственность:**
- Навигация между экранами
- Управление состоянием приложения
- Выбор героя и сохранений
- Создание/загрузка игры

**Состояния:**
```swift
@State private var showingWorldMap: Bool
@State private var showingSaveSlots: Bool
@State private var showingLoadSlots: Bool
@StateObject private var gameState: GameState
@StateObject private var saveManager: SaveManager
```

**Функции:**
- `startGame(in slot: Int)` - создать новую игру
- `loadGame(from slot: Int)` - загрузить сохранение
- `handleContinueGame()` - умная загрузка (1 слот = автозагрузка)

---

### 2. WorldMapView

**Файл:** `Views/WorldMapView.swift`

**Ответственность:**
- Основной игровой экран
- Отображение карты мира (список регионов)
- Информация о игроке и мире
- Навигация к регионам

**Параметры:**
```swift
@ObservedObject var worldState: WorldState
@ObservedObject var player: Player
var onExit: (() -> Void)?
```

**Компоненты:**
- `playerInfoBar` - статы игрока (здоровье, вера, баланс)
- `worldInfoBar` - глобальные параметры (напряжение, баланс, дни)
- `RegionCardView` - карточки регионов
- `RegionDetailView` - детали региона (sheet)

---

### 3. RegionDetailView

**Файл:** `Views/WorldMapView.swift` (вложен)

**Ответственность:**
- Детальная информация о регионе
- Информация о якоре (anchor)
- Доступные действия
- Триггер событий

**Действия:**
- 🚶 Путешествовать (переход между регионами, +1-2 дня)
- 😴 Отдохнуть (+здоровье, +день)
- 🛒 Торговать (рынок карт) — *extension point, не часть Акта I*
- ⚡ Укрепить якорь (-вера, +целостность)
- 🔍 Исследовать (триггер события)

---

### 4. EventView

**Файл:** `Views/EventView.swift`

**Ответственность:**
- Отображение события
- Показ выборов с требованиями
- Предпросмотр последствий
- Применение выбранного действия

**Логика:**
- Проверка требований (`EventRequirements.canMeet()`)
- Конвертация баланса Int → CardBalance enum
- Отображение последствий (faith↑, health↓, etc.)
- Вызов `worldState.applyConsequences()`

---

### 5. GameBoardView

**Файл:** `Views/GameBoardView.swift`

**Ответственность:**
- Карточная битва (deck-building)
- Фазы боя (draw → market → play → enemy → end)
- Рука игрока, рынок карт
- Бои с монстрами

**Статус:** ✅ Интегрирован с боевыми событиями

**Интеграция:**
- EventView вызывает GameBoardView при выборе "Вступить в бой"
- Региональные модификаторы (Borderland/Breach) применяются к врагам
- Проклятия игрока влияют на боевые параметры

---

## Системы и менеджеры

### 1. SaveManager

**Файл:** `Models/GameSave.swift`

**Функции:**
```swift
class SaveManager: ObservableObject {
    func saveGame(to slot: Int, gameState: GameState)
    func loadGame(from slot: Int) -> GameSave?
    func deleteSave(from slot: Int)
    var allSaves: [GameSave]
}
```

**Хранение:** `UserDefaults` (JSON encoding)

**Структура сохранения:**
```swift
struct GameSave: Codable {
    let slotNumber: Int
    let characterName: String
    let turnNumber: Int
    let health: Int
    let maxHealth: Int
    let faith: Int
    let balance: Int
    let encountersDefeated: Int
    let timestamp: Date
}
```

**Слоты:** 3 доступных слота (1, 2, 3)

---

### 2. Localization System

**Файл:** `Utilities/Localization.swift`

**Использование:**
```swift
Text(L10n.tmGameTitle.localized)
Text(L10n.buttonStartAdventure.localized)
```

**Поддержка:** Русский язык (все тексты в игре)

---

### 3. Event System

**Компоненты:**
- `WorldState.allEvents` - все события игры
- `WorldState.getAvailableEvents(for region)` - фильтрация по региону
- `EventView` - UI для отображения
- `applyConsequences()` - применение результатов

**Типы событий:**
1. **Combat** - боевое событие
2. **Ritual** - моральный выбор (Light/Dark)
3. **Narrative** - встреча с NPC
4. **Exploration** - исследование локации
5. **World Shift** - глобальное событие

**Флоу:**
```
Player → Region → Explore → Random Event → Choice → Consequences → Apply
```

---

## Потоки данных

### 1. Создание новой игры

```
User selects hero
    → ContentView.startGame(in slot)
        → Create Player (from hero)
        → Deck = TwilightMarchesCards.createStartingDeck(hero)
        → GameState.players = [player]
        → GameState.worldState = WorldState() (auto-init)
        → SaveManager.saveGame()
        → Show WorldMapView
```

### 2. Загрузка игры

```
User clicks Continue
    → ContentView.handleContinueGame()
        → If 1 save: loadGame() directly
        → If multiple: show loadSlotSelectionView
            → User selects slot
            → loadGame(from slot)
                → Create Player from GameSave
                → Restore stats (health, faith, balance)
                → GameState.worldState = WorldState() (new world)
                → Show WorldMapView
```

### 3. Исследование региона

```
WorldMapView → User taps region
    → RegionDetailView (sheet)
        → User taps "Исследовать"
            → triggerExploration()
                → WorldState.getAvailableEvents(for region)
                → Pick random event
                → Show EventView (sheet)
                    → User selects choice
                        → handleEventChoice()
                            → WorldState.applyConsequences()
                                → Update player stats
                                → Update region state
                                → Update world tension/balance
                            → If oneTime: mark completed
                        → Dismiss EventView
```

### 4. Применение последствий

```
EventChoice selected
    → EventConsequences
        → faithChange → Player.faith += value
        → healthChange → Player.health += value
        → balanceChange → Player.balance += value
        → tensionChange → WorldState.worldTension += value
        → reputationChange → Region.reputation += value
        → anchorIntegrityChange → Anchor.integrity += value
        → addCards → Player.deck.append(cards)
        → addCurse → Player.activeCurses.append(curse)
        → setFlags → WorldState.worldFlags[key] = value
```

### 5. Автосохранение

```
WorldMapView.onExit
    → SaveManager.saveGame(to slot, gameState)
        → Create GameSave from current state
        → Encode to JSON
        → Save to UserDefaults
```

---

## Интеграционные точки

### 1. Боевая система ← События ✅

**Статус:** РЕАЛИЗОВАНО

**Реализация:**
```swift
// GameEvent.swift
struct GameEvent {
    let monsterCard: Card?  // Карта монстра для боевых событий
}

// EventView.swift
func initiateCombat(choice: EventChoice) {
    // Create GameState with monster
    let gameState = GameState(players: [player])
    gameState.activeEncounter = event.monsterCard
    showingCombat = true
}

.fullScreenCover(isPresented: $showingCombat) {
    GameBoardView(gameState: combatGameState, onExit: handleCombatEnd)
}
```

**Как работает:**
- Боевые события содержат `monsterCard` (например, Леший)
- При выборе боевого действия создается временный GameState
- Открывается GameBoardView с монстром как activeEncounter
- После победы/поражения возвращаемся к результату события
- Применяются последствия выбора

**Файлы:** `EventView.swift:280-328`, `ExplorationModels.swift:323`, `WorldState.swift:392-442`

---

### 2. Действия в регионах ✅

**Статус:** РЕАЛИЗОВАНО

**Реализованные действия:**

**a) Путешествие (Travel):**
```swift
case .travel:
    worldState.moveToRegion(region.id)  // Перемещение
    onDismiss()                         // Закрыть детали региона
```
- Перемещает игрока в выбранный регион
- Отмечает регион как посещенный
- Увеличивает `daysPassed` на 1

**b) Отдых (Rest):**
```swift
case .rest:
    player.heal(5)                // Восстановить 5 HP
    worldState.daysPassed += 1    // День проходит
```
- Доступно только в стабильных регионах типа `settlement` или `sacred`
- Восстанавливает 5 здоровья

**c) Укрепление якоря (Strengthen Anchor):**
```swift
case .strengthenAnchor:
    if player.spendFaith(10) {
        worldState.strengthenAnchor(in: region.id, amount: 20)
    }
```
- Стоит 10 веры
- Добавляет 20% целостности якорю
- Может стабилизировать регион (borderland → stable)

**d) Исследование (Explore):**
- Запускает случайное событие из доступных в регионе
- Реализовано через `triggerExploration()`

**Файлы:** `WorldMapView.swift:743-798`

---

### 3. Рынок карт ← Регионы

**Статус:** Extension point (не часть Engine v1.0 / Акта I)

**Текущее состояние:**
- Кнопка "Торговать" зарезервирована в UI
- Реализация запланирована как расширение (см. ENGINE_ARCHITECTURE.md, Extension Points)
- Карты получаются через события и награды за бои

---

### 4. Квесты

**Статус:** ✅ Реализовано (v0.6.0)

**Реализация:**
- Квесты определены в `TwilightMarchesCards.allQuests`
- Главный квест "Путь Защитника" с 5 этапами
- Отображаются в WorldMapView.questsSection
- Прогресс через флаги в WorldState
- Награды при завершении этапов

---

## Сохранения

### ✅ Полная система сохранений кампании (v0.5.0)

**Через GameSave (Campaign v2.0):**

**Базовые данные персонажа:**
- ✅ Имя персонажа
- ✅ Здоровье (текущее/макс)
- ✅ Вера (текущая/макс)
- ✅ Баланс Light/Dark (0-100 scale)
- ✅ Все статы (Strength, Dexterity, Constitution, Intelligence, Wisdom, Charisma)
- ✅ Номер хода
- ✅ Дата сохранения

**КРИТИЧНО: Deck-building состояние:**
- ✅ playerDeck - полный состав колоды
- ✅ playerHand - карты в руке
- ✅ playerDiscard - сброс
- ✅ playerBuried - захороненные карты
- ✅ activeCurses - активные проклятия с длительностью
- ✅ spirits - призванные духи
- ✅ currentRealm - текущий мир (Yav/Nav/Prav)

**КРИТИЧНО: Состояние мира (WorldState):**
- ✅ Все регионы с якорями
- ✅ Состояния регионов (Stable/Borderland/Breach)
- ✅ Целостность якорей
- ✅ Репутация в регионах
- ✅ Активные квесты
- ✅ Завершенные квесты
- ✅ Флаги мира (последствия решений)
- ✅ WorldTension
- ✅ mainQuestStage
- ✅ daysPassed
- ✅ Все события (включая completed)

**Совместимость:**
- ✅ encountersDefeated (старая система)
- ✅ isVictory / isDefeat флаги

### Методы сохранения/загрузки

**SaveManager.saveGame()**
- Сохраняет полное состояние игры в слот
- Включает всё: колоду, мир, квесты, флаги
- Сериализация через JSONEncoder

**SaveManager.restoreGameState()**
- Восстанавливает GameState из сохранения
- Полностью воссоздаёт Player с колодой
- Восстанавливает WorldState
- Устанавливает правильную фазу игры

### Гарантии кампании

✅ **Прогресс сохраняется между сессиями**
✅ **Последствия решений помнятся** (флаги мира)
✅ **Мир не сбрасывается** (регионы, якоря, репутация)
✅ **Квесты продолжаются** (активные и завершенные)
✅ **Completed события не повторяются**
✅ **Колода сохраняется** (deck-building прогресс)

---

## Система времени и деградации

> ⚠️ **Legacy API Warning:**
> `WorldState.processDayStart()` и прямая мутация `daysPassed += 1` — legacy API.
> **Канонический способ** движения времени — `GameEngine → TimeEngine.advance()`.
> См. [ENGINE_ARCHITECTURE.md, раздел 3.1](./ENGINE_ARCHITECTURE.md)

### Правила времени

**Единица времени:** 1 день = 1 действие на карте

**Что стоит время (через TimeEngine):**
- Путешествие в соседний регион: `cost: 1`
- Путешествие в дальний регион: `cost: 2`
- Отдых в поселении: `cost: 1`
- Укрепление якоря: `cost: 1`
- Исследование события: `cost: 1` (исключение: события с `instant: true` → `cost: 0`)

### Автоматическая деградация

**Триггер:** Каждые 3 дня (`daysPassed % 3 == 0`)

**Механизм (в WorldState):**
```swift
func checkTimeDegradation() {
    guard daysPassed > 0 && daysPassed % 3 == 0 else { return }

    // 1. Увеличить напряжение
    worldTension += 2

    // 2. С вероятностью (Tension/100) деградировать регион
    let probability = Double(worldTension) / 100.0
    if Double.random(in: 0...1) < probability {
        degradeRandomRegion()
    }
}

private func degradeRandomRegion() {
    // ВАЖНО: Stable регионы НЕ деградируют напрямую!
    // Деградируют только Borderland (вес 1) и Breach (вес 2)
    // Это поддерживает fantasy "граница трещит"

    var candidates: [(region: Region, weight: Int)] = []
    for region in regions {
        switch region.state {
        case .stable:
            continue  // Stable не деградируют напрямую
        case .borderland:
            candidates.append((region, 1))
        case .breach:
            candidates.append((region, 2))
        }
    }

    guard !candidates.isEmpty else { return }

    // Weighted random selection
    let totalWeight = candidates.reduce(0) { $0 + $1.weight }
    var random = Int.random(in: 1...totalWeight)
    for (region, weight) in candidates {
        random -= weight
        if random <= 0 {
            degradeRegion(region)
            break
        }
    }
}

private func degradeRegion(_ region: Region) {
    guard var anchor = region.anchor, anchor.integrity > 0 else { return }

    // Проверка сопротивления якоря (шанс = integrity * 10%)
    let resistChance = Double(anchor.integrity) / 100.0 * 0.5
    if Double.random(in: 0...1) < resistChance {
        return  // Якорь выдержал
    }

    // Снизить целостность якоря на 20%
    anchor.integrity -= 20
    region.updateStateFromAnchor()
}
```

**Вызов:**
- После каждого действия (Travel, Rest, StrengthenAnchor)
- В `WorldState.moveToRegion()` или отдельный метод `advanceTime()`

---

## Реализовано в v0.5.0 ✅

### Campaign Systems (ЗАВЕРШЕНО)

✅ **Система победы на основе квестов**
   - checkQuestVictory() - проверка завершения главного квеста
   - checkDefeatConditions() - HP=0, Tension=100%, критический якорь
   - Интеграция в игровой цикл

✅ **Полная система сохранений кампании**
   - Сохранение состава колоды (deck/hand/discard/buried)
   - Сохранение WorldState (регионы, квесты, флаги)
   - Сохранение проклятий, духов, статов
   - Метод restoreGameState() для восстановления

✅ **7 регионов Акта I**
   - 2 Stable (Деревня у тракта, Священный Дуб)
   - 3 Borderland (Дремучий Лес, Болото Нави, Горный Перевал)
   - 2 Breach (Разлом Курганов, Чёрная Низина)
   - Все с якорями и правильной целостностью

✅ **15 событий для Акта I**
   - 5 боевых (Леший, Дикий зверь, Горный дух, Курганный призрак, и др.)
   - 3 ритуальных (укрепление/осквернение якорей)
   - 5 нарративных (торговцы, странники, квесты)
   - 2 сдвига мира (прорывы Нави)
   - Покрытие всех типов регионов

✅ **Система квестов (7 квестов)**
   - Главный квест "Путь Защитника" (5 этапов)
   - 6 побочных квестов
   - Отслеживание прогресса через objectives
   - Награды (faith, cards, artifacts, experience)
   - Автоматический старт главного квеста

✅ **Система времени и деградации**
   - checkTimeDegradation() каждые 3 дня
   - Автоматическое увеличение worldTension
   - Вероятностная деградация регионов
   - advanceTime() для ручного прогресса

✅ **Шкала баланса 0-100**
   - Обновлён Player.balance (0=Dark, 50=Neutral, 100=Light)
   - Пороги 30/70 для определения пути
   - balanceState и balanceDescription
   - Совместимость с EventRequirements

## ✅ Завершено в v0.6.0 (16 января 2026)

### Все High Priority задачи завершены! 🎉

1. **✅ Интеграция боевой системы с событиями**
   - ✅ Добавлен custom initializer в GameBoardView для передачи внешнего GameState
   - ✅ EventView корректно запускает GameBoardView с монстром из события
   - ✅ Обработка победы/поражения через handleCombatEnd()
   - ✅ Применение наград и последствий после боя

2. **✅ UI обновления**
   - ✅ Шкала баланса 0-100 отображается с визуальным прогрессом-баром
   - ✅ Квесты визуализированы в WorldMapView.questsSection
   - ✅ Objectives отображаются с чекбоксами (✓ / ○)
   - ✅ Счётчик прогресса (X/Y completed)
   - ✅ Цветовое кодирование (Main = жёлтый, Side = синий)

3. **✅ Карты-награды из событий**
   - ✅ Создано 18 reward cards в TwilightMarchesCards.createRewardCards()
   - ✅ Все карты интегрированы через getCardByID() registry
   - ✅ merchant_blessing, witch_knowledge, dark_pact ✓
   - ✅ ancestral_blessing, warrior_spirit ✓
   - ✅ defender_blessing, anchor_power ✓
   - ✅ realm_power, nav_essence ✓
   - ✅ И ещё 10 дополнительных карт

### Все Medium Priority задачи завершены! 🎉

4. **✅ Расширение контента Акта I**
   - ✅ Босс Леший-Хранитель создан (HP: 25, Power: 6, Defense: 12)
   - ✅ 3 легендарные способности босса (Regeneration, Root Strike, Nature's Wrath)
   - ✅ Босс-событие с 3 путями разрешения (Fight/Negotiate/Corrupt)
   - ✅ Артефакты: guardian_seal, ancient_relic, corrupted_power созданы

5. **✅ Квестовые триггеры и прогресс**
   - ✅ Автоматическое обновление objectives через checkQuestObjectivesByFlags()
   - ✅ Триггеры при посещении регионов (checkQuestObjectivesByRegion)
   - ✅ Триггеры при завершении событий (checkQuestObjectivesByEvent)
   - ✅ Триггер при победе над боссом (markBossDefeated)
   - ✅ UI для отслеживания прогресса в WorldMapView
   - ✅ Автоматическое завершение квестов и выдача наград

6. **✅ Босс-механики и способности**
   - ✅ Леший-Хранитель с 3 уникальными способностями
   - ✅ Легендарная редкость и повышенные характеристики
   - ✅ Интеграция в систему событий и квестов

---

## Будущие задачи

### High Priority (для v0.7.0)

1. **🎮 Полировка боевой системы**
   - Активация способностей монстров в бою
   - Визуализация регенерации босса
   - Анимации специальных атак
   - Звуковые эффекты для способностей

2. **📊 Система статистики**
   - Tracking побед/поражений
   - Счётчик использования карт
   - История прохождения квестов
   - Achievement system

3. **🎨 UI/UX улучшения**
   - Индикатор времени и деградации на карте
   - Анимации переходов между регионами
   - Визуальные эффекты для событий
   - Tutorial system для новых игроков

### Medium Priority

4. **🌍 Акт II - контент**
   - 5-7 новых регионов
   - 15+ новых событий
   - Новый финальный босс
   - Продолжение главного квеста

5. **🎨 Визуальные улучшения**
   - Визуальная карта (вместо списка)
   - Иконки регионов и якорей
   - Иллюстрации для ключевых событий
   - Портреты персонажей

### Low Priority

6. **⚡ Оптимизация**
   - Кэширование событий
   - Оптимизация размера сохранений
   - Lazy loading для карт
   - Performance improvements

8. **🎵 Звук и музыка**
   - Фоновая музыка для регионов
   - Звуковые эффекты
   - Озвучка событий

9. **📊 Статистика и достижения**
   - Глобальная статистика игрока
   - Достижения (achievements)
   - Таблица лидеров (local)

---

## Соглашения о коде

### Стиль кода

- **SwiftUI views:** PascalCase (`WorldMapView`)
- **Functions:** camelCase (`handleContinueGame`)
- **Constants:** camelCase (`hasSaves`)
- **@Published properties:** camelCase
- **Enums:** PascalCase cases (`RegionState.stable`)

### Комментарии

```swift
// MARK: - Section Name (для разделов)
// TODO: Task description (для задач)
// Однострочные комментарии для пояснений
```

### Naming Conventions

- **Bool properties:** `isEnabled`, `hasSaves`, `showingMenu`
- **Collections:** plural (`regions`, `events`, `cards`)
- **Actions:** verb-based (`handleContinueGame`, `applyConsequences`)

---

## Контакты и ресурсы

**Документация:**
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - архитектура движка (source of truth)
- [GAME_DESIGN_DOCUMENT.md](./GAME_DESIGN_DOCUMENT.md) - игровой дизайн
- [EXPLORATION_CORE_DESIGN.md](./EXPLORATION_CORE_DESIGN.md) - система исследования
- [QA_ACT_I_CHECKLIST.md](./QA_ACT_I_CHECKLIST.md) - QA-чеклист Акта I
- [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) - этот файл

**Git:**
- Branch: `claude/ios-card-game-m5L5r`
- Repository: CardSampleGame

---

## История изменений

### v0.7.0 (18.01.2026) - Engine Architecture v1.0 ✅

**Основные изменения:**

**Engine/ - Переиспользуемый игровой движок**
- Создана архитектура "Processor + Cartridge" (движок + картридж)
- Строгое разделение Rules / Data / State
- ENGINE_ARCHITECTURE.md — каноническая документация (source of truth)

**Engine/Core/ - Ядро движка (Layer 1)**
- EngineProtocols.swift — все контракты (TimeEngine, PressureEngine, EconomyManager, etc.)
- TimeEngine.swift — управление временем с threshold detection
- PressureEngine.swift — система давления/напряжения
- EconomyManager.swift — атомарные транзакции ресурсов
- GameLoop.swift — канонический 11-шаговый цикл действий

**Engine/Config/ - Конфигурация игры (Layer 2)**
- TwilightMarchesConfig.swift — "картридж" Сумрачных Пределов
  - TwilightResource — ресурсы (health, faith, balance)
  - TwilightPressureRules — правила давления
  - TwilightRegionState — состояния регионов
  - TwilightCurseDefinition — определения проклятий
  - TwilightCombatConfig — настройки боя
  - TwilightAnchorConfig — настройки якорей

**Статистика:**
- 6 новых файлов движка
- ~1200 строк кода в Engine/
- Документация ENGINE_ARCHITECTURE.md (~450 строк)
- Подготовлена основа для миграции существующего кода

---

### v0.6.0 (16.01.2026) - MVP Complete! ✅

**Статус:** Все High Priority и Medium Priority задачи завершены!

**Основные изменения:**

**GameBoardView.swift - Интеграция боевой системы**
- Добавлен custom initializer для передачи внешнего GameState
- Использует паттерн `_gameState = StateObject(wrappedValue:)` для корректной работы
- EventView теперь корректно запускает combat screen с монстром

**TwilightMarchesCards.swift - Контент завершён**
- Создано 18 reward cards (полное покрытие всех событий и квестов)
- Добавлен босс Леший-Хранитель (HP: 25, Power: 6, Defense: 12, 3 способности)
- Создано 3 легендарных артефакта:
  * guardian_seal (Печать Защитника) - Light path
  * ancient_relic (Древняя Реликвия) - Neutral
  * corrupted_power (Развращённая Сила) - Dark path
- Обновлён getCardByID() registry для всех новых карт

**WorldState.swift - Система квестовых триггеров**
- Добавлено 4 функции автоматического обновления квестов:
  * checkQuestObjectivesByFlags() - проверка по флагам мира
  * checkQuestObjectivesByRegion() - триггер при посещении региона
  * checkQuestObjectivesByEvent() - триггер при завершении события
  * markBossDefeated() - триггер после победы над боссом
- Добавлено босс-событие "Леший-Хранитель" с 3 путями разрешения
- Квесты теперь автоматически завершаются при выполнении всех objectives

**GameState.swift - Интеграция квестов в бой**
- defeatEncounter() теперь вызывает markBossDefeated() для отслеживания боссов
- Полная интеграция с quest trigger system

**Views - UI для квестов и баланса**
- **WorldMapView.swift:**
  * Полностью переработан questsSection с детальным отображением квестов
  * Objectives с чекбоксами (✓ completed, ○ pending)
  * Счётчик прогресса (X/Y completed)
  * Цветовое кодирование (Main = жёлтый, Side = синий)
  * Интеграция quest triggers в handleEventChoice() и performAction()

- **GameBoardView.swift:**
  * Обновлены balanceIcon и balanceColor для шкалы 0-100

- **EventView.swift:**
  * Обновлён getBalanceEnum() для пороговых значений 70/30

- **WorldMapView.swift (balance scale):**
  * Добавлен визуальный прогресс-бар с 3 цветовыми зонами
  * Dark (0-30, фиолетовый), Neutral (30-70, серый), Light (70-100, жёлтый)

**Статистика:**
- **4 коммита:**
  1. Combat integration fix (GameBoardView initializer)
  2. Boss + 3 artifacts (Leshy-Guardian, legendary items)
  3. Quest trigger system + Progress UI (auto-tracking)
  4. Balance UI update (0-100 visual scale)

- **6 файлов изменено:**
  * GameBoardView.swift (+7)
  * TwilightMarchesCards.swift (+176)
  * WorldState.swift (+166)
  * GameState.swift (+4)
  * Views/WorldMapView.swift (+104)
  * Views/EventView.swift (+5)

- **~480 строк кода добавлено**
- **1 босс создан** (legendary с 3 способностями)
- **3 артефакта** (legendary items)
- **18 reward cards** (полное покрытие)
- **4 quest trigger функции** (auto-progression)
- **Полная UI для квестов** (objectives tracking)

**Что теперь работает:**
- ✅ События могут запускать бои с монстрами
- ✅ Квесты автоматически обновляются по действиям игрока
- ✅ Босс с легендарными способностями
- ✅ 3 моральных пути с артефактами-наградами
- ✅ Визуальный трекинг прогресса квестов
- ✅ Шкала баланса 0-100 с визуализацией
- ✅ Все reward cards интегрированы

---

### v0.5.0 (16.01.2026) - Campaign Systems Complete ✅

**Основные изменения:**

**GameState.swift - Квестовая система победы**
- Добавлен checkQuestVictory() для проверки завершения главного квеста
- Добавлен checkDefeatConditions() с тремя условиями поражения
- Интегрирован в endTurn() и defeatEncounter()
- Старая система (10 побед) помечена как DEPRECATED

**GameSave.swift - Полное сохранение кампании (КРИТИЧНО)**
- Добавлено сохранение состава колоды (playerDeck, playerHand, playerDiscard, playerBuried)
- Добавлено сохранение WorldState (регионы, квесты, флаги, все состояния)
- Добавлено сохранение проклятий, духов, realm, статов
- Создан метод restoreGameState() для полного восстановления
- Теперь поддерживается сохранение прогресса кампании с deck-building

**WorldState.swift - Контент Акта I**
- Создано 7 регионов Акта I (2 Stable, 3 Borderland, 2 Breach)
- Добавлено 9 новых событий (всего 15):
  - Торговец на тракте, Испытание Перевала, Мудрость Священного Дуба
  - Болотная Ведьма, Стражи Курганов, Просьба Старосты
  - Плач в Лесу, Привал у костра, Сдвиг Границ Миров
- Создано 7 квестов (1 главный + 6 побочных):
  - Главный: "Путь Защитника" (5 этапов)
  - Побочные: Потерянный ребенок, Торговые пути, Болотная ведьма, Курганы предков, Монах, Горный дух
- Интеграция квестов с событиями через questLinks

**Player.swift - Шкала баланса 0-100**
- Изменён диапазон balance с -10/+10 на 0-100
- Обновлён init: balance по умолчанию = 50 (нейтраль)
- Обновлён shiftBalance() для работы с новой шкалой
- Обновлены пороги balanceState: 70+ Light, 30- Dark, между - Neutral
- Добавлен balanceDescription для UI

**ExplorationModels.swift - Совместимость**
- Обновлена логика EventRequirements.canMeet() для шкалы 0-100

**Статистика:**
- 3 коммита
- 4 файла изменено (GameState, GameSave, Player, WorldState, ExplorationModels)
- ~790 строк кода добавлено
- 15 событий готовы
- 7 квестов созданы

---

### v0.3.0 (16.01.2026) - System Integration
- ✅ Интегрирована боевая система с событиями
  - Боевые события теперь открывают GameBoardView
  - Добавлен монстр Леший для тестирования
  - Victory/Defeat обрабатываются корректно
- ✅ Реализованы действия в регионах
  - Путешествие между регионами
  - Отдых (восстановление здоровья)
  - Укрепление якорей (стоит веру)
  - Исследование (запуск событий)
- ✅ Кнопка "Продолжить" на главном экране
  - Умная загрузка: 1 сейв → авто, много → выбор

### v0.2.0 (16.01.2026) - Exploration Core MVP
- ✅ Реализована система исследования мира
- ✅ WorldMapView как основной экран игры
- ✅ Система событий (5 типов, 5 начальных событий)
- ✅ Регионы с якорями (3 тестовых региона)
- ✅ Глобальные параметры (напряжение, баланс)

### v0.1.0 (13.01.2026) - Deck-Building Core
- ✅ Базовая deck-building механика
- ✅ 4 героя со стартовыми колодами (10 карт)
- ✅ Система рынка (15+ карт)
- ✅ Карточные бои
- ✅ Система сохранений (3 слота)
- ✅ Автосохранение

---

**Конец документа**
