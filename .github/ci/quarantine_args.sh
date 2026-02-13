#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  quarantine_args.sh --format <swiftpm|xcodebuild> --suite <suite> [--registry <path>]

Examples:
  quarantine_args.sh --format swiftpm --suite spm:TwilightEngine
  quarantine_args.sh --format xcodebuild --suite xcodebuild:CardSampleGame

Notes:
  - The registry is a simple CSV without quoted commas.
  - `test_id` is interpreted by the selected format:
    - swiftpm: regex passed to `swift test --skip`
    - xcodebuild: identifier passed to `xcodebuild -skip-testing:<id>`
EOF
}

format=""
suite=""
registry_file=".github/flaky-quarantine.csv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      format="${2:-}"
      shift 2
      ;;
    --suite)
      suite="${2:-}"
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

if [[ -z "$format" || -z "$suite" ]]; then
  echo "Missing required arguments"
  usage
  exit 2
fi

if [[ ! -f "$registry_file" ]]; then
  exit 0
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

grep -v '^[[:space:]]*#' "$registry_file" | sed '/^[[:space:]]*$/d' > "$tmp_file"
if [[ ! -s "$tmp_file" ]]; then
  exit 0
fi

header="$(head -n 1 "$tmp_file")"
expected_header="test_id,owner,expires_on,issue_url,reason,suite,status"
if [[ "$header" != "$expected_header" ]]; then
  echo "Invalid quarantine registry header in $registry_file"
  echo "Expected: $expected_header"
  echo "Actual:   $header"
  exit 1
fi

today="$(date -u +%Y-%m-%d)"

tail -n +2 "$tmp_file" | while IFS=',' read -r test_id _owner expires_on _issue_url _reason row_suite status; do
  [[ -z "$test_id" ]] && continue
  [[ "$status" != "QUARANTINED" ]] && continue
  [[ "$expires_on" < "$today" ]] && continue
  if [[ "$row_suite" != "$suite" && "$row_suite" != "${format}:*" ]]; then
    continue
  fi

  case "$format" in
    swiftpm)
      echo "--skip $test_id"
      ;;
    xcodebuild)
      echo "-skip-testing:$test_id"
      ;;
    *)
      echo "Unknown --format: $format"
      exit 2
      ;;
  esac
done
