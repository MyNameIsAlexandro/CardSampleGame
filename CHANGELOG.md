# Changelog

## [2026-01-22] Data-Driven Hero System

### Изменения после Audit v1.1

#### Новая архитектура персонажей

**Было:** Хардкод `HeroClass` enum с 5 классами (warrior, mage, ranger, priest, shadow)

**Стало:** Data-driven система через `HeroRegistry` + `heroes.json`

| Компонент | Действие |
|-----------|----------|
| `Engine/Heroes/HeroClass.swift` | ❌ Удалён |
| `Resources/Content/heroes.json` | ✅ Создан (5 персонажей) |
| `Engine/Heroes/HeroRegistry.swift` | ✅ Загрузка из JSON |
| `Engine/Heroes/HeroDefinition.swift` | ✅ Протокол + StandardHeroDefinition |
| `ContentView.swift` | ✅ Использует HeroRegistry |
| `Models/GameSave.swift` | ✅ Добавлен heroId |

#### Персонажи в heroes.json

| ID | Имя | Способность |
|----|-----|-------------|
| warrior_ragnar | Рагнар | Ярость (+2 урон при HP < 50%) |
| mage_elvira | Эльвира | Медитация (+1 вера в конце хода) |
| ranger_thorin | Торин | Выслеживание (+1 кубик первая атака) |
| priest_aurelius | Аврелий | Благословение (-1 урон от тьмы) |
| shadow_umbra | Умбра | Засада (+3 урон по полным HP) |

#### Удалённый legacy код

| Файл | Что удалено |
|------|-------------|
| `TwilightMarchesCards.swift` | `createGuardians()` (~120 строк) |
| `TwilightMarchesCards.swift` | `createStartingDeck()` функции (~220 строк) |
| `HeroDefinition.swift` | `HeroStats.default` |
| `HeroAbility.swift` | `HeroAbility.defaultAbility` |

#### Обновлённая документация

| Документ | Изменения |
|----------|-----------|
| `HEROES_MODULE.md` | Переписан под data-driven (v2.0) |
| `ENGINE_ARCHITECTURE.md` | Убраны ссылки на HeroClass |
| `TECHNICAL_DOCUMENTATION.md` | Обновлена структура Heroes/ |
| `CARDS_MODULE.md` | Обновлён пример интеграции |
| `GAME_DESIGN_DOCUMENT.md` | Удалены разделы 7.1-7.4 (старые персонажи) |
| `CONTENT_PACK_GUIDE.md` | Полностью переписан на русском |

#### Исправления UI

| Проблема | Решение |
|----------|---------|
| Иконки показывали текст "sword.2" | `Image(systemName:)` вместо `Text()` |
| Иконка силы не отображалась | `bolt.fill` вместо несуществующего `sword.fill` |
| Иконка Рагнара не отображалась | `figure.fencing` вместо `sword.2` |
| Несогласованность статов | Карточка и панель показывают одинаковые статы |

---

### Коммиты

```
420972f Rewrite CONTENT_PACK_GUIDE.md in Russian with current API
4c46d42 Remove obsolete character descriptions from game design doc
a4753a4 Update documentation: remove obsolete HeroClass references
723579c Migrate to data-driven hero system
37c5eaf Fix hardcoded strings: localize HeroClass, curses, abilities, errors
```

---

### Статус тестов

- ✅ Build: SUCCEEDED
- ✅ Tests: ALL PASSED
- ✅ HeroRegistry: Загружает героев из JSON
- ✅ CardRegistry: Возвращает стартовые колоды
- ✅ UI: Отображает персонажей корректно

---

### Принцип добавления нового персонажа

1. Добавить запись в `Resources/Content/heroes.json`
2. Если новая способность — добавить в `HeroAbility.forAbilityId()`
3. Пересобрать приложение

**Никаких изменений в Swift коде для нового персонажа не требуется.**
