# План миграции на Data-Driven архитектуру

## Цель
Полностью убрать LEGACY хардкод и перейти на гибкую data-driven систему, где:
- События выбираются динамически StoryDirector'ом
- Квесты и их цели определяются в JSON с триггерами
- Кампании конфигурируют игровые сессии
- Мир живой и вариативный, не шаблонный

---

## Фаза 1: QuestTrigger System (ПРИОРИТЕТ)

### 1.1 Создать QuestTriggerDefinition
**Файл:** `Engine/Data/Definitions/QuestTriggerDefinition.swift`

```swift
/// Типы триггеров для квестовых целей
enum QuestTriggerType: String, Codable {
    case eventChoice      // Выбор в событии
    case visitRegion      // Посещение региона
    case defeatEnemy      // Победа над врагом
    case flagSet          // Установлен флаг
    case itemAcquired     // Получен предмет
    case anchorState      // Состояние якоря
    case tensionThreshold // Порог напряжения
}

struct QuestTrigger: Codable {
    let type: QuestTriggerType
    let eventId: String?        // Для eventChoice
    let choiceId: String?       // Для eventChoice
    let regionId: String?       // Для visitRegion
    let enemyId: String?        // Для defeatEnemy
    let flagName: String?       // Для flagSet
    let threshold: Int?         // Для tensionThreshold
}
```

### 1.2 Обновить QuestObjectiveDefinition
**Файл:** `Engine/Data/Definitions/QuestDefinition.swift`

```swift
struct QuestObjectiveDefinition: Codable {
    let id: String
    let title: LocalizedString
    let description: LocalizedString

    // Data-driven triggers
    let triggers: [QuestTrigger]           // Любой из триггеров активирует
    let requiredFlags: [String]            // Флаги для разблокировки
    let forbiddenFlags: [String]           // Флаги блокирующие

    // Награды при выполнении
    let setsFlags: [String]                // Устанавливаемые флаги
    let rewards: QuestRewards?
}
```

### 1.3 Создать QuestTriggerEngine
**Файл:** `Engine/Quest/QuestTriggerEngine.swift`

```swift
class QuestTriggerEngine {
    /// Проверяет триггеры после действия игрока
    func checkTriggers(
        action: GameAction,
        context: GameContext,
        quests: [QuestDefinition]
    ) -> [QuestProgressUpdate]

    /// Проверяет конкретный триггер
    func evaluateTrigger(_ trigger: QuestTrigger, action: GameAction, context: GameContext) -> Bool
}
```

### 1.4 Миграция quests.json
Обновить формат квестов с триггерами вместо хардкода.

---

## Фаза 2: StoryDirector System

### 2.1 Создать StoryDirector протокол
**Файл:** `Engine/Story/StoryDirector.swift`

```swift
protocol StoryDirector {
    /// Выбирает следующее событие для региона
    func selectEvent(
        forRegion regionId: String,
        context: GameContext,
        rng: inout RandomNumberGenerator
    ) -> EventDefinition?

    /// Получает доступные события для контекста
    func getAvailableEvents(context: GameContext) -> [EventDefinition]

    /// Проверяет и обновляет прогресс квестов
    func processAction(
        _ action: GameAction,
        result: ActionResult,
        context: GameContext
    ) -> StoryUpdate
}

struct StoryUpdate {
    let questUpdates: [QuestProgressUpdate]
    let newEvents: [EventDefinition]       // Разблокированные события
    let worldChanges: [WorldChange]        // Глобальные изменения
}
```

### 2.2 Реализовать TwilightStoryDirector
**Файл:** `Engine/Story/TwilightStoryDirector.swift`

Конкретная реализация для кампании "Сумрачные Пределы":
- Взвешенный выбор событий
- Учёт истории игрока
- Динамическая сложность
- Нарративная связность

### 2.3 Event Pool System
События группируются в пулы:
- `exploration` - случайные события исследования
- `story` - сюжетные события (привязаны к квестам)
- `world` - глобальные события мира
- `regional` - специфичные для региона

---

## Фаза 3: Campaign System

### 3.1 Создать CampaignDefinition
**Файл:** `Engine/Data/Definitions/CampaignDefinition.swift`

```swift
struct CampaignDefinition: Codable {
    let id: String
    let title: LocalizedString
    let description: LocalizedString

    // Контент кампании
    let questIds: [String]                 // Квесты кампании
    let eventPools: [String: [String]]     // Пулы событий по категориям
    let regionIds: [String]                // Доступные регионы

    // Начальное состояние
    let entryRegionId: String
    let initialFlags: [String: Bool]
    let initialTension: Int

    // Условия завершения
    let victoryConditions: [GameCondition]
    let defeatConditions: [GameCondition]
}

struct GameCondition: Codable {
    let type: ConditionType    // flag, tension, health, quest
    let parameters: [String: Any]
}
```

### 3.2 Обновить manifest.json
Добавить полную структуру кампании в манифест пака.

---

## Фаза 4: Миграция контента

### 4.1 Обновить quests.json с триггерами
```json
{
  "id": "main_quest_act1",
  "title": { "en": "Twilight Threat", "ru": "Сумеречная Угроза" },
  "objectives": [
    {
      "id": "obj_talk_elder",
      "title": { "en": "Talk to the Elder", "ru": "Поговорить со старостой" },
      "triggers": [
        { "type": "eventChoice", "eventId": "village_elder_request", "choiceId": "accept" }
      ],
      "setsFlags": ["main_quest_started"]
    },
    {
      "id": "obj_find_oak",
      "title": { "en": "Find the Sacred Oak", "ru": "Найти Священный Дуб" },
      "triggers": [
        { "type": "visitRegion", "regionId": "sacred_oak" }
      ],
      "requiredFlags": ["main_quest_started"],
      "setsFlags": ["found_sacred_oak"]
    }
  ]
}
```

### 4.2 Создать campaign.json
```json
{
  "id": "twilight_marches_act1",
  "title": { "en": "Act I: The Awakening", "ru": "Акт I: Пробуждение" },
  "entryRegionId": "village",
  "questIds": ["main_quest_act1", "side_quest_trader"],
  "eventPools": {
    "exploration": ["wild_beast_encounter", "merchant_camp", "hermit_hut"],
    "story": ["village_elder_request", "sacred_oak_wisdom", "leshy_guardian_boss"]
  },
  "victoryConditions": [
    { "type": "flag", "flag": "act1_completed" }
  ],
  "defeatConditions": [
    { "type": "tension", "threshold": 100 },
    { "type": "health", "threshold": 0 }
  ]
}
```

---

## Фаза 5: Удаление LEGACY кода

### 5.1 Удалить из WorldState.swift:
- `checkQuestObjectivesByEvent()` - заменён на QuestTriggerEngine
- `checkQuestObjectivesByFlags()` - заменён на QuestTriggerEngine
- `checkQuestObjectivesByRegion()` - заменён на QuestTriggerEngine
- `markBossDefeated()` - заменён на QuestTriggerEngine

### 5.2 Удалить из GameState.swift:
- Хардкоженные victory/defeat conditions
- `victoryThreshold` deprecated property

### 5.3 Удалить TwilightMarchesCodeContentProvider:
- Весь класс - всё в JSON

### 5.4 Удалить из TwilightMarchesCards.swift:
- `createStartingDeckForCharacter()` с хардкодом имён
- Все `createXxxStartingDeck()` методы

---

## Порядок выполнения

### Этап 1: Инфраструктура (сейчас)
1. ✅ Создать QuestTriggerDefinition
2. ✅ Обновить QuestObjectiveDefinition
3. ✅ Создать QuestTriggerEngine
4. ✅ Интегрировать в TwilightGameEngine

### Этап 2: Миграция квестов
5. ✅ Обновить quests.json с триггерами (JSONContentProvider обновлён)
6. ✅ Обновить JSONContentProvider для парсинга триггеров
7. 🔶 Удалить checkQuestObjectives* методы из WorldState (deprecated, используется QuestTriggerEngine)

### Этап 3: StoryDirector
8. ✅ Создать StoryDirector протокол
9. ✅ Реализовать BaseStoryDirector
10. 🔶 Интегрировать выбор событий через Director (частично)

### Этап 4: Campaign System
11. ⬜ Создать CampaignDefinition
12. ⬜ Создать campaign.json
13. ⬜ Загрузка кампании при старте игры

### Этап 5: Cleanup
14. ⬜ Удалить TwilightMarchesCodeContentProvider
15. ⬜ Удалить хардкод из TwilightMarchesCards
16. ⬜ Удалить deprecated методы
17. ⬜ Финальные тесты

---

## Критерии успеха

1. **Гибкость**: Новые квесты добавляются только через JSON
2. **Вариативность**: StoryDirector создаёт уникальные сессии
3. **Чистота**: Ноль хардкоженных event/quest/region IDs в Swift коде
4. **Тесты**: Все существующие тесты проходят
5. **Играбельность**: Акт 1 полностью проходим

---

## Риски и митигация

| Риск | Митигация |
|------|-----------|
| Сломается сохранение | Версионирование save format |
| Регрессии в квестах | Интеграционные тесты на прохождение |
| Сложность StoryDirector | Начать с простой реализации |

