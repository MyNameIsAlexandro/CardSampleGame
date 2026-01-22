# Heroes Module

Модуль героев для игры "Сумрачные Пределы" (Twilight Marches).

## Структура модуля

```
Engine/Heroes/
├── HeroDefinition.swift # Протоколы и структуры определения героев
├── HeroAbility.swift    # Система способностей
├── HeroRegistry.swift   # Реестр и загрузка героев из JSON
└── HEROES_MODULE.md     # Документация (этот файл)
```

## Архитектура

### Data-Driven подход

Герои загружаются из Content Pack (JSON файл `heroes.json`), без хардкода в Swift коде.

```
┌─────────────────────────────────────────────────────────────┐
│                       ENGINE LEVEL                           │
├─────────────────────────────────────────────────────────────┤
│  HeroDefinition      - Протокол определения героя            │
│  StandardHeroDefinition - Стандартная реализация            │
│  HeroRegistry        - Runtime реестр героев                │
│  HeroAbility         - Способности героев                   │
└─────────────────────────────────────────────────────────────┘
                              ↑
                         загрузка
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    CONTENT PACK LEVEL                        │
├─────────────────────────────────────────────────────────────┤
│  heroes.json         - Определения героев (статы, способности)│
└─────────────────────────────────────────────────────────────┘
```

### Принципы

- **Data-Driven**: Герои определяются в JSON, не в коде
- **Extensible**: Легко добавлять новых героев через JSON
- **Localized**: Поддержка локализации (name_ru, description_ru)
- **Testable**: Полное покрытие тестами

## Герои (из heroes.json)

| ID | Имя | HP | Сила | Вера | Способность |
|----|-----|-----|------|------|-------------|
| warrior_ragnar | Рагнар | 12 | 7 | 2 | Ярость: +2 урон при HP < 50% |
| mage_elvira | Эльвира | 7 | 2 | 5 | Медитация: +1 вера в конце хода |
| ranger_thorin | Торин | 10 | 4 | 3 | Выслеживание: +1 кубик первая атака |
| priest_aurelius | Аврелий | 9 | 3 | 5 | Благословение: -1 урон от тьмы |
| shadow_umbra | Умбра | 8 | 4 | 4 | Засада: +3 урон по полным HP |

## API

### Получение героя

```swift
// По ID
let hero = HeroRegistry.shared.hero(id: "warrior_ragnar")

// Все герои
let allHeroes = HeroRegistry.shared.allHeroes

// Первый доступный герой
let firstHero = HeroRegistry.shared.firstHero

// Доступные герои (с учётом разблокировок)
let available = HeroRegistry.shared.availableHeroes(
    unlockedConditions: ["beat_tutorial"],
    ownedDLCs: ["dark_expansion"]
)
```

### Создание игрока с героем

```swift
// Player автоматически загружает статы из HeroRegistry
let player = Player(name: hero.name, maxHandSize: 5, heroId: "warrior_ragnar")

// Стартовая колода из CardRegistry
player.deck = CardRegistry.shared.startingDeck(forHeroID: "warrior_ragnar")
```

### Формат heroes.json

```json
[
  {
    "id": "warrior_ragnar",
    "name": "Ragnar",
    "name_ru": "Рагнар",
    "hero_class": "warrior",
    "description": "Former commander of the royal guard.",
    "description_ru": "Бывший командир королевской гвардии.",
    "icon": "figure.fencing",
    "base_stats": {
      "health": 12,
      "max_health": 12,
      "strength": 7,
      "dexterity": 3,
      "constitution": 5,
      "intelligence": 1,
      "wisdom": 2,
      "charisma": 2,
      "faith": 2,
      "max_faith": 8,
      "starting_balance": 50
    },
    "ability_id": "warrior_rage",
    "starting_deck_card_ids": ["strike_basic", "strike_basic", "defend_basic", "rage_strike"],
    "availability": "always_available"
  }
]
```

## Система способностей

### Типы способностей

- **passive** - Автоматически активна
- **active** - Требует ручной активации
- **reactive** - Срабатывает на события
- **ultimate** - Мощная с долгим кулдауном

### Триггеры

- `always` - Всегда активна
- `turnStart` / `turnEnd` - Начало/конец хода
- `onAttack` / `onDamageDealt` - При атаке
- `onDamageReceived` - При получении урона
- `onCombatStart` / `onCombatEnd` - Вход/выход из боя
- `manual` - Ручная активация

### Эффекты

- `bonusDamage` / `damageReduction` - Модификаторы урона
- `bonusDice` / `rerollDice` - Кубики
- `heal` / `gainFaith` / `loseFaith` - Ресурсы
- `drawCard` / `discardCard` - Карты

## Доступность героев

```swift
enum HeroAvailability {
    case alwaysAvailable              // Всегда доступен
    case requiresUnlock(condition)    // Требует разблокировки
    case dlc(packID)                  // Требует DLC
}
```

## Добавление нового героя

1. Добавить запись в `heroes.json`
2. Добавить способность в `HeroAbility.forAbilityId()` (если новая)
3. Добавить стартовую колоду в `CardRegistry` (если нужна особая)

Пример добавления героя:
```json
{
  "id": "necromancer_dark",
  "name": "Necromancer",
  "name_ru": "Некромант",
  "hero_class": "shadow",
  "description": "Master of dark arts",
  "description_ru": "Мастер тёмных искусств",
  "icon": "moon.stars.fill",
  "base_stats": { ... },
  "ability_id": "necromancer_drain",
  "starting_deck_card_ids": ["dark_bolt", "soul_drain"],
  "availability": "dlc:dark_expansion"
}
```

## Тестирование

Тесты находятся в:
- `CardSampleGameTests/Unit/HeroClassTests.swift` - Базовые тесты героев
- `CardSampleGameTests/Unit/HeroRegistryTests.swift` - Тесты реестра

## Зависимости

- `Foundation` - Базовые типы
- `Models/Player.swift` - Интеграция с игроком
- `Engine/Cards/CardRegistry.swift` - Стартовые колоды

## История изменений

- **v1.0** - Начальная реализация с HeroClass enum
- **v1.1** - Добавлена система способностей HeroAbility
- **v1.2** - Добавлен HeroRegistry с поддержкой JSON/DLC
- **v2.0** - Data-driven система: удалён HeroClass enum, герои загружаются из heroes.json
