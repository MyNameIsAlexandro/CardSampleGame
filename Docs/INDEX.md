# Documentation Index / Карта Документации

> **GOVERNANCE DOCUMENT**
>
> Этот документ определяет структуру документации проекта.
> Все участники проекта обязаны следовать данной карте.

**Проект:** ECHO: Legends of the Veil (раб. назв. «Грань Миров»)
**Последнее обновление:** 18 февраля 2026

---

## Быстрый старт

| Вопрос | Документ |
|--------|----------|
| Что это за игра? | [PROJECT_BIBLE.md](./Design/PROJECT_BIBLE.md) |
| Как устроен движок? | [ENGINE_ARCHITECTURE.md](./Technical/ENGINE_ARCHITECTURE.md) |
| Как создать контент-пак? | [SPEC_CAMPAIGN_PACK.md](./Specs/SPEC_CAMPAIGN_PACK.md) |
| Качество и тесты? | [QUALITY_CONTROL_MODEL.md](./QA/QUALITY_CONTROL_MODEL.md) |

---

## Структура документации

### Design/ — Концепция и геймдизайн
Документы для понимания «что мы делаем и зачем», механики и системы.

| Документ | Описание |
|----------|----------|
| [PROJECT_BIBLE.md](./Design/PROJECT_BIBLE.md) | Единая точка входа: идея, механики, архитектура |
| [GAME_DESIGN_DOCUMENT.md](./Design/GAME_DESIGN_DOCUMENT.md) | Полный GDD |
| [EXPLORATION_CORE_DESIGN.md](./Design/EXPLORATION_CORE_DESIGN.md) | Дизайн механик исследования |
| [ENCOUNTER_SYSTEM_DESIGN.md](./Design/ENCOUNTER_SYSTEM_DESIGN.md) | Дизайн системы энкаунтеров |
| [COMBAT_DIPLOMACY_SPEC.md](./Design/COMBAT_DIPLOMACY_SPEC.md) | Спецификация Disposition Combat v2.0 (compact reference → SoT в design doc) |
| [Disposition Combat Design v2.5](../docs/plans/2026-02-18-disposition-combat-design.md) | Полный дизайн-документ Disposition Combat (SoT) |

### Technical/ — Техническая документация
Архитектура движка и реализация.

| Документ | Описание | Роль |
|----------|----------|------|
| [ENGINE_ARCHITECTURE.md](./Technical/ENGINE_ARCHITECTURE.md) | Архитектура движка, слои, инварианты | **ЗАКОН** |
| [EVENT_MODULE_ARCHITECTURE.md](./Technical/EVENT_MODULE_ARCHITECTURE.md) | Событийная система, Inline/MiniGame | **МОДУЛЬ** |
| [CONTENT_PACK_GUIDE.md](./Technical/CONTENT_PACK_GUIDE.md) | Руководство по созданию паков | **GUIDE** |
| [PACK_EDITOR_GUIDE.md](./Technical/PACK_EDITOR_GUIDE.md) | Руководство пользователя PackEditor (RU) | **GUIDE** |
| [PACK_EDITOR_GUIDE_EN.md](./Technical/PACK_EDITOR_GUIDE_EN.md) | PackEditor User Guide (EN) | **GUIDE** |

### Specs/ — Спецификации форматов
Формальные спецификации Content Pack форматов.

| Документ | Описание |
|----------|----------|
| [SPEC_CAMPAIGN_PACK.md](./Specs/SPEC_CAMPAIGN_PACK.md) | Спецификация Campaign Pack |
| [SPEC_BALANCE_PACK.md](./Specs/SPEC_BALANCE_PACK.md) | Спецификация Balance Pack |
| [SPEC_CHARACTER_PACK.md](./Specs/SPEC_CHARACTER_PACK.md) | Спецификация Character Pack |

**Русские версии:**
- [SPEC_CAMPAIGN_PACK_RU.md](./Specs/SPEC_CAMPAIGN_PACK_RU.md)
- [SPEC_BALANCE_PACK_RU.md](./Specs/SPEC_BALANCE_PACK_RU.md)
- [SPEC_CHARACTER_PACK_RU.md](./Specs/SPEC_CHARACTER_PACK_RU.md)

### QA/ — Тестирование
Чеклисты и планы тестирования.

| Документ | Описание |
|----------|----------|
| [QUALITY_CONTROL_MODEL.md](./QA/QUALITY_CONTROL_MODEL.md) | Модель контроля качества, обязательные gate-тесты | **ЗАКОН** |
| [TESTING_GUIDE.md](./QA/TESTING_GUIDE.md) | Руководство по запуску gate/модульных тестов | **GUIDE** |
| [ENCOUNTER_TEST_MODEL.md](./QA/ENCOUNTER_TEST_MODEL.md) | Тестовая модель EncounterEngine (инварианты, структура) | **МОДУЛЬ** |
| [RITUAL_COMBAT_TEST_MODEL.md](./QA/RITUAL_COMBAT_TEST_MODEL.md) | Тестовая модель Phase 3 Disposition Combat (disposition, momentum, 35+ тестов) | **МОДУЛЬ** |
| [QA_ACT_I_CHECKLIST.md](./QA/QA_ACT_I_CHECKLIST.md) | Чеклист тестирования Act I |

### Archive/ — Архив
Исторические документы для справки.

| Документ | Описание |
|----------|----------|
| AUDIT_REPORT_v1.2.md | Отчёт аудита v1.2 |
| CAMPAIGN_IMPLEMENTATION_REPORT.md | Отчёт реализации кампании |
| CONTENT_CACHE_GUIDE.md | Руководство по кешированию |
| LEGACY_MIGRATION_PLAN.md | Старый план миграции |
| TECHNICAL_DOCUMENTATION.md | Старая техдокументация |

---

## Служебные документы

| Документ | Описание |
|----------|----------|
| **INDEX.md** | Вы здесь |
| [SPRINT.md](./SPRINT.md) | Центральный планировщик: Phase 1–3, текущий фокус, бэклог |
| [plans/2026-02-07-audit-refactor-phase2-epics.md](./plans/2026-02-07-audit-refactor-phase2-epics.md) | Леджер эпиков Phase 2 (audit/refactor) + бэклог (Epic 15+) |
| [plans/2026-02-18-disposition-combat-design.md](../docs/plans/2026-02-18-disposition-combat-design.md) | Disposition Combat v2.5 — SoT для боевой механики |

---

## Иерархия приоритетов

При конфликте информации между документами:

```
1. PROJECT_BIBLE.md           ← Высший приоритет для КОНЦЕПЦИИ
2. ENGINE_ARCHITECTURE.md     ← Высший приоритет для КОДА
3. SPEC_*.md                  ← Высший приоритет для ФОРМАТОВ
4. QUALITY_CONTROL_MODEL.md   ← Высший приоритет для КАЧЕСТВА
```

---

## Структура проекта

```
CardSampleGame/
├── Docs/                        # Документация
│   ├── Design/                  # Концепция и геймдизайн
│   ├── Technical/               # Техническая документация
│   ├── Specs/                   # Спецификации форматов
│   ├── QA/                      # Тестирование
│   ├── Archive/                 # Архив
│   └── INDEX.md                 # Этот файл
│
├── Packages/                    # Swift Packages
│   ├── TwilightEngine/          # Игровой движок (runtime)
│   │   ├── PackAuthoring/      # Authoring tools (отдельный target)
│   │   └── Tests/              # Engine gate tests (INV_*, LayerTests, IntegrationTests)
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
    ├── TestHelpers/             # Утилиты для тестов
    ├── Unit/                    # Юнит тесты модулей
    │   ├── ContentPackTests/    # ContentPacks система
    │   ├── SaveLoadTests        # Save/Load
    │   └── HeroRegistryTests    # HeroRegistry
    ├── GateTests/               # Gate/Compliance тесты
    │   ├── AuditGateTests       # Архитектурные требования
    │   ├── DesignSystemComplianceTests
    │   ├── CodeHygieneTests
    │   ├── ContentValidationTests
    │   ├── ConditionValidatorTests
    │   └── LocalizationValidatorTests
    └── Views/                   # UI тесты
```

---

## Автоматические проверки

Тесты, обеспечивающие соблюдение стандартов:

| Тест | Что проверяет |
|------|---------------|
| AuditGateTests | Критические инварианты движка (40+ проверок) |
| DesignSystemComplianceTests | Использование DesignSystem токенов |
| CodeHygieneTests | Doc comments, размер файлов |
| ContentValidationTests | Валидность cross-references в JSON |
| ConditionValidatorTests | Типизированные conditions (защита от опечаток) |
| LocalizationValidatorTests | Канонический подход к локализации |

---

## Контакты и ресурсы

- **Репозиторий:** github.com/MyNameIsAlexandro/CardSampleGame
- **Тесты:** 700+ (SPM + Xcode, all passing)
- **Build:** SUCCESS
- **Текущая фаза:** Phase 3 — Disposition Combat (design complete, documentation sync)
