# Audit: Engine-First Architecture v1.1

> Комплексный аудит после Phase 3.5 Engine-First Architecture

---

## Замечания Аудита

### 1. Hardcoded Strings / Локализация

**Статус:** Требует исправления

Это не ломает механику, но ломает масштабирование контента и картридж-подход. Чем позже - тем дороже.

**Решение:** Вынести все строки в Localizable.strings или создать StringsProvider.

---

### 2. Тесты "на двух стульях"

**Статус:** Частично закрыто

Важно закрепить в CI: **интеграционные engine-тесты должны быть gate**, иначе можно случайно вернуться к legacy-проверкам.

**Решение:** Настроить GitHub Actions с обязательным прогоном Engine/* и Integration/* тестов.

---

### 3. Legacy Adapters / Дубли моделей

**Статус:** Переходная стадия

Это нормальная переходная стадия, но её нельзя оставлять навсегда — иначе движок перестаёт быть переиспользуемым.

**Файлы:**
- `EngineAdapters.swift` - "строительные леса"
- `WorldState.swift` - legacy runtime

**Решение:** После полной миграции UI удалить adapters, оставив только чистый Engine.

---

### 4. Audit файлы

**Статус:** Исправлено

Файлы `Audit.rtf` и `Audit_1.rtf` объединены в `AUDIT_ENGINE_FIRST_v1_1.md` для читаемого diff в git.

---

### 5. MIGRATION_PLAN.md

**Статус:** Требует проверки

Phase 3.5 "Engine-first views" должен быть отмечен как DONE.

---

### 6. CI Configuration

**Статус:** Требует настройки

В CI необходимо:
- Обязательно прогонять `CardSampleGameTests/Engine/*` и `Integration/*`
- Отдельно `RegressionPlaythroughTests` как gate на merge

---

### 7. Удаление Адаптеров

**Статус:** Phase 4+

Файлы `EngineAdapters.swift` и легаси `WorldState.swift` сейчас служат "строительными лесами".
После полной миграции оставить только чистый Engine.

---

### 8. JSON Content

**Статус:** Phase 5

Сейчас контент (регионы, события) загружается через `TwilightMarchesCodeContentProvider`.
Перенести в реальные JSON-файлы для поддержки DLC и обновлений "по воздуху" (без пересборки приложения).

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

- [ ] save → load → save даёт эквивалентное состояние (по ключевым полям)
- [ ] oneTime events / cooldown / event log сохраняются и восстанавливаются

**Статус:** ⏳ Требует тестирования

### Gate 4 — Product Sanity (must pass)

- [ ] Можно пройти Act I end-to-end через engine-first flow
- [ ] Метрики Акта I в пределах QA targets (или осознанно обновлены)

**Статус:** ⏳ Требует ручного тестирования

---

## История изменений

| Дата | Версия | Изменения |
|------|--------|-----------|
| 2026-01-19 | v1.1 | Объединение Audit.rtf + Audit_1.rtf, добавлены Release Gates |
| 2026-01-19 | v1.0 | Первичный аудит после Audit v1.1 |

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
