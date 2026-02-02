# Спецификация Balance Pack

> **Версия:** 1.0
> **Статус:** Активна
> **Обновлено:** Январь 2026

---

## 1. Обзор

### 1.1 Назначение

Balance Pack предоставляет конфигурацию игры без добавления нового контента. Он настраивает числа, веса, стоимости и другие параметры для изменения сложности, темпа и ощущений от игры.

### 1.2 Область применения

Данная спецификация охватывает:
- Структуру пака баланса и манифест
- Категории конфигурации (ресурсы, давление, время, бой, экономика)
- Границы параметров и валидацию
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

### 2.1 Основная функциональность

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-BAL-001 | Пак ДОЛЖЕН предоставлять balance.json | Обязательно |
| FR-BAL-002 | Пак НЕ ДОЛЖЕН вводить новый контент | Обязательно |
| FR-BAL-003 | Пак МОЖЕТ переопределять любой параметр | Опционально |
| FR-BAL-004 | Неуказанные параметры используют значения по умолчанию | Обязательно |
| FR-BAL-005 | Пак МОЖЕТ определять пресеты сложности | Опционально |

### 2.2 Конфигурация ресурсов

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-RES-001 | Пак МОЖЕТ настраивать максимальное здоровье | Опционально |
| FR-RES-002 | Пак МОЖЕТ настраивать начальные ресурсы | Опционально |
| FR-RES-003 | Пак МОЖЕТ настраивать скорости восстановления | Опционально |
| FR-RES-004 | Значения ресурсов ДОЛЖНЫ быть положительными | Обязательно |

### 2.3 Конфигурация давления

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-PRS-001 | Пак МОЖЕТ настраивать пороги давления | Опционально |
| FR-PRS-002 | Пак МОЖЕТ настраивать скорости роста давления | Опционально |
| FR-PRS-003 | Значения давления ДОЛЖНЫ быть 0-100 | Обязательно |
| FR-PRS-004 | Пороги ДОЛЖНЫ быть упорядочены | Обязательно |

### 2.4 Конфигурация времени

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-TIM-001 | Пак МОЖЕТ настраивать стоимость действий | Опционально |
| FR-TIM-002 | Пак МОЖЕТ настраивать длительность дня | Опционально |
| FR-TIM-003 | Значения времени ДОЛЖНЫ быть положительными | Обязательно |

### 2.5 Конфигурация боя

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-CMB-001 | Пак МОЖЕТ настраивать формулы урона | Опционально |
| FR-CMB-002 | Пак МОЖЕТ настраивать механики защиты | Опционально |
| FR-CMB-003 | Пак МОЖЕТ настраивать правила добора карт | Опционально |

### 2.6 Условия окончания

| ID | Требование | Приоритет |
|----|------------|-----------|
| FR-END-001 | Пак МОЖЕТ изменять условия поражения | Опционально |
| FR-END-002 | Пак МОЖЕТ изменять условия победы | Опционально |
| FR-END-003 | Хотя бы одно условие победы обязательно | Обязательно |

---

## 3. Нефункциональные требования

### 3.1 Производительность

| ID | Требование | Цель |
|----|------------|------|
| NFR-PERF-001 | Время загрузки конфига | < 50мс |
| NFR-PERF-002 | Максимальный размер файла | 100KB |
| NFR-PERF-003 | Поиск параметра | O(1) |

### 3.2 Совместимость

| ID | Требование | Цель |
|----|------------|------|
| NFR-COMP-001 | Версия ядра | Семантическое версионирование |
| NFR-COMP-002 | Совместимость с кампаниями | Любая кампания |
| NFR-COMP-003 | Совместимость с инвестигаторами | Любой инвестигатор |

### 3.3 Безопасность

| ID | Требование | Цель |
|----|------------|------|
| NFR-SAF-001 | Границы параметров | Валидированы |
| NFR-SAF-002 | Деление на ноль | Предотвращено |
| NFR-SAF-003 | Защита от переполнения | Обеспечена |

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
    "description": "Вера при посещении якорей"
  },
  "faith_per_combat_win": {
    "type": "integer",
    "default": 1,
    "range": [0, 5],
    "description": "Вера за победу в бою"
  }
}
```

### 4.4 Конфигурация давления

```json
{
  "starting_pressure": {
    "type": "integer",
    "default": 30,
    "range": [0, 100],
    "description": "Начальное мировое давление"
  },
  "max_pressure": {
    "type": "integer",
    "default": 100,
    "range": [50, 100],
    "description": "Максимальное давление (условие поражения)"
  },
  "pressure_per_day": {
    "type": "integer",
    "default": 5,
    "range": [0, 20],
    "description": "Рост давления за день"
  },
  "pressure_per_breach": {
    "type": "integer",
    "default": 10,
    "range": [0, 30],
    "description": "Давление от прорыва региона"
  },
  "pressure_reduction_per_strengthen": {
    "type": "integer",
    "default": 5,
    "range": [0, 20],
    "description": "Снижение давления при укреплении якоря"
  },
  "thresholds": {
    "low": {
      "type": "integer",
      "default": 30,
      "description": "Порог низкого давления"
    },
    "medium": {
      "type": "integer",
      "default": 50,
      "description": "Порог среднего давления"
    },
    "high": {
      "type": "integer",
      "default": 70,
      "description": "Порог высокого давления"
    },
    "critical": {
      "type": "integer",
      "default": 90,
      "description": "Критический порог давления"
    }
  }
}
```

### 4.5 Конфигурация якоря

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
    "description": "Целостность, восстанавливаемая при укреплении"
  },
  "default_strengthen_cost": {
    "type": "integer",
    "default": 5,
    "range": [1, 15],
    "description": "Стоимость укрепления в вере"
  },
  "stable_threshold": {
    "type": "integer",
    "default": 70,
    "description": "Целостность для стабильного состояния"
  },
  "borderland_threshold": {
    "type": "integer",
    "default": 30,
    "description": "Целостность для пограничного состояния"
  },
  "breach_threshold": {
    "type": "integer",
    "default": 0,
    "description": "Целостность для состояния прорыва"
  },
  "decay_per_turn": {
    "type": "integer",
    "default": 5,
    "description": "Потеря целостности за день"
  },
  "decay_in_breach": {
    "type": "integer",
    "default": 10,
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
    "description": "Начальное время суток"
  },
  "travel_cost": {
    "type": "integer",
    "default": 4,
    "description": "Время на путешествие между регионами"
  },
  "explore_cost": {
    "type": "integer",
    "default": 2,
    "description": "Время на исследование текущего региона"
  },
  "rest_cost": {
    "type": "integer",
    "default": 8,
    "description": "Время на отдых"
  },
  "combat_cost": {
    "type": "integer",
    "default": 2,
    "description": "Время на бой"
  },
  "strengthen_cost": {
    "type": "integer",
    "default": 4,
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
    "description": "Глобальный множитель урона"
  },
  "defense_effectiveness": {
    "type": "float",
    "default": 1.0,
    "description": "Множитель эффективности защиты"
  },
  "starting_hand_size": {
    "type": "integer",
    "default": 5,
    "description": "Карты в руке в начале боя"
  },
  "cards_per_turn": {
    "type": "integer",
    "default": 1,
    "description": "Карты, добираемые каждый ход"
  },
  "max_hand_size": {
    "type": "integer",
    "default": 10,
    "description": "Максимум карт в руке"
  },
  "enemy_damage_scaling": {
    "type": "float",
    "default": 1.0,
    "description": "Множитель урона врагов"
  },
  "enemy_health_scaling": {
    "type": "float",
    "default": 1.0,
    "description": "Множитель здоровья врагов"
  },
  "critical_hit_chance": {
    "type": "float",
    "default": 0.1,
    "description": "Базовый шанс критического удара"
  },
  "critical_hit_multiplier": {
    "type": "float",
    "default": 2.0,
    "description": "Множитель критического урона"
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
    "description": "Множитель стоимости карт в вере"
  },
  "event_reward_multiplier": {
    "type": "float",
    "default": 1.0,
    "description": "Множитель наград за события"
  },
  "combat_reward_multiplier": {
    "type": "float",
    "default": 1.0,
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
    "description": "Здоровье, вызывающее смерть (всегда 0)"
  },
  "pressure_loss": {
    "type": "integer",
    "default": 100,
    "description": "Давление, вызывающее поражение"
  },
  "victory_quests": {
    "type": "string[]",
    "default": [],
    "description": "Квесты, необходимые для победы"
  },
  "max_days": {
    "type": "integer | null",
    "default": null,
    "description": "Максимум дней (null = неограниченно)"
  },
  "all_anchors_saved": {
    "type": "boolean",
    "default": false,
    "description": "Победа при стабилизации всех якорей"
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

| Правило | Описание | Серьёзность |
|---------|----------|-------------|
| VAL-PRM-001 | Все значения в пределах определённых диапазонов | Ошибка |
| VAL-PRM-002 | Начальные значения не превышают максимумы | Ошибка |
| VAL-PRM-003 | Пороги правильно упорядочены | Ошибка |
| VAL-PRM-004 | Множители положительные | Ошибка |
| VAL-PRM-005 | Целые значения должны быть целыми | Ошибка |
| VAL-PRM-006 | Точность float максимум 2 знака | Предупреждение |

### 5.2 Валидация согласованности

| Правило | Описание | Серьёзность |
|---------|----------|-------------|
| VAL-CON-001 | starting_health <= max_health | Ошибка |
| VAL-CON-002 | starting_faith <= max_faith | Ошибка |
| VAL-CON-003 | low < medium < high < critical (пороги) | Ошибка |
| VAL-CON-004 | breach < borderland < stable (якорь) | Ошибка |
| VAL-CON-005 | starting_time в диапазоне [0, 23] | Ошибка |

### 5.3 Валидация геймплея

| Правило | Описание | Серьёзность |
|---------|----------|-------------|
| VAL-GAM-001 | Игра должна быть проходимой | Предупреждение |
| VAL-GAM-002 | Рост давления не может быть отрицательным | Предупреждение |
| VAL-GAM-003 | Отдых должен восстанавливать здоровье | Предупреждение |
| VAL-GAM-004 | Хотя бы одно условие победы | Ошибка |

---

## 6. API контракт

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

### 6.3 Интеграция с реестром

```swift
extension ContentRegistry {
    func loadBalancePack(from url: URL) throws -> LoadedPack
    func getBalanceConfig() -> BalanceConfiguration?
    func applyDifficultyModifiers(_ difficulty: DifficultyLevel)
}
```

### 6.4 Runtime доступ

```swift
// Доступ к значениям баланса в runtime
let maxHealth = BalanceConfig.current.resources.maxHealth
let pressurePerDay = BalanceConfig.current.pressure.pressurePerDay
let travelCost = BalanceConfig.current.time.travelCost
```

---

## 7. Точки расширения

### 7.1 Кастомные параметры

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

Формулы боевого урона могут быть кастомизированы:

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

### 8.1 Лёгкий режим (Easy)

- На 50% больше стартового здоровья
- На 25% меньше получаемого урона
- На 50% больше получаемой веры
- На 25% медленнее рост давления

### 8.2 Нормальный режим (Normal)

- Базовые значения
- Стандартная прогрессия
- Сбалансированный вызов

### 8.3 Сложный режим (Hard)

- На 10% меньше стартового здоровья
- На 25% больше получаемого урона
- На 20% меньше получаемой веры
- На 50% быстрее рост давления
- На 30% сильнее враги

### 8.4 Кошмарный режим (Nightmare)

- На 25% меньше стартового здоровья
- На 50% больше получаемого урона
- На 40% меньше получаемой веры
- На 100% быстрее рост давления
- На 50% сильнее враги

---

## 9. Примеры

### 9.1 Минимальный Balance Pack

```json
// manifest.json
{
  "id": "easy-mode",
  "name": { "en": "Easy Mode", "ru": "Лёгкий режим" },
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
2. Паки баланса переопределяют в порядке загрузки
3. Более поздние паки переопределяют более ранние

### 10.2 Частичные переопределения

Паки указывают только изменённые значения:

```json
{
  "pressure": {
    "pressure_per_day": 3
  }
}
```

Остальные значения сохраняют значения по умолчанию.

### 10.3 Наследование

Паки могут наследоваться от других паков баланса:

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

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - Общий гайд по пакам
- [SPEC_CAMPAIGN_PACK.md](./SPEC_CAMPAIGN_PACK.md) - Спецификация Campaign Pack
- [SPEC_CHARACTER_PACK.md](./SPEC_CHARACTER_PACK.md) - Спецификация Character Pack
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Архитектура движка

---

**Контроль документа**

| Версия | Дата | Автор | Изменения |
|--------|------|-------|-----------|
| 1.0 | 2026-01-20 | Claude | Начальная спецификация |
| 1.0-RU | 2026-01-20 | Claude | Перевод на русский |
