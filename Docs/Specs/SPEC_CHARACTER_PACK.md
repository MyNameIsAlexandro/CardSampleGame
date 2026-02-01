# Спецификация Character Pack

> **Версия:** 1.1
> **Статус:** Активный
> **Последнее обновление:** Февраль 2026

---

## 1. Обзор

### 1.1 Назначение

Character Pack предоставляет игровых персонажей-героев с их стартовыми колодами, способностями и связанными картами игрока. Эти packs фокусируются на кастомизации персонажа и опциях для построения колоды.

### 1.2 Область применения

Данная спецификация охватывает:
- Структуру character pack и требования к манифесту
- Схемы определения героев
- Схемы определения карт
- Правила составления стартовой колоды
- Функциональные и нефункциональные требования

### 1.3 Терминология

| Термин | Определение |
|--------|-------------|
| **Hero** | Игровой персонаж со статами и способностями |
| **Starting Deck** | Начальный набор карт, с которым герой начинает игру |
| **Hero Class** | Архетип, определяющий стиль игры героя |
| **Ability** | Специальная сила, уникальная для героя |
| **Card** | Играбельный элемент в бою и событиях |

---

## 2. Функциональные требования

### 2.1 Базовая функциональность

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-INV-001 | Pack ОБЯЗАН определять минимум одного героя | Обязательно |
| FR-INV-002 | Каждый герой ОБЯЗАН иметь валидную стартовую колоду | Обязательно |
| FR-INV-003 | Pack МОЖЕТ определять дополнительные карты игрока | Опционально |
| FR-INV-004 | Все карты в стартовой колоде ОБЯЗАНЫ существовать | Обязательно |
| FR-INV-005 | Pack МОЖЕТ зависеть от других packs для получения карт | Опционально |

### 2.2 Требования к героям

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-HRO-001 | Герой ОБЯЗАН иметь уникальный ID | Обязательно |
| FR-HRO-002 | Герой ОБЯЗАН иметь локализованное имя и описание | Обязательно |
| FR-HRO-003 | Герой ОБЯЗАН принадлежать к классу героя | Обязательно |
| FR-HRO-004 | Герой ОБЯЗАН иметь базовые статы | Обязательно |
| FR-HRO-005 | Герой ОБЯЗАН иметь стартовую колоду (минимум 6 карт) | Обязательно |
| FR-HRO-006 | Герой ДОЛЖЕН иметь специальную способность | Рекомендовано |
| FR-HRO-007 | Герой МОЖЕТ иметь несколько способностей | Опционально |
| FR-HRO-008 | Герой МОЖЕТ иметь условия разблокировки | Опционально |

### 2.3 Требования к картам

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-CRD-001 | Карта ОБЯЗАНА иметь уникальный ID | Обязательно |
| FR-CRD-002 | Карта ОБЯЗАНА иметь локализованное название | Обязательно |
| FR-CRD-003 | Карта ОБЯЗАНА иметь тип карты | Обязательно |
| FR-CRD-004 | Карта ОБЯЗАНА иметь редкость | Обязательно |
| FR-CRD-005 | Карта ОБЯЗАНА определять правила владения | Обязательно |
| FR-CRD-006 | Карта МОЖЕТ иметь специальные способности | Опционально |
| FR-CRD-007 | Карта МОЖЕТ иметь классовые ограничения | Опционально |
| FR-CRD-008 | Карта МОЖЕТ иметь стоимость энергии за ход | Опционально |
| FR-CRD-009 | Карта МОЖЕТ быть одноразовой (exhaust) | Опционально |

### 2.4 Правила построения колоды

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-DEC-001 | Стартовая колода ОБЯЗАНА иметь 6-12 карт | Обязательно |
| FR-DEC-002 | Стартовая колода ДОЛЖНА соответствовать стилю игры героя | Рекомендовано |
| FR-DEC-003 | Стартовая колода МОЖЕТ иметь дубликаты карт | Опционально |
| FR-DEC-004 | Колода ОБЯЗАНА соблюдать правила владения картами | Обязательно |

---

## 3. Нефункциональные требования

### 3.1 Производительность

| ID | Требование | Цель |
|----|------------|------|
| NFR-PERF-001 | Время загрузки pack | < 200мс |
| NFR-PERF-002 | Максимум героев на pack | 20 |
| NFR-PERF-003 | Максимум карт на pack | 200 |
| NFR-PERF-004 | Максимальный размер файла | 5МБ |

### 3.2 Совместимость

| ID | Требование | Цель |
|----|------------|------|
| NFR-COMP-001 | Совместимость версии ядра | Семантическое версионирование |
| NFR-COMP-002 | Проверка доступности карт | Runtime валидация |
| NFR-COMP-003 | Кросс-pack ссылки на карты | Через dependencies |

### 3.3 Баланс

| ID | Требование | Цель |
|----|------------|------|
| NFR-BAL-001 | Статы героя должны быть в пределах | Валидируется |
| NFR-BAL-002 | Уровень силы стартовой колоды | Сравним с базовыми героями |
| NFR-BAL-003 | Перезарядка способностей | Минимум 1 ход |

### 3.4 Доступность

| ID | Требование | Цель |
|----|------------|------|
| NFR-ACC-001 | Описания героев | Понятные и информативные |
| NFR-ACC-002 | Описания способностей | Однозначные эффекты |
| NFR-ACC-003 | Текст карт | Согласованная терминология |

---

## 4. Схемы данных

### 4.1 Схема манифеста

```json
{
  "$schema": "character-pack-manifest-v1",
  "id": "string (обязательно, уникальный, lowercase-hyphen)",
  "name": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "version": "SemanticVersion (обязательно)",
  "type": "character (обязательно)",
  "core_version_min": "SemanticVersion (обязательно)",
  "core_version_max": "SemanticVersion | null",
  "dependencies": "PackDependency[] (опционально)",
  "heroes_path": "string (обязательно, относительный путь)",
  "cards_path": "string (опционально, относительный путь)",
  "locales": "string[] (по умолчанию: ['en'])",
  "localization_path": "string (опционально)",
  "recommended_campaigns": "string[] (опционально, ID campaign pack)"
}
```

### 4.2 Схема героя

```json
{
  "id": "string (обязательно, уникальный)",
  "name": "string (обязательно, отображаемое имя)",
  "name_ru": "string (опционально, русское имя)",
  "hero_class": "HeroClass (обязательно)",
  "description": "string (обязательно)",
  "description_ru": "string (опционально)",
  "icon": "string (обязательно, имя SF Symbol)",
  "base_stats": "HeroStats (обязательно)",
  "special_ability": "HeroAbility (обязательно)",
  "passive_abilities": "HeroAbility[] (опционально)",
  "starting_deck": "string[] (обязательно, ID карт, min: 6)",
  "availability": "HeroAvailability (обязательно)",
  "recommended_cards": "string[] (опционально)",
  "lore": "LocalizedString (опционально, история персонажа)"
}
```

#### HeroClass

```
warrior | mage | ranger | priest | shadow | alchemist | bard | monk
```

Каждый класс определяет стиль игры:

| Класс | Фокус | Типичные статы |
|-------|-------|----------------|
| warrior | Ближний бой, защита | Высокая сила, здоровье |
| mage | Заклинания, массовые эффекты | Высокая мудрость |
| ranger | Дальний бой, мобильность | Высокая ловкость |
| priest | Лечение, поддержка | Высокая вера, мудрость |
| shadow | Скрытность, критические удары | Высокая ловкость |
| alchemist | Предметы, баффы | Сбалансированный |
| bard | Баффы, дебаффы | Высокая харизма |
| monk | Баланс, комбо | Сбалансированный |

#### HeroStats

```json
{
  "health": "integer (обязательно, диапазон: 8-15)",
  "faith": "integer (обязательно, диапазон: 1-10)",
  "strength": "integer (опционально, диапазон: 1-5)",
  "agility": "integer (опционально, диапазон: 1-5)",
  "wisdom": "integer (опционально, диапазон: 1-5)",
  "charisma": "integer (опционально, диапазон: 1-5)"
}
```

#### HeroAbility

```json
{
  "id": "string (обязательно)",
  "name": "string (обязательно)",
  "name_ru": "string (опционально)",
  "description": "string (обязательно)",
  "description_ru": "string (опционально)",
  "ability_type": "active | passive | triggered (обязательно)",
  "cooldown": "integer (опционально, ходы, min: 1)",
  "uses_per_combat": "integer | null (null = неограниченно)",
  "faith_cost": "integer (опционально, по умолчанию: 0)",
  "effect": "AbilityEffect (обязательно)",
  "icon": "string (опционально, SF Symbol)"
}
```

#### AbilityEffect

```json
{
  "effect_type": "damage | heal | buff | debuff | draw | discard | special",
  "target": "self | enemy | all_enemies | ally | all",
  "value": "integer | null",
  "duration": "integer (ходы, опционально)",
  "modifier_type": "string (опционально, для баффов/дебаффов)",
  "special_effect": "string (опционально, ID пользовательского эффекта)"
}
```

#### HeroAvailability

```json
{
  "type": "always | unlock | purchase | campaign",
  "unlock_condition": "UnlockCondition | null (если type = unlock)",
  "campaign_id": "string | null (если type = campaign)",
  "purchase_cost": "{ currency: integer } | null (если type = purchase)"
}
```

#### UnlockCondition

```json
{
  "condition_type": "complete_quest | defeat_boss | reach_day | collect_cards",
  "target_id": "string (что нужно выполнить)",
  "target_count": "integer (по умолчанию: 1)"
}
```

### 4.3 Схема карты

```json
{
  "id": "string (обязательно, уникальный)",
  "name": "string (обязательно)",
  "name_ru": "string (опционально)",
  "card_type": "CardType (обязательно)",
  "rarity": "CardRarity (обязательно)",
  "description": "string (обязательно)",
  "description_ru": "string (опционально)",
  "icon": "string (обязательно, SF Symbol)",
  "expansion_set": "string (обязательно, идентификатор pack)",
  "ownership": "CardOwnership (обязательно)",
  "class_restriction": "HeroClass | null (опционально)",
  "abilities": "CardAbility[] (опционально)",
  "faith_cost": "integer (по умолчанию: 0)",
  "balance": "light | dark | neutral (по умолчанию: neutral)",
  "power": "integer (опционально, для атакующих карт)",
  "defense": "integer (опционально, для защитных карт)",
  "health_effect": "integer (опционально, для лечащих карт)",
  "cost": "integer | null (опционально, стоимость энергии за ход, по умолчанию: 1)",
  "exhaust": "boolean (опционально, по умолчанию: false, если true — карта удаляется после розыгрыша)"
}
```

#### CardType

```
attack | defense | skill | item | spell | ritual | blessing | curse
```

| Тип | Описание |
|-----|----------|
| attack | Наносит урон врагам |
| defense | Блокирует входящий урон |
| skill | Утилитарные эффекты |
| item | Расходуемый или экипировка |
| spell | Магические эффекты |
| ritual | Мощные многоходовые эффекты |
| blessing | Положительные эффекты от веры |
| curse | Негативные эффекты |

#### CardRarity

```
common | uncommon | rare | epic | legendary
```

| Редкость | Шанс выпадения | Стартовая колода |
|----------|----------------|------------------|
| common | 50% | Разрешено |
| uncommon | 30% | Разрешено |
| rare | 15% | Ограничено (макс. 2) |
| epic | 4% | Ограничено (макс. 1) |
| legendary | 1% | Не разрешено |

#### CardOwnership

```json
{
  "type": "universal | class_specific | hero_specific | unlockable",
  "hero_id": "string | null (если hero_specific)",
  "hero_class": "HeroClass | null (если class_specific)",
  "unlock_condition": "UnlockCondition | null (если unlockable)"
}
```

#### CardAbility

```json
{
  "id": "string (обязательно)",
  "name": "string (обязательно)",
  "trigger": "on_play | on_discard | on_draw | passive",
  "effect": "AbilityEffect (обязательно)",
  "condition": "string | null (опционально, когда срабатывает способность)"
}
```

---

## 5. Правила валидации

### 5.1 Валидация героя

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-HRO-001 | ID героя должен быть уникальным | Ошибка |
| VAL-HRO-002 | Класс героя должен быть валидным | Ошибка |
| VAL-HRO-003 | Базовые статы должны быть в пределах | Ошибка |
| VAL-HRO-004 | Стартовая колода должна иметь 6-12 карт | Ошибка |
| VAL-HRO-005 | Все карты стартовой колоды должны существовать | Ошибка |
| VAL-HRO-006 | Специальная способность должна быть определена | Ошибка |
| VAL-HRO-007 | Иконка должна быть валидным SF Symbol | Предупреждение |

### 5.2 Валидация карты

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-CRD-001 | ID карты должен быть уникальным | Ошибка |
| VAL-CRD-002 | Тип карты должен быть валидным | Ошибка |
| VAL-CRD-003 | Редкость должна быть валидной | Ошибка |
| VAL-CRD-004 | Атакующие карты должны иметь power | Предупреждение |
| VAL-CRD-005 | Защитные карты должны иметь defense | Предупреждение |
| VAL-CRD-006 | Стоимость веры должна быть неотрицательной | Ошибка |
| VAL-CRD-007 | Стоимость энергии (cost) должна быть неотрицательной | Ошибка |
| VAL-CRD-008 | Exhaust карта без способностей и без power | Предупреждение |

### 5.3 Валидация колоды

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-DEC-001 | Все карты должны быть доступны герою | Ошибка |
| VAL-DEC-002 | Legendary карты не в стартовой колоде | Ошибка |
| VAL-DEC-003 | Максимум 2 rare карты в стартовой колоде | Предупреждение |
| VAL-DEC-004 | Максимум 1 epic карта в стартовой колоде | Предупреждение |

### 5.4 Валидация локализации

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-LOC-001 | Имя не должно быть пустым | Ошибка |
| VAL-LOC-002 | Описание не должно быть пустым | Ошибка |
| VAL-LOC-003 | Рекомендуется русский перевод | Информация |
| VAL-LOC-004 | Только inline `LocalizedString`; key-based зарезервирован, запрещён валидатором | Ошибка |

---

## 6. Контракт API

### 6.1 Интерфейс загрузки

```swift
protocol CharacterPackLoader {
    func loadCharacters(from url: URL) throws -> CharacterContent
    func validate(at url: URL) -> ValidationResult
}

struct CharacterContent {
    let heroes: [String: StandardHeroDefinition]
    let cards: [String: StandardCardDefinition]
}
```

### 6.2 Интерфейс Hero Provider

```swift
protocol HeroProvider {
    func getHero(id: String) -> StandardHeroDefinition?
    func getAllHeroes() -> [StandardHeroDefinition]
    func getHeroes(forClass: HeroClass) -> [StandardHeroDefinition]
    func getAvailableHeroes() -> [StandardHeroDefinition]
    func getStartingDeck(forHero: String) -> [StandardCardDefinition]
}
```

### 6.3 Интерфейс Card Provider

```swift
protocol CardProvider {
    func getCard(id: String) -> StandardCardDefinition?
    func getAllCards() -> [StandardCardDefinition]
    func getCards(ofType: CardType) -> [StandardCardDefinition]
    func getCards(forClass: HeroClass) -> [StandardCardDefinition]
    func getCards(forHero: String) -> [StandardCardDefinition]
}
```

### 6.4 Интеграция с Registry

```swift
extension ContentRegistry {
    func loadCharacterPack(from url: URL) throws -> LoadedPack
    func getHero(id: String) -> StandardHeroDefinition?
    func getCard(id: String) -> StandardCardDefinition?
    func getStartingDeck(forHero: String) -> [StandardCardDefinition]
}
```

---

## 7. Точки расширения

### 7.1 Пользовательские классы героев

Новые классы героев могут быть определены путем расширения enum HeroClass. Engine должен быть обновлен для поддержки новых классов, но packs могут подготовить данные героя для будущих классов.

### 7.2 Пользовательские типы карт

Типы карт могут быть расширены. Неизвестные типы карт обрабатываются как тип "skill" по умолчанию.

### 7.3 Пользовательские способности

Пользовательские эффекты способностей могут быть зарегистрированы:

```swift
AbilityRegistry.register("my_custom_effect") { context in
    // Реализация пользовательского эффекта
}
```

### 7.4 Синергии карт

Карты могут ссылаться на синергии с другими картами:

```json
{
  "synergies": [
    { "card_id": "flame_strike", "bonus": "+2 урона" }
  ]
}
```

---

## 8. Лучшие практики

### 8.1 Дизайн героя

1. **Четкая идентичность**: Каждый герой должен иметь уникальный стиль игры
2. **Сбалансированные статы**: Общее количество очков статов должно быть похожим у всех героев
3. **Тематические способности**: Способности должны соответствовать лору героя
4. **Синергия стартовой колоды**: Карты должны хорошо работать вместе

### 8.2 Дизайн карт

1. **Понятные эффекты**: Эффекты карт должны быть однозначными
2. **Бюджет силы**: Выше стоимость = сильнее эффекты
3. **Идентичность класса**: Классовые карты должны усиливать стиль игры
4. **Потенциал комбо**: Некоторые карты должны синергировать

### 8.3 Конвенции именования

```
Герои:     {class}_{name}         например, warrior_ragnar
Карты:     {type}_{name}          например, strike_flame
Способности: {hero}_{ability}     например, ragnar_battle_cry
```

---

## 9. Примеры

### 9.1 Минимальный Character Pack

```json
// manifest.json
{
  "id": "new-hero-pack",
  "name": { "en": "New Hero Pack" },
  "version": "1.0.0",
  "type": "character",
  "core_version_min": "1.0.0",
  "heroes_path": "heroes.json"
}
```

### 9.2 Полное определение героя

```json
{
  "id": "warrior_ragnar",
  "name": "Ragnar the Bold",
  "name_ru": "Рагнар Смелый",
  "hero_class": "warrior",
  "description": "A fearless warrior from the northern lands.",
  "description_ru": "Бесстрашный воин с северных земель.",
  "icon": "shield.lefthalf.filled",
  "base_stats": {
    "health": 12,
    "faith": 3,
    "strength": 4,
    "agility": 2,
    "wisdom": 1
  },
  "special_ability": {
    "id": "ragnar_battle_cry",
    "name": "Battle Cry",
    "name_ru": "Боевой Клич",
    "description": "Boost attack power by 50% for 2 turns.",
    "description_ru": "Увеличивает силу атаки на 50% на 2 хода.",
    "ability_type": "active",
    "cooldown": 3,
    "effect": {
      "effect_type": "buff",
      "target": "self",
      "value": 50,
      "duration": 2,
      "modifier_type": "attack_percent"
    }
  },
  "starting_deck": [
    "strike_basic",
    "strike_basic",
    "strike_basic",
    "defend_basic",
    "defend_basic",
    "rage_strike"
  ],
  "availability": {
    "type": "always"
  }
}
```

---

## 10. Связанные документы

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - Общее руководство по pack
- [SPEC_CAMPAIGN_PACK.md](./SPEC_CAMPAIGN_PACK.md) - Спецификация Campaign pack
- [SPEC_BALANCE_PACK.md](./SPEC_BALANCE_PACK.md) - Спецификация Balance pack
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Архитектура Engine

---

**Контроль документа**

| Версия | Дата | Автор | Изменения |
|--------|------|-------|-----------|
| 1.0 | 2026-01-20 | Claude | Начальная спецификация |
| 1.1 | 2026-02-01 | Claude | Добавлены поля exhaust, cost для карт |
