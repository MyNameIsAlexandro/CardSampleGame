#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_release_check_snapshot.sh [dashboard_dir] [scheme]

Purpose:
  Runs release-check against a temporary snapshot of the current working tree
  (including untracked files) without weakening clean-tree hard gates.

Defaults:
  dashboard_dir = TestResults/QualityDashboard
  scheme = CardSampleGame
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
dashboard_dir="${1:-TestResults/QualityDashboard}"
scheme="${2:-CardSampleGame}"

git -C "${repo_root}" rev-parse --show-toplevel >/dev/null

tmp_base="${TMPDIR:-/tmp}"
tmp_base="${tmp_base%/}"
tmp_root="$(mktemp -d "${tmp_base}/release-check-snapshot.XXXXXX")"
tmp_root="$(cd "${tmp_root}" && pwd -P)"
worktree_dir="${tmp_root}/worktree"
tracked_patch="${tmp_root}/tracked.patch"
untracked_list="${tmp_root}/untracked.zlist"
untracked_tar="${tmp_root}/untracked.tar"

cleanup() {
  local exit_code=$?
  if [[ -d "${worktree_dir}" ]]; then
    git -C "${repo_root}" worktree remove --force "${worktree_dir}" >/dev/null 2>&1 || true
  fi
  rm -rf "${tmp_root}" >/dev/null 2>&1 || true
  exit "${exit_code}"
}
trap cleanup EXIT INT TERM

echo "Preparing snapshot worktree: ${worktree_dir}"
git -C "${repo_root}" worktree add --detach "${worktree_dir}" HEAD >/dev/null

git -C "${repo_root}" diff --binary HEAD > "${tracked_patch}"
if [[ -s "${tracked_patch}" ]]; then
  git -C "${worktree_dir}" apply --whitespace=nowarn "${tracked_patch}"
fi

git -C "${repo_root}" ls-files --others --exclude-standard -z > "${untracked_list}"
if [[ -s "${untracked_list}" ]]; then
  tar -C "${repo_root}" --null --files-from="${untracked_list}" -cf "${untracked_tar}"
  tar -C "${worktree_dir}" -xf "${untracked_tar}"
fi

if [[ -n "$(git -C "${worktree_dir}" status --porcelain --untracked-files=all)" ]]; then
  git -C "${worktree_dir}" config user.name "Codex Snapshot"
  git -C "${worktree_dir}" config user.email "codex-snapshot@local"
  git -C "${worktree_dir}" add -A
  git -C "${worktree_dir}" commit -m "temp: release-check snapshot" --no-gpg-sign --quiet
fi

echo "Running release-check in snapshot..."
release_status=0
(
  cd "${worktree_dir}"
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    bash .github/ci/run_release_check.sh "${dashboard_dir}" "${scheme}"
) || release_status=$?

source_dashboard="${worktree_dir}/${dashboard_dir}"
target_dashboard="${repo_root}/${dashboard_dir}"
if [[ -d "${source_dashboard}" ]]; then
  rm -rf "${target_dashboard}"
  mkdir -p "$(dirname "${target_dashboard}")"
  cp -R "${source_dashboard}" "${target_dashboard}"
  echo "Copied dashboard to ${target_dashboard}"
fi

if [[ "${release_status}" -ne 0 ]]; then
  echo "Snapshot release-check failed with exit code ${release_status}."
  exit "${release_status}"
fi

echo "Snapshot release-check completed successfully."
