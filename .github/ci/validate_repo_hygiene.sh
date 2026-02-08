#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  validate_repo_hygiene.sh [--require-clean-tree]

Options:
  --require-clean-tree  Fail if git working tree has tracked changes
EOF
}

require_clean_tree=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-clean-tree)
      require_clean_tree=1
      shift
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

canonical_lockfile="CardSampleGame.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

package_resolved_files=()
while IFS= read -r lockfile; do
  [[ -z "${lockfile}" ]] && continue
  package_resolved_files+=("${lockfile}")
done < <(find . -name Package.resolved -print | sed 's#^\./##' | sort)

if [[ "${#package_resolved_files[@]}" -ne 1 ]]; then
  echo "Repository hygiene violation: expected exactly one Package.resolved."
  echo "Found ${#package_resolved_files[@]} files:"
  printf '  - %s\n' "${package_resolved_files[@]}"
  exit 1
fi

if [[ "${package_resolved_files[0]}" != "${canonical_lockfile}" ]]; then
  echo "Repository hygiene violation: Package.resolved is not canonical."
  echo "Expected: ${canonical_lockfile}"
  echo "Found:    ${package_resolved_files[0]}"
  exit 1
fi

forbidden_tracked_patterns=(
  '^TestResults(/|$)'
  '^TestReport(/|$)'
  '^TestReport\.xcresult(/|$)'
  '^app-strict-concurrency\.log$'
  '^app-strict-concurrency\.diagnostics$'
  '\.xcresult(/|$)'
  '\.xcactivitylog$'
)

violations=()
while IFS= read -r tracked_file; do
  for pattern in "${forbidden_tracked_patterns[@]}"; do
    if echo "${tracked_file}" | grep -Eq "${pattern}"; then
      violations+=("${tracked_file}")
      break
    fi
  done
done < <(git ls-files)

if [[ "${#violations[@]}" -gt 0 ]]; then
  echo "Repository hygiene violation: transient artifacts are tracked by git."
  printf '  - %s\n' "${violations[@]}"
  echo "Remove these files from git index and keep them local-only."
  exit 1
fi

if [[ "${require_clean_tree}" -eq 1 ]]; then
  tracked_changes="$(git status --porcelain --untracked-files=no)"
  if [[ -n "${tracked_changes}" ]]; then
    echo "Repository hygiene violation: working tree has tracked changes."
    echo "Commit/stash/discard tracked changes before running release check."
    printf '%s\n' "${tracked_changes}"
    exit 1
  fi
fi

echo "Repository hygiene check passed."
