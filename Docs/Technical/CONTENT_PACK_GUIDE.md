# Руководство по Content Pack

> **Версия:** 2.1
> **Обновлено:** Февраль 2026

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
9. [Hot-Reload для разработки](#hot-reload-для-разработки)

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
├── Characters/
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
| `starting_affinity` | Начальная склонность героя PlayerAffinity (-100..+100) |

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
    "power": 3,
    "cost": 1,
    "exhaust": false
  }
]
```

### Новые поля карт (v2.1)

| Поле | Тип | По умолчанию | Описание |
|------|-----|--------------|----------|
| `cost` | int? | `1` | Стоимость энергии за розыгрыш карты. `null` = 1 |
| `exhaust` | bool | `false` | Если `true`, карта удаляется из колоды после розыгрыша (в exhaustPile) |

**Пример карты с exhaust:**
```json
{
  "id": "poison_blade",
  "name": "Poison Blade",
  "card_type": "attack",
  "rarity": "uncommon",
  "abilities": [{"type": "damage", "value": 5}, {"type": "applyCurse", "value": 2}],
  "cost": 2,
  "exhaust": true
}
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
let contentRegistry = ContentRegistry()
try contentRegistry.loadPacks(from: packURLs)

let localizationManager = LocalizationManager()
let hero = contentRegistry.heroRegistry.hero(id: "warrior_ragnar")
print(hero?.name.resolve(using: localizationManager) ?? "")
print(hero?.description.resolve(using: localizationManager) ?? "")
```

---

## Загрузка контента

### HeroRegistry

```swift
let contentRegistry = ContentRegistry()
try contentRegistry.loadPacks(from: packURLs)

// Получить героя по ID
let hero = contentRegistry.heroRegistry.hero(id: "warrior_ragnar")

// Все герои
let allHeroes = contentRegistry.heroRegistry.allHeroes

// Доступные герои (с учётом DLC/разблокировок)
let available = contentRegistry.heroRegistry.availableHeroes()
```

### CardRegistry

```swift
let contentRegistry = ContentRegistry()
try contentRegistry.loadPacks(from: packURLs)

// Получить стартовую колоду (IDs) для героя
let hero = contentRegistry.heroRegistry.hero(id: "warrior_ragnar")
let deckCardIds = hero?.startingDeckCardIDs ?? []

// Получить карту по ID
let card = contentRegistry.getCard(id: "strike_basic")
```

### Создание игрока

```swift
let contentRegistry = ContentRegistry()
try contentRegistry.loadPacks(from: packURLs)

let heroId = "warrior_ragnar"
let hero = contentRegistry.heroRegistry.hero(id: heroId)
let startingDeckCardIds = hero?.startingDeckCardIDs ?? []
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
| Negative energy cost | `cost` < 0 у карты | Указать `cost` >= 0 или убрать поле |
| Exhaust without effect | Карта с `exhaust: true` без abilities и power | Добавить эффект или убрать exhaust |
| Enemy empty name | У врага пустое имя | Заполнить `name` |
| Enemy non-positive health | `health` <= 0 | Указать health > 0 |
| Enemy empty pattern | Массив `pattern` пустой | Добавить хотя бы один шаг или убрать pattern |

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

## Pack Format

### Текущее состояние (v2.x) ✅

**Authoring Format:** JSON
**Distribution/Runtime Format:** Binary `.pack`

Контент создаётся в JSON, компилируется в binary .pack через `pack-compiler`, загружается runtime напрямую из .pack файлов.

### Архитектура

```
Authoring Flow:
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ JSON Files  │ ──▶ │ Pack Compiler│ ──▶ │ .pack File  │
│ (editable)  │     │ (packc)      │     │ (optimized) │
└─────────────┘     └──────────────┘     └─────────────┘

Runtime Flow:
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ .pack File  │ ──▶ │ PackLoader   │ ──▶ │ Game Memory │
│ (binary)    │     │ (fast)       │     │             │
└─────────────┘     └──────────────┘     └─────────────┘
```

### Преимущества Binary Pack

| Аспект | JSON | Binary .pack |
|--------|------|--------------|
| Размер | ~100KB | ~30KB (gzip) |
| Парсинг | ~50ms | ~5ms |
| Валидация | Runtime | Compile-time |
| Защита контента | Нет | Да (обфускация) |
| Версионирование | Manual | Built-in |

### Pack Compiler CLI

```bash
cd Packages/TwilightEngine

# Компиляция пака
swift run pack-compiler compile ./path/to/MyPack ./output/MyPack.pack

# Валидация без компиляции
swift run pack-compiler validate ./path/to/MyPack

# Информация о паке
swift run pack-compiler info ./MyPack.pack
```

### Binary Pack Structure

```
.pack file format:
┌────────────────────────────────┐
│ Header (magic, version, flags) │  16 bytes
├────────────────────────────────┤
│ Manifest (compressed)          │  variable
├────────────────────────────────┤
│ Content Table (offsets)        │  variable
├────────────────────────────────┤
│ Content Blocks (compressed)    │  variable
│   - Heroes                     │
│   - Cards                      │
│   - Events                     │
│   - Regions                    │
│   - Localization               │
├────────────────────────────────┤
│ Checksum (SHA256)              │  32 bytes
└────────────────────────────────┘
```

### Roadmap

| Версия | Статус | Описание |
|--------|--------|----------|
| v1.0 | ✅ Done | JSON loading, validation |
| v1.1 | ✅ Done | Pack composition, caching |
| v1.2 | ✅ Done | Season/campaign organization |
| v2.0 | ✅ Done | Binary .pack format, Pack Compiler CLI |
| v2.1 | ✅ Done | Binary runtime loading, Hot-Reload |
| v2.2 | ✅ Done | Content Manager UI |
| v3.0 | ✅ Done | Runtime rejects raw JSON (gate test) |

### Acceptance Criteria

**v2.0 — Binary Pack Format** ✅
- [x] `pack-compiler compile` создаёт валидный .pack файл
- [x] Binary runtime loading работает (`ContentRegistry.loadPack`)
- [x] `.pack` файлы созданы для CoreHeroes и TwilightMarchesActI
- [x] Тесты `ContentRegistryTests` проверяют загрузку .pack файлов

**v2.1 — Hot-Reload** ✅
- [x] `ContentManager` с safe reload и rollback
- [x] Валидация перед загрузкой
- [x] `ContentManagerTests` — 27 тестов

**v3.0 — Production-Only Binary** ✅
- [x] `testRuntimeRejectsRawJSON()` — gate test в AuditGateTests
- [x] `ContentRegistry.loadPack()` принимает только .pack файлы
- [x] JSON загрузка только в PackCompiler/PackLoader (compile-time)

---

## Hot-Reload для разработки

### Обзор

Hot-Reload позволяет обновлять контент в работающем приложении без перезапуска. Это значительно ускоряет итерацию при создании и отладке контента.

### Архитектура

```
┌─────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│ ContentManager  │────▶│ ContentManagerVM │────▶│ContentManagerView │
│   (Engine)      │     │ (ObservableObject)│     │    (SwiftUI)      │
└─────────────────┘     └──────────────────┘     └───────────────────┘
         │
         ▼
┌─────────────────┐
│ ContentRegistry │
│   (Singleton)   │
└─────────────────┘
```

### Принципы безопасности

1. **Validate First, Load Second** — новый контент валидируется ДО выгрузки старого
2. **Atomic Replacement** — старый контент работает пока новый не загружен полностью
3. **Rollback on Failure** — при ошибке автоматический откат к предыдущему состоянию
4. **Production Safety** — битые паки никогда не грузятся, ошибки показываются но не крашат

### Workflow разработки контента

#### 1. Редактирование JSON

Редактируйте JSON файлы в директории вашего пака:

```
Packages/StoryPacks/Season1/TwilightMarchesActI/
└── Sources/TwilightMarchesActIContent/Resources/TwilightMarchesActI/
    ├── manifest.json
    ├── Campaign/
    │   ├── regions.json
    │   ├── events.json
    │   └── quests.json
    ├── Characters/
    │   └── heroes.json
    └── Cards/
        └── cards.json
```

#### 2. Компиляция пака

Используйте pack-compiler для создания .pack файла:

```bash
cd Packages/TwilightEngine

# Компиляция пака в Documents (для hot-reload)
swift run pack-compiler compile \
    ../StoryPacks/Season1/TwilightMarchesActI/Sources/TwilightMarchesActIContent/Resources/TwilightMarchesActI \
    ~/Library/Developer/CoreSimulator/Devices/YOUR_DEVICE_ID/data/Containers/Data/Application/YOUR_APP_ID/Documents/Packs/TwilightMarchesActI.pack
```

> **Tip:** Для iOS Simulator путь к Documents можно найти через `xcrun simctl get_app_container booted BUNDLE_ID data`

#### 3. Использование Content Manager

1. Запустите приложение в DEBUG режиме
2. На главном экране нажмите иконку **📦** (Content Manager)
3. Найдите ваш пак в секции **External Packs**
4. Нажмите **Validate** для проверки
5. Нажмите **Reload** для загрузки

### Расположение файлов

| Платформа | Путь к Documents/Packs/ |
|-----------|-------------------------|
| iOS Simulator | `~/Library/Developer/CoreSimulator/Devices/{DEVICE_ID}/data/Containers/Data/Application/{APP_ID}/Documents/Packs/` |
| iOS Device | Через Files app → CardSampleGame → Packs/ |
| macOS | `~/Documents/CardSampleGame/Packs/` |

### Статусы паков

| Статус | Иконка | Описание |
|--------|--------|----------|
| Discovered | ○ | Найден на диске, не проверен |
| Validating | ⟳ | Идёт проверка |
| Validated ✓ | ✓ | Проверен, ошибок нет |
| Validated ⚠️ | ⚠️ | Проверен, есть предупреждения |
| Validated ✗ | ✗ | Проверен, есть ошибки |
| Loading | ⟳ | Загружается |
| Loaded | ● | Успешно загружен |
| Failed | ✗ | Ошибка загрузки |

### API для Hot-Reload

#### ContentManager (Engine)

```swift
let registry = ContentRegistry()
let contentManager = ContentManager(registry: registry)

// Обнаружение паков
let packs = contentManager.discoverPacks(bundledURLs: bundledURLs)

// Валидация пака
let summary = await contentManager.validatePack(packId)

// Безопасная перезагрузка с откатом при ошибке
let result = await contentManager.safeReloadPack(packId)
switch result {
case .success(let loadedPack):
    print("Pack reloaded: \(loadedPack.manifest.packId)")
case .failure(let error):
    print("Reload failed, old pack preserved: \(error)")
}
```

#### ContentRegistry (Safe Reload)

```swift
// Атомарная перезагрузка с откатом
let registry = ContentRegistry()
let result = registry.safeReloadPack(packId, from: url)
switch result {
case .success(let newPack):
    // Новый контент загружен
case .failure(let error):
    // Старый контент сохранён
}
```

### Пример: Быстрая итерация

```bash
# Терминал 1: Следим за изменениями и перекомпилируем
cd Packages/TwilightEngine
fswatch -o ../StoryPacks/Season1/TwilightMarchesActI | \
    xargs -I{} swift run pack-compiler compile \
        ../StoryPacks/Season1/TwilightMarchesActI/Sources/.../TwilightMarchesActI \
        ~/Documents/Packs/TwilightMarchesActI.pack

# В приложении: нажимаем Reload в Content Manager
```

### Ограничения

1. **Bundled паки не перезагружаются** — они read-only в бандле приложения
2. **Изменения кода требуют пересборки** — hot-reload только для данных
3. **Активные игры** — изменения применяются при следующем запуске игры, не во время активной сессии

### Отладка проблем

#### Пак не появляется в списке

1. Проверьте расширение файла: должно быть `.pack`
2. Проверьте путь: `Documents/Packs/`
3. Нажмите кнопку обновления в Content Manager

#### Валидация не проходит

1. Откройте детали пака для списка ошибок
2. Проверьте кросс-ссылки (hero → cards, region → neighbors)
3. Используйте `pack-compiler validate` для детального отчёта

#### Контент не обновляется

1. Убедитесь что Reload прошёл успешно (зелёный статус)
2. Начните новую игру (изменения не применяются к активной)
3. Проверьте версию в manifest.json

---

## Использование PackEditor

Для создания и редактирования контент-паков рекомендуется использовать **PackEditor** — macOS-приложение с графическим интерфейсом.

PackEditor предоставляет:
- Визуальное редактирование всех 10 категорий контента (враги, карты, события, регионы, герои, карты судьбы, квесты, поведения, якоря, баланс)
- Редактирование манифеста пака (metadata, версии, совместимость)
- CRUD-операции с шаблонами для быстрого создания сущностей
- Импорт/экспорт сущностей через буфер обмена
- Валидацию пака с отображением ошибок
- JSON-превью для каждой сущности
- Компиляцию в .pack бинарный формат

Подробное руководство: [PACK_EDITOR_GUIDE.md](./PACK_EDITOR_GUIDE.md) (RU) | [PACK_EDITOR_GUIDE_EN.md](./PACK_EDITOR_GUIDE_EN.md) (EN)

> **Примечание:** Ручное редактирование JSON (описанное выше) остаётся актуальным для CI/CD пайплайнов и скриптовой генерации контента.

---

## Связанные документы

- [HEROES_MODULE.md](../Engine/Heroes/HEROES_MODULE.md) — Модуль героев
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) — Архитектура движка
- [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) — Техническая документация
