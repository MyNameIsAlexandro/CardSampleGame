#!/usr/bin/env bash
set -euo pipefail

log_file="app-strict-concurrency.log"
diagnostics_file="app-strict-concurrency.diagnostics"
all_concurrency_file="app-strict-concurrency.all"
destination="${IOS_SIMULATOR_DESTINATION:-$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)}"
app_scope_regex='/(App|Views|ViewModels|Managers|Models|Utilities|PackEditor|DevTools)/[^:]*:[0-9]+:[0-9]+: (warning|error):'

build_exit=0
xcodebuild build \
  -scheme CardSampleGame \
  -destination "${destination}" \
  SWIFT_STRICT_CONCURRENCY=complete \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -warn-concurrency' \
  > "${log_file}" 2>&1 || build_exit=$?

grep -E ":[0-9]+:[0-9]+: (warning|error):" "${log_file}" \
  | grep -Ei "(sendable|non-sendable|actor[- ]isolated|main actor|global actor|nonisolated|concurrency|data race|cross-actor)" \
  > "${all_concurrency_file}" || true

grep -E "${app_scope_regex}" "${all_concurrency_file}" > "${diagnostics_file}" || true

echo "Strict-concurrency diagnostics:"
if [ -s "${diagnostics_file}" ]; then
  cat "${diagnostics_file}"
else
  echo "(none)"
fi

if [ -s "${all_concurrency_file}" ] && [ ! -s "${diagnostics_file}" ]; then
  echo "Note: found strict-concurrency diagnostics outside app scope; not failing Gate 0."
fi

if [ -s "${diagnostics_file}" ]; then
  echo "Strict-concurrency diagnostics are not allowed in app build."
  exit 1
fi

if [ "${build_exit}" -ne 0 ]; then
  echo "xcodebuild failed without strict-concurrency diagnostics match."
  tail -n 200 "${log_file}"
  exit "${build_exit}"
fi
