# Карта Ответственности Документов
## Documentation Responsibility Map

> **GOVERNANCE DOCUMENT**
>
> Этот документ определяет **правила управления знаниями проекта**.
> Все участники проекта обязаны следовать данной карте ответственности.
> В случае спора — ссылайтесь на этот документ.

---

## Какой документ открывать?

| Если ваш вопрос... | Документ-ответчик | Роль |
|--------------------|-------------------|------|
| "Какова философия игры? Что чувствует игрок?" | [GAME_DESIGN_DOCUMENT.md](./GAME_DESIGN_DOCUMENT.md) | **ВИДЕНИЕ** (Vision) |
| "Как именно работает эта механика? Какая формула?" | [EXPLORATION_CORE_DESIGN.md](./EXPLORATION_CORE_DESIGN.md) | **СПЕЦИФИКАЦИЯ** (Spec) |
| "Как правильно написать код? Куда положить файл?" | [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) | **ЗАКОН** (Law) |
| "Как работает Event Module? Inline vs Mini-Game?" | [EVENT_MODULE_ARCHITECTURE.md](./EVENT_MODULE_ARCHITECTURE.md) | **МОДУЛЬ** (Module) |
| "Где сейчас лежит этот класс? Какой статус у фичи?" | [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) | **КАРТА КОДА** (Map) |
| "Готова ли фича? Как её проверить?" | [QA_ACT_I_CHECKLIST.md](./QA_ACT_I_CHECKLIST.md) | **СУДЬЯ** (Judge) |
| "Что мы уже сделали и зафиксировали?" | [CAMPAIGN_IMPLEMENTATION_REPORT.md](./CAMPAIGN_IMPLEMENTATION_REPORT.md) | **ИСТОРИЯ** (History) 🔒 |

---

## Иерархия Разрешения Конфликтов

Если информация в документах противоречит друг другу, **побеждает документ выше в списке**:

```
1. ENGINE_ARCHITECTURE.md     ← Высший приоритет для КОДА
2. EXPLORATION_CORE_DESIGN.md ← Высший приоритет для МЕХАНИК
3. GAME_DESIGN_DOCUMENT.md    ← Высший приоритет для ИДЕИ
4. TECHNICAL_DOCUMENTATION.md ← Отражение реальности
```

### Примеры разрешения конфликтов:

| Конфликт | Победитель | Почему |
|----------|------------|--------|
| GDD: "сохранять в XML" vs ARCH: "JSON Codable" | ARCH | Код важнее формулировки |
| GDD: "монстры бьют больно" vs CORE: "урон = power × 1.5" | CORE | Формула точнее |
| CORE: формула верна, но убивает атмосферу | GDD | Идея важнее математики |
| TECH противоречит ARCH | ARCH | TECH нужно обновить |

### ❌ Анти-пример (как НЕ надо)

> Разработчик меняет формулу деградации (`tensionIncrement = 3`),
> ориентируясь только на `TECHNICAL_DOCUMENTATION.md`,
> не проверив `ENGINE_ARCHITECTURE.md` и `QA_ACT_I_CHECKLIST.md`.
>
> **Это нарушение governance.**
>
> ✅ **Правильное действие:**
> 1. Изменить формулу в `EXPLORATION_CORE_DESIGN.md`
> 2. Обновить конфиг в `ENGINE_ARCHITECTURE.md` (если затрагивает архитектуру)
> 3. Обновить/добавить тест в `QA_ACT_I_CHECKLIST.md`
> 4. Только потом менять код

---

## Когда обновлять документы

| Действие | Что обновлять |
|----------|---------------|
| Меняем формулу / правило | EXPLORATION_CORE + QA |
| Меняем архитектуру / слои | ENGINE_ARCHITECTURE |
| Добавили файл / класс | TECHNICAL_DOCUMENTATION |
| Завершили milestone | CAMPAIGN_REPORT (или новый) |
| Изменили философию | GAME_DESIGN_DOCUMENT |

---

## Практический Workflow

### 1. Перед началом задачи

```
□ Открыть ENGINE_ARCHITECTURE.md
  → Проверить слой (Core / Config / Runtime)
  → Проверить инварианты

□ Открыть EXPLORATION_CORE_DESIGN.md
  → Взять структуру данных (JSON/Struct)
  → Взять формулы
```

### 2. В процессе кодинга

```
□ НЕ смотреть в старый код как на истину
□ Смотреть в ENGINE_ARCHITECTURE.md → "Инварианты"
□ Код должен делать нарушения инвариантов невозможными
```

### 3. После написания кода

```
□ Открыть QA_ACT_I_CHECKLIST.md
  → Написать тест, покрывающий кейс

□ Обновить TECHNICAL_DOCUMENTATION.md
  → Если добавлены новые файлы/модули
```

---

## Визуализация экосистемы

```
┌─────────────────────────────────────────────────────────┐
│                   WHY & WHAT (Design)                   │
│  ┌─────────────────────┐    ┌─────────────────────┐    │
│  │ GAME_DESIGN_DOC     │───▶│ EXPLORATION_CORE    │    │
│  │ Vision & Pillars    │    │ Mechanics & Formulas│    │
│  └─────────────────────┘    └──────────┬──────────┘    │
└────────────────────────────────────────┼────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────┐
│                    HOW (Engineering)                    │
│  ┌─────────────────────┐    ┌─────────────────────┐    │
│  │ ENGINE_ARCHITECTURE │───▶│ TECHNICAL_DOC       │    │
│  │ Rules & Layers      │    │ Project Structure   │    │
│  └─────────────────────┘    └──────────┬──────────┘    │
└────────────────────────────────────────┼────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────┐
│                     VERIFICATION                        │
│  ┌─────────────────────┐    ┌─────────────────────┐    │
│  │ QA_ACT_I_CHECKLIST  │───▶│ CAMPAIGN_REPORT     │    │
│  │ Tests & Metrics     │    │ Progress Log 🔒     │    │
│  └─────────────────────┘    └─────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Файлы документации

| Файл | Строк | Статус |
|------|-------|--------|
| ENGINE_ARCHITECTURE.md | ~700 | ✅ Source of Truth |
| EVENT_MODULE_ARCHITECTURE.md | ~450 | ✅ Active |
| EXPLORATION_CORE_DESIGN.md | ~3100 | ✅ Active |
| GAME_DESIGN_DOCUMENT.md | ~1050 | ✅ Active |
| TECHNICAL_DOCUMENTATION.md | ~1100 | ✅ Active |
| QA_ACT_I_CHECKLIST.md | ~640 | ✅ Active |
| CAMPAIGN_IMPLEMENTATION_REPORT.md | ~500 | 🔒 Frozen v0.6.0 |
| **INDEX.md** | — | 📍 Вы здесь |

---

**Последнее обновление:** 18 января 2026
