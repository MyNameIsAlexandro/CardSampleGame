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

raw_destinations="$(xcodebuild -showdestinations -scheme "${scheme}")"

candidates="$(
  printf '%s\n' "${raw_destinations}" \
    | grep "platform:iOS Simulator" \
    | sed -nE 's/.*OS:([^,}]+), name:([^}]+).*/\2|\1/p' \
    | awk -F'|' '{name=$1; os=$2; sub(/^[[:space:]]+/, "", name); sub(/[[:space:]]+$/, "", name); sub(/^[[:space:]]+/, "", os); sub(/[[:space:]]+$/, "", os); print name "|" os}' \
    | awk '!seen[$0]++'
)"

if [ -z "${candidates}" ]; then
  echo "No iOS Simulator destinations found for scheme: ${scheme}" >&2
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
