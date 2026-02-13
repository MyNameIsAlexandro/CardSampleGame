#!/usr/bin/env bash
set -euo pipefail

registry_file="${1:-.github/flaky-quarantine.csv}"

if [[ ! -f "$registry_file" ]]; then
  echo "Quarantine registry not found: $registry_file"
  exit 1
fi

today="$(date -u +%Y-%m-%d)"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

grep -v '^[[:space:]]*#' "$registry_file" | sed '/^[[:space:]]*$/d' > "$tmp_file"

if [[ ! -s "$tmp_file" ]]; then
  echo "Registry file is empty after filtering comments: $registry_file"
  exit 1
fi

header="$(head -n 1 "$tmp_file")"
expected_header="test_id,owner,expires_on,issue_url,reason,suite,status"
if [[ "$header" != "$expected_header" ]]; then
  echo "Invalid header in $registry_file"
  echo "Expected: $expected_header"
  echo "Actual:   $header"
  exit 1
fi

line_no=1

duplicate_ids="$(tail -n +2 "$tmp_file" | awk -F',' '{print $1}' | sort | uniq -d | sed '/^[[:space:]]*$/d' || true)"
if [[ -n "$duplicate_ids" ]]; then
  echo "Duplicate test_id entries detected:"
  echo "$duplicate_ids"
  exit 1
fi

while IFS=',' read -r test_id owner expires_on issue_url reason suite status; do
  line_no=$((line_no + 1))

  if [[ -z "$test_id" || -z "$owner" || -z "$expires_on" || -z "$issue_url" || -z "$reason" || -z "$suite" || -z "$status" ]]; then
    echo "Line $line_no: all fields are required"
    exit 1
  fi

  if [[ "$owner" != *"@"* ]]; then
    echo "Line $line_no: owner must be an accountable handle/email: $owner"
    exit 1
  fi

  if [[ ! "$expires_on" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Line $line_no: expires_on must be YYYY-MM-DD: $expires_on"
    exit 1
  fi

  if [[ "$expires_on" < "$today" ]]; then
    echo "Line $line_no: quarantine expired on $expires_on (today: $today)"
    exit 1
  fi

  if [[ "$issue_url" != http*://* ]]; then
    echo "Line $line_no: issue_url must be an absolute URL: $issue_url"
    exit 1
  fi

  if [[ "$status" != "QUARANTINED" ]]; then
    echo "Line $line_no: status must be QUARANTINED: $status"
    exit 1
  fi
done < <(tail -n +2 "$tmp_file")

echo "Flaky quarantine registry is valid: $registry_file"
