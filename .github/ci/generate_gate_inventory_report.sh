#!/usr/bin/env bash
set -euo pipefail

dashboard_dir="${1:-TestResults/QualityDashboard}"
workflow_file="${2:-.github/workflows/tests.yml}"
app_tests_root="${3:-CardSampleGameTests}"
engine_tests_root="${4:-Packages/TwilightEngine/Tests/TwilightEngineTests}"
docs_files=(
  "Docs/QA/QUALITY_CONTROL_MODEL.md"
  "Docs/QA/TESTING_GUIDE.md"
  "Docs/QA/ENCOUNTER_TEST_MODEL.md"
  "Docs/QA/RITUAL_COMBAT_TEST_MODEL.md"
)

mkdir -p "${dashboard_dir}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_array_from_file() {
  local file="$1"
  local first=1
  printf '['
  if [[ -f "${file}" ]]; then
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      if (( first == 0 )); then
        printf ','
      fi
      first=0
      printf '"%s"' "$(json_escape "${line}")"
    done < "${file}"
  fi
  printf ']'
}

count_lines() {
  local file="$1"
  if [[ -s "${file}" ]]; then
    wc -l < "${file}" | tr -d ' '
  else
    echo 0
  fi
}

write_bullet_list() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    echo "- _(none)_"
    return
  fi
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    echo "- \`${line}\`"
  done < "${file}"
}

extract_test_classes() {
  local root="$1"
  local output="$2"

  if [[ ! -d "${root}" ]]; then
    : > "${output}"
    return
  fi

  grep -RhoE 'class[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*XCTestCase' "${root}" 2>/dev/null \
    | sed -E 's/.*class[[:space:]]+([A-Za-z0-9_]+).*/\1/' \
    | sed '/^[[:space:]]*$/d' \
    | LC_ALL=C sort -u \
    > "${output}"
}

ci_gate_ids_file="${tmp_dir}/ci_gate_ids.txt"
ci_app_suites_file="${tmp_dir}/ci_app_suites.txt"
ci_engine_smoke_file="${tmp_dir}/ci_engine_smoke_filters.txt"
docs_refs_all_file="${tmp_dir}/docs_refs_all.txt"
docs_refs_suites_file="${tmp_dir}/docs_refs_suites.txt"
docs_refs_invariants_file="${tmp_dir}/docs_refs_invariants.txt"
app_test_classes_file="${tmp_dir}/app_test_classes.txt"
engine_test_classes_file="${tmp_dir}/engine_test_classes.txt"
all_test_classes_file="${tmp_dir}/all_test_classes.txt"

drift_ci_app_missing_docs_file="${tmp_dir}/drift_ci_app_missing_docs.txt"
drift_ci_app_missing_code_file="${tmp_dir}/drift_ci_app_missing_code.txt"
drift_ci_engine_missing_docs_file="${tmp_dir}/drift_ci_engine_missing_docs.txt"
drift_ci_engine_missing_code_file="${tmp_dir}/drift_ci_engine_missing_code.txt"
drift_docs_suites_missing_code_file="${tmp_dir}/drift_docs_suites_missing_code.txt"
drift_docs_invariants_missing_code_file="${tmp_dir}/drift_docs_invariants_missing_code.txt"

if [[ -f "${workflow_file}" ]]; then
  grep -Eo -- '--id "[^"]+"' "${workflow_file}" \
    | sed -E 's/--id "([^"]+)"/\1/' \
    | sed '/^[[:space:]]*$/d' \
    | LC_ALL=C sort -u \
    > "${ci_gate_ids_file}" || true

  grep -Eo -- '-only-testing:CardSampleGameTests/[A-Za-z0-9_]+' "${workflow_file}" \
    | sed -E 's#-only-testing:CardSampleGameTests/##' \
    | sed '/^[[:space:]]*$/d' \
    | LC_ALL=C sort -u \
    > "${ci_app_suites_file}" || true

  grep -Eo -- "--filter '[^']+'" "${workflow_file}" \
    | sed -E "s/--filter '([^']+)'/\\1/" \
    | tr '|' '\n' \
    | sed 's/[[:space:]]//g' \
    | grep -E '^(INV_[A-Z0-9_]+|[A-Za-z0-9_]+Tests)$' \
    | LC_ALL=C sort -u \
    > "${ci_engine_smoke_file}" || true
else
  : > "${ci_gate_ids_file}"
  : > "${ci_app_suites_file}"
  : > "${ci_engine_smoke_file}"
fi

docs_refs_raw_file="${tmp_dir}/docs_refs_raw.txt"
docs_refs_normalized_file="${tmp_dir}/docs_refs_normalized.txt"
docs_sources_file="${tmp_dir}/docs_sources.txt"
: > "${docs_refs_raw_file}"
: > "${docs_sources_file}"
for doc in "${docs_files[@]}"; do
  if [[ -f "${doc}" ]]; then
    printf '%s\n' "${doc}" >> "${docs_sources_file}"
    grep -Eho '`[^`]+`' "${doc}" | tr -d '`' >> "${docs_refs_raw_file}" || true
  fi
done

while IFS= read -r token; do
  [[ -z "${token}" ]] && continue
  token="${token##*/}"
  printf '%s\n' "${token}"
done < "${docs_refs_raw_file}" \
  | sed '/^[[:space:]]*$/d' \
  | LC_ALL=C sort -u \
  > "${docs_refs_normalized_file}"

grep -E '^(INV_[A-Z0-9_]+|[A-Za-z0-9_]+Tests)$' "${docs_refs_normalized_file}" \
  | LC_ALL=C sort -u \
  > "${docs_refs_all_file}" || true

grep -E '^[A-Za-z0-9_]+Tests$' "${docs_refs_all_file}" \
  | grep -Ev '^(CardSampleGameTests|TwilightEngineTests)$' \
  | LC_ALL=C sort -u \
  > "${docs_refs_suites_file}" || true

grep -E '^INV_[A-Z0-9_]+$' "${docs_refs_all_file}" \
  | LC_ALL=C sort -u \
  > "${docs_refs_invariants_file}" || true

extract_test_classes "${app_tests_root}" "${app_test_classes_file}"
extract_test_classes "${engine_tests_root}" "${engine_test_classes_file}"
cat "${app_test_classes_file}" "${engine_test_classes_file}" \
  | sed '/^[[:space:]]*$/d' \
  | LC_ALL=C sort -u \
  > "${all_test_classes_file}"

comm -23 "${ci_app_suites_file}" "${docs_refs_suites_file}" > "${drift_ci_app_missing_docs_file}" || true
comm -23 "${ci_app_suites_file}" "${app_test_classes_file}" > "${drift_ci_app_missing_code_file}" || true
comm -23 "${ci_engine_smoke_file}" "${docs_refs_all_file}" > "${drift_ci_engine_missing_docs_file}" || true
comm -23 "${ci_engine_smoke_file}" "${engine_test_classes_file}" > "${drift_ci_engine_missing_code_file}" || true
comm -23 "${docs_refs_suites_file}" "${all_test_classes_file}" > "${drift_docs_suites_missing_code_file}" || true
comm -23 "${docs_refs_invariants_file}" "${engine_test_classes_file}" > "${drift_docs_invariants_missing_code_file}" || true

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
inventory_json="${dashboard_dir}/gate_inventory.json"
drift_report_md="${dashboard_dir}/gate_drift_report.md"

{
  echo "{"
  echo "  \"generated_at_utc\": \"${generated_at}\","
  echo "  \"sources\": {"
  echo "    \"workflow\": \"$(json_escape "${workflow_file}")\","
  printf "    \"docs\": %s,\n" "$(json_array_from_file "${docs_sources_file}")"
  echo "    \"app_tests_root\": \"$(json_escape "${app_tests_root}")\","
  echo "    \"engine_tests_root\": \"$(json_escape "${engine_tests_root}")\""
  echo "  },"
  echo "  \"ci\": {"
  printf "    \"quality_gate_ids\": %s,\n" "$(json_array_from_file "${ci_gate_ids_file}")"
  printf "    \"app_only_testing_suites\": %s,\n" "$(json_array_from_file "${ci_app_suites_file}")"
  printf "    \"engine_smoke_filters\": %s\n" "$(json_array_from_file "${ci_engine_smoke_file}")"
  echo "  },"
  echo "  \"docs\": {"
  printf "    \"referenced_tokens\": %s,\n" "$(json_array_from_file "${docs_refs_all_file}")"
  printf "    \"referenced_suites\": %s,\n" "$(json_array_from_file "${docs_refs_suites_file}")"
  printf "    \"referenced_invariants\": %s\n" "$(json_array_from_file "${docs_refs_invariants_file}")"
  echo "  },"
  echo "  \"code\": {"
  printf "    \"app_test_suites\": %s,\n" "$(json_array_from_file "${app_test_classes_file}")"
  printf "    \"engine_test_suites\": %s\n" "$(json_array_from_file "${engine_test_classes_file}")"
  echo "  },"
  echo "  \"drift\": {"
  printf "    \"ci_app_suites_missing_in_docs\": %s,\n" "$(json_array_from_file "${drift_ci_app_missing_docs_file}")"
  printf "    \"ci_app_suites_missing_in_code\": %s,\n" "$(json_array_from_file "${drift_ci_app_missing_code_file}")"
  printf "    \"ci_engine_filters_missing_in_docs\": %s,\n" "$(json_array_from_file "${drift_ci_engine_missing_docs_file}")"
  printf "    \"ci_engine_filters_missing_in_code\": %s,\n" "$(json_array_from_file "${drift_ci_engine_missing_code_file}")"
  printf "    \"docs_suites_missing_in_code\": %s,\n" "$(json_array_from_file "${drift_docs_suites_missing_code_file}")"
  printf "    \"docs_invariants_missing_in_code\": %s\n" "$(json_array_from_file "${drift_docs_invariants_missing_code_file}")"
  echo "  }"
  echo "}"
} > "${inventory_json}"

{
  echo "# Gate Inventory and Drift Report"
  echo
  echo "- Generated (UTC): ${generated_at}"
  echo "- Workflow source: \`${workflow_file}\`"
  echo
  echo "## Inventory Counts"
  echo
  echo "| Metric | Count |"
  echo "|---|---:|"
  echo "| CI quality gate IDs | $(count_lines "${ci_gate_ids_file}") |"
  echo "| CI app suites (-only-testing) | $(count_lines "${ci_app_suites_file}") |"
  echo "| CI engine smoke filters | $(count_lines "${ci_engine_smoke_file}") |"
  echo "| Doc referenced suites/invariants | $(count_lines "${docs_refs_all_file}") |"
  echo "| App test suites in code | $(count_lines "${app_test_classes_file}") |"
  echo "| Engine test suites in code | $(count_lines "${engine_test_classes_file}") |"
  echo
  echo "## Drift Summary"
  echo
  echo "| Check | Missing |"
  echo "|---|---:|"
  echo "| CI app suites missing in docs | $(count_lines "${drift_ci_app_missing_docs_file}") |"
  echo "| CI app suites missing in code | $(count_lines "${drift_ci_app_missing_code_file}") |"
  echo "| CI engine filters missing in docs | $(count_lines "${drift_ci_engine_missing_docs_file}") |"
  echo "| CI engine filters missing in code | $(count_lines "${drift_ci_engine_missing_code_file}") |"
  echo "| Doc suites missing in code | $(count_lines "${drift_docs_suites_missing_code_file}") |"
  echo "| Doc invariants missing in code | $(count_lines "${drift_docs_invariants_missing_code_file}") |"
  echo
  echo "## Details"
  echo
  echo "### CI App Suites Missing In Docs"
  write_bullet_list "${drift_ci_app_missing_docs_file}"
  echo
  echo "### CI App Suites Missing In Code"
  write_bullet_list "${drift_ci_app_missing_code_file}"
  echo
  echo "### CI Engine Filters Missing In Docs"
  write_bullet_list "${drift_ci_engine_missing_docs_file}"
  echo
  echo "### CI Engine Filters Missing In Code"
  write_bullet_list "${drift_ci_engine_missing_code_file}"
  echo
  echo "### Doc Suites Missing In Code"
  write_bullet_list "${drift_docs_suites_missing_code_file}"
  echo
  echo "### Doc Invariants Missing In Code"
  write_bullet_list "${drift_docs_invariants_missing_code_file}"
} > "${drift_report_md}"

echo "Wrote gate inventory JSON: ${inventory_json}"
echo "Wrote gate drift report: ${drift_report_md}"
