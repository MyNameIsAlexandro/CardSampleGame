# Спецификация Campaign Pack

> **Версия:** 1.0
> **Статус:** Активна
> **Обновлено:** Январь 2026

---

## 1. Обзор

### 1.1 Назначение

Campaign Pack предоставляет сюжетный контент: регионы, события, квесты, якоря и врагов. Кампейн-паки определяют игровой мир, его нарратив и механики прогрессии.

### 1.2 Область применения

Данная спецификация охватывает:
- Структуру кампейн-пака и требования к манифесту
- Схемы контента (регионы, события, квесты, якоря, враги)
- Функциональные и нефункциональные требования
- Правила валидации и обработки ошибок
- Точки расширения и API

### 1.3 Терминология

| Термин | Определение |
|--------|-------------|
| **Region** | Локация в игровом мире, которую можно посетить |
| **Event** | Нарративная встреча, происходящая в регионе |
| **Quest** | Многоэтапная цель с наградами |
| **Anchor** | Священная точка, стабилизирующая регион |
| **Enemy** | Противник для боевых встреч |
| **Pressure** | Глобальный уровень опасности в мире |

---

## 2. Функциональные требования

### 2.1 Основная функциональность

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-CAM-001 | Пак ДОЛЖЕН определять хотя бы один регион | Обязательно |
| FR-CAM-002 | Пак ДОЛЖЕН указать начальный регион в манифесте | Обязательно |
| FR-CAM-003 | Все регионы ДОЛЖНЫ образовывать связный граф | Обязательно |
| FR-CAM-004 | Пак МОЖЕТ определять события для любого региона | Опционально |
| FR-CAM-005 | Пак МОЖЕТ определять квесты с несколькими этапами | Опционально |
| FR-CAM-006 | Пак МОЖЕТ определять якоря для регионов | Опционально |
| FR-CAM-007 | Пак МОЖЕТ определять врагов для боевых событий | Опционально |

### 2.2 Требования к регионам

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-REG-001 | Регион ДОЛЖЕН иметь уникальный ID в пределах пака | Обязательно |
| FR-REG-002 | Регион ДОЛЖЕН иметь локализованный заголовок | Обязательно |
| FR-REG-003 | Регион ДОЛЖЕН указывать соседние регионы | Обязательно |
| FR-REG-004 | Регион ДОЛЖЕН иметь начальное состояние (stable/borderland/breach) | Обязательно |
| FR-REG-005 | Регион МОЖЕТ ссылаться на пулы событий | Опционально |
| FR-REG-006 | Регион МОЖЕТ ссылаться на якорь | Опционально |

### 2.3 Требования к событиям

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-EVT-001 | Событие ДОЛЖНО иметь уникальный ID | Обязательно |
| FR-EVT-002 | Событие ДОЛЖНО иметь хотя бы один выбор | Обязательно |
| FR-EVT-003 | Событие ДОЛЖНО определять условия доступности | Обязательно |
| FR-EVT-004 | Выборы ДОЛЖНЫ определять последствия | Обязательно |
| FR-EVT-005 | Боевые события ДОЛЖНЫ ссылаться на валидного врага | Обязательно |
| FR-EVT-006 | Событие МОЖЕТ определять required/forbidden флаги | Опционально |
| FR-EVT-007 | Событие МОЖЕТ быть одноразовым или повторяемым | Опционально |

### 2.4 Требования к квестам

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-QST-001 | Квест ДОЛЖЕН иметь уникальный ID | Обязательно |
| FR-QST-002 | Квест ДОЛЖЕН иметь хотя бы одну цель | Обязательно |
| FR-QST-003 | Цели квеста ДОЛЖНЫ быть выполнимыми | Обязательно |
| FR-QST-004 | Квест ДОЛЖЕН определять награды за выполнение | Обязательно |
| FR-QST-005 | Квест МОЖЕТ иметь предварительные условия | Опционально |
| FR-QST-006 | Квест МОЖЕТ быть главным или побочным | Опционально |

### 2.5 Требования к якорям

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-ANC-001 | Якорь ДОЛЖЕН ссылаться на валидный регион | Обязательно |
| FR-ANC-002 | Якорь ДОЛЖЕН иметь значения целостности | Обязательно |
| FR-ANC-003 | Якорь ДОЛЖЕН определять стоимость укрепления | Обязательно |
| FR-ANC-004 | Максимум один якорь на регион | Обязательно |

### 2.6 Требования к врагам

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-ENM-001 | Враг ДОЛЖЕН иметь уникальный ID | Обязательно |
| FR-ENM-002 | Враг ДОЛЖЕН иметь боевые характеристики (health, power, defense) | Обязательно |
| FR-ENM-003 | Враг ДОЛЖЕН иметь рейтинг сложности | Обязательно |
| FR-ENM-004 | Враг МОЖЕТ иметь особые способности | Опционально |
| FR-ENM-005 | Враг МОЖЕТ выдавать карты в качестве добычи | Опционально |

---

## 3. Нефункциональные требования

### 3.1 Производительность

| ID | Требование | Цель |
|----|------------|------|
| NFR-PERF-001 | Время загрузки пака | < 500мс |
| NFR-PERF-002 | Максимум регионов | 100 на пак |
| NFR-PERF-003 | Максимум событий | 500 на пак |
| NFR-PERF-004 | Максимальный размер файлов | 10MB всего |

### 3.2 Совместимость

| ID | Требование | Цель |
|----|------------|------|
| NFR-COMP-001 | Совместимость версий ядра | Семантическое версионирование |
| NFR-COMP-002 | Обратная совместимость | MINOR версии |
| NFR-COMP-003 | Кросс-пак ссылки | Через зависимости |

### 3.3 Локализация

| ID | Требование | Цель |
|----|------------|------|
| NFR-LOC-001 | Весь пользовательский текст | Локализован |
| NFR-LOC-002 | Запасной язык | Английский (en) |
| NFR-LOC-003 | Минимум локалей | 1 (en) |

### 3.4 Валидация

| ID | Требование | Цель |
|----|------------|------|
| NFR-VAL-001 | Валидация перед загрузкой | Весь контент |
| NFR-VAL-002 | Валидация ссылок | Все ID |
| NFR-VAL-003 | Валидация схемы | Весь JSON |

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
  "entry_quest": "string | null (опционально, начальный квест)",
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
  "neighbor_ids": "string[] (обязательно, мин: 1)",
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
  "choices": "ChoiceDefinition[] (обязательно, мин: 1)",
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

### 4.4 Схема квеста

```json
{
  "id": "string (обязательно, уникальный)",
  "title": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "quest_kind": "main | side | daily | hidden (обязательно)",
  "objectives": "QuestObjective[] (обязательно, мин: 1)",
  "completion_rewards": "QuestRewards (обязательно)",
  "prerequisites": "QuestPrerequisites | null",
  "region_id": "string | null (опционально, локация квеста)",
  "time_limit_days": "integer | null (опционально)"
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
  "health": "integer (обязательно, мин: 1)",
  "power": "integer (обязательно, мин: 0)",
  "defense": "integer (обязательно, мин: 0)",
  "difficulty": "integer (обязательно, 1-5)",
  "enemy_type": "beast | spirit | undead | humanoid | boss (обязательно)",
  "rarity": "common | uncommon | rare | epic | legendary (обязательно)",
  "abilities": "EnemyAbility[] (опционально)",
  "loot_card_ids": "string[] (опционально)",
  "faith_reward": "integer (по умолчанию: 0)",
  "balance_delta": "integer (по умолчанию: 0)"
}
```

---

## 5. Правила валидации

### 5.1 Структурная валидация

| Правило | Описание | Серьёзность |
|---------|----------|-------------|
| VAL-STR-001 | manifest.json должен существовать в корне пака | Ошибка |
| VAL-STR-002 | Все указанные пути должны существовать | Ошибка |
| VAL-STR-003 | Весь JSON должен быть синтаксически корректным | Ошибка |
| VAL-STR-004 | Все обязательные поля должны присутствовать | Ошибка |

### 5.2 Валидация ссылок

| Правило | Описание | Серьёзность |
|---------|----------|-------------|
| VAL-REF-001 | neighbor_ids региона должны ссылаться на существующие регионы | Ошибка |
| VAL-REF-002 | region_ids события должны ссылаться на существующие регионы | Ошибка |
| VAL-REF-003 | region_id якоря должен ссылаться на существующий регион | Ошибка |
| VAL-REF-004 | target_id квеста должен ссылаться на валидную цель | Предупреждение |
| VAL-REF-005 | loot_card_ids врага должны ссылаться на существующие карты | Предупреждение |
| VAL-REF-006 | entry_region должен ссылаться на существующий регион | Ошибка |

### 5.3 Семантическая валидация

| Правило | Описание | Серьёзность |
|---------|----------|-------------|
| VAL-SEM-001 | Все ID должны быть уникальными в пределах типа | Ошибка |
| VAL-SEM-002 | Граф регионов должен быть связным | Предупреждение |
| VAL-SEM-003 | Боевые события должны иметь ссылку на врага | Ошибка |
| VAL-SEM-004 | Цели квеста должны быть достижимыми | Предупреждение |
| VAL-SEM-005 | Диапазоны pressure должны быть валидными (0-100) | Ошибка |

---

## 6. API контракт

### 6.1 Интерфейс загрузки

```swift
protocol CampaignPackLoader {
    /// Загрузить контент кампании по URL
    func loadCampaign(from url: URL) throws -> CampaignContent

    /// Валидировать кампанию перед загрузкой
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

### 6.2 Интерфейс провайдера контента

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

---

## 7. Точки расширения

### 7.1 Кастомные типы событий

Паки могут определять кастомные типы событий используя `event_kind.type = "mini_game"` с кастомным `mini_game_kind`. Движок попытается направить в соответствующий обработчик.

### 7.2 Кастомные способности

Способности врагов могут определять кастомные типы `effect`, которые будут обрабатываться процессорами способностей, зарегистрированными в движке.

### 7.3 Пулы событий

Можно определять кастомные пулы событий и ссылаться на них из регионов:

```json
{
  "pool_ids": ["common_events", "forest_spirits", "act2_special"]
}
```

---

## 8. Примеры

### 8.1 Минимальный Campaign Pack

```
MyCampaign/
├── manifest.json
└── Campaign/
    └── ActI/
        ├── regions.json
        └── events.json
```

### 8.2 Полный Campaign Pack

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

## 9. Связанные документы

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - Общий гайд по пакам
- [SPEC_INVESTIGATOR_PACK.md](./SPEC_INVESTIGATOR_PACK.md) - Спецификация Investigator Pack
- [SPEC_BALANCE_PACK.md](./SPEC_BALANCE_PACK.md) - Спецификация Balance Pack
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Архитектура движка

---

**Контроль документа**

| Версия | Дата | Автор | Изменения |
|--------|------|-------|-----------|
| 1.0 | 2026-01-20 | Claude | Начальная спецификация |
| 1.0-RU | 2026-01-20 | Claude | Перевод на русский |
