#!/usr/bin/env bash
set -euo pipefail

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/twilightengine_strict_concurrency.XXXXXX")"
tmp_log="${tmp_root}/build.log"
scratch_path="${tmp_root}/swiftpm-scratch"
module_cache_path="${tmp_root}/clang-module-cache"

mkdir -p "$scratch_path" "$module_cache_path"
trap 'rm -rf "$tmp_root"' EXIT

developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ -z "$developer_dir" || "$developer_dir" == *"/CommandLineTools" ]]; then
  developer_dir="/Applications/Xcode.app/Contents/Developer"
fi

export DEVELOPER_DIR="$developer_dir"

CLANG_MODULE_CACHE_PATH="$module_cache_path" swift build \
	  --package-path Packages/TwilightEngine \
	  --scratch-path "$scratch_path" \
	  --disable-sandbox \
	  --build-tests \
	  -Xswiftc -strict-concurrency=complete \
	  -Xswiftc -warn-concurrency \
	  2>&1 | tee "$tmp_log"

if grep -Eq ":[0-9]+:[0-9]+: (warning|error):" "$tmp_log"; then
  echo "Strict concurrency diagnostics detected:"
  grep -E ":[0-9]+:[0-9]+: (warning|error):" "$tmp_log"
  exit 1
fi
