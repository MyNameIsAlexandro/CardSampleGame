# Agent Teams Integration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create phase-specific agent definitions and update CLAUDE.md so that Lead can spawn phase-agents instead of manual `./phase.sh` switching.

**Architecture:** Custom agents in `.claude/agents/*.md` define per-phase scope. Lead orchestrates agents via Agent Teams. Deny rules removed from settings.local.json — control via agent prompts.

**Tech Stack:** Claude Code Agent Teams, `.claude/agents/*.md` custom agent definitions.

---

### Task 1: Create code-agent definition

**Files:**
- Create: `.claude/agents/code-agent.md`

**Step 1: Create the agent file**

```markdown
---
name: code-agent
description: "Phase:code agent — implementation of features in allowed source zones. Reads CLAUDE.md for project rules."
---

# code-agent — Phase:code

## Зона ответственности

Ты — code-agent в Agent Team. Твоя зона — **исходный код приложения**.

### Можно редактировать
- `App/**`
- `Views/**`
- `ViewModels/**`
- `Models/**`
- `Managers/**`
- `Utilities/**`
- `Packages/*/Sources/**`
- `DevTools/**`
- `.github/ci/**`
- `CardSampleGame.xcodeproj/project.pbxproj`

### Запрещено редактировать
- Тесты (`*Tests/**`, `CardSampleGameTests/**`)
- Документация (`Docs/**`, `README.md`)
- Контент-паки (`Packages/StoryPacks/**`, `Packages/CharacterPacks/**`)
- Локализация (`*.lproj/**`, `Assets.xcassets/**`)
- Контракт (`CLAUDE.md`, `.claude/**`)

## Обязательные правила

1. **Прочитай `CLAUDE.md`** перед началом работы — это инженерный контракт проекта.
2. **Заголовок файла** обязателен для каждого нового/изменённого Swift-файла (секция 5.2 CLAUDE.md).
3. **600 строк максимум** на файл (секция 5.1).
4. **Engine-first**: мутации состояния только через action pipeline (секция 1.1).
5. **Без TODO/FIXME** в production-коде (секция 5.3).
6. **Без системного RNG** в gameplay (секция 1.3).

## Cross-phase протокол

Если для выполнения задачи нужно изменение **вне твоей зоны**:

1. **НЕ делай изменение сам.**
2. Отправь Lead-агенту сообщение:

```
CROSS-PHASE ЗАПРОС от code-agent

Файл: <path>
Принадлежит: <phase>
ЧТО: <что именно нужно изменить>
ЗАЧЕМ: <почему без этого нельзя продолжить>
ВЛИЯНИЕ: <scope изменения>
```

3. Жди ответа от Lead. Продолжай работу над тем, что можешь сделать без этого изменения.

## Полезные команды

- Swift build (engine): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift build --package-path Packages/TwilightEngine`
- Xcode build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)"`
```

**Step 2: Verify file created**

Run: `cat .claude/agents/code-agent.md | head -5`
Expected: frontmatter with `name: code-agent`

**Step 3: Commit**

```bash
git add .claude/agents/code-agent.md
git commit -m "feat: add code-agent definition for Agent Teams"
```

---

### Task 2: Create test-agent definition

**Files:**
- Create: `.claude/agents/test-agent.md`

**Step 1: Create the agent file**

```markdown
---
name: test-agent
description: "Phase:tests agent — test model, gate tests, regression tests. Reads CLAUDE.md for project rules."
---

# test-agent — Phase:tests

## Зона ответственности

Ты — test-agent в Agent Team. Твоя зона — **тестовая модель**.

### Можно редактировать
- `CardSampleGameTests/**`
- `Packages/*/Tests/**`
- `TestResults/QualityDashboard/gate_inventory.json`
- `CardSampleGame.xcodeproj/project.pbxproj` (только для добавления тест-файлов)

### Запрещено редактировать
- Исходный код (`App/**`, `Views/**`, `Packages/*/Sources/**` и др.)
- Документация (`Docs/**`, `README.md`)
- Контент-паки (`Packages/StoryPacks/**`, `Packages/CharacterPacks/**`)
- Контракт (`CLAUDE.md`, `.claude/**`)

## Обязательные правила

1. **Прочитай `CLAUDE.md`** перед началом работы — секции 6 (тестовая модель) и 5.2 (заголовок файла).
2. **Заголовок файла** обязателен для тест-файлов (секция 5.2).
3. **Каждому дефекту — регрессионный тест** (секция 6.2).
4. **Детерминизм-проверки** для save/load/resume и RNG (секция 6.2).
5. **Gate-тесты** — минимальный набор перед интеграцией (секция 6.1).

## Cross-phase протокол

Если для написания теста нужно изменение в исходном коде (например, добавить public API):

1. **НЕ меняй исходный код сам.**
2. Отправь Lead-агенту сообщение:

```
CROSS-PHASE ЗАПРОС от test-agent

Файл: <path>
Принадлежит: phase:code
ЧТО: <что именно нужно изменить — например, сделать метод public>
ЗАЧЕМ: <какой тест требует этого доступа>
ВЛИЯНИЕ: <scope — read-only accessor / new method / etc.>
```

3. Жди ответа. Продолжай работу над другими тестами.

## Полезные команды

- Engine tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --package-path Packages/TwilightEngine`
- App gate tests: `bash .github/ci/run_xcodebuild.sh test -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" -only-testing:CardSampleGameTests/AuditArchitectureBoundaryGateTests`
- Snapshot release check: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash .github/ci/run_release_check_snapshot.sh TestResults/QualityDashboard CardSampleGame`
```

**Step 2: Commit**

```bash
git add .claude/agents/test-agent.md
git commit -m "feat: add test-agent definition for Agent Teams"
```

---

### Task 3: Create docs-agent definition

**Files:**
- Create: `.claude/agents/docs-agent.md`

**Step 1: Create the agent file**

```markdown
---
name: docs-agent
description: "Phase:docs agent — documentation, quality control docs, testing guides. Reads CLAUDE.md for project rules."
---

# docs-agent — Phase:docs

## Зона ответственности

Ты — docs-agent в Agent Team. Твоя зона — **документация**.

### Можно редактировать
- `Docs/**`
- `README.md`
- `TestResults/QualityDashboard/gate_inventory.json`

### Запрещено редактировать
- Исходный код (`App/**`, `Views/**`, `Packages/*/Sources/**` и др.)
- Тесты (`*Tests/**`)
- Контент-паки (`Packages/StoryPacks/**`, `Packages/CharacterPacks/**`)
- Контракт (`CLAUDE.md`, `.claude/**`)

## Обязательные правила

1. **Прочитай `CLAUDE.md`** перед началом — секции 6.4 (синхронизация документации) и 8 (Definition of Done).
2. При изменении gate-контрактов обновить: `Docs/QA/QUALITY_CONTROL_MODEL.md`, `Docs/QA/TESTING_GUIDE.md`, `gate_inventory.json`.
3. Документация должна соответствовать текущему состоянию кода — не опережать и не отставать.

## Cross-phase протокол

Аналогичен другим агентам. Если нужно изменение вне зоны — CROSS-PHASE ЗАПРОС к Lead.
```

**Step 2: Commit**

```bash
git add .claude/agents/docs-agent.md
git commit -m "feat: add docs-agent definition for Agent Teams"
```

---

### Task 4: Create content-agent definition

**Files:**
- Create: `.claude/agents/content-agent.md`

**Step 1: Create the agent file**

```markdown
---
name: content-agent
description: "Phase:content agent — story packs, character packs, localization, assets. Reads CLAUDE.md for project rules."
---

# content-agent — Phase:content

## Зона ответственности

Ты — content-agent в Agent Team. Твоя зона — **контент и локализация**.

### Можно редактировать
- `Packages/StoryPacks/**`
- `Packages/CharacterPacks/**`
- `**/Resources/**`
- `en.lproj/**`, `ru.lproj/**`
- `Assets.xcassets/**`

### Запрещено редактировать
- Исходный код (`App/**`, `Views/**`, `Packages/*/Sources/**` и др.)
- Тесты (`*Tests/**`)
- Документация (`Docs/**`, `README.md`)
- Контракт (`CLAUDE.md`, `.claude/**`)

## Обязательные правила

1. **Прочитай `CLAUDE.md`** перед началом — секции 3 (контент и паки) и 4 (локализация).
2. **Content IDs стабильные** — никаких UUID/random (секция 3.1).
3. **Backward compatibility** для локализованных карт (секция 3.3).
4. После изменений — пересобрать `.pack` и прогнать `BundledPacksValidationTests` (секция 3.4).
5. **SF Symbols** только через `Image(systemName:)` (секция 4.3).

## Cross-phase протокол

Аналогичен другим агентам. Если нужно изменение вне зоны — CROSS-PHASE ЗАПРОС к Lead.
```

**Step 2: Commit**

```bash
git add .claude/agents/content-agent.md
git commit -m "feat: add content-agent definition for Agent Teams"
```

---

### Task 5: Create auditor definition

**Files:**
- Create: `.claude/agents/auditor.md`

**Step 1: Create the agent file**

```markdown
---
name: auditor
description: "Read-only auditor — reviews code quality, architecture compliance, contract adherence. Never edits files."
allowedTools: [Read, Glob, Grep, Bash, LSP, WebSearch, WebFetch]
---

# auditor — Read-Only Reviewer

## Роль

Ты — аудитор в Agent Team. Ты **НЕ редактируешь файлы**. Только читаешь и проверяешь.

## Что проверяешь

### Архитектура (CLAUDE.md секции 1-2)
- Engine-first: мутации только через action pipeline
- Границы слоёв: engine без UI-фреймворков, bridge без доменной логики
- Determinism: нет системного RNG в gameplay
- External combat: транзакционный паттерн

### Качество кода (CLAUDE.md секции 5, 9)
- Файлы ≤ 600 строк
- Заголовки файлов
- Нет TODO/FIXME в production
- Нет запрещённых паттернов (секция 9)

### Тестовая модель (CLAUDE.md секция 6)
- Есть регрессионные тесты для изменений
- Gate-тесты проходят

### Локализация (CLAUDE.md секция 4)
- Нет raw ключей в UI
- SF Symbols через Image(systemName:)

## Формат отчёта

```
## Аудит-отчёт

**Scope:** <что проверялось>
**Статус:** PASS / FAIL / WARN

### Архитектура
- [ ] Engine-first соблюдён
- [ ] Границы слоёв не нарушены
- [ ] Determinism сохранён

### Качество
- [ ] Лимиты файлов соблюдены
- [ ] Заголовки на месте
- [ ] Нет TODO/FIXME

### Тесты
- [ ] Регрессионные тесты добавлены
- [ ] Gate-тесты проходят

### Находки
1. [CRITICAL/WARN/INFO] описание
```

## Полезные команды (только для чтения результатов)

- Engine tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --package-path Packages/TwilightEngine`
- Snapshot release check: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash .github/ci/run_release_check_snapshot.sh TestResults/QualityDashboard CardSampleGame`
```

**Step 2: Commit**

```bash
git add .claude/agents/auditor.md
git commit -m "feat: add auditor agent definition for Agent Teams"
```

---

### Task 6: Update CLAUDE.md — add section 12

**Files:**
- Modify: `CLAUDE.md` (append after section 11, line 279)

**Step 1: Add section 12**

Append after the last line of section 11:

```markdown

---

## 12) Agent Teams Integration

### 12.1 Phase-агенты
Проект использует Agent Teams для автоматического управления фазами.
Lead-агент декомпозирует задачу и спавнит phase-агентов:

| Агент | Файл | Зона | Тип |
|-------|------|------|-----|
| code-agent | `.claude/agents/code-agent.md` | Sources/**, App/**, Views/** и др. | general-purpose |
| test-agent | `.claude/agents/test-agent.md` | *Tests/**, gate_inventory.json | general-purpose |
| docs-agent | `.claude/agents/docs-agent.md` | Docs/**, README.md | general-purpose |
| content-agent | `.claude/agents/content-agent.md` | StoryPacks/**, CharacterPacks/**, lproj/** | general-purpose |
| auditor | `.claude/agents/auditor.md` | ничего (read-only) | Explore |

### 12.2 Параллельность
- `code-agent` + `test-agent` — допускается одновременно.
- Все остальные комбинации — только последовательно.
- `contract` фаза — только ручная в основной сессии Lead.

### 12.3 Cross-phase протокол в Agent Teams
Если phase-агент обнаруживает необходимость изменения вне своей зоны:
1. Агент отправляет Lead сообщение с обоснованием (ЧТО/ЗАЧЕМ/ВЛИЯНИЕ).
2. Lead формирует STOP-отчёт пользователю.
3. Пользователь одобряет → Lead делегирует нужному phase-агенту.
4. Агент НЕ делает изменение сам — только описывает что нужно.

### 12.4 Аудит
- После завершения phase-агентов Lead спавнит auditor для проверки.
- Auditor — read-only, не редактирует файлы.
- Auditor проверяет: архитектуру, контракты, качество, gate-тесты.
- По запросу Lead формирует пакет для внешнего аудита (diff + тесты + отчёт).

### 12.5 Запрещено в Agent Teams
- Phase-агенты не меняют phase.json и settings.local.json.
- Phase-агенты не меняют CLAUDE.md и .claude/agents/*.
- Phase-агенты не выходят за свою зону без одобрения.
- Auditor не редактирует файлы.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "contract: add Agent Teams Integration section to CLAUDE.md"
```

---

### Task 7: Update CLAUDE.md — update section 11

**Files:**
- Modify: `CLAUDE.md` (section 11.0, around line 217-221)

**Step 1: Update section 11.0 to reference Agent Teams**

Replace section 11.0 content with:

```markdown
### 11.0 Phase system overview
- Проект использует фазовую систему разработки для контроля целостности артефактов.
- **Основной режим:** Agent Teams (секция 12) — Lead-агент автоматически спавнит phase-агентов.
- **Fallback режим:** ручное переключение через `./phase.sh` (для работы без Agent Teams).
- Текущая фаза хранится в `.claude/phase.json` и переключается скриптом `./phase.sh`.
- В ручном режиме deny-списки в `.claude/settings.local.json` блокируют Edit вне текущей фазы.
- В режиме Agent Teams контроль зон — через промпты агентов (`.claude/agents/*.md`).
```

**Step 2: Update section 11.1 to support both modes**

Replace section 11.1 with:

```markdown
### 11.1 При старте сессии
Claude обязан прочитать `.claude/phase.json` и показать:
```
📋 Текущая фаза: <phase>
✅ Доступно: <allowed_summary из phase.json>
🔒 Заблокировано: всё остальное
Готов к работе. Что делаем?
```
Если `.claude/phase.json` отсутствует — сообщить пользователю: `"Фаза не установлена. Запустите ./phase.sh <phase> перед началом работы."`

При использовании Agent Teams (секция 12) ручное переключение фаз не требуется — Lead автоматически спавнит нужных phase-агентов.
```

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "contract: update phase system docs to reference Agent Teams"
```

---

### Task 8: Update settings.local.json — remove deny rules

**Files:**
- Modify: `.claude/settings.local.json`

**Step 1: Remove deny rules, keep allow rules**

Replace entire file with:

```json
{
  "permissions": {
    "allow": [
      "WebSearch",
      "WebFetch(domain:github.com)",
      "Bash(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift build:*)",
      "Bash(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild:*)",
      "Bash(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test:*)",
      "Bash(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build:*)",
      "Bash(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test:*)",
      "Bash(bash:*)",
      "Bash(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash:*)"
    ]
  }
}
```

**Step 2: Commit**

```bash
git add .claude/settings.local.json
git commit -m "contract: remove phase deny rules — control via Agent Teams prompts"
```

---

### Task 9: Verify setup

**Step 1: Check all agent files exist**

Run: `ls -la .claude/agents/`
Expected: 5 files (code-agent.md, test-agent.md, docs-agent.md, content-agent.md, auditor.md)

**Step 2: Check CLAUDE.md has section 12**

Run: `grep "Agent Teams Integration" CLAUDE.md`
Expected: match found

**Step 3: Check settings.local.json has no deny rules**

Run: `grep "deny" .claude/settings.local.json`
Expected: no match

**Step 4: Final commit (if any remaining changes)**

```bash
git status
```
