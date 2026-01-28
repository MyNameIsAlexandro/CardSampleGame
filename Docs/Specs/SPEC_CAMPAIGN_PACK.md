# Спецификация Campaign Pack

> **Версия:** 1.0
> **Статус:** Активный
> **Последнее обновление:** Январь 2026

---

## 1. Обзор

### 1.1 Назначение

Campaign Pack предоставляет сюжетный контент: регионы, события, квесты, якоря и врагов. Campaign pack определяет игровой мир, его нарратив и механику прогрессии.

### 1.2 Область применения

Данная спецификация охватывает:
- Структуру campaign pack и требования к манифесту
- Схемы контента (регионы, события, квесты, якоря, враги)
- Функциональные и нефункциональные требования
- Правила валидации и обработку ошибок
- Точки расширения и API

### 1.3 Терминология

| Термин | Определение |
|--------|-------------|
| **Region** | Локация в игровом мире, которую можно посетить |
| **Event** | Нарративная встреча, происходящая в регионе |
| **Quest** | Многоэтапная цель с наградами |
| **Anchor** | Священная точка, стабилизирующая регион |
| **Enemy** | Противник для боевых столкновений |
| **Pressure** | Глобальный уровень опасности мира |

---

## 2. Функциональные требования

### 2.1 Базовая функциональность

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-CAM-001 | Pack ОБЯЗАН определять минимум один регион | Обязательно |
| FR-CAM-002 | Pack ОБЯЗАН указывать entry region в манифесте | Обязательно |
| FR-CAM-003 | Все регионы ОБЯЗАНЫ формировать связный граф | Обязательно |
| FR-CAM-004 | Pack МОЖЕТ определять события для любого региона | Опционально |
| FR-CAM-005 | Pack МОЖЕТ определять квесты с несколькими этапами | Опционально |
| FR-CAM-006 | Pack МОЖЕТ определять якоря для регионов | Опционально |
| FR-CAM-007 | Pack МОЖЕТ определять врагов для боевых событий | Опционально |

### 2.2 Требования к регионам

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-REG-001 | Регион ОБЯЗАН иметь уникальный ID в рамках pack | Обязательно |
| FR-REG-002 | Регион ОБЯЗАН иметь локализованный заголовок | Обязательно |
| FR-REG-003 | Регион ОБЯЗАН указывать связи с соседями | Обязательно |
| FR-REG-004 | Регион ОБЯЗАН иметь начальное состояние (stable/borderland/breach) | Обязательно |
| FR-REG-005 | Регион МОЖЕТ ссылаться на пулы событий | Опционально |
| FR-REG-006 | Регион МОЖЕТ ссылаться на якорь | Опционально |

### 2.3 Требования к событиям

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-EVT-001 | Событие ОБЯЗАНО иметь уникальный ID | Обязательно |
| FR-EVT-002 | Событие ОБЯЗАНО иметь минимум один выбор | Обязательно |
| FR-EVT-003 | Событие ОБЯЗАНО определять условия доступности | Обязательно |
| FR-EVT-004 | Выборы в событии ОБЯЗАНЫ определять последствия | Обязательно |
| FR-EVT-005 | Боевые события ОБЯЗАНЫ ссылаться на валидного врага | Обязательно |
| FR-EVT-006 | Событие МОЖЕТ определять required/forbidden флаги | Опционально |
| FR-EVT-007 | Событие МОЖЕТ быть одноразовым или повторяемым | Опционально |

### 2.4 Требования к квестам

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-QST-001 | Квест ОБЯЗАН иметь уникальный ID | Обязательно |
| FR-QST-002 | Квест ОБЯЗАН иметь минимум одну цель | Обязательно |
| FR-QST-003 | Цели квеста ОБЯЗАНЫ быть выполнимыми | Обязательно |
| FR-QST-004 | Квест ОБЯЗАН определять награды за выполнение | Обязательно |
| FR-QST-005 | Квест МОЖЕТ иметь предварительные условия | Опционально |
| FR-QST-006 | Квест МОЖЕТ быть основным или побочным | Опционально |

### 2.5 Требования к якорям

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-ANC-001 | Якорь ОБЯЗАН ссылаться на валидный регион | Обязательно |
| FR-ANC-002 | Якорь ОБЯЗАН иметь значения целостности | Обязательно |
| FR-ANC-003 | Якорь ОБЯЗАН определять стоимость укрепления | Обязательно |
| FR-ANC-004 | Максимум один якорь на регион | Обязательно |

### 2.6 Требования к врагам

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-ENM-001 | Враг ОБЯЗАН иметь уникальный ID | Обязательно |
| FR-ENM-002 | Враг ОБЯЗАН иметь боевые характеристики (health, power, defense) | Обязательно |
| FR-ENM-003 | Враг ОБЯЗАН иметь рейтинг сложности | Обязательно |
| FR-ENM-004 | Враг МОЖЕТ иметь специальные способности | Опционально |
| FR-ENM-005 | Враг МОЖЕТ выдавать карты лута | Опционально |

---

## 3. Нефункциональные требования

### 3.1 Производительность

| ID | Требование | Цель |
|----|------------|------|
| NFR-PERF-001 | Время загрузки pack | < 500мс |
| NFR-PERF-002 | Максимум регионов | 100 на pack |
| NFR-PERF-003 | Максимум событий | 500 на pack |
| NFR-PERF-004 | Максимальный размер файла | 10МБ всего |

### 3.2 Совместимость

| ID | Требование | Цель |
|----|------------|------|
| NFR-COMP-001 | Совместимость версии ядра | Семантическое версионирование |
| NFR-COMP-002 | Обратная совместимость | MINOR версии |
| NFR-COMP-003 | Кросс-pack ссылки | Через dependencies |

### 3.3 Локализация

| ID | Требование | Цель |
|----|------------|------|
| NFR-LOC-001 | Весь пользовательский текст | Локализован |
| NFR-LOC-002 | Резервный язык | Английский (en) |
| NFR-LOC-003 | Минимум локалей | 1 (en) |
| NFR-LOC-004 | Формат локализации | Inline `LocalizedString { "en": "...", "ru": "..." }`. Key-based (StringKey + string tables) зарезервирован, запрещён валидатором |

### 3.4 Валидация

| ID | Требование | Цель |
|----|------------|------|
| NFR-VAL-001 | Пред-загрузочная валидация | Весь контент |
| NFR-VAL-002 | Валидация ссылок | Все ID |
| NFR-VAL-003 | Валидация схемы | Все JSON |

---

## 4. Схемы данных

### 4.1 Схема манифеста

```json
{
  "$schema": "campaign-pack-manifest-v1",
  "id": "string (обязательно, уникальный, lowercase-hyphen)",
  "name": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "version": "SemanticVersion (обязательно, формат: X.Y.Z)",
  "type": "campaign (обязательно)",
  "core_version_min": "SemanticVersion (обязательно)",
  "core_version_max": "SemanticVersion | null",
  "dependencies": "PackDependency[] (опционально, по умолчанию: [])",
  "entry_region": "string (обязательно, должен ссылаться на валидный регион)",
  "entry_quest": "string | null (опционально, стартовый квест)",
  "regions_path": "string (обязательно, относительный путь)",
  "events_path": "string (обязательно, относительный путь)",
  "quests_path": "string (опционально, относительный путь)",
  "anchors_path": "string (опционально, относительный путь)",
  "enemies_path": "string (опционально, относительный путь)",
  "locales": "string[] (опционально, по умолчанию: ['en'])",
  "localization_path": "string (опционально, относительный путь)"
}
```

### 4.2 Схема региона

```json
{
  "id": "string (обязательно, уникальный)",
  "title": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "neighbor_ids": "string[] (обязательно, min: 1)",
  "initial_state": "stable | borderland | breach (обязательно)",
  "initially_discovered": "boolean (по умолчанию: false)",
  "anchor_id": "string | null (опционально, ссылка на якорь)",
  "event_pool_ids": "string[] (опционально)",
  "region_type": "settlement | forest | swamp | mountain | wasteland (опционально)"
}
```

### 4.3 Схема события

```json
{
  "id": "string (обязательно, уникальный)",
  "title": "LocalizedString (обязательно)",
  "body": "LocalizedString (обязательно, описание события)",
  "event_kind": "EventKind (обязательно)",
  "availability": "EventAvailability (обязательно)",
  "choices": "ChoiceDefinition[] (обязательно, min: 1)",
  "weight": "integer (опционально, по умолчанию: 10)",
  "is_one_time": "boolean (опционально, по умолчанию: false)",
  "is_instant": "boolean (опционально, по умолчанию: false)",
  "pool_ids": "string[] (опционально)",
  "mini_game_challenge": "MiniGameChallenge | null (для боевых событий)"
}
```

#### EventKind

```json
{
  "type": "inline | mini_game",
  "mini_game_kind": "combat | ritual | exploration | dialogue | puzzle (если mini_game)"
}
```

#### EventAvailability

```json
{
  "region_ids": "string[] | null (null = все регионы)",
  "region_states": "string[] | null (stable/borderland/breach, null = все)",
  "min_pressure": "integer | null (0-100)",
  "max_pressure": "integer | null (0-100)",
  "required_flags": "string[] (по умолчанию: [])",
  "forbidden_flags": "string[] (по умолчанию: [])"
}
```

#### ChoiceDefinition

```json
{
  "id": "string (обязательно)",
  "label": "LocalizedString (обязательно)",
  "requirements": "ChoiceRequirements | null",
  "consequences": "ChoiceConsequences (обязательно)"
}
```

#### ChoiceRequirements

```json
{
  "min_resources": "{ [resource]: integer } (опционально)",
  "min_resonance": "integer | null (-100..+100)",
  "max_resonance": "integer | null (-100..+100)",
  "required_flags": "string[] (опционально)",
  "required_cards": "string[] (опционально)"
}
```

#### ChoiceConsequences

```json
{
  "resource_changes": "{ [resource]: integer } (опционально)",
  "balance_delta": "integer (по умолчанию: 0)",
  "set_flags": "string[] (опционально)",
  "clear_flags": "string[] (опционально)",
  "quest_progress": "QuestProgressEffect | null",
  "region_state_change": "RegionStateChange | null",
  "card_rewards": "string[] (опционально)",
  "result_key": "string | null (для локализованного сообщения о результате)"
}
```

### 4.4 Схема квеста

```json
{
  "id": "string (обязательно, уникальный)",
  "title": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "quest_kind": "main | side | daily | hidden (обязательно)",
  "objectives": "QuestObjective[] (обязательно, min: 1)",
  "completion_rewards": "QuestRewards (обязательно)",
  "prerequisites": "QuestPrerequisites | null",
  "region_id": "string | null (опционально, локация квеста)",
  "time_limit_days": "integer | null (опционально)"
}
```

#### QuestObjective

```json
{
  "id": "string (обязательно)",
  "description": "LocalizedString (обязательно)",
  "objective_type": "visit_region | complete_event | defeat_enemy | collect_item | reach_state",
  "target_id": "string (обязательно, с чем взаимодействовать)",
  "target_count": "integer (по умолчанию: 1)",
  "order": "integer (опционально, для последовательных целей)"
}
```

### 4.5 Схема якоря

```json
{
  "id": "string (обязательно, уникальный)",
  "title": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "region_id": "string (обязательно, ссылка на регион)",
  "anchor_type": "chapel | shrine | monument | tree | stone (обязательно)",
  "initial_influence": "light | dark | neutral (обязательно)",
  "power": "integer (обязательно, 1-10)",
  "max_integrity": "integer (обязательно, по умолчанию: 100)",
  "initial_integrity": "integer (обязательно, 0-max_integrity)",
  "strengthen_amount": "integer (обязательно)",
  "strengthen_cost": "{ [resource]: integer } (обязательно)",
  "abilities": "AnchorAbility[] (опционально)"
}
```

### 4.6 Схема врага

```json
{
  "id": "string (обязательно, уникальный)",
  "name": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "health": "integer (обязательно, min: 1)",
  "power": "integer (обязательно, min: 0)",
  "defense": "integer (обязательно, min: 0)",
  "difficulty": "integer (обязательно, 1-5)",
  "enemy_type": "beast | spirit | undead | humanoid | boss (обязательно)",
  "rarity": "common | uncommon | rare | epic | legendary (обязательно)",
  "abilities": "EnemyAbility[] (опционально)",
  "loot_card_ids": "string[] (опционально)",
  "faith_reward": "integer (по умолчанию: 0)",
  "balance_delta": "integer (по умолчанию: 0)"
}
```

#### EnemyAbility

```json
{
  "id": "string (обязательно)",
  "name": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "trigger": "on_attack | on_defend | on_turn_start | on_turn_end | on_death",
  "effect": "AbilityEffect (обязательно)",
  "cooldown": "integer (опционально, 0 = всегда)"
}
```

---

## 5. Правила валидации

### 5.1 Структурная валидация

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-STR-001 | manifest.json должен существовать в корне pack | Ошибка |
| VAL-STR-002 | Все указанные пути должны существовать | Ошибка |
| VAL-STR-003 | Все JSON должны иметь валидный синтаксис | Ошибка |
| VAL-STR-004 | Все обязательные поля должны присутствовать | Ошибка |

### 5.2 Валидация ссылок

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-REF-001 | neighbor_ids региона должны ссылаться на существующие регионы | Ошибка |
| VAL-REF-002 | region_ids события должны ссылаться на существующие регионы | Ошибка |
| VAL-REF-003 | region_id якоря должен ссылаться на существующий регион | Ошибка |
| VAL-REF-004 | target_id квеста должен ссылаться на валидную цель | Предупреждение |
| VAL-REF-005 | loot_card_ids врага должны ссылаться на существующие карты | Предупреждение |
| VAL-REF-006 | entry_region должен ссылаться на существующий регион | Ошибка |

### 5.3 Семантическая валидация

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-SEM-001 | Все ID должны быть уникальны в рамках типа | Ошибка |
| VAL-SEM-002 | Граф регионов должен быть связным | Предупреждение |
| VAL-SEM-003 | Боевые события должны иметь ссылку на врага | Ошибка |
| VAL-SEM-004 | Цели квеста должны быть достижимы | Предупреждение |
| VAL-SEM-005 | Диапазоны pressure должны быть валидны (0-100) | Ошибка |

### 5.4 Валидация локализации

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-LOC-001 | Все LocalizedString должны иметь ключ 'en' | Ошибка |
| VAL-LOC-002 | Все объявленные локали должны иметь строки | Предупреждение |
| VAL-LOC-003 | Пустые строки не допускаются | Предупреждение |

---

## 6. Контракт API

### 6.1 Интерфейс загрузки

```swift
// Интерфейс PackLoader для Campaign packs
protocol CampaignPackLoader {
    /// Загрузить campaign контент из URL pack
    func loadCampaign(from url: URL) throws -> CampaignContent

    /// Валидировать campaign перед загрузкой
    func validate(at url: URL) -> ValidationResult
}

struct CampaignContent {
    let regions: [String: RegionDefinition]
    let events: [String: EventDefinition]
    let quests: [String: QuestDefinition]
    let anchors: [String: AnchorDefinition]
    let enemies: [String: EnemyDefinition]
}
```

### 6.2 Интерфейс Content Provider

```swift
protocol CampaignContentProvider {
    func getRegion(id: String) -> RegionDefinition?
    func getAllRegions() -> [RegionDefinition]
    func getEvent(id: String) -> EventDefinition?
    func getEvents(forRegion: String) -> [EventDefinition]
    func getQuest(id: String) -> QuestDefinition?
    func getAnchor(id: String) -> AnchorDefinition?
    func getAnchor(forRegion: String) -> AnchorDefinition?
    func getEnemy(id: String) -> EnemyDefinition?
}
```

### 6.3 Runtime интеграция

```swift
// Интеграция с ContentRegistry
extension ContentRegistry {
    func loadCampaignPack(from url: URL) throws -> LoadedPack
    func getAvailableEvents(forRegion: String, pressure: Int) -> [EventDefinition]
    func getActiveQuests() -> [QuestDefinition]
}
```

---

## 7. Точки расширения

### 7.1 Пользовательские типы событий

Packs могут определять пользовательские типы событий, используя `event_kind.type = "mini_game"` с пользовательским `mini_game_kind`. Engine попытается маршрутизировать к соответствующему обработчику.

### 7.2 Пользовательские способности

Способности врагов могут определять пользовательские типы `effect`, которые будут обрабатываться процессорами способностей, зарегистрированными в engine.

### 7.3 Пулы событий

Пользовательские пулы событий могут быть определены и использованы регионами:

```json
{
  "pool_ids": ["common_events", "forest_spirits", "act2_special"]
}
```

---

## 8. Миграция и версионирование

### 8.1 Совместимость версий

| Версия Pack | Версия Core | Совместимость |
|-------------|-------------|---------------|
| 1.x.x | 1.x.x | Полная |
| 1.x.x | 2.x.x | Требуется обновление |

### 8.2 Эволюция схемы

- **Добавление полей**: Всегда опциональные со значениями по умолчанию
- **Удаление полей**: Deprecated в MINOR, удаление в MAJOR
- **Изменение типов**: Никогда не допускается, требуется новое поле

---

## 9. Примеры

### 9.1 Минимальный Campaign Pack

```
MyCampaign/
├── manifest.json
└── Campaign/
    └── ActI/
        ├── regions.json
        └── events.json
```

### 9.2 Полный Campaign Pack

```
TwilightMarches/
├── manifest.json
├── Campaign/
│   ├── ActI/
│   │   ├── regions.json
│   │   ├── events.json
│   │   ├── quests.json
│   │   └── anchors.json
│   └── Enemies/
│       └── enemies.json
├── Cards/
│   └── cards.json
├── Balance/
│   └── balance.json
└── Localization/
    ├── en.json
    └── ru.json
```

---

## 10. Связанные документы

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - Общее руководство по pack
- [SPEC_CHARACTER_PACK.md](./SPEC_CHARACTER_PACK.md) - Спецификация Character pack
- [SPEC_BALANCE_PACK.md](./SPEC_BALANCE_PACK.md) - Спецификация Balance pack
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Архитектура Engine

---

**Контроль документа**

| Версия | Дата | Автор | Изменения |
|--------|------|-------|-----------|
| 1.0 | 2026-01-20 | Claude | Начальная спецификация |
