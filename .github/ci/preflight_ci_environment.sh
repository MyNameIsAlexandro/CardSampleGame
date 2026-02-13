#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:-TestResults/QualityDashboard}"
scheme="${2:-CardSampleGame}"
snapshot_file="${out_dir}/toolchain_snapshot.md"

mkdir -p "${out_dir}"

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
    resolved_destination="$(bash .github/ci/select_ios_destination.sh --scheme "${scheme}")"
    echo "- Resolved iOS destination (${scheme}): ${resolved_destination}"
  fi
} > "${snapshot_file}"

echo "Wrote CI toolchain snapshot: ${snapshot_file}"
