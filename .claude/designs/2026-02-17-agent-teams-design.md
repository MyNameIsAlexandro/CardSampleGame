# Agent Teams Integration Design

**Дата:** 2026-02-17
**Статус:** Одобрен
**Цель:** Автоматизировать управление фазами разработки через Agent Teams, убрав ручное переключение `./phase.sh`.

---

## Проблема

Текущая система фаз требует ручного переключения:
1. Выйти из Claude Code
2. Запустить `./phase.sh <phase>` в терминале
3. Вернуться в Claude Code

При cross-phase изменениях цикл повторяется. Это замедляет работу и создаёт friction.

## Решение

Заменить ручное переключение фаз системой Agent Teams:
- Каждая фаза = отдельный агент со своей зоной ответственности
- Lead-агент (основная сессия) координирует и маршрутизирует задачи
- Auditor-агент проверяет результаты (read-only)
- Пользователь сохраняет контроль через cross-phase одобрения

## Архитектура

```
Пользователь → Lead Agent → Phase Agents → Auditor → [Внешний аудит]
```

### Роли

| Роль | Файл | Зона редактирования | Тип |
|------|------|---------------------|-----|
| Lead | основная сессия | ничего напрямую (делегирует) | — |
| code-agent | `.claude/agents/code-agent.md` | App/**, Views/**, ViewModels/**, Models/**, Managers/**, Utilities/**, Packages/*/Sources/**, DevTools/**, .github/ci/**, project.pbxproj | general-purpose |
| test-agent | `.claude/agents/test-agent.md` | CardSampleGameTests/**, Packages/*/Tests/**, gate_inventory.json, project.pbxproj | general-purpose |
| docs-agent | `.claude/agents/docs-agent.md` | Docs/**, README.md | general-purpose |
| content-agent | `.claude/agents/content-agent.md` | Packages/StoryPacks/**, Packages/CharacterPacks/**, **/Resources/**, *.lproj/**, Assets.xcassets/** | general-purpose |
| auditor | `.claude/agents/auditor.md` | ничего (read-only) | Explore |

### Параллельность

- `code-agent` + `test-agent` — допускается одновременно (зоны не пересекаются: Sources vs Tests)
- Все остальные комбинации — только последовательно
- `contract` фаза — только ручная в основной сессии Lead

### Cross-phase протокол

1. Агент обнаруживает необходимость изменения вне своей зоны
2. Агент отправляет Lead сообщение: ЧТО / ЗАЧЕМ / ВЛИЯНИЕ
3. Lead формирует STOP-отчёт пользователю
4. Пользователь одобряет → Lead делегирует нужному phase-агенту
5. Агент НЕ делает изменение сам — только описывает что нужно

### Аудит

- После завершения phase-агентов Lead спавнит auditor
- Auditor проверяет: архитектуру (CLAUDE.md), контракты, качество, gate-тесты
- По запросу Lead формирует пакет для внешнего аудита: diff + результаты тестов + отчёт аудитора

## Workflow

1. Пользователь описывает задачу (фичу/баг/рефакторинг)
2. Lead декомпозирует на фазовые задачи
3. Lead создаёт Team + Tasks
4. Lead спавнит нужных phase-агентов (code + tests параллельно если нужно)
5. Агенты работают, координируются через task list
6. Cross-phase запросы → через Lead к пользователю
7. После завершения → auditor
8. При необходимости → внешний аудит

## Изменения в проекте

### Новые файлы
- `.claude/agents/code-agent.md`
- `.claude/agents/test-agent.md`
- `.claude/agents/docs-agent.md`
- `.claude/agents/content-agent.md`
- `.claude/agents/auditor.md`

### Изменения в существующих файлах
- `CLAUDE.md` — секция 12 (Agent Teams Integration)
- `CLAUDE.md` — секция 11 (ссылка на Agent Teams как основной режим)
- `.claude/settings.local.json` — убрать deny rules (контроль через промпты агентов)

### Не меняется
- `phase.sh` — остаётся как fallback для ручного режима
- `.claude/phase.json` — остаётся для обратной совместимости

## Ограничения

- Модель может нарушить scope (нет технической блокировки) — митигируется STOP-протоколом и аудитором
- Больше токенов — каждый агент = отдельный контекст
- Экспериментальная фича Agent Teams — может меняться
