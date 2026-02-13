# Development Phases — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 5-phase file access control system (docs/tests/code/content/contract) with `phase.sh` script, `phase.json` state file, and CLAUDE.md integration.

**Architecture:** Bash script generates deny-lists in `.claude/settings.local.json` based on active phase. CLAUDE.md §11 defines behavioral rules. `phase.json` stores current phase for Claude to read at session start.

**Tech Stack:** Bash (phase.sh), JSON (settings.local.json, phase.json), Markdown (CLAUDE.md §11)

**Design doc:** `Docs/plans/2026-02-13-development-phases-design.md`

---

### Task 1: Create `phase.sh` script

**Files:**
- Create: `phase.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
# phase.sh — Development phase switcher for Claude Code
# Usage: ./phase.sh <docs|tests|code|content|contract|status>
#
# Switches the active development phase by:
# 1. Writing .claude/phase.json (Claude reads at session start)
# 2. Updating deny-lists in .claude/settings.local.json (technical block)
# 3. Printing summary to terminal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${SCRIPT_DIR}/.claude"
PHASE_FILE="${CLAUDE_DIR}/phase.json"
SETTINGS_FILE="${CLAUDE_DIR}/settings.local.json"

VALID_PHASES=("docs" "tests" "code" "content" "contract")

# ── Helpers ──────────────────────────────────────────────────────

usage() {
    echo "Usage: ./phase.sh <phase|status>"
    echo ""
    echo "Phases:"
    echo "  docs      Documentation and requirements"
    echo "  tests     Test model (TDD)"
    echo "  code      Implementation"
    echo "  content   Content packs and localization"
    echo "  contract  Engineering contract (CLAUDE.md, .claude/*)"
    echo "  status    Show current phase"
    exit 1
}

is_valid_phase() {
    local phase="$1"
    for p in "${VALID_PHASES[@]}"; do
        [[ "$p" == "$phase" ]] && return 0
    done
    return 1
}

now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ── Phase deny-list definitions ──────────────────────────────────
# Each phase defines what is DENIED (everything outside its scope).

deny_for_docs() {
    cat <<'DENY'
      "Edit(App/**)",
      "Edit(Views/**)",
      "Edit(ViewModels/**)",
      "Edit(Models/**)",
      "Edit(Managers/**)",
      "Edit(Utilities/**)",
      "Edit(DevTools/**)",
      "Edit(Packages/TwilightEngine/Sources/**)",
      "Edit(Packages/EchoEngine/Sources/**)",
      "Edit(Packages/EchoScenes/Sources/**)",
      "Edit(Packages/PackEditorKit/Sources/**)",
      "Edit(Packages/PackEditorApp/Sources/**)",
      "Edit(CardSampleGameTests/**)",
      "Edit(Packages/TwilightEngine/Tests/**)",
      "Edit(Packages/EchoEngine/Tests/**)",
      "Edit(Packages/EchoScenes/Tests/**)",
      "Edit(Packages/PackEditorKit/Tests/**)",
      "Edit(Packages/PackEditorApp/Tests/**)",
      "Edit(Packages/StoryPacks/**)",
      "Edit(Packages/CharacterPacks/**)",
      "Edit(en.lproj/**)",
      "Edit(ru.lproj/**)",
      "Edit(Assets.xcassets/**)",
      "Edit(CardSampleGame.xcodeproj/**)",
      "Edit(.github/ci/**)",
      "Edit(CLAUDE.md)",
      "Edit(.claude/**)"
DENY
}

deny_for_tests() {
    cat <<'DENY'
      "Edit(App/**)",
      "Edit(Views/**)",
      "Edit(ViewModels/**)",
      "Edit(Models/**)",
      "Edit(Managers/**)",
      "Edit(Utilities/**)",
      "Edit(DevTools/**)",
      "Edit(Packages/TwilightEngine/Sources/**)",
      "Edit(Packages/EchoEngine/Sources/**)",
      "Edit(Packages/EchoScenes/Sources/**)",
      "Edit(Packages/PackEditorKit/Sources/**)",
      "Edit(Packages/PackEditorApp/Sources/**)",
      "Edit(Docs/**)",
      "Edit(README.md)",
      "Edit(Packages/StoryPacks/**)",
      "Edit(Packages/CharacterPacks/**)",
      "Edit(en.lproj/**)",
      "Edit(ru.lproj/**)",
      "Edit(Assets.xcassets/**)",
      "Edit(.github/ci/**)",
      "Edit(CLAUDE.md)",
      "Edit(.claude/**)"
DENY
}

deny_for_code() {
    cat <<'DENY'
      "Edit(Docs/**)",
      "Edit(README.md)",
      "Edit(TestResults/QualityDashboard/gate_inventory.json)",
      "Edit(CardSampleGameTests/**)",
      "Edit(Packages/TwilightEngine/Tests/**)",
      "Edit(Packages/EchoEngine/Tests/**)",
      "Edit(Packages/EchoScenes/Tests/**)",
      "Edit(Packages/PackEditorKit/Tests/**)",
      "Edit(Packages/PackEditorApp/Tests/**)",
      "Edit(Packages/StoryPacks/**)",
      "Edit(Packages/CharacterPacks/**)",
      "Edit(en.lproj/**)",
      "Edit(ru.lproj/**)",
      "Edit(Assets.xcassets/**)",
      "Edit(CLAUDE.md)",
      "Edit(.claude/**)"
DENY
}

deny_for_content() {
    cat <<'DENY'
      "Edit(App/**)",
      "Edit(Views/**)",
      "Edit(ViewModels/**)",
      "Edit(Models/**)",
      "Edit(Managers/**)",
      "Edit(Utilities/**)",
      "Edit(DevTools/**)",
      "Edit(Packages/TwilightEngine/Sources/**)",
      "Edit(Packages/EchoEngine/Sources/**)",
      "Edit(Packages/EchoScenes/Sources/**)",
      "Edit(Packages/PackEditorKit/Sources/**)",
      "Edit(Packages/PackEditorApp/Sources/**)",
      "Edit(CardSampleGameTests/**)",
      "Edit(Packages/TwilightEngine/Tests/**)",
      "Edit(Packages/EchoEngine/Tests/**)",
      "Edit(Packages/EchoScenes/Tests/**)",
      "Edit(Packages/PackEditorKit/Tests/**)",
      "Edit(Packages/PackEditorApp/Tests/**)",
      "Edit(Docs/**)",
      "Edit(README.md)",
      "Edit(TestResults/QualityDashboard/gate_inventory.json)",
      "Edit(CardSampleGame.xcodeproj/**)",
      "Edit(.github/ci/**)",
      "Edit(CLAUDE.md)",
      "Edit(.claude/**)"
DENY
}

deny_for_contract() {
    cat <<'DENY'
      "Edit(App/**)",
      "Edit(Views/**)",
      "Edit(ViewModels/**)",
      "Edit(Models/**)",
      "Edit(Managers/**)",
      "Edit(Utilities/**)",
      "Edit(DevTools/**)",
      "Edit(Packages/TwilightEngine/Sources/**)",
      "Edit(Packages/EchoEngine/Sources/**)",
      "Edit(Packages/EchoScenes/Sources/**)",
      "Edit(Packages/PackEditorKit/Sources/**)",
      "Edit(Packages/PackEditorApp/Sources/**)",
      "Edit(CardSampleGameTests/**)",
      "Edit(Packages/TwilightEngine/Tests/**)",
      "Edit(Packages/EchoEngine/Tests/**)",
      "Edit(Packages/EchoScenes/Tests/**)",
      "Edit(Packages/PackEditorKit/Tests/**)",
      "Edit(Packages/PackEditorApp/Tests/**)",
      "Edit(Docs/**)",
      "Edit(README.md)",
      "Edit(TestResults/QualityDashboard/gate_inventory.json)",
      "Edit(Packages/StoryPacks/**)",
      "Edit(Packages/CharacterPacks/**)",
      "Edit(en.lproj/**)",
      "Edit(ru.lproj/**)",
      "Edit(Assets.xcassets/**)",
      "Edit(CardSampleGame.xcodeproj/**)",
      "Edit(.github/ci/**)"
DENY
}

# ── Allowed summaries (for phase.json) ───────────────────────────

allowed_for_phase() {
    case "$1" in
        docs)     echo '["Docs/**", "README.md", "TestResults/QualityDashboard/gate_inventory.json"]' ;;
        tests)    echo '["CardSampleGameTests/**", "Packages/*/Tests/**", "TestResults/QualityDashboard/gate_inventory.json", "CardSampleGame.xcodeproj/project.pbxproj"]' ;;
        code)     echo '["App/**", "Views/**", "ViewModels/**", "Models/**", "Managers/**", "Utilities/**", "Packages/*/Sources/**", "DevTools/**", ".github/ci/**", "CardSampleGame.xcodeproj/project.pbxproj"]' ;;
        content)  echo '["Packages/StoryPacks/**", "Packages/CharacterPacks/**", "**/Resources/**", "en.lproj/**", "ru.lproj/**", "Assets.xcassets/**"]' ;;
        contract) echo '["CLAUDE.md", ".claude/**"]' ;;
    esac
}

# ── Extract existing allow rules ─────────────────────────────────

extract_existing_allow() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        # Extract the allow array content using python3 (available on macOS)
        python3 -c "
import json, sys
try:
    with open('$SETTINGS_FILE') as f:
        data = json.load(f)
    allow = data.get('permissions', {}).get('allow', [])
    # Filter out any stale Edit() rules that might have been added
    allow = [r for r in allow if not r.startswith('Edit(')]
    for r in allow:
        print(json.dumps(r))
except:
    pass
" 2>/dev/null
    fi
}

# ── Write settings.local.json ────────────────────────────────────

write_settings() {
    local phase="$1"
    local deny_fn="deny_for_${phase}"
    local deny_content
    deny_content=$($deny_fn)

    # Collect existing allow rules
    local allow_lines=""
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            if [[ -n "$allow_lines" ]]; then
                allow_lines="${allow_lines},
      ${line}"
            else
                allow_lines="      ${line}"
            fi
        fi
    done < <(extract_existing_allow)

    # Build JSON
    local allow_block=""
    if [[ -n "$allow_lines" ]]; then
        allow_block="\"allow\": [
${allow_lines}
    ],
    "
    fi

    cat > "$SETTINGS_FILE" <<EOF
{
  "permissions": {
    ${allow_block}"deny": [
${deny_content}
    ]
  }
}
EOF
}

# ── Write phase.json ─────────────────────────────────────────────

write_phase() {
    local phase="$1"
    local allowed
    allowed=$(allowed_for_phase "$phase")

    cat > "$PHASE_FILE" <<EOF
{
  "current": "${phase}",
  "since": "$(now_iso)",
  "by": "user",
  "allowed_summary": ${allowed}
}
EOF
}

# ── Status display ───────────────────────────────────────────────

show_status() {
    if [[ ! -f "$PHASE_FILE" ]]; then
        echo "No phase set. Run: ./phase.sh <docs|tests|code|content|contract>"
        exit 0
    fi

    local current
    current=$(python3 -c "import json; print(json.load(open('$PHASE_FILE'))['current'])" 2>/dev/null || echo "unknown")
    local since
    since=$(python3 -c "import json; print(json.load(open('$PHASE_FILE')).get('since','?'))" 2>/dev/null || echo "?")
    local allowed
    allowed=$(python3 -c "
import json
data = json.load(open('$PHASE_FILE'))
print(', '.join(data.get('allowed_summary', [])))
" 2>/dev/null || echo "?")

    echo ""
    echo "📋 Current phase: ${current}"
    echo "⏰ Since: ${since}"
    echo "✅ Allowed: ${allowed}"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage

PHASE="$1"

if [[ "$PHASE" == "status" ]]; then
    show_status
    exit 0
fi

if ! is_valid_phase "$PHASE"; then
    echo "Error: unknown phase '${PHASE}'"
    echo "Available: ${VALID_PHASES[*]}, status"
    exit 1
fi

# Ensure .claude directory exists
mkdir -p "$CLAUDE_DIR"

# Write both files
write_phase "$PHASE"
write_settings "$PHASE"

# Display result
echo ""
echo "✅ Phase switched to: ${PHASE}"
show_status
echo "🔒 Deny rules written to: ${SETTINGS_FILE}"
echo "📄 Phase state written to: ${PHASE_FILE}"
echo ""
echo "Start a new Claude Code session to apply changes."
```

**Step 2: Make script executable**

Run: `chmod +x phase.sh`

**Step 3: Test all phases**

Run each phase and verify output:
```bash
./phase.sh docs
./phase.sh status
./phase.sh tests
./phase.sh code
./phase.sh content
./phase.sh contract
./phase.sh invalid_phase   # should error
./phase.sh                  # should show usage
```

Expected:
- Each valid phase prints summary with allowed paths
- `invalid_phase` prints error with available phases list
- No args prints usage
- `.claude/phase.json` and `.claude/settings.local.json` are updated each time

**Step 4: Verify settings.local.json preserves existing allow rules**

Run: `cat .claude/settings.local.json`

Expected: JSON has both `"allow"` (preserved from existing file) and `"deny"` (generated for phase). Existing allow rules like `"WebSearch"`, `"Bash(DEVELOPER_DIR=...)"` are preserved.

**Step 5: Commit**

```bash
git add phase.sh
git commit -m "feat: add phase.sh development phase switcher

Implements 5-phase file access control (docs/tests/code/content/contract).
Generates deny-lists in .claude/settings.local.json and writes
phase state to .claude/phase.json."
```

---

### Task 2: Add §11 Development Phases to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (append after §10)

**Step 1: Append the new section to CLAUDE.md**

Add after the last line of §10 (line 208):

```markdown

---

## 11) Development Phases (file access control)

### 11.0 Phase system overview
- Проект использует фазовую систему разработки для контроля целостности артефактов.
- Текущая фаза хранится в `.claude/phase.json` и переключается скриптом `./phase.sh`.
- Deny-списки в `.claude/settings.local.json` технически блокируют Edit вне текущей фазы.
- Claude **не может** самостоятельно переключать фазу или менять `phase.json`/`settings.local.json`.

### 11.1 При старте сессии
Claude обязан прочитать `.claude/phase.json` и показать:
```
📋 Текущая фаза: <phase>
✅ Доступно: <allowed_summary из phase.json>
🔒 Заблокировано: всё остальное
Готов к работе. Что делаем?
```

### 11.2 Фазы и разрешённые зоны

| Фаза | Можно редактировать |
|------|-------------------|
| `docs` | `Docs/**`, `README.md`, `gate_inventory.json` |
| `tests` | `**/Tests/**`, `CardSampleGameTests/**`, `gate_inventory.json`, `project.pbxproj` |
| `code` | `App/**`, `Views/**`, `ViewModels/**`, `Models/**`, `Managers/**`, `Utilities/**`, `Packages/*/Sources/**`, `DevTools/**`, `.github/ci/**`, `project.pbxproj` |
| `content` | `Packages/StoryPacks/**`, `Packages/CharacterPacks/**`, `**/Resources/**`, `*.lproj/**`, `Assets.xcassets/**` |
| `contract` | `CLAUDE.md`, `.claude/**` |

Во всех фазах: чтение любых файлов разрешено. Запуск тестов и скриптов разрешён.

### 11.3 Протокол STOP-отчёта (cross-phase change request)

Когда Claude обнаруживает необходимость изменить файл вне текущей фазы, обязателен полный STOP:

1. **Немедленная остановка** работы над текущей задачей.
2. **Структурированный отчёт:**

```
⚠️ ТРЕБУЕТСЯ ИЗМЕНЕНИЕ ВНЕ ТЕКУЩЕЙ ФАЗЫ

Текущая фаза: phase:<current>
Файл: <path>
Принадлежит фазе: phase:<target>

ЧТО: <что именно нужно изменить>
ЗАЧЕМ: <почему без этого нельзя продолжить>
ОБОСНОВАНИЕ: <ссылка на документацию/требование, обосновывающее изменение>
ВЛИЯНИЕ: <scope изменения, что затрагивает>
РИСКИ: <что может пойти не так>
КАЧЕСТВО: <как влияет на качество — снижается / не меняется / улучшается>

Жду решения:
1. Одобрить изменение в этом файле
2. Отложить — продолжу работу без этого изменения
3. Переключить фазу для batch-исправлений
```

3. **Ждать** явного одобрения: `"одобряю изменение в [файл]"`.
4. **При одобрении** — только конкретное одобренное изменение, без расширения scope.

### 11.4 Запрещённые действия в фазовой системе
- Claude не переключает фазу самостоятельно.
- Claude не редактирует `.claude/phase.json` или `.claude/settings.local.json`.
- Claude не обходит deny-блокировку через Bash/Write/другие инструменты.
- Claude не объединяет несколько cross-phase изменений без отдельного одобрения каждого.
```

**Step 2: Verify CLAUDE.md is valid**

Run: `wc -l CLAUDE.md`
Expected: approximately 270-280 lines (was 209, added ~70)

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add §11 Development Phases to CLAUDE.md

Defines phase system rules: session greeting, allowed zones per phase,
STOP-report protocol for cross-phase changes, and forbidden actions."
```

---

### Task 3: Set initial phase and verify end-to-end

**Step 1: Run phase.sh to set initial phase**

```bash
./phase.sh code
```

Expected: phase set to `code`, settings updated.

**Step 2: Verify phase.json**

Run: `cat .claude/phase.json`

Expected: JSON with `"current": "code"`, `"since"`, `"by": "user"`, `"allowed_summary"`.

**Step 3: Verify settings.local.json has deny rules**

Run: `cat .claude/settings.local.json`

Expected: JSON with `"deny"` array containing `Edit(Docs/**)`, `Edit(CardSampleGameTests/**)`, etc. And `"allow"` array preserving existing rules.

**Step 4: Test phase switching**

```bash
./phase.sh tests
cat .claude/phase.json
cat .claude/settings.local.json
./phase.sh status
```

Expected: phase changes, deny-lists update, status displays correctly.

**Step 5: Switch back to code for current work**

```bash
./phase.sh code
```

**Step 6: Commit phase.json (optional — gitignored by default)**

Note: `.claude/settings.local.json` is auto-gitignored by Claude Code. `.claude/phase.json` may also be gitignored. If you want phase.json tracked, add it explicitly. Otherwise skip this step.

---

### Task 4: Add phase.sh to §10 useful commands in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (§10 section)

**Step 1: Add phase commands to §10**

After the last command in §10, add:

```markdown
- Switch development phase:
  - `./phase.sh code` / `./phase.sh tests` / `./phase.sh docs` / `./phase.sh content` / `./phase.sh contract`
  - `./phase.sh status` — показать текущую фазу
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add phase.sh commands to §10 useful commands"
```

---

### Task 5: Final verification

**Step 1: Run snapshot release check**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash .github/ci/run_release_check_snapshot.sh TestResults/QualityDashboard CardSampleGame
```

Expected: All gates pass (the new files don't break any existing gates).

**Step 2: Verify no hygiene violations**

The new `phase.sh` is a bash script (not Swift), so it won't trigger Swift hygiene gates. CLAUDE.md changes should pass docs-sync validation.

**Step 3: Test all five phases one more time**

```bash
for p in docs tests code content contract; do
    echo "=== Testing phase: $p ==="
    ./phase.sh "$p"
    echo ""
done
./phase.sh status
```

Expected: All phases switch cleanly, status shows last phase (contract).

**Step 4: Set final phase for ongoing work**

```bash
./phase.sh code
```
