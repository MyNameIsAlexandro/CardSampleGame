# HANDOFF: CardSampleGame (Twilight Marches)

> Файл для передачи контекста между Mac (Claude Code) и iPhone (Claude App)

---

## Текущий статус

**Дата:** 2026-01-19
**Ветка:** `claude/add-game-tests-PxCCP`
**Последний коммит:** `b762f56 Remove misleading @available deprecated from test-retained methods`

### Что сделано

- [x] Engine-First Architecture (Phase 3.5) - полностью реализована
- [x] EngineSave.swift - persistence без WorldState
- [x] Engine-First Views (EngineRegionCardView, EngineRegionDetailView, EngineEventLogView)
- [x] Новые actions: dismissCurrentEvent, dismissDayEvent
- [x] Fix determinism: регионы сортируются по имени
- [x] Fix warnings: убраны @available deprecated с test-retained методов
- [x] Все 170+ тестов проходят
- [x] 0 warnings в production коде

### Архитектура

```
UI Layer (SwiftUI Views)
    │ читает engine.* (@Published)
    │ пишет engine.performAction()
    ▼
TwilightGameEngine (Single Source of Truth)
    │
    ▼
EngineSave (Codable) - для persistence
```

---

## Что осталось (Phase 4+)

| Задача | Phase | Приоритет |
|--------|-------|-----------|
| Card system migration | Phase 4 | High |
| RNG state persistence | Phase 4 | Medium |
| Trade/Market UI через Engine | Phase 4 | Medium |
| Content from JSON | Phase 5 | Low |
| Localization | Phase 5 | Low |
| Remove Legacy Adapters | После миграции | Low |

---

## Ключевые файлы

| Файл | Описание |
|------|----------|
| `Engine/Core/TwilightGameEngine.swift` | Главный движок, Single Source of Truth |
| `Engine/Core/EngineSave.swift` | Структура для save/load |
| `Engine/Core/TwilightGameAction.swift` | Все игровые действия |
| `Views/WorldMapView.swift` | Engine-First Views |
| `Models/WorldState.swift` | Legacy, используется через adapters |
| `CHANGELOG_ENGINE_FIRST.md` | Лог изменений для аудиторов |

---

## Как продолжить работу

### На Mac (Claude Code)
```bash
cd "/Users/abondarenko/Library/Mobile Documents/com~apple~CloudDocs/XCode/CardSampleGame"
git pull  # если были изменения
claude    # запустить Claude Code
```

### На iPhone (Claude App)
1. Открой этот файл через GitHub или iCloud
2. Скопируй контекст в Claude App:
```
Продолжаем работу над CardSampleGame (Twilight Marches).
Ветка: claude/add-game-tests-PxCCP
Последний коммит: b762f56
Архитектура: Engine-First, TwilightGameEngine = Single Source of Truth
Что сделано: Phase 3.5 завершена, все тесты проходят
Нужно: [твоя задача]
```

### Перед уходом с Mac
```bash
git add .
git commit -m "WIP: [описание где остановился]"
git push
# Попроси Claude Code обновить этот файл:
# "обнови HANDOFF.md с текущим статусом"
```

---

## Известные проблемы

*Нет активных проблем*

---

## Заметки

- Legacy код (WorldState, Adapters) оставлен для обратной совместимости
- UI постепенно мигрирует на Engine-First
- Тесты используют WorldState напрямую (это нормально - "retained for tests")

---

*Обновлено: 2026-01-19 Claude Code*
