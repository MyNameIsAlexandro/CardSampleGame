# Техническая документация проекта
# Twilight Marches (Сумрачные Пределы)

**Версия:** 0.4.0
**Последнее обновление:** 16 января 2026
**Платформа:** iOS (SwiftUI)
**Статус:** Core Systems + Campaign Support

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

**Twilight Marches** - deck-building игра с системой исследования мира, вдохновленная славянской мифологией.

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
├── Models/                   # Модели данных
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
├── ContentView.swift        # Корневой View (меню, выбор героя)
│
└── Documentation/           # Документация
    ├── GAME_DESIGN_DOCUMENT.md
    ├── EXPLORATION_CORE_DESIGN.md
    └── TECHNICAL_DOCUMENTATION.md (этот файл)
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
    @Published var balance: Int         // -100 (dark) to +100 (light)
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
- 🚶 Путешествовать (TODO)
- 😴 Отдохнуть (+здоровье, +день)
- 🛒 Торговать (рынок карт) (TODO)
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

**Статус:** Отключен в текущем флоу (будет интегрирован с боевыми событиями)

**TODO:** Открывать GameBoardView из EventView при выборе "Вступить в бой"

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

**Статус:** TODO (приоритет средний)

**План:**
- Кнопка "Торговать" существует но не реализована
- Варианты:
  - Открывать GameBoardView в режиме только рынка
  - Создать отдельный MarketView
  - Интегрировать с settlement regions

---

### 4. Квесты

**Статус:** TODO (приоритет низкий)

**План:**
- Квесты появляются через события
- Отображаются в RegionDetailView.questsSection
- Прогресс отслеживается в WorldState.activeQuests
- Награды при завершении

---

## Сохранения

### Что сохраняется (текущая версия)

**Через GameSave:**
- ✅ Имя персонажа
- ✅ Здоровье (текущее/макс)
- ✅ Вера
- ✅ Баланс Light/Dark
- ✅ Номер хода
- ✅ Побежденные враги
- ✅ Дата сохранения

**Что НЕ сохраняется (пересоздается) — ПРОБЛЕМА:**
- ❌ Колода игрока (воссоздается из startingDeck) — **КРИТИЧНО**
- ❌ Состояние мира (WorldState reinit) — **КРИТИЧНО**
- ❌ Активные квесты — **КРИТИЧНО**
- ❌ Состояние регионов — **КРИТИЧНО**
- ❌ Completed events
- ❌ World flags

### Требования для кампании

**ОБЯЗАТЕЛЬНО для кампании (из дизайн-документа):**

Игра должна сохранять:
- ✅ **Колода игрока** (deck/discard/hand/buried) — состав карт
- ✅ **WorldState** целиком:
  - Регионы (состояния, якоря, репутация)
  - Квесты (активные, завершённые)
  - Флаги мира (последствия решений)
  - WorldTension, Light/Dark Balance
  - daysPassed
- ✅ **Completed events** (oneTime события не повторяются)
- ✅ **Player state** (ресурсы, проклятия, баланс)

**Без этого кампания не работает:**
- Игрок теряет прогресс между сессиями
- Последствия решений не сохраняются
- Мир сбрасывается (нарушает дизайн-пиллар "мир помнит")

### План обновления сохранений

**Фаза 1: Расширить GameSave (КРИТИЧНО)**
```swift
struct GameSave: Codable {
    // ... существующие поля ...
    let playerDeck: [Card]           // NEW
    let playerDiscard: [Card]        // NEW
    let playerHand: [Card]           // NEW
    let playerBuried: [Card]         // NEW
    let worldStateData: WorldState   // NEW
    let daysPassed: Int              // NEW
}
```

**Фаза 2: WorldState Codable**
- Сделать WorldState Codable
- Сериализовать regions, quests, worldFlags, allEvents

**Фаза 3: Тестирование**
- Сохранение → загрузка → проверка состояния
- Прогресс квестов сохраняется
- Completed events не повторяются

---

## Система времени и деградации

### Правила времени

**Единица времени:** 1 день = 1 действие на карте

**Что стоит время:**
- Путешествие в соседний регион: `daysPassed += 1`
- Путешествие в дальний регион: `daysPassed += 2`
- Отдых в поселении: `daysPassed += 1`
- Укрепление якоря: `daysPassed += 1`
- Исследование события: `daysPassed += 0` (мгновенно)

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
    let stableRegions = regions.filter { $0.state == .stable }
    guard let randomRegion = stableRegions.randomElement() else { return }

    // Снизить целостность якоря на 20%
    if var anchor = randomRegion.anchor {
        anchor.integrity -= 20
        // Обновить состояние региона на основе якоря
        region.updateStateFromAnchor()
    }
}
```

**Вызов:**
- После каждого действия (Travel, Rest, StrengthenAnchor)
- В `WorldState.moveToRegion()` или отдельный метод `advanceTime()`

---

## Будущие задачи

### High Priority

1. **🎯 Интеграция боевой системы с событиями**
   - Триггер GameBoardView из EventView
   - Передача монстра в бой
   - Обработка победы/поражения
   - Применение наград/штрафов

2. **🗺️ Система путешествий**
   - Перемещение между регионами
   - Затраты времени и ресурсов
   - Случайные события в пути
   - Визуализация доступных маршрутов

3. **💾 Расширение системы сохранений**
   - Сохранение состояния мира
   - Сохранение колоды игрока
   - Сохранение квестов
   - Сохранение флагов

### Medium Priority

4. **🌍 Расширение карты мира**
   - Добавить 7-10 регионов
   - Разнообразие типов (горы, степи, города)
   - Уникальные якоря для каждого

5. **📜 Система квестов**
   - Главный квест (5 актов)
   - Побочные квесты (15+)
   - Отслеживание прогресса
   - Награды и последствия

6. **✨ Больше событий**
   - 30-50 уникальных событий
   - События для каждого типа региона
   - Редкие/эпические события
   - Сюжетные события

### Low Priority

7. **🎨 Визуальные улучшения**
   - Анимации переходов
   - Визуальная карта (не список)
   - Иконки регионов
   - Иллюстрации событий

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
- [GAME_DESIGN_DOCUMENT.md](./GAME_DESIGN_DOCUMENT.md) - игровой дизайн
- [EXPLORATION_CORE_DESIGN.md](./EXPLORATION_CORE_DESIGN.md) - система исследования
- [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) - этот файл

**Git:**
- Branch: `claude/ios-card-game-m5L5r`
- Repository: CardSampleGame

---

## История изменений

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
