# Quality Control Model

**Scope:** architecture correctness, determinism, migration safety, CI enforceability.  
**Status:** source of truth for quality gates.  
**Last updated:** 2026-02-09

This document is the canonical control point for validating product health after the Phase 2 audit/refactor stream.

## 1. Control Layers

1. **Engine package gates (`swift test`)**
   - Determinism and state invariants.
   - Save schema compatibility and migration contract.
   - Strict concurrency gate.
2. **App gates (`xcodebuild test`)**
   - Architecture boundaries (Engine-First).
   - Save/load integration and wrapper compatibility.
   - Static hygiene gates (mutation boundaries, design/l10n/content).
3. **CI pipeline (`.github/workflows/tests.yml`)**
   - Blocks merge on gate failure.
   - Includes focused smoke filters for fast non-regression.
4. **Documentation contract**
   - `Docs/plans/2026-02-07-audit-refactor-phase2-epics.md` is the epic status ledger.
   - This file is the quality policy and test model baseline.

## 2. Mandatory Gates

### 2.1 Engine (TwilightEngine)

- **Determinism smoke:**
  - `INV_RNG_GateTests`
  - `INV_REPLAY30_GateTests`
  - `INV_RESUME47_GateTests`
  - `ContentRegistryRegistrySyncTests`
- **Schema compatibility smoke (Epic 28):**
  - `INV_SCHEMA28_GateTests`
- **Strict concurrency:**
  - `bash .github/ci/spm_twilightengine_strict_concurrency_gate.sh`
  - Gate uses build-only mode (`swift build --build-tests`) with strict flags, so runtime test flakes do not mask compiler diagnostics.
  - CI fails on compiler diagnostics with file/line coordinates.

### 2.2 App (CardSampleGameTests)

- **Architecture + mutation boundaries:**
  - `AuditGateTests` (core runtime/content/save boundary enforcement)
  - Includes `testEngineJournalUsesCoreStatePrimitives` (journal/resonance core primitive contract)
  - Includes `testCardSampleGameTestsDoesNotLinkTwilightEngineDirectly` (prevents duplicate TwilightEngine runtime loading in host+tests)
  - `AuditArchitectureBoundaryGateTests` (active split suite for architecture boundary contracts, used by `app_gate_2b_audit_architecture`)
- **Save/load integration:**
  - `SaveLoadTests`
  - Includes legacy file-wrapper decode path (`testSaveManagerLoadsLegacySchemaPayloadsFromDisk`).
- **Quality suites:**
  - `CodeHygieneTests`
  - Hard line-limit contract: first-party Swift files must stay `<= 600` lines (line-limit has no legacy exemptions; vendor/build artifacts excluded).
  - Public type-count contract: audited files must stay `<= 5` public types per file (no legacy exemptions).
  - `DesignSystemComplianceTests`
  - `ContrastComplianceTests`
  - `LocalizationValidatorTests`
  - `LocalizationCompletenessTests`
  - `ContentValidationTests`
  - `ConditionValidatorTests`
  - `ExpressionParserTests`
  - `ProfileGateTests`
  - `HeroRegistryTests`
  - `ContentManagerTests`
  - `ContentRegistryTests`
  - `PackLoaderTests`
  - `HeroPanelTests`
- **Runtime test stability contract (Epic 59):**
  - Do not hardcode balance-derived runtime constants in tests when the active content config is the source of truth.
  - Do not assert localized narrative copy for gameplay success/failure semantics; assert typed outcomes (`MiniGameOutcome`) and/or state changes.

## 3. Save Schema Contract (Epic 28)

### 3.1 Contract Rules

- Engine save payloads must decode from:
  - **legacy payloads** (missing compatibility/runtime fields),
  - **forward payloads** (unknown extra fields).
- Decoding defaults must preserve deterministic recovery:
  - If `rngState` is missing, fallback to `rngSeed`.
- Schema changes require:
  - updating schema gate expectations,
  - updating migration fixtures/payload tests,
  - keeping `formatVersion` contract explicit.

### 3.2 Enforcement Points

- `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_SCHEMA28_GateTests.swift`
  - known-key contract per `formatVersion`,
  - required encoded-key contract per `formatVersion`,
  - legacy + forward decode matrix.
- `CardSampleGameTests/Unit/SaveLoadTests.swift`
  - file-based wrapper migration test through `SaveManager`.
- `Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineSave.swift`
  - decode defaults and migration-safe fallbacks.

## 4. External Combat Boundary Contract

- Canonical world-state commit path for external combat:
  - `commitExternalCombat(...)` facade on `TwilightGameEngine`.
- Quick Battle/Arena is sandboxed:
  - does not commit combat result to the world save path.
- App static gates enforce boundary rules:
  - block unauthorized `EchoCombatBridge.applyCombatResult(...)` call-sites,
  - block unauthorized `.startCombat(...)` / `.commitExternalCombat(...)` call-sites,
  - block direct `combat.setupCombatEnemy(...)` app-layer call-sites,
  - block any direct app-layer `.combatFinish(...)` usage,
  - block app-layer `extension TwilightGameEngine` reintroduction in `Views/Combat` bridge files,
  - block app-layer direct assignments to critical engine state fields,
  - block app-layer direct access to `engine.services.rng`,
  - block `UInt64.random(...)` seed generation in `BattleArenaView` (arena uses an arena-local deterministic seed generator),
  - enforce BattleArena sandbox contract via `AuditArchitectureBoundaryGateTests.testBattleArenaRemainsSandboxedFromWorldEngineCommitPath`,
  - enforce that audit suites do not duplicate test names (`AuditArchitectureBoundaryGateTests.testAuditGateSuitesDoNotDuplicateTestNames`),
  - enforce typed invalid-action reason contract (`ActionError.invalidAction(reason: InvalidActionReason)`) and block raw string construction (`.invalidAction(reason: "..."`) in `Engine/Core`,
  - block ViewModel imports of UI/render modules (`SwiftUI/UIKit/AppKit/SpriteKit/SceneKit/Echo*`),
  - block model-layer imports of UI/render modules,
  - block ViewModel references to concrete View types.
- prevent direct `TwilightEngine` package linkage in `CardSampleGameTests` target (host app is the single runtime owner, enforced by `AuditGateTests`).
- Engine/Core static allowlist gate enforces that critical state mutation points stay centralized in approved files.
- Stress determinism matrix (Epic 35):
  - `ExternalCombatPersistenceTests` verifies pending external-combat fingerprint stability across repeated save/load cycles,
  - interrupted-combat commit parity is validated after resume round-trips (`commitExternalCombat(.escaped, ...)`).
  - `combatFinish` commit path clears event lock (`currentEventId/currentEvent`) after quest-trigger processing to avoid stale event drift between fresh and resumed sessions.

## 4.1 Core Journal/Resonance Mutation Contract

- Journal writes must use core primitives only:
  - `resolveRegionName(forRegionId:)`
  - `appendEventLogEntry(dayNumber:...)`
- Journal extension must not mutate/read UI mirror fields directly (`publishedRegions`, `publishedEventLog`, `setEventLog(...)`).
- Resonance updates in engine action flow must go through canonical setter:
  - `setWorldResonance(_:)` (absolute clamp)
  - `adjustResonance(by:)` (delta path)

## 5. Deterministic Replay Contract (Epic 30)

- Canonical replay trace schema (`schemaVersion`, `traceId`, ordered `steps`) is encoded with stable JSON ordering.
- Replay fixture corpus is versioned and source-controlled:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/Fixtures/Replay/epic30_smoke_seed_424242_v1.json`
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/Fixtures/Replay/epic30_smoke_seed_808080_v1.json`
- Replay harness runs a fixed trace against `TwilightGameEngine` and records:
  - step-digest fingerprint (success/error/day/tension/event/rng state per step),
  - final-state fingerprint (canonical normalized engine snapshot).
- Checkpoint restore contract:
  - replay with save/load checkpoints must match linear replay fingerprints for the same seed.
- Replay drift diagnostics are mandatory:
  - gate output must include fingerprint mismatch details,
  - first step-digest mismatch (when present),
  - suggested replacement block for fixture `expected` payload.
- Controlled fixture refresh path:
  - run `REPLAY_FIXTURE_UPDATE=1 swift test --package-path Packages/TwilightEngine --filter INV_REPLAY30_GateTests`.
- Enforcement point:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_REPLAY30_GateTests.swift`

## 5.1 Save/Resume Fault Injection Matrix (Epic 47)

- Save/resume determinism is validated under injected persistence faults:
  - interrupted save-write payload (decode failure) with fallback to last valid checkpoint,
  - partial snapshot resume path (missing migration-default fields),
  - repeated mixed recoveries across multiple seeds.
- Recovery path contract:
  - baseline and recovered runs must keep identical step and final fingerprints,
  - no drift in RNG/event-lock-related state (`rngState`, `currentEventId`, `pendingEncounterState`, `pendingExternalCombatSeed`).
- Enforcement point:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_RESUME47_GateTests.swift`

## 6. Package Resolution Contract

- Workspace uses a single canonical lockfile:
  - `CardSampleGame.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Repository hygiene gate:
  - `.github/ci/validate_repo_hygiene.sh` enforces canonical lockfile path and blocks tracked transient artifacts.
  - optional hard mode (`--require-clean-tree`) enforces zero tracked working-tree drift.
- Dependency graph expectation:
  - `EchoEngine` resolves `FirebladeECS` from local path override.

## 6.1 Documentation Sync Contract (Epic 48)

- Documentation drift is a blocking quality signal.
- Validator:
  - `.github/ci/validate_docs_sync.sh`
- Contract scope:
  - workflow smoke filter tokens in `.github/workflows/tests.yml`,
  - QA policy in `Docs/QA/QUALITY_CONTROL_MODEL.md`,
  - operational guide in `Docs/QA/TESTING_GUIDE.md`,
  - epic status ledger in `Docs/plans/2026-02-07-audit-refactor-phase2-epics.md`.
- Mandatory contract markers:
  - `INV_SCHEMA28_GateTests`
  - `INV_REPLAY30_GateTests`
  - `INV_RESUME47_GateTests`
  - `ContentRegistryRegistrySyncTests`
  - Epic status markers for `Epic 28`, `Epic 30`, `Epic 47`, `Epic 48`.
  - Backlog epoch marker must match auto-detected latest `DONE` epic:
    - `Pending backlog (post-Epic N)` where `N = max(done_epic_number)`.

## 7. CI Quality Budget & Flake Control (Epic 31)

- CI wraps gate steps with `run_quality_gate.sh` to:
  - enforce time budgets,
  - write a per-job dashboard artifact with durations and failure taxonomy:
    - `TestResults/QualityDashboard/summary.md`
    - `TestResults/QualityDashboard/gates.jsonl`
    - `TestResults/QualityDashboard/gate_inventory.json`
    - `TestResults/QualityDashboard/gate_drift_report.md`
  - render `summary.md` as a latest-only snapshot per gate ID (last result wins); full attempt history remains in `gates.jsonl`.
- CI normalizes app-runner variability with:
  - `.github/ci/select_ios_destination.sh` (resolves valid simulator `name+OS` for current Xcode image),
  - `.github/ci/run_xcodebuild.sh` (`xcpretty` optional, plain `xcodebuild` fallback).
  - `.github/ci/clean_test_artifacts.sh` (clears stale `xcresult`/log artifacts before gates),
  - `.github/ci/preflight_ci_environment.sh` (captures toolchain snapshot per job in quality dashboard artifact).
  - `.github/ci/generate_gate_inventory_report.sh` (builds CI/tests/docs inventory + drift report in quality dashboard artifact).
- Failure taxonomy (coarse, CI-oriented):
  - `deterministic`: reproducible test/build failure.
  - `infra_transient`: simulator/resolution/host instability patterns.
  - `deterministic_budget`: gate exceeded its declared runtime budget.
- Flaky test quarantine policy:
  - Registry: `.github/flaky-quarantine.csv` (CSV, no quoted commas).
  - Validation gate: `.github/ci/validate_flaky_quarantine.sh` (fails CI on missing owner/expiry, invalid format, or expired entries).
  - Application:
    - SwiftPM: `.github/ci/quarantine_args.sh --format swiftpm --suite spm:<Package>` emits `--skip <regex>` for `swift test`.
    - Xcodebuild: `.github/ci/quarantine_args.sh --format xcodebuild --suite xcodebuild:CardSampleGame` emits `-skip-testing:<id>`.
  - Rule: quarantine entries must have explicit `owner`, `issue_url`, and `expires_on`, and must be removed/renewed before expiry.

## 8. Release Candidate Quality Profile (Epic 38/39)

- Enforcer script: `.github/ci/validate_release_profile.sh`.
- RC profiles are declarative and fail hard on:
  - missing gate results in `TestResults/QualityDashboard/gates.jsonl`,
  - non-passed gate status,
  - gate duration above the RC threshold,
  - configured gate budget above the RC threshold,
  - any active entries in `.github/flaky-quarantine.csv` (zero-tolerance window).
- Profile `rc_engine_twilight` requires:
  - `spm_TwilightEngine_tests` (`<=1200s`)
  - `spm_twilightengine_strict_concurrency` (`<=1200s`)
  - `spm_twilightengine_determinism_smoke` (`<=300s`)
- Profile `rc_app` requires:
  - `app_gate_0_strict_concurrency` (`<=1200s`)
  - `app_gate_1_quality` (`<=1200s`)
  - `app_gate_2_content_validation` (`<=1200s`)
  - `app_gate_2a_audit_core` (`<=1200s`)
  - `app_gate_2b_audit_architecture` (`<=1200s`)
  - `app_gate_3_unit_views` (`<=1200s`)
- Profile `rc_build_content` requires:
  - `build_cardsamplegame` (`<=1200s`)
  - `build_packeditor` (`<=1200s`)
  - `content_json_lint` (`<=300s`)
  - `repo_hygiene` (`<=120s`)
  - `docs_sync` (`<=120s`)
- Profile `rc_full` requires all gates from:
  - `rc_engine_twilight`
  - `rc_app`
  - `rc_build_content`
- CI wiring:
  - `spm-packages` job validates `rc_engine_twilight` for `TwilightEngine`.
  - `app-tests` job validates `rc_app` after gate inventory generation.
  - `build-validation` writes `build_cardsamplegame` / `build_packeditor` through `run_quality_gate.sh`.
  - `content-validation` writes `content_json_lint` and `repo_hygiene` through `run_quality_gate.sh`.
  - `content-validation` writes `docs_sync` through `run_quality_gate.sh`.
  - `release-readiness-profile` job aggregates all dashboards and validates `rc_full`.
- Unified local release checkpoint:
  - `.github/ci/run_release_check.sh` runs app/engine/build/content gates and validates `rc_engine_twilight`, `rc_app`, `rc_build_content`, `rc_full`.
  - local run is hard-gated by `validate_repo_hygiene.sh --require-clean-tree` before any test/build step starts.
- RC reports are published into dashboard artifacts:
  - `TestResults/QualityDashboard/release_profile_rc_engine_twilight.md`
  - `TestResults/QualityDashboard/release_profile_rc_app.md`
  - `TestResults/QualityDashboard/release_profile_rc_build_content.md`
  - `TestResults/QualityDashboard/release_profile_rc_full.md`

## 9. Execution Commands

```bash
# Engine schema/determinism smoke
swift test --package-path Packages/TwilightEngine \
  --filter 'INV_RNG_GateTests|INV_SCHEMA28_GateTests|INV_REPLAY30_GateTests|INV_RESUME47_GateTests|ContentRegistryRegistrySyncTests'

# App architecture + save/load integration
xcodebuild test -project CardSampleGame.xcodeproj \
  -scheme CardSampleGame \
  -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" \
  -only-testing:CardSampleGameTests/AuditGateTests \
  -only-testing:CardSampleGameTests/AuditArchitectureBoundaryGateTests \
  -only-testing:CardSampleGameTests/SaveLoadTests

# RC profile validation (after gates have produced QualityDashboard/gates.jsonl)
bash .github/ci/validate_release_profile.sh \
  --profile rc_engine_twilight \
  --dashboard-dir TestResults/QualityDashboard \
  --registry .github/flaky-quarantine.csv

bash .github/ci/validate_release_profile.sh \
  --profile rc_app \
  --dashboard-dir TestResults/QualityDashboard \
  --registry .github/flaky-quarantine.csv

# Repository hygiene (canonical Package.resolved + transient-artifact guard)
bash .github/ci/validate_repo_hygiene.sh

bash .github/ci/validate_release_profile.sh \
  --profile rc_full \
  --dashboard-dir TestResults/QualityDashboard \
  --registry .github/flaky-quarantine.csv

# Unified local release readiness run
bash .github/ci/run_release_check.sh TestResults/QualityDashboard CardSampleGame
```

## 10. Change Checklist (Required for Refactors)

- Update/extend gate tests before or with behavior changes.
- Keep CI smoke filters aligned with new gate suites.
- Update `Docs/plans/2026-02-07-audit-refactor-phase2-epics.md` status.
- Update this document when quality policy, gates, or contracts change.

## 11. Structural Decomposition Backlog (Post-Epic 59)

- Current monolith hotspots:
  - `Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine.swift` (`1085` lines after Epic 53 checkpoint #5),
  - `Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentRegistry.swift` (`987` lines after current split),
  - `Views/WorldMapView.swift` (`287` lines after Epic 55 checkpoint #1),
  - `CardSampleGameTests/GateTests/AuditGateTests.swift` (`2382` lines).
- Current decomposition checkpoint:
  - world-state models moved out of engine core into `Core/EngineWorldStateModels.swift`,
  - read-only engine query API moved into `Core/TwilightGameEngine+ReadOnlyQueries.swift`,
  - exploration availability query moved into `Core/TwilightGameEngine+ExplorationQueries.swift`,
  - action validation/time/execution pipeline moved into `Core/TwilightGameEngine+ActionPipeline.swift`,
  - bootstrap/mapping/validation helpers moved into `Core/TwilightGameEngine+BootstrapAndValidation.swift`,
  - combat/resonance/external-commit support moved into `Core/TwilightGameEngine+StateSupport.swift`,
  - persistence snapshot builder moved into `Core/TwilightGameEngine+PersistenceSnapshot.swift`,
  - world bootstrap model moved into `Core/EngineWorldBootstrapState.swift`,
  - world map subviews moved out of `Views/WorldMapView.swift` into `Views/WorldMap/EngineRegionDetailView.swift`, `Views/WorldMap/EngineRegionCardView.swift`, `Views/WorldMap/EngineEventLogView.swift`, and `Views/WorldMap/EventLogEntryView.swift`,
  - `BalancePackAccess` moved out of `ContentRegistry.swift` into `ContentPacks/BalancePackAccess.swift`.
- Validation policy for decomposition waves:
  - mandatory: TwilightEngine determinism/schema smoke (`INV_RNG`, `INV_SCHEMA28`, `INV_REPLAY30`, `INV_RESUME47`, `ContentRegistryRegistrySyncTests`),
  - mandatory: app architecture gate suite (`AuditGateTests`, `AuditArchitectureBoundaryGateTests`) when simulator infrastructure is available.
- Infra risk note:
  - `xcodebuild` test runs may fail with runner bootstrap crash (`Early unexpected exit`) unrelated to compile/contracts; classify as `infra_transient` and re-run under CI/local simulator health check before regression triage.
