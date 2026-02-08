# Testing Guide

**Last updated:** 2026-02-08  
**Primary QA source of truth:** `Docs/QA/QUALITY_CONTROL_MODEL.md`

This guide is the operational runner for day-to-day checks.  
Policy, contracts, and gate definitions live in `QUALITY_CONTROL_MODEL.md`.

## 1. Test Topology

- **Engine package tests**: `Packages/TwilightEngine/Tests/TwilightEngineTests`
- **App tests**: `CardSampleGameTests`
- **CI orchestration**: `.github/workflows/tests.yml`

## 2. Core Commands

```bash
# Full TwilightEngine package tests
swift test --package-path Packages/TwilightEngine

# Epic 28 schema compatibility smoke
swift test --package-path Packages/TwilightEngine \
  --filter INV_SCHEMA28_GateTests

# Epic 30 replay determinism smoke
swift test --package-path Packages/TwilightEngine \
  --filter INV_REPLAY30_GateTests

# App save/load + architecture gates
xcodebuild test -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" \
  -only-testing:CardSampleGameTests/SaveLoadTests \
  -only-testing:CardSampleGameTests/AuditArchitectureBoundaryGateTests \
  -only-testing:CardSampleGameTests/AuditGateTests
```

## 3. CI Gate Mapping

- **SPM package matrix**: all package tests.
- **TwilightEngine strict concurrency gate**: fails on strict-concurrency diagnostics.
- **TwilightEngine determinism/schema smoke**:
  - `INV_RNG_GateTests`
  - `INV_SCHEMA28_GateTests`
  - `INV_REPLAY30_GateTests`
  - `INV_RESUME47_GateTests`
  - `ContentRegistryRegistrySyncTests`
- **App strict concurrency gate**: `xcodebuild build` with `SWIFT_STRICT_CONCURRENCY=complete`.
- **App gate layers**:
  - quality/l10n/design gates,
  - content validation gates,
  - unit/view suites (`HeroRegistryTests`, `SaveLoadTests`, `ContentManagerTests`, `ContentRegistryTests`, `PackLoaderTests`, `HeroPanelTests`),
  - audit core suite in `AuditGateTests` (asset/content/save/runtime contracts),
  - audit architecture suite in `AuditArchitectureBoundaryGateTests` (Epic 29/33/34/36/42/43 boundaries: critical state assignment scan, RNG-service access scan, arena sandbox gate + `UInt64.random` ban, explicit `.startCombat/.commitExternalCombat/EchoCombatBridge.applyCombatResult` allowlists, direct `.combatFinish` ban, combat-bridge no-extension gate, ViewModel/model UI-import bans, ViewModel→View type-reference ban, Engine/Core allowlist scan).
  - Epic 35 external-combat stress determinism checks in `ExternalCombatPersistenceTests` (resume fingerprint stability across repeated save/load + interrupted-commit parity after resume cycles; event lock clears consistently on combat commit).
- **Destination/tooling stability helpers**:
  - `.github/ci/select_ios_destination.sh` resolves a concrete simulator `name+OS` from current Xcode runtime set.
  - `.github/ci/run_xcodebuild.sh` uses `xcpretty` when available and falls back to plain `xcodebuild` otherwise.
  - `.github/ci/clean_test_artifacts.sh` removes stale local/CI test artifacts before gate execution.
  - `.github/ci/preflight_ci_environment.sh` writes `toolchain_snapshot.md` into `TestResults/QualityDashboard`.
- **RC profile enforcement (Epic 38/39)**:
  - `spm-packages` validates `rc_engine_twilight` for `TwilightEngine`.
  - `app-tests` validates `rc_app` after inventory/drift generation.
  - `build-validation` publishes `build_cardsamplegame` and `build_packeditor` gates.
  - `content-validation` publishes `content_json_lint`, `repo_hygiene`, and `docs_sync` gates.
  - `release-readiness-profile` validates aggregated `rc_full` from all artifacts.
  - both profiles require zero active quarantine entries.

## 4. Save Schema Migration Checks (Epic 28)

- Engine-level matrix and key-contract tests:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_SCHEMA28_GateTests.swift`
- App wrapper legacy-file compatibility:
  - `CardSampleGameTests/Unit/SaveLoadTests.swift`
  - `testSaveManagerLoadsLegacySchemaPayloadsFromDisk`

## 5. Replay Contract Checks (Epic 30)

- Canonical action-trace replay gate:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_REPLAY30_GateTests.swift`
- Versioned replay fixtures:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/Fixtures/Replay/epic30_smoke_seed_424242_v1.json`
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/Fixtures/Replay/epic30_smoke_seed_808080_v1.json`
- Coverage:
  - canonical trace schema round-trip stability,
  - same-seed replay fingerprint stability,
  - checkpoint restore vs linear replay fingerprint parity,
  - different-seed divergence,
  - fixture drift diagnostics (fingerprints + first step mismatch + suggested expected block).
- Controlled fixture update flow:

```bash
REPLAY_FIXTURE_UPDATE=1 \
swift test --package-path Packages/TwilightEngine \
  --filter INV_REPLAY30_GateTests
```

## 5.1 Save/Resume Fault Injection (Epic 47)

- Gate suite:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_RESUME47_GateTests.swift`
- Coverage:
  - interrupted save-write simulation with fallback recovery from last valid checkpoint,
  - partial snapshot resume path with migration-default fields omitted,
  - repeated mixed recoveries with deterministic baseline parity.
- Drift checks:
  - final fingerprint and step fingerprint parity versus baseline,
  - no drift in `rngState`, `currentEventId`, `pendingEncounterState`, `pendingExternalCombatSeed`.

```bash
swift test --package-path Packages/TwilightEngine \
  --filter INV_RESUME47_GateTests
```

## 6. CI Quality Dashboard (Epic 31)

- Each CI gate writes duration + status metadata into:
  - `TestResults/QualityDashboard/summary.md`
  - `TestResults/QualityDashboard/gates.jsonl`
- `summary.md` keeps one latest row per gate ID (last execution wins); `gates.jsonl` preserves the raw append-only gate history.
- Epic 37 inventory/drift artifact:
  - `TestResults/QualityDashboard/gate_inventory.json`
  - `TestResults/QualityDashboard/gate_drift_report.md`
- Runner: `.github/ci/run_quality_gate.sh` (budget enforcement + failure taxonomy).
- Inventory generator: `.github/ci/generate_gate_inventory_report.sh`.

## 7. Release Candidate Profile (Epic 38/39)

- Enforcer: `.github/ci/validate_release_profile.sh`.
- Input: `TestResults/QualityDashboard/gates.jsonl` produced by `run_quality_gate.sh`.
- Output reports:
  - `TestResults/QualityDashboard/release_profile_rc_engine_twilight.md`
  - `TestResults/QualityDashboard/release_profile_rc_app.md`
  - `TestResults/QualityDashboard/release_profile_rc_build_content.md`
  - `TestResults/QualityDashboard/release_profile_rc_full.md`
- Fails if gate is missing/not passed, if runtime or configured budget exceeds RC threshold, or if quarantine has active entries.

```bash
# Validate TwilightEngine RC subset (run in TwilightEngine SPM job context)
bash .github/ci/validate_release_profile.sh \
  --profile rc_engine_twilight \
  --dashboard-dir TestResults/QualityDashboard \
  --registry .github/flaky-quarantine.csv

# Validate App RC subset (run in app-tests job context)
bash .github/ci/validate_release_profile.sh \
  --profile rc_app \
  --dashboard-dir TestResults/QualityDashboard \
  --registry .github/flaky-quarantine.csv

# Validate full RC profile (run in aggregated release-readiness context)
bash .github/ci/validate_release_profile.sh \
  --profile rc_full \
  --dashboard-dir TestResults/QualityDashboard \
  --registry .github/flaky-quarantine.csv

# Unified local release check
bash .github/ci/run_release_check.sh TestResults/QualityDashboard CardSampleGame

# Pre-check only: fail on tracked working tree drift
bash .github/ci/validate_repo_hygiene.sh --require-clean-tree
```

## 8. Flaky Quarantine (Epic 31)

- Registry: `.github/flaky-quarantine.csv` (CSV, no quoted commas, must keep header).
- Validation: `.github/ci/validate_flaky_quarantine.sh` (fails on expired entries or missing owner/expiry/issue).
- Application:
  - SwiftPM: `.github/ci/quarantine_args.sh --format swiftpm --suite spm:<Package>` emits `--skip <regex>`.
  - Xcodebuild: `.github/ci/quarantine_args.sh --format xcodebuild --suite xcodebuild:CardSampleGame` emits `-skip-testing:<id>`.

## 9. Package Lockfile Check

Before closing dependency-related tasks:

```bash
bash .github/ci/validate_repo_hygiene.sh
```

This check enforces:
- single canonical lockfile path (`CardSampleGame.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`),
- no tracked transient artifacts (`xcresult`, local logs, temporary reports).
- in hard mode (`--require-clean-tree`), no tracked working-tree changes.

## 9.1 Documentation Sync Gate (Epic 48)

- Validator:
  - `.github/ci/validate_docs_sync.sh`
- Enforced contracts:
  - determinism/scheme smoke tokens in workflow vs docs,
  - epic status markers (`Epic 28`, `Epic 30`, `Epic 47`, `Epic 48`) in ledger,
  - dynamic backlog epoch marker parity (`Pending backlog (post-Epic N)` with latest `DONE` epic).
- RC implication:
  - `docs_sync` is required in `rc_build_content` and therefore in `rc_full`.

```bash
bash .github/ci/validate_docs_sync.sh
```

## 10. Change Discipline

- Add or update tests in the same PR as behavior changes.
- Keep `QUALITY_CONTROL_MODEL.md` and epic status docs in sync.
- Do not soften gate failures with skips in mandatory suites.
