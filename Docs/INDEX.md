# Documentation Index / Карта Документации

> **GOVERNANCE DOCUMENT**
>
> Этот документ определяет структуру документации проекта.
> Все участники проекта обязаны следовать данной карте.

**Проект:** ECHO: Legends of the Veil (раб. назв. «Грань Миров»)
**Последнее обновление:** 26 января 2026

---

## Быстрый старт

| Вопрос | Документ |
|--------|----------|
| Что это за игра? | [PROJECT_BIBLE.md](./Concept/PROJECT_BIBLE.md) |
| Как устроен движок? | [ENGINE_ARCHITECTURE.md](./Technical/ENGINE_ARCHITECTURE.md) |
| Как создать контент-пак? | [SPEC_CAMPAIGN_PACK.md](./Specs/SPEC_CAMPAIGN_PACK.md) |
| Что изменилось? | [CHANGELOG.md](./CHANGELOG.md) |
| Статус проекта? | [AUDIT_REPORT_v2.0.md](./Audit/AUDIT_REPORT_v2.0.md) |

---

## Структура документации

### Concept/ — Концепция и видение
Документы для понимания «что мы делаем и зачем».

| Документ | Описание | Аудитория |
|----------|----------|-----------|
| [PROJECT_BIBLE.md](./Concept/PROJECT_BIBLE.md) | Единая точка входа: идея, механики, архитектура | Все |

### Design/ — Геймдизайн
Детальное описание игровых механик и систем.

| Документ | Описание |
|----------|----------|
| [GAME_DESIGN_DOCUMENT.md](./Design/GAME_DESIGN_DOCUMENT.md) | Полный GDD |
| [EXPLORATION_CORE_DESIGN.md](./Design/EXPLORATION_CORE_DESIGN.md) | Дизайн механик исследования |

### Technical/ — Техническая документация
Архитектура движка и реализация.

| Документ | Описание | Роль |
|----------|----------|------|
| [ENGINE_ARCHITECTURE.md](./Technical/ENGINE_ARCHITECTURE.md) | Архитектура движка, слои, инварианты | **ЗАКОН** |
| [EVENT_MODULE_ARCHITECTURE.md](./Technical/EVENT_MODULE_ARCHITECTURE.md) | Событийная система, Inline/MiniGame | **МОДУЛЬ** |
| [CONTENT_PACK_GUIDE.md](./Technical/CONTENT_PACK_GUIDE.md) | Руководство по созданию паков | **GUIDE** |

### Specs/ — Спецификации форматов
Формальные спецификации Content Pack форматов.

| Документ | Описание |
|----------|----------|
| [SPEC_CAMPAIGN_PACK.md](./Specs/SPEC_CAMPAIGN_PACK.md) | Спецификация Campaign Pack |
| [SPEC_BALANCE_PACK.md](./Specs/SPEC_BALANCE_PACK.md) | Спецификация Balance Pack |
| [SPEC_INVESTIGATOR_PACK.md](./Specs/SPEC_INVESTIGATOR_PACK.md) | Спецификация Character/Investigator Pack |

**Русские версии:**
- [SPEC_CAMPAIGN_PACK_RU.md](./Specs/SPEC_CAMPAIGN_PACK_RU.md)
- [SPEC_BALANCE_PACK_RU.md](./Specs/SPEC_BALANCE_PACK_RU.md)
- [SPEC_INVESTIGATOR_PACK_RU.md](./Specs/SPEC_INVESTIGATOR_PACK_RU.md)

### Audit/ — Отчёты аудита
Результаты проверок качества и соответствия архитектуре.

| Документ | Описание | Статус |
|----------|----------|--------|
| [AUDIT_REPORT_v2.0.md](./Audit/AUDIT_REPORT_v2.0.md) | Финальный отчёт аудита v2.0 | **ТЕКУЩИЙ** |
| [AUDIT_ENGINE_FIRST_v1_1.md](./Audit/AUDIT_ENGINE_FIRST_v1_1.md) | Аудит Engine-First v1.1 | Завершён |
| [AUDIT_3.0.md](./Audit/AUDIT_3.0.md) | Требования Аудит 3.0 | Референс |

### Migration/ — Планы миграции
Дорожные карты и планы переходов.

| Документ | Описание |
|----------|----------|
| [MIGRATION_PLAN.md](./Migration/MIGRATION_PLAN.md) | Engine v1.0 Release Gates |
| [MIGRATION_GUIDE.md](./Migration/MIGRATION_GUIDE.md) | Руководство по миграции |

### QA/ — Тестирование
Чеклисты и планы тестирования.

| Документ | Описание |
|----------|----------|
| [QA_ACT_I_CHECKLIST.md](./QA/QA_ACT_I_CHECKLIST.md) | Чеклист тестирования Act I |

### Archive/ — Архив
Исторические документы для справки.

| Документ | Описание |
|----------|----------|
| ARCHITECTURE.md | Старая версия архитектуры |
| AUDIT_REPORT_v1.2.md | Отчёт аудита v1.2 |
| CAMPAIGN_IMPLEMENTATION_REPORT.md | Отчёт реализации кампании |
| CONTENT_CACHE_GUIDE.md | Руководство по кешированию |
| LEGACY_MIGRATION_PLAN.md | Старый план миграции |
| TECHNICAL_DOCUMENTATION.md | Старая техдокументация |

---

## Служебные документы

| Документ | Описание |
|----------|----------|
| [CHANGELOG.md](./CHANGELOG.md) | История изменений |
| [HANDOFF.md](./HANDOFF.md) | Передача контекста между сессиями |
| **INDEX.md** | Вы здесь |

---

## Иерархия приоритетов

При конфликте информации между документами:

```
1. PROJECT_BIBLE.md           ← Высший приоритет для КОНЦЕПЦИИ
2. ENGINE_ARCHITECTURE.md     ← Высший приоритет для КОДА
3. SPEC_*.md                  ← Высший приоритет для ФОРМАТОВ
4. AUDIT_REPORT_v2.0.md       ← Высший приоритет для СТАТУСА
```

---

## Структура проекта

```
CardSampleGame/
├── Docs/                        # Документация
│   ├── Concept/                 # Концепция игры
│   ├── Design/                  # Геймдизайн
│   ├── Technical/               # Техническая документация
│   ├── Specs/                   # Спецификации форматов
│   ├── Audit/                   # Отчёты аудита
│   ├── Migration/               # Планы миграции
│   ├── QA/                      # Тестирование
│   ├── Archive/                 # Архив
│   ├── CHANGELOG.md
│   ├── HANDOFF.md
│   └── INDEX.md                 # Этот файл
│
├── Packages/                    # Swift Packages
│   ├── TwilightEngine/          # Игровой движок
│   ├── CharacterPacks/          # Паки персонажей
│   │   └── CoreHeroes/
│   └── StoryPacks/              # Сюжетные паки
│       └── Season1/
│           └── TwilightMarchesActI/
│
├── Views/                       # SwiftUI Views
├── Models/                      # Data Models
├── Utilities/                   # Utilities (DesignSystem, Localization)
└── CardSampleGameTests/         # Tests (256 тестов)
```

---

## Автоматические проверки

Тесты, обеспечивающие соблюдение стандартов:

| Тест | Что проверяет |
|------|---------------|
| DesignSystemComplianceTests | Использование DesignSystem токенов |
| CodeHygieneTests | Doc comments, размер файлов |
| ContentValidationTests | Валидность ссылок в JSON |
| AuditGateTests | Критические инварианты движка |

---

## Контакты и ресурсы

- **Репозиторий:** github.com/MyNameIsAlexandro/CardSampleGame
- **Тесты:** 256 passed, 0 failed
- **Build:** SUCCESS
