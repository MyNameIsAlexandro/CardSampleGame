#!/usr/bin/env bash
set -euo pipefail

workflow_file="${1:-.github/workflows/tests.yml}"
quality_doc="${2:-Docs/QA/QUALITY_CONTROL_MODEL.md}"
testing_doc="${3:-Docs/QA/TESTING_GUIDE.md}"
ledger_doc="${4:-Docs/plans/2026-02-07-audit-refactor-phase2-epics.md}"

require_file() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "Missing required file: ${file}"
    return 1
  fi
}

require_literal() {
  local file="$1"
  local literal="$2"
  local label="$3"
  if ! grep -Fq "${literal}" "${file}"; then
    echo "Missing ${label} in ${file}: ${literal}"
    return 1
  fi
}

extract_engine_smoke_tokens() {
  local workflow="$1"
  grep -Eo -- "--filter '[^']+'" "${workflow}" \
    | sed -E "s/--filter '([^']+)'/\\1/" \
    | tr '|' '\n' \
    | sed 's/[[:space:]]//g' \
    | grep -E '^(INV_[A-Z0-9_]+|[A-Za-z0-9_]+Tests)$' \
    | LC_ALL=C sort -u
}

require_file "${workflow_file}"
require_file "${quality_doc}"
require_file "${testing_doc}"
require_file "${ledger_doc}"

mandatory_smoke_tokens=(
  "INV_RNG_GateTests"
  "INV_SCHEMA28_GateTests"
  "INV_REPLAY30_GateTests"
  "INV_RESUME47_GateTests"
  "ContentRegistryRegistrySyncTests"
)

epic_done_markers=(
  "### Epic 28 [DONE]"
  "### Epic 30 [DONE]"
  "### Epic 47 [DONE]"
  "### Epic 48 [DONE]"
)

engine_smoke_tokens_file="$(mktemp)"
trap 'rm -f "${engine_smoke_tokens_file}"' EXIT
extract_engine_smoke_tokens "${workflow_file}" > "${engine_smoke_tokens_file}"

failures=0

for token in "${mandatory_smoke_tokens[@]}"; do
  if ! grep -Fxq "${token}" "${engine_smoke_tokens_file}"; then
    echo "Workflow determinism smoke is missing token: ${token}"
    failures=$((failures + 1))
  fi

  if ! grep -Fq "${token}" "${quality_doc}"; then
    echo "Quality model is missing mandatory token: ${token}"
    failures=$((failures + 1))
  fi

  if ! grep -Fq "${token}" "${testing_doc}"; then
    echo "Testing guide is missing mandatory token: ${token}"
    failures=$((failures + 1))
  fi
done

for marker in "${epic_done_markers[@]}"; do
  if ! grep -Fq "${marker}" "${ledger_doc}"; then
    echo "Epic ledger marker is missing: ${marker}"
    failures=$((failures + 1))
  fi
done

latest_done_epic="$(
  awk '
    /^### Epic [0-9]+ \[DONE\]/ {
      epic = $3 + 0
      if (epic > max) { max = epic }
    }
    END {
      if (max > 0) { print max }
    }
  ' "${ledger_doc}"
)"

if [[ -z "${latest_done_epic}" ]]; then
  echo "Epic ledger has no DONE epic headings: ${ledger_doc}"
  failures=$((failures + 1))
fi

expected_backlog_marker="Pending backlog (post-Epic ${latest_done_epic})"
if ! grep -Fq "${expected_backlog_marker}" "${ledger_doc}"; then
  echo "Epic ledger header is stale: expected ${expected_backlog_marker}"
  failures=$((failures + 1))
fi

if [[ ${failures} -gt 0 ]]; then
  echo "Documentation sync validation failed with ${failures} issue(s)."
  exit 1
fi

echo "Documentation sync validation passed."
