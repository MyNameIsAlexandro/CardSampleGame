# Testing Guide

**Last updated:** 2026-02-12  
**Phase 2 checkpoint:** Epic 66  
**Primary QA source of truth:** `Docs/QA/QUALITY_CONTROL_MODEL.md`
**Policy sync:** `CLAUDE.md` v4.1 engineering contract

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

# TwilightEngine strict concurrency diagnostics gate (build-only)
bash .github/ci/spm_twilightengine_strict_concurrency_gate.sh

# App save/load + architecture gates
xcodebuild test -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" \
  -only-testing:CardSampleGameTests/SaveLoadTests \
  -only-testing:CardSampleGameTests/AuditArchitectureBoundaryGateTests \
  -only-testing:CardSampleGameTests/AuditGateTests

# Resume-path localization smoke (external combat bridge relocalization)
xcodebuild test -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" \
  -only-testing:CardSampleGameTests/SaveLoadTests/testEchoEncounterBridgeRelocalizesResumeDeckCardsFromRegistry

# Optional: enable verbose loader diagnostics for local debugging
TWILIGHT_TEST_VERBOSE=1 swift test --package-path Packages/TwilightEngine --filter GameplayFlowTests
```

## 3. CI Gate Mapping

- **SPM package matrix**: all package tests.
- **TwilightEngine strict concurrency gate**:
  - runs in build-only mode (`swift build --build-tests` + strict flags),
  - fails on strict-concurrency diagnostics only.
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
  - unit/view suites (`HeroRegistryTests`, `SaveLoadTests`, `ContentManagerTests`, `ContentRegistryTests`, `PackLoaderTests`, `HeroPanelTests`, `RitualIntegrationMappingsGateTests`),
  - audit core suite in `AuditGateTests` (asset/content/save/runtime contracts and journal/runtime boundary checks),
  - `CodeHygieneTests` enforces hard `<=600` line limit and `<=5` public types per file for first-party Swift code (excluding vendor/build artifacts; no legacy exemptions),
  - `CodeHygieneTests.testFirstPartySwiftFilesHaveCanonicalFileHeaders` enforces mandatory 4-line Russian file-header contract for first-party Swift files,
  - `AuditGateTests.testEngineJournalUsesCoreStatePrimitives` enforces core journal/resonance mutation primitives (`resolveRegionName`, `appendEventLogEntry`, `setWorldResonance`) and blocks fallback to UI mirror state access.
  - `AuditGateTests.testCardSampleGameTestsDoesNotLinkTwilightEngineDirectly` blocks direct `TwilightEngine` linkage in `CardSampleGameTests` target to avoid host+test runtime duplication warnings (`Class ... is implemented in both`).
  - audit architecture suite in `AuditArchitectureBoundaryGateTests` is an active split gate (`app_gate_2b_audit_architecture`) for static boundary enforcement (Epic 29/33/34/36/42/43: critical state assignment scan, RNG-service access scan, arena sandbox gate + `UInt64.random` ban, explicit `.startCombat/.commitExternalCombat/EchoCombatBridge.applyCombatResult` allowlists, direct `.combatFinish` ban, combat-bridge no-extension gate, ViewModel/model UI-import bans, ViewModel→View type-reference ban, Engine/Core allowlist scan, and anti-duplicate audit test-name gate).
  - `AuditArchitectureBoundaryGateTests.testEngineInvalidActionUsesTypedReasonCodes` blocks regression to `invalidAction(reason: String)` and raw string reason literals in `Engine/Core`.
  - `SaveLoadTests.testEchoEncounterBridgeRelocalizesResumeDeckCardsFromRegistry` enforces resume-path relocalization for external-combat payload display fields via active `ContentRegistry` + `LocalizationManager` (prevents stale EN/service-token leaks in RU UI).
  - `AuditArchitectureBoundaryGateTests.testHeroAndAbilityIconsAreNotRenderedAsRawTokens` blocks icon/service-token rendering as plain `Text`.
  - Epic 35 external-combat stress determinism checks in `INV_RESUME47_GateTests` (resume fingerprint stability across repeated save/load + interrupted-commit parity after resume cycles; event lock clears consistently on combat commit).
  - Epic 64 test observability hardening keeps loader/runtime debug traces quiet by default; set `TWILIGHT_TEST_VERBOSE=1` to re-enable detailed diagnostics in local debug runs.
- **Destination/tooling stability helpers**:
  - `.github/ci/select_ios_destination.sh` resolves a concrete simulator `name+OS` from current Xcode runtime set.
  - `.github/ci/run_xcodebuild.sh` uses `xcpretty` when available, falls back to plain `xcodebuild`, and auto-retries transient simulator/bootstrap failures for test invocations (`test`, `build-for-testing`, `test-without-building`).
    - knobs: `XCODEBUILD_MAX_ATTEMPTS` (default: `2` for test invocations, `1` otherwise), `XCODEBUILD_RETRY_DELAY_SEC` (default: `8`).
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

# Unified local release check for dirty working tree (snapshot mode)
bash .github/ci/run_release_check_snapshot.sh TestResults/QualityDashboard CardSampleGame

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
bash .github/ci/validate_repo_hygiene.sh --require-clean-tree
```

This check enforces:
- single canonical lockfile path (`CardSampleGame.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`),
- no tracked transient artifacts (`xcresult`, local logs, temporary reports).
- no tracked working-tree changes.
- for local diagnostics on a dirty tree, use `run_release_check_snapshot.sh` (creates a temporary clean snapshot worktree and preserves hard gates).

## 9.1 Documentation Sync Gate (Epic 48)

- Validator:
  - `.github/ci/validate_docs_sync.sh`
- Enforced contracts:
  - determinism/scheme smoke tokens in workflow vs docs,
  - architecture spec sync via `Docs/Technical/ENGINE_ARCHITECTURE.md`,
  - epic status markers (`Epic 28`, `Epic 30`, `Epic 47`, `Epic 48`) in ledger,
  - date parity across QA/testing/architecture/ledger source-of-truth docs,
  - `Phase 2 checkpoint` parity across QA/testing/architecture docs + ledger `DONE` marker,
  - dynamic backlog epoch marker parity (`Pending backlog (post-Epic N)` with latest `DONE` epic).
- RC implication:
  - `docs_sync` is required in `rc_build_content` and therefore in `rc_full`.

```bash
bash .github/ci/validate_docs_sync.sh
```

## 9.2 Legacy Cleanup Gate (Epic 57)

- Validator:
  - `.github/ci/validate_legacy_cleanup.sh`
- Enforced contracts:
  - no TODO/FIXME markers in first-party sources,
  - bridge/adapter entry points must have call-sites (no orphaned adapter files),
  - compatibility markers `COMPAT_REMOVE_BY: YYYY-MM-DD` must not be expired.
- RC implication:
  - `legacy_cleanup` is required in `rc_build_content` and therefore in `rc_full`.

```bash
bash .github/ci/validate_legacy_cleanup.sh
```

## 9.3 File Header Contract Gate (Epic 68)

- Enforced by:
  - `CardSampleGameTests/GateTests/CodeHygieneTests+XcodeProjectStructure.swift`
  - `CodeHygieneTests.testFirstPartySwiftFilesHaveCanonicalFileHeaders`
- Contract:
  - every first-party Swift file must start with:
    - `/// Файл: <relative path>`
    - `/// Назначение: ...`
    - `/// Зона ответственности: ...`
    - `/// Контекст: ...`
- Scope:
  - includes app/tests/packages first-party source,
  - excludes vendor/build/internal agent paths (`Packages/ThirdParty`, `.build`, `.codex_home`) and `Package.swift` manifests (tools-version must be first line).

```bash
xcodebuild test -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" \
  -only-testing:CardSampleGameTests/CodeHygieneTests/testFirstPartySwiftFilesHaveCanonicalFileHeaders
```

## 9a. Phase 3: Disposition Combat Tests (planned)

Phase 3 вводит 7 категорий gate-тестов (35+). После реализации — запуск:

**Engine-side (Disposition + Momentum + Fate):**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test \
  --package-path Packages/TwilightEngine \
  --filter "DispositionMechanicsGateTests|MomentumGateTests|FateKeywordGateTests|EnemyModeGateTests"
```

**App-side (Scene + Resonance + Integration + Anti-Meta):**
```bash
xcodebuild test -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" \
  -only-testing:CardSampleGameTests/CardPlayGateTests \
  -only-testing:CardSampleGameTests/ResonanceEffectsGateTests \
  -only-testing:CardSampleGameTests/AntiMetaGateTests \
  -only-testing:CardSampleGameTests/DispositionIntegrationGateTests
```

**Gate-тесты по категориям (35+):**

| Категория | Тестов | Ключевые инварианты |
|-----------|--------|---------------------|
| Disposition mechanics | 6 | Шкала -100…+100, hard cap effective_power ≤ 25, clamping |
| Momentum system | 5 | streak_bonus, switch_penalty (threshold 3), threat_bonus |
| Card play modes | 4 | Strike/Influence/Sacrifice contracts, drag targets |
| Fate keywords | 5 | Surge +50%, Echo not after Sacrifice, disposition-dependent effects |
| Enemy modes | 5 | Survival/Desperation/Weakened transitions, dynamic thresholds |
| Resonance effects | 5 | Zone modifiers (Навь/Правь/Явь), backlash cancellation |
| Anti-meta | 5 | Vulnerability × Resonance 3D lookup, systemic asymmetry |

> **Source:** [Disposition Combat Design v2.5](../../docs/plans/2026-02-18-disposition-combat-design.md) §10, `QUALITY_CONTROL_MODEL.md` §2a

## 10. Change Discipline

- Add or update tests in the same PR as behavior changes.
- Keep `QUALITY_CONTROL_MODEL.md` and epic status docs in sync.
- Keep `CLAUDE.md`, `QUALITY_CONTROL_MODEL.md`, and this guide in sync when contract-level rules change.
- Do not soften gate failures with skips in mandatory suites.
- Runtime semantic assertions must be locale-agnostic (`outcome`/state changes), not localized narrative substring matching.
- For config-driven engine behavior, tests should assert against active balance/config values, not hardcoded constants.
