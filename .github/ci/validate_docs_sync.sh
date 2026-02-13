#!/usr/bin/env bash
set -euo pipefail

workflow_file="${1:-.github/workflows/tests.yml}"
quality_doc="${2:-Docs/QA/QUALITY_CONTROL_MODEL.md}"
testing_doc="${3:-Docs/QA/TESTING_GUIDE.md}"
ledger_doc="${4:-Docs/plans/2026-02-07-audit-refactor-phase2-epics.md}"
architecture_doc="${5:-Docs/Technical/ENGINE_ARCHITECTURE.md}"
release_runner_file="${6:-.github/ci/run_release_check.sh}"

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

extract_last_updated_date() {
  local file="$1"
  sed -nE 's/^\*\*Last updated:\*\* ([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]*$/\1/p' "${file}" | head -n1
}

extract_last_updated_iso_date() {
  local file="$1"
  sed -nE 's/^\*\*Last updated \(ISO\):\*\* ([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]*$/\1/p' "${file}" | head -n1
}

extract_ledger_snapshot_date() {
  local file="$1"
  sed -nE 's/^## Status snapshot \(([0-9]{4}-[0-9]{2}-[0-9]{2})\)[[:space:]]*$/\1/p' "${file}" | head -n1
}

extract_phase2_checkpoint_epic() {
  local file="$1"
  sed -nE 's/^\*\*Phase 2 checkpoint:\*\* Epic ([0-9]+)[[:space:]]*$/\1/p' "${file}" | head -n1
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
require_file "${architecture_doc}"
require_file "${release_runner_file}"

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

if ! grep -Fq "validate_repo_hygiene.sh --require-clean-tree" "${workflow_file}"; then
  echo "Workflow is missing hard repo hygiene invocation: validate_repo_hygiene.sh --require-clean-tree"
  failures=$((failures + 1))
fi

if ! grep -Fq "validate_repo_hygiene.sh --require-clean-tree" "${release_runner_file}"; then
  echo "Release runner is missing hard repo hygiene invocation: validate_repo_hygiene.sh --require-clean-tree"
  failures=$((failures + 1))
fi

if ! require_literal "${architecture_doc}" "Architecture Lock (Source of Truth)" "architecture status marker"; then
  failures=$((failures + 1))
fi

quality_date="$(extract_last_updated_date "${quality_doc}")"
testing_date="$(extract_last_updated_date "${testing_doc}")"
ledger_snapshot_date="$(extract_ledger_snapshot_date "${ledger_doc}")"
architecture_date="$(extract_last_updated_iso_date "${architecture_doc}")"

if [[ -z "${quality_date}" ]]; then
  echo "Quality model is missing parseable Last updated date: ${quality_doc}"
  failures=$((failures + 1))
fi

if [[ -z "${testing_date}" ]]; then
  echo "Testing guide is missing parseable Last updated date: ${testing_doc}"
  failures=$((failures + 1))
fi

if [[ -z "${ledger_snapshot_date}" ]]; then
  echo "Epic ledger is missing parseable status snapshot date: ${ledger_doc}"
  failures=$((failures + 1))
fi

if [[ -z "${architecture_date}" ]]; then
  echo "Architecture spec is missing parseable Last updated (ISO) date: ${architecture_doc}"
  failures=$((failures + 1))
fi

if [[ -n "${quality_date}" && -n "${testing_date}" && -n "${ledger_snapshot_date}" && -n "${architecture_date}" ]]; then
  if [[ "${quality_date}" != "${testing_date}" || "${quality_date}" != "${ledger_snapshot_date}" || "${quality_date}" != "${architecture_date}" ]]; then
    echo "Documentation date drift detected: quality=${quality_date}, testing=${testing_date}, ledger=${ledger_snapshot_date}, architecture=${architecture_date}"
    failures=$((failures + 1))
  fi
fi

quality_checkpoint_epic="$(extract_phase2_checkpoint_epic "${quality_doc}")"
testing_checkpoint_epic="$(extract_phase2_checkpoint_epic "${testing_doc}")"
architecture_checkpoint_epic="$(extract_phase2_checkpoint_epic "${architecture_doc}")"

if [[ -z "${quality_checkpoint_epic}" ]]; then
  echo "Quality model is missing Phase 2 checkpoint marker: ${quality_doc}"
  failures=$((failures + 1))
fi

if [[ -z "${testing_checkpoint_epic}" ]]; then
  echo "Testing guide is missing Phase 2 checkpoint marker: ${testing_doc}"
  failures=$((failures + 1))
fi

if [[ -z "${architecture_checkpoint_epic}" ]]; then
  echo "Architecture spec is missing Phase 2 checkpoint marker: ${architecture_doc}"
  failures=$((failures + 1))
fi

checkpoint_epic=""
if [[ -n "${quality_checkpoint_epic}" ]]; then
  checkpoint_epic="${quality_checkpoint_epic}"
fi

if [[ -n "${quality_checkpoint_epic}" && -n "${testing_checkpoint_epic}" && "${quality_checkpoint_epic}" != "${testing_checkpoint_epic}" ]]; then
  echo "Phase 2 checkpoint drift between quality/testing docs: quality=Epic ${quality_checkpoint_epic}, testing=Epic ${testing_checkpoint_epic}"
  failures=$((failures + 1))
fi

if [[ -n "${quality_checkpoint_epic}" && -n "${architecture_checkpoint_epic}" && "${quality_checkpoint_epic}" != "${architecture_checkpoint_epic}" ]]; then
  echo "Phase 2 checkpoint drift between quality/architecture docs: quality=Epic ${quality_checkpoint_epic}, architecture=Epic ${architecture_checkpoint_epic}"
  failures=$((failures + 1))
fi

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

if [[ -n "${checkpoint_epic}" ]]; then
  if ! grep -Eq "^### Epic ${checkpoint_epic} \\[DONE\\]" "${ledger_doc}" \
    && ! grep -Eq "^[[:space:]]*-[[:space:]]*\`Epic ${checkpoint_epic}\`: DONE" "${ledger_doc}"; then
    echo "Epic ledger is missing DONE marker for phase checkpoint: Epic ${checkpoint_epic}"
    failures=$((failures + 1))
  fi

  if [[ -n "${latest_done_epic}" && "${checkpoint_epic}" -gt "${latest_done_epic}" ]]; then
    echo "Phase checkpoint epic exceeds latest DONE heading: checkpoint=Epic ${checkpoint_epic}, latest heading=Epic ${latest_done_epic}"
    failures=$((failures + 1))
  fi
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
