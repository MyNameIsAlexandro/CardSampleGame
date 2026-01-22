# Руководство по Content Pack

> **Версия:** 2.0
> **Обновлено:** Январь 2026

Руководство по созданию контент-паков для игры "Сумрачные Пределы".

---

## Содержание

1. [Обзор](#обзор)
2. [Структура пака](#структура-пака)
3. [Персонажи (heroes.json)](#персонажи)
4. [Карты (cards.json)](#карты)
5. [Регионы и события](#регионы-и-события)
6. [Локализация](#локализация)
7. [Загрузка контента](#загрузка-контента)
8. [Валидация](#валидация)

---

## Обзор

### Что такое Content Pack?

Content Pack — это набор JSON-файлов с игровым контентом:
- **Персонажи** — герои со статами, способностями и стартовыми колодами
- **Карты** — карты для колод и магазина
- **Регионы** — локации на карте мира
- **События** — случайные и сюжетные события
- **Квесты** — цели и задания
- **Якоря** — точки силы в регионах

### Принципы

1. **Data-Driven** — весь контент в JSON, без изменения кода
2. **Локализация** — поддержка нескольких языков
3. **Валидация** — автоматическая проверка ссылок и данных
4. **Модульность** — можно подключать/отключать паки

---

## Структура пака

### Текущая структура проекта

```
Resources/Content/           # Основной контент (загружается в бандл)
├── heroes.json             # Персонажи
├── regions.json            # Регионы
├── anchors.json            # Якоря
├── quests.json             # Квесты
├── challenges.json         # Испытания
└── events/                 # Пулы событий
    ├── pool_common.json
    ├── pool_village.json
    ├── pool_forest.json
    └── ...

ContentPacks/TwilightMarches/   # Дополнительный пак
├── manifest.json              # Метаданные пака
├── Investigators/
│   └── heroes.json            # Доп. персонажи
├── Cards/
│   └── cards.json             # Карты
├── Balance/
│   └── balance.json           # Настройки баланса
└── Localization/
    ├── en.json
    └── ru.json
```

---

## Персонажи

Персонажи загружаются из `heroes.json` через `HeroRegistry`.

### Формат heroes.json

```json
[
  {
    "id": "warrior_ragnar",
    "name": "Ragnar",
    "name_ru": "Рагнар",
    "hero_class": "warrior",
    "description": "Former commander of the royal guard.",
    "description_ru": "Бывший командир королевской гвардии. Его ярость в бою легендарна.",
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

### Поля персонажа

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | Уникальный идентификатор |
| `name` | string | Имя на английском |
| `name_ru` | string | Имя на русском |
| `description` | string | Описание на английском |
| `description_ru` | string | Описание на русском |
| `icon` | string | SF Symbol для иконки |
| `base_stats` | object | Базовые характеристики |
| `ability_id` | string | ID способности из `HeroAbility` |
| `starting_deck_card_ids` | [string] | ID карт стартовой колоды |
| `availability` | string | Доступность: `always_available`, `dlc:pack_id`, `requires_unlock:condition` |

### Характеристики (base_stats)

| Поле | Описание |
|------|----------|
| `health` | Текущее здоровье |
| `max_health` | Максимальное здоровье |
| `strength` | Сила (урон в бою) |
| `dexterity` | Ловкость |
| `constitution` | Телосложение (защита) |
| `intelligence` | Интеллект |
| `wisdom` | Мудрость |
| `charisma` | Харизма |
| `faith` | Текущая вера |
| `max_faith` | Максимальная вера |
| `starting_balance` | Начальный баланс Свет/Тьма (0-100) |

### Способности

Способности определены в `HeroAbility.swift`. Доступные ID:

| ability_id | Название | Эффект |
|------------|----------|--------|
| `warrior_rage` | Ярость | +2 урон при HP < 50% |
| `mage_meditation` | Медитация | +1 вера в конце хода |
| `ranger_tracking` | Выслеживание | +1 кубик при первой атаке |
| `priest_blessing` | Благословение | -1 урон от тёмных источников |
| `shadow_ambush` | Засада | +3 урона по целям с полным HP |

### Добавление нового персонажа

1. Добавить запись в `heroes.json`
2. Если нужна новая способность — добавить в `HeroAbility.forAbilityId()`
3. Убедиться что карты из `starting_deck_card_ids` существуют в `CardRegistry`

---

## Карты

### Формат cards.json

```json
[
  {
    "id": "strike_basic",
    "name": "Strike",
    "name_ru": "Удар",
    "card_type": "attack",
    "rarity": "common",
    "description": "Deal 3 damage to enemy",
    "description_ru": "Нанести 3 урона врагу",
    "icon": "bolt.fill",
    "expansion_set": "baseSet",
    "ownership": "universal",
    "abilities": [
      {
        "type": "damage",
        "value": 3
      }
    ],
    "faith_cost": 0,
    "balance": "neutral",
    "power": 3
  }
]
```

### Типы карт (card_type)

- `attack` — атакующие карты
- `defense` — защитные карты
- `resource` — ресурсные карты
- `special` — особые карты
- `curse` — проклятия

### Редкость (rarity)

- `common` — обычная
- `uncommon` — необычная
- `rare` — редкая
- `legendary` — легендарная

### Владение (ownership)

- `universal` — доступна всем
- `starter` — только в стартовых колодах
- `market` — только в магазине

---

## Регионы и события

### regions.json

```json
{
  "regions": [
    {
      "id": "village",
      "title_key": "region_village",
      "description_key": "region_village_desc",
      "neighbor_ids": ["forest", "road"],
      "initial_state": "stable",
      "initially_discovered": true,
      "anchor_id": "village_chapel",
      "event_pool_ids": ["pool_village", "pool_common"]
    }
  ]
}
```

### events/pool_*.json

```json
{
  "events": [
    {
      "id": "village_merchant",
      "title_key": "event_merchant_title",
      "description_key": "event_merchant_desc",
      "weight": 10,
      "is_one_time": false,
      "availability": {
        "min_pressure": 0,
        "max_pressure": 50
      },
      "choices": [
        {
          "id": "buy",
          "label_key": "choice_buy",
          "consequences": {
            "faith_cost": 3,
            "draw_cards": 1
          }
        },
        {
          "id": "leave",
          "label_key": "choice_leave",
          "consequences": {}
        }
      ]
    }
  ]
}
```

---

## Локализация

### Встроенная локализация (в JSON)

```json
{
  "name": "Ragnar",
  "name_ru": "Рагнар",
  "description": "English description",
  "description_ru": "Описание на русском"
}
```

### Файлы локализации

`Localization/ru.json`:
```json
{
  "region_village": "Деревня",
  "region_village_desc": "Небольшая деревня на границе",
  "event_merchant_title": "Торговец",
  "choice_buy": "Купить"
}
```

### Получение локализованного текста

```swift
// Автоматически выбирается язык системы
let hero = HeroRegistry.shared.hero(id: "warrior_ragnar")
print(hero.name)        // "Рагнар" (если система на русском)
print(hero.description) // "Бывший командир..."
```

---

## Загрузка контента

### HeroRegistry

```swift
// Герои загружаются автоматически из heroes.json при старте приложения

// Получить героя по ID
let hero = HeroRegistry.shared.hero(id: "warrior_ragnar")

// Все герои
let allHeroes = HeroRegistry.shared.allHeroes

// Доступные герои (с учётом DLC/разблокировок)
let available = HeroRegistry.shared.availableHeroes()
```

### CardRegistry

```swift
// Получить стартовую колоду для героя
let deck = CardRegistry.shared.startingDeck(forHeroID: "warrior_ragnar")

// Получить карту по ID
let card = CardRegistry.shared.card(id: "strike_basic")
```

### Создание игрока

```swift
// Player автоматически загружает статы из HeroRegistry
let player = Player(name: hero.name, maxHandSize: 5, heroId: "warrior_ragnar")
player.deck = CardRegistry.shared.startingDeck(forHeroID: "warrior_ragnar")
```

---

## Валидация

### PackValidator

```swift
let validator = PackValidator(packURL: packURL)
let summary = validator.validate()

if !summary.isValid {
    for error in summary.errors {
        print("Ошибка: \(error)")
    }
}
```

### Типичные ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| Unknown ability_id | Способность не найдена | Добавить в `HeroAbility.forAbilityId()` |
| Card not found | Карта из стартовой колоды не существует | Проверить ID карты |
| Missing region | Сосед региона не найден | Проверить `neighbor_ids` |

---

## Пример: Добавление нового персонажа

### 1. Добавить в heroes.json

```json
{
  "id": "necromancer_dark",
  "name": "Mortis",
  "name_ru": "Мортис",
  "hero_class": "shadow",
  "description": "Master of the undead",
  "description_ru": "Повелитель нежити",
  "icon": "moon.stars.fill",
  "base_stats": {
    "health": 8,
    "max_health": 8,
    "strength": 3,
    "dexterity": 2,
    "constitution": 2,
    "intelligence": 6,
    "wisdom": 4,
    "charisma": 1,
    "faith": 4,
    "max_faith": 12,
    "starting_balance": 20
  },
  "ability_id": "shadow_ambush",
  "starting_deck_card_ids": ["dark_bolt", "dark_bolt", "soul_drain", "raise_dead"],
  "availability": "always_available"
}
```

### 2. Проверить что карты существуют

Убедиться что `dark_bolt`, `soul_drain`, `raise_dead` есть в CardRegistry.

### 3. Пересобрать приложение

Персонаж появится в списке выбора автоматически.

---

## Связанные документы

- [HEROES_MODULE.md](../Engine/Heroes/HEROES_MODULE.md) — Модуль героев
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) — Архитектура движка
- [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) — Техническая документация
