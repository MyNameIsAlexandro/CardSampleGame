#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:-TestResults/QualityDashboard}"
scheme="${2:-CardSampleGame}"
snapshot_file="${out_dir}/toolchain_snapshot.md"

mkdir -p "${out_dir}"

resolve_ios_destination_with_retry() {
  local attempts="${CI_DESTINATION_RESOLVE_ATTEMPTS:-5}"
  local delay_sec="${CI_DESTINATION_RESOLVE_DELAY_SEC:-5}"
  local attempt=1
  local output=""

  while [ "${attempt}" -le "${attempts}" ]; do
    if output="$(bash .github/ci/select_ios_destination.sh --scheme "${scheme}" 2>&1)"; then
      printf '%s' "${output}"
      return 0
    fi

    if [ "${attempt}" -eq "${attempts}" ]; then
      echo "Failed to resolve iOS destination for scheme '${scheme}' after ${attempts} attempts." >&2
      printf '%s\n' "${output}" >&2
      return 1
    fi

    echo "Destination resolution attempt ${attempt}/${attempts} failed; retrying in ${delay_sec}s..." >&2
    printf '%s\n' "${output}" >&2
    sleep "${delay_sec}"
    attempt=$((attempt + 1))
  done

  return 1
}

{
  echo "# CI Toolchain Snapshot"
  echo
  echo "- Generated (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "- Bash: $(bash --version | head -n 1)"

  if command -v swift >/dev/null 2>&1; then
    echo "- Swift: $(swift --version | head -n 1)"
  else
    echo "- Swift: unavailable"
  fi

  if command -v xcodebuild >/dev/null 2>&1; then
    echo "- Xcode: $(xcodebuild -version | tr '\n' '; ' | sed -E 's/; $//')"
  else
    echo "- Xcode: unavailable"
  fi

  if command -v python3 >/dev/null 2>&1; then
    echo "- Python: $(python3 --version 2>&1)"
  else
    echo "- Python: unavailable"
  fi

  if command -v jq >/dev/null 2>&1; then
    echo "- jq: $(jq --version)"
  else
    echo "- jq: unavailable"
  fi

  if [ "${CI_RESOLVE_IOS_DESTINATION:-0}" = "1" ] \
    && [ -x ".github/ci/select_ios_destination.sh" ] \
    && command -v xcodebuild >/dev/null 2>&1; then
    resolved_destination="$(resolve_ios_destination_with_retry)"
    echo "- Resolved iOS destination (${scheme}): ${resolved_destination}"
  fi
} > "${snapshot_file}"

echo "Wrote CI toolchain snapshot: ${snapshot_file}"
