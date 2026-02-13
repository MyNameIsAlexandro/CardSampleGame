#!/usr/bin/env bash
set -euo pipefail

ensure_developer_dir() {
  if [ -z "${DEVELOPER_DIR:-}" ]; then
    active_developer_dir="$(xcode-select -p 2>/dev/null || true)"
    if [[ "${active_developer_dir}" == *"/CommandLineTools"* ]] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
      export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    fi
  fi
}

is_test_invocation() {
  for arg in "$@"; do
    case "$arg" in
      test|build-for-testing|test-without-building)
        return 0
        ;;
    esac
  done
  return 1
}

is_transient_simulator_failure() {
  local log_file="$1"
  grep -Eiq \
    "FBSOpenApplicationServiceErrorDomain|failed preflight checks|CoreSimulatorService connection became invalid|simdiskimaged.*(crashed|not responding)|Unable to boot the Simulator|simulator.*timed out|Testing cancelled|Unable to find a destination matching|Connection refused|Unable to launch .*Simulator|Simulator device support disabled" \
    "${log_file}"
}

recover_simulator_services() {
  echo "Attempting simulator service recovery..."

  if command -v xcrun >/dev/null 2>&1; then
    xcrun simctl shutdown all >/dev/null 2>&1 || true
    xcrun simctl delete unavailable >/dev/null 2>&1 || true
  fi

  pkill -9 -x Simulator >/dev/null 2>&1 || true
  pkill -9 -f CoreSimulatorService >/dev/null 2>&1 || true
}

extract_result_bundle_path() {
  local previous=""
  for arg in "$@"; do
    if [ "${previous}" = "-resultBundlePath" ]; then
      echo "${arg}"
      return 0
    fi

    case "${arg}" in
      -resultBundlePath=*)
        echo "${arg#-resultBundlePath=}"
        return 0
        ;;
    esac

    previous="${arg}"
  done

  return 1
}

cleanup_result_bundle_path_if_needed() {
  local result_bundle_path
  result_bundle_path="$(extract_result_bundle_path "$@")" || return 0

  if [ -d "${result_bundle_path}" ]; then
    rm -rf "${result_bundle_path}"
  elif [ -f "${result_bundle_path}" ]; then
    rm -f "${result_bundle_path}"
  fi
}

run_once() {
  local log_file="$1"
  shift

  set +e
  if command -v xcpretty >/dev/null 2>&1; then
    xcodebuild "$@" 2>&1 | tee "${log_file}" | xcpretty
  else
    xcodebuild "$@" 2>&1 | tee "${log_file}"
  fi
  local exit_code="${PIPESTATUS[0]:-1}"
  set -e

  return "${exit_code}"
}

ensure_developer_dir

max_attempts="${XCODEBUILD_MAX_ATTEMPTS:-}"
if [[ -z "${max_attempts}" ]]; then
  if is_test_invocation "$@"; then
    max_attempts=2
  else
    max_attempts=1
  fi
fi

if ! [[ "${max_attempts}" =~ ^[0-9]+$ ]] || [ "${max_attempts}" -lt 1 ]; then
  echo "Invalid XCODEBUILD_MAX_ATTEMPTS value: ${max_attempts}" >&2
  exit 2
fi

retry_delay_sec="${XCODEBUILD_RETRY_DELAY_SEC:-8}"
if ! [[ "${retry_delay_sec}" =~ ^[0-9]+$ ]]; then
  echo "Invalid XCODEBUILD_RETRY_DELAY_SEC value: ${retry_delay_sec}" >&2
  exit 2
fi

attempt=1
while [ "${attempt}" -le "${max_attempts}" ]; do
  if [ "${attempt}" -gt 1 ]; then
    cleanup_result_bundle_path_if_needed "$@"
  fi

  log_file="$(mktemp "${TMPDIR:-/tmp}/xcodebuild-attempt-${attempt}.XXXXXX")"
  echo "xcodebuild attempt ${attempt}/${max_attempts}"

  if run_once "${log_file}" "$@"; then
    exit_code=0
  else
    exit_code=$?
  fi

  if [ "${exit_code}" -eq 0 ]; then
    rm -f "${log_file}" >/dev/null 2>&1 || true
    exit 0
  fi

  if [ "${attempt}" -ge "${max_attempts}" ] || ! is_transient_simulator_failure "${log_file}"; then
    echo "xcodebuild failed on attempt ${attempt}/${max_attempts}. Log: ${log_file}" >&2
    exit "${exit_code}"
  fi

  echo "Detected transient simulator/Xcode failure on attempt ${attempt}. Retrying in ${retry_delay_sec}s..."
  recover_simulator_services
  sleep "${retry_delay_sec}"
  attempt=$((attempt + 1))
done
