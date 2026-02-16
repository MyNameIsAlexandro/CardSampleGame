#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_quality_gate.sh --id <gate_id> --budget-sec <seconds> --dashboard-dir <dir> -- "<command>"

Example:
  run_quality_gate.sh \
    --id app_gate_1 \
    --budget-sec 1200 \
    --dashboard-dir TestResults/QualityDashboard \
    -- "xcodebuild test -scheme CardSampleGame | xcpretty"
EOF
}

classify_failure() {
  local log_file="$1"

  if grep -Eiq \
    "unable to find a destination|failed to boot|simulator.*timed out|could not resolve package dependencies|network connection was lost|operation timed out|resource temporarily unavailable|connection reset" \
    "$log_file"; then
    echo "infra_transient"
    return
  fi

  echo "deterministic"
}

render_summary() {
  local jsonl_file="$1"
  local summary_file="$2"
  local latest_jsonl
  latest_jsonl="$(mktemp)"

  awk '
    {
      if (match($0, /"gate_id":"[^"]+"/) == 0) next
      gate = substr($0, RSTART + 11, RLENGTH - 12)
      if (!(gate in seen)) {
        order[++count] = gate
        seen[gate] = 1
      }
      latest[gate] = $0
    }
    END {
      for (i = 1; i <= count; i++) {
        gate = order[i]
        if (gate in latest) {
          print latest[gate]
        }
      }
    }
  ' "$jsonl_file" > "$latest_jsonl"

  {
    echo "# CI Quality Dashboard"
    echo
    echo "| Gate | Status | Duration (s) | Budget (s) | Failure Class | Run Attempt |"
    echo "|------|--------|--------------|------------|---------------|-------------|"
  } > "$summary_file"

  while IFS= read -r gate_line; do
    [[ -z "$gate_line" ]] && continue

    gate_id="$(printf '%s\n' "$gate_line" | sed -n 's/.*"gate_id":"\([^"]*\)".*/\1/p')"
    status="$(printf '%s\n' "$gate_line" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
    duration_sec="$(printf '%s\n' "$gate_line" | sed -n 's/.*"duration_sec":\([0-9][0-9]*\).*/\1/p')"
    budget_sec="$(printf '%s\n' "$gate_line" | sed -n 's/.*"budget_sec":\([0-9][0-9]*\).*/\1/p')"
    failure_class="$(printf '%s\n' "$gate_line" | sed -n 's/.*"failure_class":"\([^"]*\)".*/\1/p')"
    run_attempt="$(printf '%s\n' "$gate_line" | sed -n 's/.*"run_attempt":"\([^"]*\)".*/\1/p')"

    printf '| `%s` | `%s` | %s | %s | `%s` | `%s` |\n' \
      "$gate_id" \
      "${status:-unknown}" \
      "${duration_sec:--}" \
      "${budget_sec:--}" \
      "${failure_class:-unknown}" \
      "${run_attempt:-unknown}" \
      >> "$summary_file"
  done < "$latest_jsonl"

  rm -f "$latest_jsonl"
}

gate_id=""
budget_sec=""
dashboard_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)
      gate_id="${2:-}"
      shift 2
      ;;
    --budget-sec)
      budget_sec="${2:-}"
      shift 2
      ;;
    --dashboard-dir)
      dashboard_dir="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
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

command="${*:-}"

if [[ -z "$gate_id" || -z "$budget_sec" || -z "$dashboard_dir" || -z "$command" ]]; then
  echo "Missing required arguments"
  usage
  exit 2
fi

if ! [[ "$budget_sec" =~ ^[0-9]+$ ]]; then
  echo "Invalid --budget-sec value: $budget_sec"
  exit 2
fi

mkdir -p "$dashboard_dir"
log_file="${dashboard_dir}/${gate_id}.log"
jsonl_file="${dashboard_dir}/gates.jsonl"
summary_file="${dashboard_dir}/summary.md"

start_ts="$(date +%s)"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

set +e
python3 - "$budget_sec" "$command" "$log_file" <<'PY'
import os
import signal
import subprocess
import sys
import threading

timeout_sec = int(sys.argv[1])
command = sys.argv[2]
log_path = sys.argv[3]

process = subprocess.Popen(
    ["bash", "-lc", f"set -o pipefail; {command}"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    bufsize=1,
    preexec_fn=os.setsid,
)

with open(log_path, "w", encoding="utf-8", errors="replace") as log_file:
    def pump_output() -> None:
        assert process.stdout is not None
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            log_file.write(line)
            log_file.flush()

    output_thread = threading.Thread(target=pump_output, daemon=True)
    output_thread.start()

    timed_out = False
    try:
        process.wait(timeout=timeout_sec)
    except subprocess.TimeoutExpired:
        timed_out = True
        timeout_line = f"Quality gate timed out after {timeout_sec}s; terminating command...\n"
        sys.stdout.write(timeout_line)
        sys.stdout.flush()
        log_file.write(timeout_line)
        log_file.flush()

        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()

    output_thread.join(timeout=5)

if timed_out:
    sys.exit(124)
sys.exit(process.returncode if process.returncode is not None else 1)
PY
command_exit=$?
set -e

end_ts="$(date +%s)"
duration_sec=$((end_ts - start_ts))
timed_out=0
if (( command_exit == 124 )); then
  timed_out=1
fi

status="passed"
failure_class="none"

if (( command_exit != 0 )); then
  status="failed"
  failure_class="$(classify_failure "$log_file")"
fi

if (( duration_sec > budget_sec )); then
  status="failed_budget"
  failure_class="deterministic_budget"
fi

if (( timed_out == 1 )); then
  status="failed_budget"
  failure_class="deterministic_budget"
fi

run_attempt="${GITHUB_RUN_ATTEMPT:-1}"
job_name="${GITHUB_JOB:-local}"

printf '{"gate_id":"%s","status":"%s","duration_sec":%d,"budget_sec":%d,"failure_class":"%s","run_attempt":"%s","job":"%s","started_at":"%s","log_file":"%s"}\n' \
  "$gate_id" "$status" "$duration_sec" "$budget_sec" "$failure_class" "$run_attempt" "$job_name" "$started_at" "$log_file" \
  >> "$jsonl_file"

render_summary "$jsonl_file" "$summary_file"

if [[ "$status" != "passed" ]]; then
  echo "Quality gate failed: $gate_id"
  echo "Status: $status"
  echo "Failure class: $failure_class"
  echo "Duration: ${duration_sec}s (budget ${budget_sec}s)"
  echo "Last log lines:"
  tail -n 120 "$log_file" || true
  exit 1
fi

echo "Quality gate passed: $gate_id (${duration_sec}s / budget ${budget_sec}s)"
