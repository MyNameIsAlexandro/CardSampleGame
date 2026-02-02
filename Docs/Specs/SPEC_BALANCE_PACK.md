# Спецификация Balance Pack

> **Версия:** 1.0
> **Статус:** Активный
> **Последнее обновление:** Январь 2026

---

## 1. Обзор

### 1.1 Назначение

Balance Pack предоставляет конфигурацию игры без добавления нового контента. Он настраивает числа, веса, стоимости и другие параметры тюнинга для изменения сложности игры, темпа и ощущений от игры.

### 1.2 Область применения

Данная спецификация охватывает:
- Структуру balance pack и манифест
- Категории конфигурации (ресурсы, pressure, время, бой, экономика)
- Границы параметров и валидация
- Пресеты сложности
- Совместимость модов

### 1.3 Терминология

| Термин | Определение |
|--------|-------------|
| **Balance** | Числовая конфигурация, влияющая на геймплей |
| **Tuning** | Тонкая настройка существующих параметров |
| **Difficulty** | Общий уровень сложности игры |
| **Parameter** | Отдельное настраиваемое значение |
| **Override** | Замена значений по умолчанию |

---

## 2. Функциональные требования

### 2.1 Базовая функциональность

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-BAL-001 | Pack ОБЯЗАН предоставлять balance.json | Обязательно |
| FR-BAL-002 | Pack НЕ ДОЛЖЕН вводить новый контент | Обязательно |
| FR-BAL-003 | Pack МОЖЕТ переопределять любой параметр | Опционально |
| FR-BAL-004 | Неуказанные параметры используют значения по умолчанию | Обязательно |
| FR-BAL-005 | Pack МОЖЕТ определять пресеты сложности | Опционально |

### 2.2 Конфигурация ресурсов

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-RES-001 | Pack МОЖЕТ настраивать максимальное здоровье | Опционально |
| FR-RES-002 | Pack МОЖЕТ настраивать стартовые ресурсы | Опционально |
| FR-RES-003 | Pack МОЖЕТ настраивать скорость регенерации | Опционально |
| FR-RES-004 | Значения ресурсов ОБЯЗАНЫ быть положительными | Обязательно |

### 2.3 Конфигурация Pressure

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-PRS-001 | Pack МОЖЕТ настраивать пороги pressure | Опционально |
| FR-PRS-002 | Pack МОЖЕТ настраивать скорость pressure | Опционально |
| FR-PRS-003 | Значения pressure ОБЯЗАНЫ быть 0-100 | Обязательно |
| FR-PRS-004 | Пороги ОБЯЗАНЫ быть упорядочены | Обязательно |

### 2.4 Конфигурация времени

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-TIM-001 | Pack МОЖЕТ настраивать стоимость действий | Опционально |
| FR-TIM-002 | Pack МОЖЕТ настраивать длину дня | Опционально |
| FR-TIM-003 | Значения времени ОБЯЗАНЫ быть положительными | Обязательно |

### 2.5 Конфигурация боя

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-CMB-001 | Pack МОЖЕТ настраивать формулы урона | Опционально |
| FR-CMB-002 | Pack МОЖЕТ настраивать механику защиты | Опционально |
| FR-CMB-003 | Pack МОЖЕТ настраивать правила вытягивания карт | Опционально |

### 2.6 Условия окончания

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-END-001 | Pack МОЖЕТ изменять условия поражения | Опционально |
| FR-END-002 | Pack МОЖЕТ изменять условия победы | Опционально |
| FR-END-003 | Требуется минимум одно условие победы | Обязательно |

---

## 3. Нефункциональные требования

### 3.1 Производительность

| ID | Требование | Цель |
|----|------------|------|
| NFR-PERF-001 | Время загрузки конфигурации | < 50мс |
| NFR-PERF-002 | Максимальный размер файла | 100КБ |
| NFR-PERF-003 | Поиск параметра | O(1) |

### 3.2 Совместимость

| ID | Требование | Цель |
|----|------------|------|
| NFR-COMP-001 | Версия ядра | Семантическое версионирование |
| NFR-COMP-002 | Совместимость с campaign | Любой campaign |
| NFR-COMP-003 | Совместимость с character pack | Любой character pack |

### 3.3 Безопасность

| ID | Требование | Цель |
|----|------------|------|
| NFR-SAF-001 | Границы параметров | Валидируются |
| NFR-SAF-002 | Деление на ноль | Предотвращается |
| NFR-SAF-003 | Защита от переполнения | Обеспечивается |

### 3.4 Удобство использования

| ID | Требование | Цель |
|----|------------|------|
| NFR-USE-001 | Понятные имена параметров | Самодокументирующиеся |
| NFR-USE-002 | Пресеты сложности | Удобные для пользователя |
| NFR-USE-003 | Значения по умолчанию | Всегда предоставлены |

---

## 4. Схемы данных

### 4.1 Схема манифеста

```json
{
  "$schema": "balance-pack-manifest-v1",
  "id": "string (обязательно, уникальный)",
  "name": "LocalizedString (обязательно)",
  "description": "LocalizedString (обязательно)",
  "version": "SemanticVersion (обязательно)",
  "type": "balance (обязательно)",
  "core_version_min": "SemanticVersion (обязательно)",
  "core_version_max": "SemanticVersion | null",
  "balance_path": "string (обязательно, относительный путь)",
  "difficulty_level": "easy | normal | hard | nightmare (опционально)",
  "tags": "string[] (опционально, для фильтрации)"
}
```

### 4.2 Схема конфигурации баланса

```json
{
  "resources": "ResourceConfiguration (опционально)",
  "pressure": "PressureConfiguration (опционально)",
  "anchor": "AnchorConfiguration (опционально)",
  "time": "TimeConfiguration (опционально)",
  "combat": "CombatConfiguration (опционально)",
  "economy": "EconomyConfiguration (опционально)",
  "end_conditions": "EndConditionConfiguration (опционально)",
  "difficulty_modifiers": "DifficultyModifiers (опционально)"
}
```

### 4.3 Конфигурация ресурсов

```json
{
  "max_health": {
    "type": "integer",
    "default": 10,
    "range": [5, 20],
    "description": "Максимальное здоровье игрока"
  },
  "starting_health": {
    "type": "integer",
    "default": 10,
    "range": [1, "max_health"],
    "description": "Здоровье в начале игры"
  },
  "max_faith": {
    "type": "integer",
    "default": 10,
    "range": [3, 15],
    "description": "Максимум очков веры"
  },
  "starting_faith": {
    "type": "integer",
    "default": 3,
    "range": [0, "max_faith"],
    "description": "Вера в начале игры"
  },
  "health_regen_per_rest": {
    "type": "integer",
    "default": 3,
    "range": [1, 10],
    "description": "Здоровье, восстанавливаемое при отдыхе"
  },
  "faith_per_anchor_visit": {
    "type": "integer",
    "default": 1,
    "range": [0, 5],
    "description": "Вера, получаемая у якорей"
  },
  "faith_per_combat_win": {
    "type": "integer",
    "default": 1,
    "range": [0, 5],
    "description": "Вера, получаемая за победу в бою"
  }
}
```

### 4.4 Конфигурация Pressure

```json
{
  "starting_pressure": {
    "type": "integer",
    "default": 30,
    "range": [0, 100],
    "description": "Начальный pressure мира"
  },
  "max_pressure": {
    "type": "integer",
    "default": 100,
    "range": [50, 100],
    "description": "Максимальный pressure (условие поражения)"
  },
  "pressure_per_day": {
    "type": "integer",
    "default": 5,
    "range": [0, 20],
    "description": "Рост pressure за день"
  },
  "pressure_per_breach": {
    "type": "integer",
    "default": 10,
    "range": [0, 30],
    "description": "Pressure от прорыва региона"
  },
  "pressure_reduction_per_strengthen": {
    "type": "integer",
    "default": 5,
    "range": [0, 20],
    "description": "Снижение pressure при укреплении якоря"
  },
  "thresholds": {
    "low": {
      "type": "integer",
      "default": 30,
      "range": [10, 40],
      "description": "Порог низкого pressure"
    },
    "medium": {
      "type": "integer",
      "default": 50,
      "range": [30, 60],
      "description": "Порог среднего pressure"
    },
    "high": {
      "type": "integer",
      "default": 70,
      "range": [50, 80],
      "description": "Порог высокого pressure"
    },
    "critical": {
      "type": "integer",
      "default": 90,
      "range": [70, 95],
      "description": "Порог критического pressure"
    }
  }
}
```

### 4.5 Конфигурация якорей

```json
{
  "max_integrity": {
    "type": "integer",
    "default": 100,
    "range": [50, 200],
    "description": "Максимальная целостность якоря"
  },
  "default_strengthen_amount": {
    "type": "integer",
    "default": 20,
    "range": [5, 50],
    "description": "Целостность, восстанавливаемая за укрепление"
  },
  "default_strengthen_cost": {
    "type": "integer",
    "default": 5,
    "range": [1, 15],
    "description": "Стоимость веры для укрепления"
  },
  "stable_threshold": {
    "type": "integer",
    "default": 70,
    "range": [50, 90],
    "description": "Целостность для стабильного состояния"
  },
  "borderland_threshold": {
    "type": "integer",
    "default": 30,
    "range": [10, 50],
    "description": "Целостность для состояния пограничья"
  },
  "breach_threshold": {
    "type": "integer",
    "default": 0,
    "range": [0, 20],
    "description": "Целостность для состояния прорыва"
  },
  "decay_per_turn": {
    "type": "integer",
    "default": 5,
    "range": [0, 15],
    "description": "Потеря целостности за день"
  },
  "decay_in_breach": {
    "type": "integer",
    "default": 10,
    "range": [5, 25],
    "description": "Дополнительная потеря при прорыве"
  }
}
```

### 4.6 Конфигурация времени

```json
{
  "starting_time": {
    "type": "integer",
    "default": 8,
    "range": [0, 23],
    "description": "Начальное время дня"
  },
  "travel_cost": {
    "type": "integer",
    "default": 4,
    "range": [1, 12],
    "description": "Время на путешествие между регионами"
  },
  "explore_cost": {
    "type": "integer",
    "default": 2,
    "range": [1, 8],
    "description": "Время на исследование текущего региона"
  },
  "rest_cost": {
    "type": "integer",
    "default": 8,
    "range": [4, 16],
    "description": "Время на отдых"
  },
  "combat_cost": {
    "type": "integer",
    "default": 2,
    "range": [1, 6],
    "description": "Время на бой"
  },
  "strengthen_cost": {
    "type": "integer",
    "default": 4,
    "range": [2, 8],
    "description": "Время на укрепление якоря"
  }
}
```

### 4.7 Конфигурация боя

```json
{
  "base_damage_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Глобальный множитель урона"
  },
  "defense_effectiveness": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Множитель снижения защиты"
  },
  "starting_hand_size": {
    "type": "integer",
    "default": 5,
    "range": [3, 7],
    "description": "Карты, выдаваемые в начале боя"
  },
  "cards_per_turn": {
    "type": "integer",
    "default": 1,
    "range": [1, 3],
    "description": "Карты, выдаваемые каждый ход"
  },
  "max_hand_size": {
    "type": "integer",
    "default": 10,
    "range": [5, 15],
    "description": "Максимум карт в руке"
  },
  "enemy_damage_scaling": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Множитель урона врагов"
  },
  "enemy_health_scaling": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 3.0],
    "description": "Множитель здоровья врагов"
  },
  "critical_hit_chance": {
    "type": "float",
    "default": 0.1,
    "range": [0.0, 0.3],
    "description": "Базовый шанс критического удара"
  },
  "critical_hit_multiplier": {
    "type": "float",
    "default": 2.0,
    "range": [1.5, 3.0],
    "description": "Множитель урона критического удара"
  }
}
```

### 4.8 Конфигурация экономики

```json
{
  "card_acquisition_enabled": {
    "type": "boolean",
    "default": true,
    "description": "Разрешить получение новых карт"
  },
  "faith_cost_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Множитель стоимости веры карт"
  },
  "event_reward_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Множитель наград событий"
  },
  "combat_reward_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Множитель наград за бой"
  }
}
```

### 4.9 Конфигурация условий окончания

```json
{
  "death_health": {
    "type": "integer",
    "default": 0,
    "range": [0, 0],
    "description": "Здоровье, вызывающее смерть (всегда 0)"
  },
  "pressure_loss": {
    "type": "integer",
    "default": 100,
    "range": [80, 100],
    "description": "Pressure, вызывающий поражение"
  },
  "victory_quests": {
    "type": "string[]",
    "default": [],
    "description": "Квесты, необходимые для победы"
  },
  "max_days": {
    "type": "integer | null",
    "default": null,
    "range": [10, 100],
    "description": "Максимум дней (null = без ограничения)"
  },
  "all_anchors_saved": {
    "type": "boolean",
    "default": false,
    "description": "Победа, если все якоря стабилизированы"
  }
}
```

### 4.10 Модификаторы сложности

```json
{
  "easy": {
    "health_multiplier": 1.5,
    "damage_taken_multiplier": 0.75,
    "faith_multiplier": 1.5,
    "pressure_multiplier": 0.75,
    "enemy_health_multiplier": 0.8
  },
  "normal": {
    "health_multiplier": 1.0,
    "damage_taken_multiplier": 1.0,
    "faith_multiplier": 1.0,
    "pressure_multiplier": 1.0,
    "enemy_health_multiplier": 1.0
  },
  "hard": {
    "health_multiplier": 0.9,
    "damage_taken_multiplier": 1.25,
    "faith_multiplier": 0.8,
    "pressure_multiplier": 1.5,
    "enemy_health_multiplier": 1.3
  },
  "nightmare": {
    "health_multiplier": 0.75,
    "damage_taken_multiplier": 1.5,
    "faith_multiplier": 0.6,
    "pressure_multiplier": 2.0,
    "enemy_health_multiplier": 1.5
  }
}
```

---

## 5. Правила валидации

### 5.1 Валидация параметров

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-PRM-001 | Все значения должны быть в определенных диапазонах | Ошибка |
| VAL-PRM-002 | Стартовые значения не могут превышать максимумы | Ошибка |
| VAL-PRM-003 | Пороги должны быть правильно упорядочены | Ошибка |
| VAL-PRM-004 | Множители должны быть положительными | Ошибка |
| VAL-PRM-005 | Целые значения должны быть целыми | Ошибка |
| VAL-PRM-006 | Точность float максимум 2 десятичных знака | Предупреждение |

### 5.2 Валидация согласованности

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-CON-001 | starting_health <= max_health | Ошибка |
| VAL-CON-002 | starting_faith <= max_faith | Ошибка |
| VAL-CON-003 | low < medium < high < critical (пороги) | Ошибка |
| VAL-CON-004 | breach < borderland < stable (якорь) | Ошибка |
| VAL-CON-005 | starting_time in range [0, 23] | Ошибка |

### 5.3 Валидация геймплея

| Правило | Описание | Серьезность |
|---------|----------|-------------|
| VAL-GAM-001 | Игра должна быть выигрываемой | Предупреждение |
| VAL-GAM-002 | Рост pressure не может быть отрицательным | Предупреждение |
| VAL-GAM-003 | Отдых должен восстанавливать здоровье | Предупреждение |
| VAL-GAM-004 | Минимум одно условие победы | Ошибка |

---

## 6. Контракт API

### 6.1 Интерфейс конфигурации

```swift
protocol BalanceConfigurationProvider {
    func getValue<T>(_ key: String) -> T?
    func getValue<T>(_ key: String, default: T) -> T
    func getSection(_ name: String) -> [String: Any]?
}
```

### 6.2 Структура конфигурации баланса

```swift
struct BalanceConfiguration: Codable {
    let resources: ResourceConfiguration
    let pressure: PressureConfiguration
    let anchor: AnchorConfiguration
    let time: TimeConfiguration
    let combat: CombatConfiguration
    let economy: EconomyConfiguration
    let endConditions: EndConditionConfiguration
    let difficultyModifiers: DifficultyModifiers?

    static let `default`: BalanceConfiguration
}
```

### 6.3 Интеграция с Registry

```swift
extension ContentRegistry {
    func loadBalancePack(from url: URL) throws -> LoadedPack
    func getBalanceConfig() -> BalanceConfiguration?
    func applyDifficultyModifiers(_ difficulty: DifficultyLevel)
}
```

### 6.4 Runtime доступ

```swift
// Доступ к значениям баланса во время игры
let maxHealth = BalanceConfig.current.resources.maxHealth
let pressurePerDay = BalanceConfig.current.pressure.pressurePerDay
let travelCost = BalanceConfig.current.time.travelCost
```

---

## 7. Точки расширения

### 7.1 Пользовательские параметры

Новые параметры могут быть добавлены в существующие секции:

```json
{
  "resources": {
    "custom_parameter": {
      "type": "integer",
      "default": 10,
      "range": [1, 100]
    }
  }
}
```

Неизвестные параметры игнорируются, но логируются.

### 7.2 Переопределение формул

Формулы урона в бою могут быть настроены:

```json
{
  "combat": {
    "damage_formula": "base_power * multiplier + bonus",
    "defense_formula": "min(incoming_damage, defense_value)"
  }
}
```

### 7.3 Условные модификаторы

Модификаторы могут быть условными:

```json
{
  "conditional_modifiers": [
    {
      "condition": "pressure > 70",
      "modifier": { "enemy_damage_scaling": 1.2 }
    }
  ]
}
```

---

## 8. Пресеты сложности

### 8.1 Легкий режим

- На 50% больше стартового здоровья
- На 25% меньше получаемого урона
- На 50% больше получаемой веры
- На 25% медленнее рост pressure

### 8.2 Нормальный режим

- Базовые значения
- Стандартная прогрессия
- Сбалансированный вызов

### 8.3 Сложный режим

- На 10% меньше стартового здоровья
- На 25% больше получаемого урона
- На 20% меньше получаемой веры
- На 50% быстрее рост pressure
- На 30% сильнее враги

### 8.4 Кошмарный режим

- На 25% меньше стартового здоровья
- На 50% больше получаемого урона
- На 40% меньше получаемой веры
- На 100% быстрее рост pressure
- На 50% сильнее враги

---

## 9. Примеры

### 9.1 Минимальный Balance Pack

```json
// manifest.json
{
  "id": "easy-mode",
  "name": { "en": "Easy Mode" },
  "version": "1.0.0",
  "type": "balance",
  "core_version_min": "1.0.0",
  "balance_path": "balance.json",
  "difficulty_level": "easy"
}

// balance.json
{
  "resources": {
    "max_health": 15,
    "starting_health": 15
  },
  "pressure": {
    "pressure_per_day": 3
  }
}
```

### 9.2 Полное переопределение баланса

```json
{
  "resources": {
    "max_health": 10,
    "starting_health": 10,
    "max_faith": 10,
    "starting_faith": 3,
    "health_regen_per_rest": 3
  },
  "pressure": {
    "starting_pressure": 30,
    "max_pressure": 100,
    "pressure_per_day": 5,
    "thresholds": {
      "low": 30,
      "medium": 50,
      "high": 70,
      "critical": 90
    }
  },
  "anchor": {
    "max_integrity": 100,
    "default_strengthen_amount": 20,
    "default_strengthen_cost": 5,
    "stable_threshold": 70,
    "decay_per_turn": 5,
    "defile_cost_hp": 5,
    "dark_strengthen_cost_hp": 3
  },
  "time": {
    "starting_time": 8,
    "travel_cost": 4,
    "rest_cost": 8
  },
  "combat": {
    "starting_hand_size": 5,
    "cards_per_turn": 1,
    "enemy_damage_scaling": 1.0
  },
  "end_conditions": {
    "pressure_loss": 100,
    "victory_quests": ["main_quest"]
  }
}
```

---

## 10. Совместимость модов

### 10.1 Порядок загрузки

1. Сначала загружаются значения по умолчанию ядра
2. Balance packs переопределяют в порядке загрузки
3. Поздние packs переопределяют ранние

### 10.2 Частичные переопределения

Packs должны указывать только измененные значения:

```json
{
  "pressure": {
    "pressure_per_day": 3
  }
}
```

Остальные значения сохраняют значения по умолчанию.

### 10.3 Наследование

Packs могут наследовать от других balance packs:

```json
{
  "extends": "base-balance",
  "overrides": {
    "resources": { "max_health": 12 }
  }
}
```

---

## 11. Связанные документы

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - Общее руководство по pack
- [SPEC_CAMPAIGN_PACK.md](./SPEC_CAMPAIGN_PACK.md) - Спецификация Campaign pack
- [SPEC_CHARACTER_PACK.md](./SPEC_CHARACTER_PACK.md) - Спецификация Character pack
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Архитектура Engine

---

**Контроль документа**

| Версия | Дата | Автор | Изменения |
|--------|------|-------|-----------|
| 1.0 | 2026-01-20 | Claude | Начальная спецификация |
