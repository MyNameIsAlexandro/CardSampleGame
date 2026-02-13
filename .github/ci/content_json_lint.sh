#!/usr/bin/env bash
set -euo pipefail

echo "Validating JSON content files..."

fail=0
for json_file in $(find Packages/CharacterPacks Packages/StoryPacks -name '*.json' -type f); do
  if ! python3 -m json.tool "${json_file}" > /dev/null 2>&1; then
    echo "Invalid JSON: ${json_file}"
    fail=1
  fi
done

if [[ "${fail}" -ne 0 ]]; then
  echo "JSON validation failed."
  exit 1
fi

echo "All JSON files are valid."
