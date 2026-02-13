#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  validate_release_profile.sh --profile <rc_app|rc_engine_twilight|rc_build_content|rc_full> \
    [--dashboard-dir <dir>] [--registry <path>]

Examples:
  validate_release_profile.sh \
    --profile rc_engine_twilight \
    --dashboard-dir TestResults/QualityDashboard \
    --registry .github/flaky-quarantine.csv

  validate_release_profile.sh --profile rc_app
  validate_release_profile.sh --profile rc_full
EOF
}

profile=""
dashboard_dir="TestResults/QualityDashboard"
registry_file=".github/flaky-quarantine.csv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --dashboard-dir)
      dashboard_dir="${2:-}"
      shift 2
      ;;
    --registry)
      registry_file="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${profile}" ]]; then
  echo "Missing required --profile"
  usage
  exit 2
fi

gates_file="${dashboard_dir}/gates.jsonl"
if [[ ! -f "${gates_file}" ]]; then
  echo "Missing gate results file: ${gates_file}"
  exit 1
fi

declare -a gate_thresholds
case "${profile}" in
  rc_app)
    gate_thresholds=(
      "app_gate_1_quality:1200"
      "app_gate_2_content_validation:1200"
      "app_gate_2a_audit_core:1200"
      "app_gate_2b_audit_architecture:1200"
      "app_gate_3_unit_views:1200"
    )
    ;;
  rc_engine_twilight)
    gate_thresholds=(
      "spm_TwilightEngine_tests:1200"
      "spm_twilightengine_strict_concurrency:1200"
      "spm_twilightengine_determinism_smoke:300"
    )
    ;;
  rc_build_content)
    gate_thresholds=(
      "build_cardsamplegame:1200"
      "build_packeditor:1200"
      "content_json_lint:300"
      "repo_hygiene:120"
      "docs_sync:120"
      "legacy_cleanup:120"
    )
    ;;
  rc_full)
    gate_thresholds=(
      "spm_TwilightEngine_tests:1200"
      "spm_twilightengine_strict_concurrency:1200"
      "spm_twilightengine_determinism_smoke:300"
      "app_gate_1_quality:1200"
      "app_gate_2_content_validation:1200"
      "app_gate_2a_audit_core:1200"
      "app_gate_2b_audit_architecture:1200"
      "app_gate_3_unit_views:1200"
      "build_cardsamplegame:1200"
      "build_packeditor:1200"
      "content_json_lint:300"
      "repo_hygiene:120"
      "docs_sync:120"
      "legacy_cleanup:120"
    )
    ;;
  *)
    echo "Unknown profile '${profile}'. Supported: rc_app, rc_engine_twilight, rc_build_content, rc_full"
    exit 2
    ;;
esac

bash .github/ci/validate_flaky_quarantine.sh "${registry_file}" >/dev/null

filtered_registry_file="$(mktemp)"
trap 'rm -f "${filtered_registry_file}"' EXIT

grep -v '^[[:space:]]*#' "${registry_file}" | sed '/^[[:space:]]*$/d' > "${filtered_registry_file}"
active_quarantine_count="$(
  tail -n +2 "${filtered_registry_file}" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' '
)"

report_file="${dashboard_dir}/release_profile_${profile}.md"
{
  echo "# Release Profile Check"
  echo
  echo "- Profile: \`${profile}\`"
  echo "- Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Gate source: \`${gates_file}\`"
  echo "- Quarantine source: \`${registry_file}\`"
  echo
  echo "## Gate Results"
  echo
  echo "| Gate | Status | Duration (s) | Budget (s) | Threshold (s) | Result |"
  echo "|---|---|---:|---:|---:|---|"
} > "${report_file}"

failures=0

if (( active_quarantine_count > 0 )); then
  echo "Active quarantine entries are not allowed for release profile '${profile}'."
  tail -n +2 "${filtered_registry_file}" || true
  failures=$((failures + 1))
fi

for gate_threshold in "${gate_thresholds[@]}"; do
  gate_id="${gate_threshold%%:*}"
  threshold="${gate_threshold##*:}"

  gate_line="$(grep "\"gate_id\":\"${gate_id}\"" "${gates_file}" | tail -n 1 || true)"
  if [[ -z "${gate_line}" ]]; then
    echo "Missing gate result for '${gate_id}'"
    echo "| \`${gate_id}\` | missing | - | - | ${threshold} | FAIL |" >> "${report_file}"
    failures=$((failures + 1))
    continue
  fi

  status="$(printf '%s\n' "${gate_line}" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
  duration_sec="$(printf '%s\n' "${gate_line}" | sed -n 's/.*"duration_sec":\([0-9][0-9]*\).*/\1/p')"
  budget_sec="$(printf '%s\n' "${gate_line}" | sed -n 's/.*"budget_sec":\([0-9][0-9]*\).*/\1/p')"

  gate_failed=0
  if [[ "${status}" != "passed" ]]; then
    echo "Gate '${gate_id}' status is '${status}' (expected 'passed')"
    gate_failed=1
  fi
  if [[ -n "${duration_sec}" ]] && (( duration_sec > threshold )); then
    echo "Gate '${gate_id}' duration ${duration_sec}s exceeds RC threshold ${threshold}s"
    gate_failed=1
  fi
  if [[ -n "${budget_sec}" ]] && (( budget_sec > threshold )); then
    echo "Gate '${gate_id}' budget ${budget_sec}s exceeds RC threshold ${threshold}s"
    gate_failed=1
  fi

  if (( gate_failed == 1 )); then
    failures=$((failures + 1))
    gate_result="FAIL"
  else
    gate_result="OK"
  fi

  echo "| \`${gate_id}\` | ${status:-unknown} | ${duration_sec:-"-"} | ${budget_sec:-"-"} | ${threshold} | ${gate_result} |" >> "${report_file}"
done

{
  echo
  echo "## Quarantine Policy"
  echo
  echo "- Active entries: ${active_quarantine_count}"
  echo "- Policy: zero-tolerance for RC profiles"
} >> "${report_file}"

if (( failures > 0 )); then
  echo "Release profile '${profile}' failed with ${failures} issue(s)."
  echo "Report: ${report_file}"
  exit 1
fi

echo "Release profile '${profile}' passed."
echo "Report: ${report_file}"
