#!/usr/bin/env bash
set -euo pipefail

paths=(
  "TestResults/QualityDashboard"
  "TestResults/QualityGates.xcresult"
  "TestResults/ContentValidation.xcresult"
  "TestResults/UnitTests.xcresult"
  "app-strict-concurrency.log"
  "app-strict-concurrency.diagnostics"
)

if [ "$#" -gt 0 ]; then
  paths=("$@")
fi

for path in "${paths[@]}"; do
  if [ -e "${path}" ]; then
    rm -rf "${path}"
  fi
done
