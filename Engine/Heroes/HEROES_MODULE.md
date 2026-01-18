# Heroes Module

Модуль героев для игры "Сумрачные Пределы" (Twilight Marches).

## Структура модуля

```
Engine/Heroes/
├── HeroClass.swift      # Классы героев и базовые характеристики
├── HeroDefinition.swift # Протоколы определения героев
├── HeroAbility.swift    # Система способностей
├── HeroRegistry.swift   # Реестр и загрузка героев
└── HEROES_MODULE.md     # Документация (этот файл)
```

## Архитектура

### Слои абстракции

1. **HeroClass** - Enum классов (Warrior, Mage, Ranger, Priest, Shadow)
2. **HeroDefinition** - Протокол определения героя (данные)
3. **HeroAbility** - Система способностей героя
4. **HeroRegistry** - Централизованный реестр всех героев

### Принципы

- **Data-Driven**: Герои определяются данными, а не кодом
- **Extensible**: Легко добавлять новых героев через JSON или код
- **Modular**: Модуль можно подключать/отключать от основной игры
- **Testable**: Полное покрытие тестами

## Классы героев

| Класс | HP | Сила | Вера | Особенность |
|-------|-----|------|------|-------------|
| Warrior | 12 | 7 | 2 | Ярость: +2 урон при HP < 50% |
| Mage | 7 | 2 | 5 | Медитация: +1 вера в конце хода |
| Ranger | 10 | 4 | 3 | Выслеживание: +1 кубик первая атака |
| Priest | 9 | 3 | 5 | Благословение: -1 урон от тьмы |
| Shadow | 8 | 4 | 4 | Засада: +3 урон по полным HP |

## API

### Получение героя

```swift
// По ID
let hero = HeroRegistry.shared.hero(id: "warrior_ragnar")

// По классу
let warrior = HeroRegistry.shared.hero(forClass: .warrior)

// Все герои
let allHeroes = HeroRegistry.shared.allHeroes

// Доступные герои (с учётом разблокировок)
let available = HeroRegistry.shared.availableHeroes(
    unlockedConditions: ["beat_tutorial"],
    ownedDLCs: ["dark_expansion"]
)
```

### Регистрация нового героя

```swift
// Программно
HeroRegistry.shared.register(StandardHeroDefinition(
    id: "warrior_custom",
    name: "Мой Воин",
    heroClass: .warrior,
    description: "Кастомный воин",
    icon: "⚔️",
    baseStats: HeroClass.warrior.baseStats,
    specialAbility: .warriorRage,
    startingDeckCardIDs: ["strike", "strike", "defend"],
    availability: .alwaysAvailable
))

// Из JSON файла
let jsonSource = JSONHeroDataSource(
    id: "custom_heroes",
    name: "Custom Heroes",
    fileURL: Bundle.main.url(forResource: "custom_heroes", withExtension: "json")!
)
HeroRegistry.shared.addDataSource(jsonSource)
```

### Формат JSON

```json
[
    {
        "id": "warrior_custom",
        "name": "Кастомный Воин",
        "heroClass": "warrior",
        "description": "Описание героя",
        "icon": "⚔️",
        "startingDeckCardIDs": ["strike", "strike", "defend"],
        "availability": {
            "alwaysAvailable": {}
        }
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
- `onCardPlayed` - При розыгрыше карты
- `onCombatStart` / `onCombatEnd` - Вход/выход из боя
- `manual` - Ручная активация

### Условия

- `hpBelowPercent` / `hpAbovePercent` - HP героя
- `targetFullHP` - Цель на полном HP
- `firstAttack` - Первая атака в бою
- `damageSourceDark` / `damageSourceLight` - Источник урона
- `hasCurse` - Наличие проклятия
- `balanceAbove` / `balanceBelow` - Баланс Свет/Тьма

### Эффекты

- `bonusDamage` / `damageReduction` - Модификаторы урона
- `bonusDice` / `rerollDice` - Кубики
- `heal` / `gainFaith` / `loseFaith` - Ресурсы
- `shiftLight` / `shiftDark` - Баланс
- `drawCard` / `discardCard` - Карты
- `applyCurseToEnemy` / `removeCurse` - Проклятия

## Доступность героев

```swift
enum HeroAvailability {
    case alwaysAvailable              // Всегда доступен
    case requiresUnlock(condition)    // Требует разблокировки
    case dlc(packID)                  // Требует DLC
}
```

## Расширение модуля

### Добавление нового класса

1. Добавить case в `HeroClass`
2. Реализовать `baseStats`, `specialAbility`, etc.
3. Создать `HeroAbility.xxxAbility`
4. Зарегистрировать базового героя в `HeroRegistry`

### Создание DLC пакета

```swift
let dlcSource = DLCHeroDataSource(
    id: "dark_expansion",
    name: "Dark Expansion",
    packID: "dark_expansion",
    heroes: [
        StandardHeroDefinition(
            id: "necromancer_dark",
            name: "Некромант",
            // ...
            availability: .dlc(packID: "dark_expansion")
        )
    ]
)
HeroRegistry.shared.addDataSource(dlcSource)
```

## Тестирование

Тесты находятся в `CardSampleGameTests/Unit/HeroClassTests.swift`.

Основные тест-кейсы:
- Базовые характеристики всех классов
- Создание Player с HeroClass
- Особые способности каждого класса
- Расчёт урона с модификаторами
- Стартовые пути колод

```swift
func testWarriorRageAbility() {
    let player = Player(name: "Воин", heroClass: .warrior)

    // При полном HP нет бонуса
    XCTAssertEqual(player.getHeroClassDamageBonus(), 0)

    // При HP < 50% бонус +2
    player.health = 5  // 5/12 < 50%
    XCTAssertEqual(player.getHeroClassDamageBonus(), 2)
}
```

## Зависимости

- `Foundation` - Базовые типы
- `Models/Player.swift` - Интеграция с игроком
- `Engine/Cards` - Стартовые колоды (по ID карт)

## История изменений

- **v1.0** - Начальная реализация (5 классов)
- **v1.1** - Добавлена система способностей HeroAbility
- **v1.2** - Добавлен HeroRegistry с поддержкой JSON/DLC
