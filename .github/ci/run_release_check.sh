#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_release_check.sh [dashboard_dir] [scheme]

Defaults:
  dashboard_dir = TestResults/QualityDashboard
  scheme = CardSampleGame
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

dashboard_dir="${1:-TestResults/QualityDashboard}"
scheme="${2:-CardSampleGame}"
registry_file=".github/flaky-quarantine.csv"

mkdir -p "${dashboard_dir}"

bash .github/ci/validate_repo_hygiene.sh --require-clean-tree
bash .github/ci/clean_test_artifacts.sh
CI_RESOLVE_IOS_DESTINATION=1 bash .github/ci/preflight_ci_environment.sh "${dashboard_dir}" "${scheme}"

ios_destination="$(bash .github/ci/select_ios_destination.sh --scheme "${scheme}")"
skip_args_xcode="$(bash .github/ci/quarantine_args.sh --format xcodebuild --suite xcodebuild:CardSampleGame)"
skip_args_spm="$(bash .github/ci/quarantine_args.sh --format swiftpm --suite spm:TwilightEngine)"
stamp="$(date +%Y%m%d%H%M%S)"

echo "Running app gates..."
bash .github/ci/run_quality_gate.sh \
  --id "app_gate_0_strict_concurrency" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/app_gate0_strict_concurrency.sh"

bash .github/ci/run_quality_gate.sh \
  --id "app_gate_1_quality" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/run_xcodebuild.sh test -scheme ${scheme} -destination \"${ios_destination}\" ${skip_args_xcode} -only-testing:CardSampleGameTests/CodeHygieneTests -only-testing:CardSampleGameTests/DesignSystemComplianceTests -only-testing:CardSampleGameTests/ContrastComplianceTests -only-testing:CardSampleGameTests/LocalizationValidatorTests -only-testing:CardSampleGameTests/LocalizationCompletenessTests -resultBundlePath TestResults/QualityGates.${stamp}.xcresult"

bash .github/ci/run_quality_gate.sh \
  --id "app_gate_2_content_validation" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/run_xcodebuild.sh test -scheme ${scheme} -destination \"${ios_destination}\" ${skip_args_xcode} -only-testing:CardSampleGameTests/ContentValidationTests -only-testing:CardSampleGameTests/ConditionValidatorTests -only-testing:CardSampleGameTests/ExpressionParserTests -only-testing:CardSampleGameTests/ProfileGateTests -resultBundlePath TestResults/ContentValidation.${stamp}.xcresult"

bash .github/ci/run_quality_gate.sh \
  --id "app_gate_2a_audit_core" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/run_xcodebuild.sh test -scheme ${scheme} -destination \"${ios_destination}\" ${skip_args_xcode} -only-testing:CardSampleGameTests/AuditGateTests -resultBundlePath TestResults/AuditCore.${stamp}.xcresult"

bash .github/ci/run_quality_gate.sh \
  --id "app_gate_2b_audit_architecture" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/run_xcodebuild.sh test -scheme ${scheme} -destination \"${ios_destination}\" ${skip_args_xcode} -only-testing:CardSampleGameTests/AuditArchitectureBoundaryGateTests -resultBundlePath TestResults/AuditArchitecture.${stamp}.xcresult"

bash .github/ci/run_quality_gate.sh \
  --id "app_gate_3_unit_views" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/run_xcodebuild.sh test -scheme ${scheme} -destination \"${ios_destination}\" ${skip_args_xcode} -only-testing:CardSampleGameTests/HeroRegistryTests -only-testing:CardSampleGameTests/SaveLoadTests -only-testing:CardSampleGameTests/ContentManagerTests -only-testing:CardSampleGameTests/ContentRegistryTests -only-testing:CardSampleGameTests/PackLoaderTests -only-testing:CardSampleGameTests/HeroPanelTests -resultBundlePath TestResults/UnitTests.${stamp}.xcresult"

echo "Running TwilightEngine gates..."
bash .github/ci/run_quality_gate.sh \
  --id "spm_TwilightEngine_tests" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "swift test --package-path Packages/TwilightEngine ${skip_args_spm}"

bash .github/ci/run_quality_gate.sh \
  --id "spm_twilightengine_strict_concurrency" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/spm_twilightengine_strict_concurrency_gate.sh"

bash .github/ci/run_quality_gate.sh \
  --id "spm_twilightengine_determinism_smoke" \
  --budget-sec 300 \
  --dashboard-dir "${dashboard_dir}" \
  -- "swift test --package-path Packages/TwilightEngine --filter 'INV_RNG_GateTests|INV_SCHEMA28_GateTests|INV_REPLAY30_GateTests|INV_RESUME47_GateTests|ContentRegistryRegistrySyncTests' ${skip_args_spm}"

echo "Running build/content gates..."
bash .github/ci/run_quality_gate.sh \
  --id "build_cardsamplegame" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/run_xcodebuild.sh build -scheme CardSampleGame -destination \"${ios_destination}\""

bash .github/ci/run_quality_gate.sh \
  --id "build_packeditor" \
  --budget-sec 1200 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/run_xcodebuild.sh build -scheme PackEditor -destination \"platform=macOS\""

bash .github/ci/run_quality_gate.sh \
  --id "content_json_lint" \
  --budget-sec 300 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/content_json_lint.sh"

bash .github/ci/run_quality_gate.sh \
  --id "repo_hygiene" \
  --budget-sec 120 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/validate_repo_hygiene.sh --require-clean-tree"

bash .github/ci/run_quality_gate.sh \
  --id "docs_sync" \
  --budget-sec 120 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/validate_docs_sync.sh"

bash .github/ci/run_quality_gate.sh \
  --id "legacy_cleanup" \
  --budget-sec 120 \
  --dashboard-dir "${dashboard_dir}" \
  -- "bash .github/ci/validate_legacy_cleanup.sh"

bash .github/ci/generate_gate_inventory_report.sh "${dashboard_dir}"

echo "Validating RC profiles..."
bash .github/ci/validate_release_profile.sh --profile rc_engine_twilight --dashboard-dir "${dashboard_dir}" --registry "${registry_file}"
bash .github/ci/validate_release_profile.sh --profile rc_app --dashboard-dir "${dashboard_dir}" --registry "${registry_file}"
bash .github/ci/validate_release_profile.sh --profile rc_build_content --dashboard-dir "${dashboard_dir}" --registry "${registry_file}"
bash .github/ci/validate_release_profile.sh --profile rc_full --dashboard-dir "${dashboard_dir}" --registry "${registry_file}"

bash .github/ci/validate_repo_hygiene.sh --require-clean-tree

echo "Release check completed successfully."
