#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DEVELOPER_DIR:-}" ]; then
  active_developer_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ "${active_developer_dir}" == *"/CommandLineTools"* ]] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
fi

scheme="CardSampleGame"
preferred_names="${IOS_SIMULATOR_PREFERRED_NAMES:-iPhone 17 Pro,iPhone 17,iPhone 16 Pro,iPhone 16,iPhone 15 Pro,iPhone 15,iPhone SE (3rd generation)}"

while [ $# -gt 0 ]; do
  case "$1" in
    --scheme)
      scheme="$2"
      shift 2
      ;;
    --preferred-names)
      preferred_names="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

extract_candidates() {
  local raw="$1"
  printf '%s\n' "${raw}" \
    | grep -E "platform:[[:space:]]*iOS Simulator" \
    | while IFS= read -r line; do
      name="$(printf '%s\n' "${line}" | sed -nE 's/.*name:[[:space:]]*([^,}]+).*/\1/p')"
      os="$(printf '%s\n' "${line}" | sed -nE 's/.*OS:[[:space:]]*([^,}]+).*/\1/p')"

      name="$(printf '%s' "${name}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
      os="$(printf '%s' "${os}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

      if [ -n "${name}" ] && [ -n "${os}" ]; then
        printf '%s|%s\n' "${name}" "${os}"
      fi
    done \
    | awk '!seen[$0]++'
}

raw_destinations=""
candidates=""
for attempt in 1 2 3; do
  raw_destinations="$(xcodebuild -showdestinations -scheme "${scheme}" 2>&1 || true)"
  candidates="$(extract_candidates "${raw_destinations}")"
  if [ -n "${candidates}" ]; then
    break
  fi

  if [ "${attempt}" -lt 3 ]; then
    sleep 2
  fi
done

if [ -z "${candidates}" ]; then
  echo "No iOS Simulator destinations found for scheme: ${scheme}" >&2
  echo "xcodebuild -showdestinations output:" >&2
  printf '%s\n' "${raw_destinations}" >&2
  exit 1
fi

selected=""
IFS=',' read -r -a preferred <<< "${preferred_names}"
for preferred_name in "${preferred[@]}"; do
  preferred_name="$(printf '%s' "${preferred_name}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  [ -z "${preferred_name}" ] && continue
  match="$(printf '%s\n' "${candidates}" | awk -F'|' -v name="${preferred_name}" '$1==name {print; exit}')"
  if [ -n "${match}" ]; then
    selected="${match}"
    break
  fi
done

if [ -z "${selected}" ]; then
  selected="$(printf '%s\n' "${candidates}" | head -n 1)"
fi

selected_name="${selected%%|*}"
selected_os="${selected##*|}"
selected_name="$(printf '%s' "${selected_name}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
selected_os="$(printf '%s' "${selected_os}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

echo "platform=iOS Simulator,name=${selected_name},OS=${selected_os}"
