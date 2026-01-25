# Documentation Index
## Карта Документации

> **GOVERNANCE DOCUMENT**
>
> Этот документ определяет структуру документации проекта.
> Все участники проекта обязаны следовать данной карте.

---

## Активные Документы (Docs/)

| Документ | Описание | Роль |
|----------|----------|------|
| [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) | Архитектура движка, слои, инварианты | **ЗАКОН** |
| [EVENT_MODULE_ARCHITECTURE.md](./EVENT_MODULE_ARCHITECTURE.md) | Событийная система, Inline/MiniGame | **МОДУЛЬ** |
| [SPEC_CAMPAIGN_PACK.md](./SPEC_CAMPAIGN_PACK.md) | Спецификация Campaign Pack | **SPEC** |
| [SPEC_BALANCE_PACK.md](./SPEC_BALANCE_PACK.md) | Спецификация Balance Pack | **SPEC** |
| [SPEC_INVESTIGATOR_PACK.md](./SPEC_INVESTIGATOR_PACK.md) | Спецификация Investigator Pack | **SPEC** |
| [QA_ACT_I_CHECKLIST.md](./QA_ACT_I_CHECKLIST.md) | Чеклист тестирования Act I | **QA** |
| [AUDIT_REPORT_v2.0.md](./AUDIT_REPORT_v2.0.md) | Отчёт аудита v2.0 | **АУДИТ** |
| [CHANGELOG.md](./CHANGELOG.md) | История изменений | **ИСТОРИЯ** |
| **INDEX.md** | Вы здесь | **НАВИГАЦИЯ** |

### Русские версии спецификаций

- [SPEC_CAMPAIGN_PACK_RU.md](./SPEC_CAMPAIGN_PACK_RU.md)
- [SPEC_BALANCE_PACK_RU.md](./SPEC_BALANCE_PACK_RU.md)
- [SPEC_INVESTIGATOR_PACK_RU.md](./SPEC_INVESTIGATOR_PACK_RU.md)

---

## Архив (Docs/Archive/)

Устаревшие и исторические документы:

| Документ | Описание |
|----------|----------|
| ARCHITECTURE.md | Старая версия архитектуры |
| AUDIT_REPORT_v1.2.md | Отчёт аудита v1.2 |
| CAMPAIGN_IMPLEMENTATION_REPORT.md | Отчёт реализации кампании |
| CONTENT_CACHE_GUIDE.md | Руководство по кешированию |
| CONTENT_PACK_GUIDE.md | Руководство по Content Pack |
| EXPLORATION_CORE_DESIGN.md | Дизайн механик исследования |
| GAME_DESIGN_DOCUMENT.md | Game Design Document |
| LEGACY_MIGRATION_PLAN.md | План миграции на Engine-First |
| MIGRATION_GUIDE.md | Руководство по миграции |
| TECHNICAL_DOCUMENTATION.md | Техническая документация |

---

## Иерархия Приоритетов

При конфликте информации между документами:

```
1. ENGINE_ARCHITECTURE.md     ← Высший приоритет для КОДА
2. SPEC_*.md                  ← Высший приоритет для ФОРМАТОВ
3. QA_ACT_I_CHECKLIST.md      ← Высший приоритет для ТЕСТОВ
```

---

## Структура Проекта

```
CardSampleGame/
├── Docs/                        # Документация
│   ├── ENGINE_ARCHITECTURE.md   # Архитектура движка
│   ├── EVENT_MODULE_*.md        # Событийная система
│   ├── SPEC_*.md                # Спецификации паков
│   ├── QA_ACT_I_CHECKLIST.md    # QA чеклист
│   ├── CHANGELOG.md             # История изменений
│   ├── INDEX.md                 # Этот файл
│   └── Archive/                 # Архив старых документов
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
└── CardSampleGameTests/         # Tests
```

---

## Автоматические Проверки

Тесты, обеспечивающие соблюдение стандартов:

| Тест | Файл | Что проверяет |
|------|------|---------------|
| DesignSystemComplianceTests | Engine/ | Использование DesignSystem токенов |
| CodeHygieneTests | Engine/ | Doc comments, размер файлов |
| AuditGateTests | Engine/ | Критические инварианты |

---

**Последнее обновление:** 25 января 2026
