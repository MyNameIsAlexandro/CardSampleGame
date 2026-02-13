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
        python3 -c "
import json, sys
try:
    with open('$SETTINGS_FILE') as f:
        data = json.load(f)
    allow = data.get('permissions', {}).get('allow', [])
    # Filter out any stale Edit() rules
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

    echo "📋 Current phase: ${current}"
    echo "⏰ Since: ${since}"
    echo "✅ Allowed: ${allowed}"
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
echo ""
show_status
echo ""
echo "🔒 Deny rules written to: ${SETTINGS_FILE}"
echo "📄 Phase state written to: ${PHASE_FILE}"
echo ""
echo "Start a new Claude Code session to apply changes."
