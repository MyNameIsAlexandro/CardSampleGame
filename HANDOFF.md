# HANDOFF: CardSampleGame (Twilight Marches)

> Файл для передачи контекста между Mac (Claude Code) и iPhone (Claude App)

---

## Текущий статус

**Дата:** 2026-01-19
**Ветка:** `claude/add-game-tests-PxCCP`
**Последний коммит:** `0e1639d Add CI workflow and audit documentation`

### Что сделано сегодня

- [x] AUDIT_ENGINE_FIRST_v1_1.md - объединённый аудит в markdown
- [x] .github/workflows/tests.yml - CI gates для тестов
- [x] Удалены Audit.rtf файлы
- [x] Проверка Release Gates (Gate 1 partial, Gate 2 passed)

### Release Gates Status

| Gate | Статус | Описание |
|------|--------|----------|
| Gate 1 | ✅ PASSED | CombatView мигрирован на Engine-First |
| Gate 2 | ✅ PASSED | Нет randomElement/shuffled |
| Gate 3 | ⏳ | Требует тестирования |
| Gate 4 | ⏳ | Требует ручного тестирования |

### Что исправлено (2026-01-19)

**CombatView.swift** теперь использует `engine.performAction()`:
- Добавлены combat actions в TwilightGameAction
- Добавлен CombatActionEffect enum
- CombatView и EventView мигрированы на Engine-First

---

## Приоритеты (по порядку)

1. ~~**[КРИТИЧНО]** Исправить Gate 1: Мигрировать CombatView на Engine~~ ✅ DONE
2. Локализация: Вынести hardcoded strings в Localizable.strings
3. Gate 3: Тест Save/Load parity
4. Gate 4: Act I end-to-end тест
5. JSON Content: Перенести контент в JSON файлы
6. Remove Legacy: Удалить EngineAdapters после полной миграции

---

## Архитектура

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

## Ключевые файлы

| Файл | Статус |
|------|--------|
| `Views/CombatView.swift` | ❌ Нарушает Gate 1 |
| `Views/WorldMapView.swift` | ✅ Engine-First |
| `Engine/Core/TwilightGameEngine.swift` | ✅ Single Source of Truth |
| `AUDIT_ENGINE_FIRST_v1_1.md` | Полный аудит |
| `.github/workflows/tests.yml` | CI gates |

---

## Как продолжить

### На iPhone (Claude App)
```
Продолжаем работу над CardSampleGame.
Ветка: claude/add-game-tests-PxCCP
Последний коммит: 0e1639d

КРИТИЧНО: CombatView нарушает Engine-First.
Нужно добавить combat actions в Engine:
- combatDealDamage(amount:)
- combatHeal(amount:)
- combatSpendFaith(amount:)

Файл: Views/CombatView.swift
```

### На Mac (Claude Code)
```bash
git pull
claude
# "продолжи работу над Gate 1 - миграция CombatView"
```

---

## Известные проблемы

1. **CombatView Gate 1 violation** - прямые мутации player
2. **Hardcoded strings** - Views не используют Localizable.strings
3. **Legacy adapters** - EngineAdapters.swift ещё существует

---

*Обновлено: 2026-01-19 Claude Code*
