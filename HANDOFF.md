# HANDOFF: CardSampleGame (Twilight Marches)

> Файл для передачи контекста между Mac (Claude Code) и iPhone (Claude App)

---

## Текущий статус

**Дата:** 2026-01-19
**Ветка:** `claude/add-game-tests-PxCCP`
**Последний коммит:** `988a81e Add JSON content files for Phase 5`

### Что сделано сегодня (продолжение)

- [x] Combat L10n keys добавлены в Helpers/Localization.swift
- [x] CombatView мигрирован на L10n (~60 строк)
- [x] WorldMapView частично мигрирован на L10n
- [x] Переводы EN/RU для combat UI добавлены
- [x] Анализ Legacy Adapters - всё ещё используются
- [x] Resources/Content/regions.json создан (7 регионов)
- [x] Resources/Content/anchors.json создан (6 якорей)

### Release Gates Status

| Gate | Статус | Описание |
|------|--------|----------|
| Gate 1 | ✅ PASSED | CombatView мигрирован на Engine-First |
| Gate 2 | ✅ PASSED | Нет randomElement/shuffled |
| Gate 3 | ✅ PASSED | Save/Load parity tests pass |
| Gate 4 | ✅ PASSED | 20 ActIPlaythroughTests pass |

### Прогресс по Audit Issues

| Issue | Статус | Описание |
|-------|--------|----------|
| #1 Hardcoded Strings | 🟡 Частично | Combat L10n done, Views partial |
| #3 Legacy Adapters | 🟡 Анализ | ContentView/GameBoardView используют legacy init |
| #8 JSON Content | 🟡 Начато | regions.json, anchors.json созданы |

---

## Приоритеты (по порядку)

1. ~~**[КРИТИЧНО]** Исправить Gate 1: Мигрировать CombatView на Engine~~ ✅ DONE
2. ~~Gate 3: Тест Save/Load parity~~ ✅ DONE
3. ~~Gate 4: Act I end-to-end тест~~ ✅ DONE
4. 🟡 Локализация: Вынести hardcoded strings в Localizable.strings (Combat done)
5. 🟡 JSON Content: Перенести контент в JSON файлы (regions/anchors done)
6. Remove Legacy: Удалить EngineAdapters после миграции ContentView

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
