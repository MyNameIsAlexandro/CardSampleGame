# Audit: Engine-First Architecture v1.1

> Комплексный аудит после Phase 3.5 Engine-First Architecture

---

## Замечания Аудита

### 1. Hardcoded Strings / Локализация

**Статус:** 🟡 Частично исправлено (2026-01-19)

**Что сделано:**
- Добавлены L10n ключи для Combat UI (~60 ключей)
- CombatView мигрирован на L10n
- WorldMapView частично мигрирован
- EN/RU переводы добавлены

**Остаётся:**
- Полная миграция всех Views
- Проверка что все ключи используются

---

### 2. Тесты "на двух стульях"

**Статус:** ✅ Закрыто

CI настроен: `.github/workflows/tests.yml` запускает все Engine/* и Integration/* тесты.
`RegressionPlaythroughTests` включены в прогон.

---

### 3. Legacy Adapters / Дубли моделей

**Статус:** 🟡 Документировано, Phase 4+

**Анализ (2026-01-19):**
- `ContentView.swift` и `GameBoardView.swift` используют legacy init
- Адаптеры нужны для bridge WorldState → Engine
- Требуется миграция ContentView на Engine-First init

**Файлы:**
- `Engine/Migration/EngineAdapters.swift` - "строительные леса"
- `Engine/Migration/LegacyAdapters.swift` - protocol bridges
- `Models/WorldState.swift` - legacy runtime

---

### 4. Audit файлы

**Статус:** ✅ Исправлено

Файлы `Audit.rtf` и `Audit_1.rtf` объединены в `AUDIT_ENGINE_FIRST_v1_1.md`.

---

### 5. MIGRATION_PLAN.md

**Статус:** ✅ Обновлён

Phase 3.5 отмечен как DONE.

---

### 6. CI Configuration

**Статус:** ✅ Настроено

`.github/workflows/tests.yml` настроен с:
- Прогон `CardSampleGameTests/Engine/*` и `Integration/*`
- `RegressionPlaythroughTests` как gate

---

### 7. Удаление Адаптеров

**Статус:** 📋 Phase 4+ (запланировано)

Требуется:
1. Мигрировать ContentView на Engine-First init
2. Мигрировать GameBoardView на Engine-First init
3. Удалить legacy adapters

---

### 8. JSON Content

**Статус:** ✅ Создано (2026-01-19)

**Созданные файлы:**
```
Resources/Content/
├── regions.json (7 регионов)
├── anchors.json (6 якорей)
├── quests.json (4 квеста)
├── challenges.json (7 челленджей)
└── events/
    ├── pool_common.json (3 события)
    ├── pool_village.json (3 события)
    ├── pool_forest.json (3 события)
    ├── pool_swamp.json (3 события)
    ├── pool_mountain.json (3 события)
    ├── pool_sacred.json (2 события)
    ├── pool_breach.json (3 события)
    └── pool_boss.json (1 босс-событие)
```

**Итого:** 24 события, 7 регионов, 6 якорей, 4 квеста, 7 челленджей

**Остаётся:**
- Реализовать загрузку JSON в `JSONContentProvider`
- Переключить на JSON вместо CodeContentProvider

---

## Release Gates

### Gate 1 — Engine-First Invariant (must pass)

- [x] UI **нигде** не мутирует legacy state напрямую (WorldMapView)
- [x] Все действия проходят через `engine.performAction()` (WorldMapView)
- [x] `Phase3ContractTests` подтверждают это
- [x] CombatView мигрирован на Engine-First (2026-01-19)

**Статус:** ✅ PASSED

**Изменения:**
- Добавлены combat actions в `TwilightGameAction` (combatInitialize, combatAttack, combatApplyEffect, etc.)
- Добавлен `CombatActionEffect` enum для боевых эффектов
- CombatView теперь использует `engine.performAction()` для всех мутаций
- EventView получил Engine-First архитектуру с legacy fallback

### Gate 2 — Determinism Invariant (must pass)

- [x] Один seed → один outcome (regression + metrics)
- [x] Никаких `randomElement()/shuffled()/Double.random()` в world/core пути

**Статус:** ✅ Пройден. Нет недетерминистичных вызовов в production коде.

### Gate 3 — Save/Load Parity (must pass)

- [x] save → load → save даёт эквивалентное состояние (по ключевым полям)
- [x] oneTime events / cooldown / event log сохраняются и восстанавливаются
- [x] `testSaveLoadRoundtripPreservesState` проходит
- [x] `testDeckStatePersistsAcrossSaveLoad` проходит

**Статус:** ✅ PASSED

### Gate 4 — Product Sanity (must pass)

- [x] Можно пройти Act I end-to-end через engine-first flow
- [x] 20 ActIPlaythroughTests проходят
- [x] Все key checkpoints: init, tension growth, quest progression, victory/defeat

**Статус:** ✅ PASSED

---

## История изменений

| Дата | Версия | Изменения |
|------|--------|-----------|
| 2026-01-19 | v1.2 | JSON Content создан, Localization частично выполнена, Audit issues обновлены |
| 2026-01-19 | v1.1 | Объединение Audit.rtf + Audit_1.rtf, добавлены Release Gates |
| 2026-01-19 | v1.0 | Первичный аудит после Audit v1.1 |

---

## Резюме по Audit Issues

| # | Issue | Статус |
|---|-------|--------|
| 1 | Hardcoded Strings | 🟡 Частично (Combat done) |
| 2 | Тесты на двух стульях | ✅ Закрыто |
| 3 | Legacy Adapters | 🟡 Phase 4+ |
| 4 | Audit файлы | ✅ Закрыто |
| 5 | MIGRATION_PLAN.md | ✅ Закрыто |
| 6 | CI Configuration | ✅ Закрыто |
| 7 | Удаление Адаптеров | 📋 Phase 4+ |
| 8 | JSON Content | ✅ Создано |

**Итого:** 5/8 закрыто, 3/8 требуют дальнейшей работы (Phase 4+)

---

## Предыдущие замечания (Audit v1.0)

### Решённые проблемы

| # | Проблема | Статус |
|---|----------|--------|
| 1 | Legacy WorldState Object - UI привязан к WorldState | ✅ Engine-First Views |
| 4 | Phase 3 - единственная точка изменения state | ✅ `performAction()` |
| 5 | Seed задаётся после WorldState() | ✅ Исправлен порядок |
| 6 | Дублирование day-start логики | ✅ `TwilightPressureRules` |
| 7 | Singleton RNG без reset | ✅ `resetToSystem()` в tearDown |
| 8 | Legacy Adapters Overhead | ✅ Engine-First Views |
| 9 | Дублирование моделей | ⏳ Переходная стадия |

---

*Обновлено: 2026-01-19*
