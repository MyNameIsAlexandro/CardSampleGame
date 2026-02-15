#!/usr/bin/env bash
set -euo pipefail

# Legacy cleanup gate (Epic 57)
# Prevents dead-code and compatibility drift from silently accumulating.

failures=0

roots_to_scan=(
  "App"
  "Views"
  "ViewModels"
  "Models"
  "Managers"
  "Utilities"
  "Packages/TwilightEngine/Sources"
  "Packages/EchoEngine/Sources"
  "Packages/EchoScenes/Sources"
  "Packages/PackEditorKit/Sources"
  "PackEditor"
)

search_swift() {
  local literal="$1"
  shift
  local roots=( "$@" )

  if command -v rg >/dev/null 2>&1; then
    rg -n -F \
      --glob '*.swift' \
      --glob '!**/.build/**' \
      --glob '!**/Packages/ThirdParty/**' \
      --glob '!**/.codex_home/**' \
      "${literal}" \
      "${roots[@]}" \
      || true
    return
  fi

  # Fallback: searches tracked files only (CI uses tracked sources).
  git grep -n -F -- "${literal}" "${roots[@]}" 2>/dev/null || true
}

search_swift_regex() {
  local regex="$1"
  shift
  local roots=( "$@" )

  if command -v rg >/dev/null 2>&1; then
    rg -n \
      --glob '*.swift' \
      --glob '!**/.build/**' \
      --glob '!**/Packages/ThirdParty/**' \
      --glob '!**/.codex_home/**' \
      "${regex}" \
      "${roots[@]}" \
      || true
    return
  fi

  # Fallback: searches tracked files only (CI uses tracked sources).
  git grep -n -E -- "${regex}" "${roots[@]}" 2>/dev/null || true
}

check_callsite() {
  local label="$1"
  local pattern="$2"
  local definition_file="$3"
  shift 3
  local roots=( "$@" )

  local matches
  matches="$(search_swift "${pattern}" "${roots[@]}" | grep -Fv "${definition_file}:" || true)"

  if [[ -z "${matches}" ]]; then
    echo "Legacy cleanup violation: orphaned bridge/adapter entry point."
    echo "- Label: ${label}"
    echo "- Expected call-site pattern: ${pattern}"
    echo "- Definition file: ${definition_file}"
    failures=$((failures + 1))
  fi
}

check_no_todo_fixme() {
  local matches
  matches="$(search_swift_regex '\\b(TODO|FIXME)\\b' "${roots_to_scan[@]}")"

  if [[ -n "${matches}" ]]; then
    echo "Legacy cleanup violation: found TODO/FIXME markers in first-party sources."
    echo "${matches}"
    failures=$((failures + 1))
  fi
}

check_compat_remove_by_markers() {
  local today
  today="$(date -u +%Y-%m-%d)"

  local matches
  matches="$(search_swift "COMPAT_REMOVE_BY:" "${roots_to_scan[@]}")"
  [[ -z "${matches}" ]] && return

  local match_file
  local rest
  local line_no
  local line
  local remove_by

  while IFS= read -r match; do
    [[ -z "${match}" ]] && continue

    match_file="${match%%:*}"
    rest="${match#*:}"
    line_no="${rest%%:*}"
    line="${match#*:*:}"

    if [[ "${line}" =~ COMPAT_REMOVE_BY:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      remove_by="${BASH_REMATCH[1]}"
      if [[ "${remove_by}" < "${today}" ]]; then
        echo "Legacy cleanup violation: expired compatibility marker (${remove_by} < ${today}) at ${match_file}:${line_no}"
        failures=$((failures + 1))
      fi
    else
      echo "Legacy cleanup violation: COMPAT_REMOVE_BY marker must use ISO date YYYY-MM-DD at ${match_file}:${line_no}"
      failures=$((failures + 1))
    fi
  done <<< "${matches}"
}

check_no_todo_fixme
check_compat_remove_by_markers

# Orphaned bridge/adapter call-site checks (production sources only).
# NOTE: EchoCombatBridge and EchoEncounterBridge removed from checks —
# replaced by RitualCombatBridge (R9). Files kept for test-only usage.

check_callsite \
  "QuestDefinition.toQuest" \
  ".toQuest(" \
  "Packages/TwilightEngine/Sources/TwilightEngine/Migration/QuestDefinitionAdapter.swift" \
  "Packages/TwilightEngine/Sources/TwilightEngine"

check_callsite \
  "EventDefinition.toGameEvent" \
  ".toGameEvent(" \
  "Packages/TwilightEngine/Sources/TwilightEngine/Migration/EventDefinitionAdapter.swift" \
  "Packages/TwilightEngine/Sources/TwilightEngine"

if (( failures > 0 )); then
  echo "Legacy cleanup validation failed with ${failures} issue(s)."
  exit 1
fi

echo "Legacy cleanup validation passed."
