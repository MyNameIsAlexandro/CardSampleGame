# Cards Module

Модуль карт для игры "Сумрачные Пределы" (Twilight Marches).

## Структура модуля

```
Engine/Cards/
├── CardDefinition.swift  # Протоколы и типы определения карт
├── CardRegistry.swift    # Реестр и загрузка карт
└── CARDS_MODULE.md       # Документация (этот файл)
```

Связанные файлы в основном проекте:
```
Models/
├── Card.swift            # Игровая модель карты (Runtime)
└── CardType.swift        # Типы, редкости, эффекты карт
```

## Архитектура

### Разделение ответственности

1. **CardDefinition** (Data Layer) - Статические данные карты
2. **Card** (Runtime Layer) - Игровой экземпляр карты
3. **CardRegistry** (Service Layer) - Управление и загрузка карт

### Система принадлежности карт

Вдохновлена системой сигнатурных карт из Arkham Horror LCG.

```
CardOwnership
├── universal           # Доступна всем героям
├── classSpecific       # Только для класса (Warrior, Mage, etc.)
├── heroSignature       # Уникальная карта конкретного героя
├── expansion           # Требует DLC
├── requiresUnlock      # Требует разблокировки
└── composite           # Комбинация условий
```

## Типы карт

### Базовые типы
| Тип | Описание |
|-----|----------|
| attack | Карты атаки |
| defense | Карты защиты |
| spell | Заклинания |
| special | Особые карты |
| weapon | Оружие |
| armor | Броня |
| item | Предметы |

### Специфичные для Twilight Marches
| Тип | Описание |
|-----|----------|
| curse | Проклятия |
| spirit | Духи (призываемые союзники) |
| artifact | Артефакты (мощные древние предметы) |
| ritual | Ритуалы (заклинания с подготовкой) |

## API

### Получение карт

```swift
// По ID
let card = CardRegistry.shared.card(id: "strike_basic")

// Все карты
let allCards = CardRegistry.shared.allCards

// Карты доступные герою
let available = CardRegistry.shared.availableCards(
    forHeroID: "warrior_ragnar",
    heroClass: .warrior,
    ownedExpansions: ["borderlands"],
    unlockedConditions: ["beat_tutorial"]
)

// Карты класса
let warriorCards = CardRegistry.shared.cards(forClass: .warrior)

// Сигнатурные карты героя
let signature = CardRegistry.shared.cards(forHeroID: "warrior_ragnar")

// Стартовая колода
let deck = CardRegistry.shared.startingDeck(
    forHeroID: "warrior_ragnar",
    heroClass: .warrior
)

// Карты для магазина
let shopCards = CardRegistry.shared.shopCards(
    forHeroID: "warrior_ragnar",
    heroClass: .warrior,
    maxRarity: .rare
)
```

### Регистрация карт

```swift
// Одиночная карта
CardRegistry.shared.register(StandardCardDefinition(
    id: "my_card",
    name: "Моя карта",
    cardType: .attack,
    description: "Описание",
    abilities: [CardAbility(
        name: "Удар",
        description: "Нанести 5 урона",
        effect: .damage(amount: 5, type: .physical)
    )],
    faithCost: 3
))

// Пул карт класса
CardRegistry.shared.registerClassPool(ClassCardPool(
    heroClass: .warrior,
    startingCards: [warriorStrike],
    purchasableCards: [warriorRage, warriorShield],
    upgradeCards: [improvedStrike]
))

// Сигнатурные карты героя
CardRegistry.shared.registerSignatureCards(HeroSignatureCards(
    heroID: "warrior_ragnar",
    requiredCards: [ancestralAxe],      // Начинают в колоде
    optionalCards: [familyHeirloom],    // Можно добавить
    weakness: bloodRage                  // Слабость героя
))
```

### Формат JSON

```json
[
    {
        "id": "custom_strike",
        "name": "Кастомный удар",
        "cardType": "attack",
        "rarity": "uncommon",
        "description": "Нанести 4 урона",
        "icon": "⚔️",
        "faithCost": 3,
        "balance": "neutral",
        "power": 4,
        "ownershipType": "class:warrior"
    }
]
```

Значения `ownershipType`:
- `"universal"` - Универсальная
- `"class:warrior"` - Для класса Warrior
- `"hero:warrior_ragnar"` - Сигнатурная для героя

## Система сигнатурных карт

### Обязательные карты (Required)
Начинают в колоде героя. Нельзя удалить или продать.

### Опциональные карты (Optional)
Можно добавить в колоду во время кампании. Доступны только этому герою.

### Слабость (Weakness)
Негативная карта, отражающая недостаток героя. Начинает в колоде.
Как в Arkham Horror LCG - это часть идентичности персонажа.

Примеры:
- **Рагнар**: "Кровавая ярость" - при низком HP атакует ближайшую цель
- **Умбра**: "Тёмный договор" - убийства сдвигают баланс к Тьме

## Пулы карт классов

Каждый класс имеет свой пул карт:

### Стартовые карты (Starting)
Добавляются в начальную колоду при выборе класса.

### Покупаемые карты (Purchasable)
Доступны в магазине только для героев этого класса.

### Карты улучшения (Upgrade)
Заменяют базовые карты на улучшенные версии.

```swift
// Пример: Улучшение "Удар" → "Мощный удар"
let improvedStrike = StandardCardDefinition(
    id: "warrior_improved_strike",
    name: "Мощный удар",
    cardType: .attack,
    description: "Улучшенная версия Удара. Нанести 5 урона",
    // upgradesFrom: "strike_basic"  // Будущая фича
)
```

## Баланс и редкость

### Баланс Свет/Тьма
| Баланс | Описание | Роли |
|--------|----------|------|
| light | Защита, исцеление | Sustain, Control |
| neutral | Сбалансированные | Utility |
| dark | Атака, проклятия | Power |

### Редкость
| Редкость | Получение |
|----------|-----------|
| common | Стартовые, магазин |
| uncommon | Магазин, награды |
| rare | Редкие награды, боссы |
| epic | Только данжи и квесты |
| legendary | Уникальные артефакты |

## Расширение модуля

### Добавление нового типа карт

1. Добавить case в `CardType` (Models/CardType.swift)
2. Создать карты этого типа
3. Добавить обработку в CombatView/GameEngine

### Добавление DLC пакета

```swift
let dlcSource = JSONCardDataSource(
    id: "borderlands_expansion",
    name: "Порубежье",
    fileURL: Bundle.main.url(forResource: "borderlands_cards", withExtension: "json")!
)
CardRegistry.shared.addDataSource(dlcSource)
```

### Создание нового героя с картами

```swift
// 1. Зарегистрировать героя
HeroRegistry.shared.register(newHeroDefinition)

// 2. Зарегистрировать сигнатурные карты
CardRegistry.shared.registerSignatureCards(HeroSignatureCards(
    heroID: "new_hero_id",
    requiredCards: [signatureWeapon],
    optionalCards: [specialAbility1, specialAbility2],
    weakness: heroWeakness
))
```

## Интеграция с Heroes Module

```swift
// Получить полную стартовую колоду героя
func getFullStartingDeck(heroID: String, heroClass: HeroClass) -> [Card] {
    // 1. Базовые карты из HeroRegistry
    let heroDefinition = HeroRegistry.shared.hero(id: heroID)
    let cardIDs = heroDefinition?.startingDeckCardIDs ?? []

    // 2. Карты из CardRegistry
    return CardRegistry.shared.startingDeck(
        forHeroID: heroID,
        heroClass: heroClass
    )
}
```

## Тестирование

Тесты находятся в `CardSampleGameTests/Unit/CardTests.swift`.

Основные тест-кейсы:
- Регистрация и получение карт
- Фильтрация по классу/герою
- Проверка доступности (ownership)
- Формирование стартовой колоды
- Загрузка из JSON

```swift
func testCardOwnershipClassSpecific() {
    let card = StandardCardDefinition(
        id: "test_warrior_card",
        ownership: .classSpecific(heroClass: .warrior),
        // ...
    )

    XCTAssertTrue(card.ownership.isAvailable(
        forHeroID: nil,
        heroClass: .warrior
    ))

    XCTAssertFalse(card.ownership.isAvailable(
        forHeroID: nil,
        heroClass: .mage
    ))
}
```

## Зависимости

- `Foundation` - Базовые типы
- `Models/Card.swift` - Игровая модель
- `Models/CardType.swift` - Типы и эффекты
- `Engine/Heroes` - Интеграция с героями

## История изменений

- **v1.0** - Начальная реализация (базовые карты)
- **v1.1** - Добавлена система CardOwnership
- **v1.2** - Добавлены сигнатурные карты героев
- **v1.3** - Добавлены пулы карт классов
- **v1.4** - Добавлена загрузка из JSON
