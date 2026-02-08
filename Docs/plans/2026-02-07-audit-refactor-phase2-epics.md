# Phase 2 (Post-Epic 14) — Audit & Refactor Backlog

Scope: architecture correctness + quality gates. This is **not** gameplay/product polishing.

## What’s already done (post-Epic 14)

- External combat determinism hardening: external combat seed allocated in `performAction(.startCombat)` and reused (UI reads no longer advance RNG); bridges commit results via `performAction(.combatFinish)`.

## Status snapshot (2026-02-08)

- `Epic 15`: DONE (canonical consequences + mini-game action path covered by target tests).
- `Epic 16`: DONE (typed invalid-action reasons + l10n mapping + gate checks, no raw reason construction in `Engine/Core`).
- `Epic 17`: DONE (seeded determinism harness with save/load checkpoints in target tests).
- `Epic 18`: DONE (atomic safeReload + derived-state rebind + deterministic hot-reload tests).
- `Epic 19`: DONE (shared external combat snapshot builder + bridge consistency tests).
- `Epic 20`: DONE (background/runtime snapshot persistence for external combat + resume path integration).
- `Epic 21`: DONE (legacy event pipelines isolated to devtools target + production gate coverage).
- `Epic 22`: DONE (RNG/save-load determinism contract + architecture gate checks).
- `Epic 23`: DONE (TwilightEngine strict-concurrency baseline hardened to zero warnings under `-strict-concurrency=complete`).
- `Epic 24`: DONE (CI strict-concurrency gate for `TwilightEngine` in `.github/workflows/tests.yml`).
- `Epic 25`: DONE (CI determinism smoke gate for RNG/save-load + safeReload rollback in `TwilightEngine`).
- `Epic 26`: DONE (app-level strict-concurrency gate introduced in CI for `CardSampleGame` builds).
- `Epic 27`: DONE (third-party strict-concurrency unblock via local `FirebladeECS` override + zero-allowlist app gate).
- `Epic 28`: DONE (schema contract gates + legacy/forward migration matrix in engine/app save paths + CI smoke integration).
- `Epic 29`: DONE (critical engine-state mutation boundary gates expanded: app-layer direct assignments blocked, app RNG service access blocked, BattleArena sandbox invariant + Engine/Core mutation allowlist checks).
- `Epic 30`: DONE (canonical replay trace contract + step/final fingerprint harness + checkpoint-restore determinism gates + CI smoke integration).
- `Epic 31`: DONE (CI quality budget wrapper + per-gate dashboard artifacts + flaky quarantine registry with validation and automatic skip args for SwiftPM/xcodebuild).
- `Epic 32`: DONE (CI hermetic runner prep: preflight toolchain snapshot + stale artifact cleanup hook + destination/tool fallback hardening in app/build gates).
- `Epic 33`: DONE (external combat action call-site gates hardened: explicit allowlists for `.startCombat` / `.combatFinish` and stronger BattleArena sandbox prohibition patterns).
- `Epic 34`: DONE (canonical external combat commit facade `commitExternalCombat(...)` added in engine + app-layer direct `.combatFinish` banned by gate).
- `Epic 35`: DONE (save/resume stress determinism matrix added for external combat snapshots: repeated save/load round-trips + interrupted-combat commit parity via deterministic fingerprints).
- `Epic 36`: DONE (architecture dependency gates added: ViewModels/models UI-import bans + ViewModel→View type-reference ban; ContentManagerVM decoupled from UI clipboard APIs).
- `Epic 37`: DONE (CI gate inventory + contract drift auto-report generated in `TestResults/QualityDashboard` as JSON+Markdown artifact with tests/docs/workflow consistency checks).
- `Epic 38`: DONE (release-candidate quality profile enforcer added with RC gate subsets, threshold checks, and quarantine zero-tolerance policy wired into CI app + TwilightEngine paths).
- `Epic 39`: DONE (release readiness consolidation: build/content converted to quality-gated artifacts, aggregated `rc_full` validation in CI, and single-command local `run_release_check.sh` orchestration).
- `Epic 40`: DONE (external combat snapshot/context extraction into TwilightEngine package + app bridge hardening gate to prevent regression).
- `Epic 41`: DONE (public RNG seed facade removed; app-layer `nextSeed` access blocked by static gates; seed capability anchored to action pipeline).
- `Epic 42`: DONE (BattleArena sandbox RNG hardening: local deterministic RNG instance in arena flow + static gate ban for `UInt64.random` in `BattleArenaView`).
- `Epic 43`: DONE (app-layer external-combat bridges de-extended: `EchoCombatBridge`/`EchoEncounterBridge` are adapter types, call-sites migrated, and static gate blocks `extension TwilightGameEngine` reintroduction in `Views/Combat`).
- `Epic 47`: DONE (save/resume fault-injection matrix added with interrupted-write fallback recovery, partial snapshot resume, and deterministic fingerprint parity checks).
- `Epic 48`: DONE (documentation sync validator gate added; CI/RC now fail on mandatory contract drift across epic ledger + QA model + testing guide).
- `Epic 49`: DONE (`run_quality_gate.sh` now renders `summary.md` as latest-only per gate ID; duplicate historical attempts remain in `gates.jsonl` only).
- `Epic 50`: DONE (local release runner now hard-gates on clean tracked working tree via `validate_repo_hygiene.sh --require-clean-tree` before any gate execution).
- `App strict-concurrency note`: app strict build baseline is green (no compiler file/line warnings/errors) with local `Packages/ThirdParty/FirebladeECS` override.
- `Release readiness checkpoint (local)`: `run_release_check.sh` passed with `rc_engine_twilight`, `rc_app`, `rc_build_content`, and `rc_full`.

## Epics

### Epic 15 [DONE] — Event / MiniGame Consequences Canonicalization

Goal: stop “legacy consequence execution drift”. The engine must apply the **canonical** `ChoiceConsequences` / `MiniGameChallengeDefinition` semantics from content packs.

Deliverables:
- `chooseEventOption` applies consequences from `EventDefinition.choices[choiceIndex].consequences` (not only the legacy `GameEvent/EventConsequences` adapter output), with a safe fallback for synthetic events (e.g. random encounters).
- Support `region_state_change` (restore/degrade/set) as an engine mutation + `StateChange.regionStateChanged`.
- `resolveMiniGame` becomes a real first-class action:
  - Allowed during event-lock.
  - Strict validation (active event + matching mini-game challenge).
  - Applies victory/defeat consequences deterministically.
  - Produces an “event completed” quest trigger.

Acceptance:
- New unit test: a story-pack event with `region_state_change: restore` actually transitions region state (`breach → borderland`) through `performAction(.chooseEventOption)`.
- No UI-level direct state mutation added; only `performAction` commits.

### Epic 16 [DONE] — Error / L10n Canon (No Raw User Strings)

Goal: user-facing errors/messages must be stable codes + localized keys. No raw English/Russian strings in engine error paths.

Deliverables:
- Convert remaining raw strings in engine “error-like” returns to codes + `L10n`.
- Introduce a gate test that flags new raw-string regressions in:
  - `ActionError.localizedDescription` fallbacks
  - mini-game/event error paths

Acceptance:
- Gate test fails if a new raw string is introduced in restricted engine paths.

### Epic 17 [DONE] — Save/Load Determinism Harness

Goal: prove “same seed + same actions ⇒ same observable state”, including round-trips through save/load.

Deliverables:
- Differential tests:
  - run a seeded action script; save/load at N checkpoints; compare canonical snapshots.
  - ensure RNG state + derived state remain consistent.
- Expand “reads don’t mutate” coverage (RNG purity, fate deck snapshots, config factories).

Acceptance:
- Determinism suite runs multiple iterations without flakiness.

### Epic 18 [DONE] — Content Hot-Reload Safety (Engine Consistency)

Goal: pack reload must be atomic for the engine: either fully applied and all derived caches rebuilt, or fully rolled back.

Deliverables:
- Define the engine’s “derived state” contract (balanceConfig, pressure rules, fate deck wiring, quest triggers, etc.).
- Ensure safe reload rebinds derived state deterministically.

Acceptance:
- Tests verify rollback on invalid pack + consistent derived state on valid reload.

### Epic 19 [DONE] — External Combat Context Unification

Goal: one canonical “external combat context” builder, eliminating drift between Echo and Encounter bridges.

Deliverables:
- Shared builder for:
  - enemy stats (incl. region/curses modifiers)
  - hero snapshot + cards
  - fate deck snapshot + seed
- Remove duplicated logic across `EncounterBridge` / `EchoEncounterBridge`.

Acceptance:
- Unit tests show both builders produce consistent seeds and enemy numeric stats.

### Epic 20 [DONE] — Lifecycle Integrity (Background / Resume)

Goal: backgrounding during external combat cannot lose state or commit partial results.

Deliverables:
- Explicit policy:
  - store pending encounter snapshot on background;
  - resume path reuses stored seed/state;
  - never commits combatFinish automatically.

Acceptance:
- App-level tests (or integration tests) validate save-on-background and resume path stability.

### Epic 21 [DONE] — Module Hygiene (Dead Code vs Integration)

Goal: remove or integrate “concept-only” modules that conflict with the canonical architecture (avoid parallel pipelines).

Deliverables:
- Decide for `EventPipeline` / `MiniGameDispatcher`: integrate with engine services + determinism, or move to DevTools/TDD, or delete.
- Update docs so architecture matches the code.

Acceptance:
- No unused conflicting pipelines remain in production code.

### Epic 22 [DONE] — Save/Load RNG Contract Hardening

Goal: guarantee that external combat snapshot persistence and save/load round-trips do not mutate RNG unexpectedly and preserve deterministic resume behavior.

Deliverables:
- Add app-level tests that verify storing external combat snapshot does not advance engine RNG state.
- Add save/load round-trip tests for pending encounter snapshot to ensure deterministic resume config reconstruction.
- Add architecture gate checks to prevent direct app/view mutations of combat persistence fields.

Acceptance:
- Determinism tests pass with no RNG drift after snapshot persistence.
- Gate tests fail on direct app-level mutation regressions for `pendingEncounterState` / `pendingExternalCombatSeed`.

### Epic 23 [DONE] — Strict Concurrency Contract (Engine Package)

Goal: make `TwilightEngine` resilient to Swift 6 concurrency checks by removing strict-concurrency warnings in package builds.

Deliverables:
- Add `Sendable` conformance to immutable value models used in shared static constants (`ContentInventory`, consequences/diff structs, validation summaries, versioning types, etc.).
- Harden singleton/service containers with explicit concurrency contracts (`@unchecked Sendable` where access is synchronized or intentionally shared).
- Eliminate mutable global evaluator pattern (`Requirements.evaluator`) in favor of immutable contract.
- Remove test-helper global mutable state that violates concurrency checks.

Acceptance:
- `swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency` for `Packages/TwilightEngine` reports no warnings/errors.
- Standard `swift test` remains green after the hardening pass.

### Epic 24 [DONE] — CI Gate for Strict Concurrency

Goal: enforce non-regression of strict-concurrency guarantees in continuous integration.

Deliverables:
- Extend `.github/workflows/tests.yml` with a dedicated strict-concurrency step for `TwilightEngine`.
- Fail CI when compiler emits strict-concurrency diagnostics (`warning`/`error`) under:
  - `-Xswiftc -strict-concurrency=complete`
  - `-Xswiftc -warn-concurrency`

Acceptance:
- CI fails on new strict-concurrency compiler diagnostics in `TwilightEngine`.
- Existing package test matrix still runs unchanged for other packages.

### Epic 25 [DONE] — CI Determinism Smoke Gate

Goal: enforce fast non-regression checks for deterministic runtime behavior in package CI.

Deliverables:
- Add a dedicated TwilightEngine smoke step in `.github/workflows/tests.yml`.
- Run focused tests for:
  - RNG/save-load determinism (`INV_RNG_GateTests`)
  - hot-reload/registry rollback consistency (`ContentRegistryRegistrySyncTests`)

Acceptance:
- CI fails if deterministic RNG/save-load behavior regresses.
- CI fails if safe reload rollback/registry sync behavior regresses.

### Epic 26 [DONE] — App Strict Concurrency Baseline Gate

Goal: establish strict-concurrency non-regression gate for app builds in CI.

Deliverables:
- Add app-level strict-concurrency build step to `.github/workflows/tests.yml` (`xcodebuild build` with `SWIFT_STRICT_CONCURRENCY=complete` + `-warn-concurrency`).
- Parse compiler diagnostics and make strict diagnostics explicit in CI logs.
- Establish baseline for follow-up hardening in Epic 27.

Acceptance:
- CI enforces app strict-concurrency diagnostics parsing on `xcodebuild` output.
- This established the baseline gate that was later tightened in Epic 27.

### Epic 27 [DONE] — Third-Party Strict Concurrency Unblock (`FirebladeECS`)

Goal: remove the quarantine allowlist by eliminating the root blocker in `FirebladeECS`.

Deliverables:
- Introduced local patched dependency override at `Packages/ThirdParty/FirebladeECS`.
- Switched `Packages/EchoEngine/Package.swift` from remote `ecs.git` to path dependency.
- Patched `FirebladeECS` strict-concurrency blockers (`CodingStrategy: Sendable`, `TopLevelEncoder/Decoder.userInfo` sendable-safe type).
- Tightened app strict-concurrency CI gate in `.github/workflows/tests.yml` to zero-allowlist mode.
- Added dependency patch policy entry in `Docs/Technical/THIRD_PARTY_PATCHES.md`.

Acceptance:
- App strict-concurrency build passes without allowlist.
- CI gate from Epic 26 is simplified to zero-allowlist mode.

### Epic 28 [DONE] — Save Schema Compatibility Contract

Goal: guarantee backward-compatible load behavior as save schema evolves.

Deliverables:
- Introduced explicit save schema matrix tests for `EngineSave` and app save wrappers:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_SCHEMA28_GateTests.swift`
  - `CardSampleGameTests/Unit/SaveLoadTests.swift` (`testSaveManagerLoadsLegacySchemaPayloadsFromDisk`)
- Added migration-path tests for missing/legacy fields and forward-unknown fields.
- Hardened `EngineSave` decoding defaults for legacy payload compatibility (`decodeIfPresent` + deterministic RNG fallback).
- Added CI smoke enforcement by extending `TwilightEngine` determinism smoke filter in `.github/workflows/tests.yml`.

Acceptance:
- Legacy fixture/payload saves load successfully with deterministic RNG state recovery.
- Schema key-contract gates fail when unknown keys appear or required encoded keys disappear for the current `formatVersion`.

### Epic 29 [DONE] — Engine Mutation Boundary Hardening

Goal: strengthen Engine-First invariant by statically blocking direct state mutations from app layers.

Deliverables:
- Expand architecture gate scans to high-risk engine fields (combat/session persistence, quest/journal critical state).
- Define explicit allowlist for mutation points inside engine action/save-load paths only.
- Add negative tests for representative forbidden mutation patterns.

Acceptance:
- Gate fails on new direct mutation in `App/Views/ViewModels/Models`.
- Engine mutation surface remains centralized in approved core files.

### Epic 30 [DONE] — Deterministic Replay Contract

Goal: prove replay determinism from canonical action traces across save/load checkpoints.

Deliverables:
- Define canonical action-trace format and snapshot fingerprint.
- Build replay harness that replays trace N times with fixed seeds and checkpoint restores.
- Add CI smoke subset for fast determinism confidence.

Acceptance:
- Same trace + same seed always yields identical fingerprints.
- CI catches replay drift caused by RNG/order/state regression.

### Epic 31 [DONE] — CI Quality Budget & Flake Control

Goal: keep audit gates fast, reliable, and enforceable.

Deliverables:
- Add per-gate runtime budget and failure taxonomy (deterministic fail vs infra/transient).
- Add flaky test quarantine workflow with owner + expiry metadata.
- Publish CI quality dashboard artifact (gate durations, fail reasons, retry patterns).

Acceptance:
- Gate runtime remains within agreed budget.
- Flaky tests cannot stay quarantined without expiry/owner.

### Epic 32 [DONE] — CI Hermetic Runner Prep

Goal: make CI gate execution independent from runner-specific volatility (stale artifacts/tooling assumptions) and keep reproducibility high.

Deliverables:
- Add preflight environment snapshot script:
  - `.github/ci/preflight_ci_environment.sh`
  - Writes `toolchain_snapshot.md` into `TestResults/QualityDashboard`.
- Add deterministic cleanup step before gate execution:
  - `.github/ci/clean_test_artifacts.sh`
  - Removes stale `xcresult` bundles and strict-concurrency log leftovers.
- Wire both scripts into CI workflow before SPM/App gates.

Acceptance:
- App gate runs are not blocked by stale `-resultBundlePath` artifacts.
- CI artifacts include an explicit toolchain snapshot for post-failure diagnostics.

### Epic 33 [DONE] — External Combat Action Call-Site Hardening

Goal: tighten Engine-First combat boundary by explicitly controlling where external combat can start/finish from app/UI code.

Deliverables:
- Expand `AuditGateTests` with explicit call-site allowlists for:
  - `.startCombat(...)`
  - `.combatFinish(...)`
- Strengthen BattleArena sandbox static gate to also block:
  - app-layer `.performAction(...)` combat path usage,
  - direct `.startCombat(...)`, `.combatFinish(...)`, and `.combatStoreEncounterState(...)` usage in arena view.

Acceptance:
- Gate fails on new non-canonical start/finish combat call-sites in app layers.
- BattleArena remains isolated from world-engine commit paths by static enforcement.

### Epic 34 [DONE] — External Combat Commit API Canonicalization

Goal: remove ad-hoc app direct `.combatFinish(...)` usage and expose one canonical engine-level commit entry for external combat.

Deliverables:
- Added `commitExternalCombat(...)` facade to `TwilightGameEngine` (`TwilightGameEngine+Facade.swift`).
- Migrated app commit call-sites (`EventView`, `EncounterBridge`, `EchoCombatBridge`) to the facade.
- Tightened `AuditGateTests`:
  - direct app-layer `.combatFinish(...)` usage is forbidden,
  - explicit allowlist is defined for `.commitExternalCombat(...)` call-sites.

Acceptance:
- No app-layer direct `.combatFinish(...)` call-sites remain.
- External combat commit remains centralized and static-gated.

### Epic 35 [DONE] — Save/Resume Stress Determinism Matrix

Goal: add stress matrix (background/foreground, repeated save/load, interrupted combats) with deterministic fingerprint assertions.

Deliverables:
- Extended `ExternalCombatPersistenceTests` with stress-matrix tests:
  - repeated save/load round-trips for in-progress external combat snapshots with fingerprint parity checks,
  - interrupted-combat commit parity checks (`commitExternalCombat(.escaped, ...)`) after multiple resume cycles.
- Added canonical pending/resume and post-commit fingerprints (state + RNG + resume-config fields) to detect drift.
- Fixed commit-path drift in `combatFinish`: event lock is cleared (`currentEventId/currentEvent`) after quest-trigger handling so fresh vs resumed commit paths converge.

Acceptance:
- Pending external-combat resume fingerprint is stable across repeated save/load cycles.
- Interrupted combat commit result is deterministic and matches baseline regardless of resume cycle count.

### Epic 36 [DONE] — Architecture Dependency Gates

Goal: add static import/layering gates (View ↔ ViewModel ↔ Engine boundaries) to prevent cross-layer leakage regressions.

Deliverables:
- Added static dependency gates in `CardSampleGameTests/GateTests/AuditGateTests.swift`:
  - `testViewModelsDoNotImportUIOrRenderModules`
  - `testModelsDoNotImportUIOrRenderModules`
  - `testViewModelsDoNotReferenceViewTypes`
- Removed UI-framework dependency from `ViewModels/ContentManagerVM.swift` (`SwiftUI` import dropped; clipboard side effects moved to View layer).
- Kept App-layer compile/test flow green with targeted gate run.

Acceptance:
- `AuditGateTests` fails on new cross-layer dependency leakage from ViewModel/Model layers into UI/render modules.
- `AuditGateTests` fails when ViewModel code references concrete `View` types.
- Targeted gate run passes after refactor.

## Proposed next epics

### Epic 37 [DONE] — Contract Drift Auto-Report

Goal: generate machine-readable gate inventory + doc drift report (tests/docs/CI mismatch) as a single CI artifact.

Deliverables:
- Added `.github/ci/generate_gate_inventory_report.sh`:
  - extracts CI gate IDs + suite filters from `.github/workflows/tests.yml`,
  - extracts referenced gate suites/invariants from QA docs,
  - extracts real XCTest suite classes from app/engine test trees,
  - writes machine-readable inventory (`gate_inventory.json`) and drift report (`gate_drift_report.md`).
- Wired report generation into app CI job (`tests.yml`) so it is included in uploaded `TestResults/QualityDashboard` artifacts.
- Synchronized QA docs so report shows zero drift for mandatory suites/invariants.

Acceptance:
- CI artifacts contain both `gate_inventory.json` and `gate_drift_report.md`.
- Report drift checks are green for mandatory CI app suites, engine smoke filters, and documented gate contracts.

### Epic 38 [DONE] — Release Candidate Quality Profile

Goal: codify RC profile (required gate subsets + budget thresholds + quarantine zero-tolerance window) for predictable release readiness.

Deliverables:
- Added `.github/ci/validate_release_profile.sh` with two codified profiles:
  - `rc_engine_twilight` (`spm_TwilightEngine_tests`, `spm_twilightengine_strict_concurrency`, `spm_twilightengine_determinism_smoke`),
  - `rc_app` (`app_gate_0_strict_concurrency`, `app_gate_1_quality`, `app_gate_2_content_validation`, `app_gate_2a_audit_core`, `app_gate_2b_audit_architecture`, `app_gate_3_unit_views`).
- Enforced RC checks for each required gate:
  - gate presence in `TestResults/QualityDashboard/gates.jsonl`,
  - status must be `passed`,
  - observed duration and configured gate budget must be within profile threshold.
- Enforced quarantine zero-tolerance window for RC:
  - `.github/flaky-quarantine.csv` must contain zero active entries.
- Generated RC profile report artifact in dashboard:
  - `release_profile_rc_engine_twilight.md` / `release_profile_rc_app.md`.
- Wired RC profile checks into CI:
  - `spm-packages` (`TwilightEngine` branch of matrix),
  - `app-tests` after inventory/drift report generation.
- Updated QA contract docs (`QUALITY_CONTROL_MODEL.md`, `TESTING_GUIDE.md`, `ENCOUNTER_TEST_MODEL.md`) with RC profile policy and run commands.

Acceptance:
- CI fails if any required RC gate is missing/failed or breaches threshold.
- CI fails if quarantine registry has active entries during RC profile checks.
- RC profile reports are present in `TestResults/QualityDashboard` artifacts.

### Epic 39 [DONE] — Unified Release Readiness Check

Goal: make release readiness a single enforceable contract across test/build/content layers, not only app/engine test subsets.

Deliverables:
- Extended RC profile enforcer (`.github/ci/validate_release_profile.sh`) with:
  - `rc_build_content` (`build_cardsamplegame`, `build_packeditor`, `content_json_lint`, `repo_hygiene`),
  - `rc_full` (engine + app + build/content combined).
- Converted standalone build/content jobs into quality-gated outputs:
  - `build-validation` now emits `build_cardsamplegame` / `build_packeditor` via `run_quality_gate.sh`,
  - `content-validation` now emits `content_json_lint` / `repo_hygiene` via `run_quality_gate.sh`.
- Added `release-readiness-profile` CI job:
  - downloads app/SPM/build/content dashboards,
  - merges `gates.jsonl`,
  - validates `rc_full`,
  - publishes `release-readiness-dashboard` artifact.
- Added unified local orchestrator:
  - `.github/ci/run_release_check.sh` executes app + engine + build + content gates and validates all RC profiles in one command.
- Added reusable content validation script:
  - `.github/ci/content_json_lint.sh`.
- Updated QA docs to include full-profile and one-command release workflow.

Acceptance:
- CI blocks merge when any required full-release gate is missing/failed or exceeds RC thresholds.
- Full release profile report (`release_profile_rc_full.md`) is generated from aggregated gate data.
- Local one-command release check reproduces the same gate contract.

### Epic 40 [DONE] — External Combat Snapshot Layer Extraction

Goal: remove app-layer ownership of external combat snapshot/context building and keep engine mutation/builder logic in `TwilightEngine`.

Deliverables:
- Added canonical engine file `Packages/TwilightEngine/Sources/TwilightEngine/Encounter/ExternalCombatSnapshot.swift` with:
  - `ExternalCombatEnemySnapshot`, `ExternalCombatSnapshot`,
  - public `TwilightGameEngine` APIs: `makeExternalCombatSnapshot(...)`, `makeEncounterContext(...)`, `applyEncounterResult(...)`.
- Replaced app-side `Views/Combat/EncounterBridge.swift` implementation with a thin adapter marker (no `TwilightGameEngine` extension / no snapshot structs).
- Removed obsolete app-level `EnemyDefinition.from(card:)` bridge from `Views/Combat/EchoEncounterBridge.swift`.
- Hardened static gate in `CardSampleGameTests/GateTests/AuditGateTests.swift`:
  - `testEncounterBridgeFileDoesNotReintroduceEngineExtensions`
  - tighter allowlist for `testCommitExternalCombatCallSitesAreExplicit`.

Acceptance:
- Encounter snapshot/context builders compile and execute from `TwilightEngine` package (not app layer).
- App gate tests fail if `EncounterBridge.swift` reintroduces engine extensions or local snapshot structs.
- Targeted validation remains green (`swift test` on `TwilightEngine` + targeted `AuditGateTests`).

### Epic 41 [DONE] — RNG Capability Contract Hardening

Goal: remove ad-hoc public seed issuance API and ensure deterministic seed allocation only happens through the engine action pipeline.

Deliverables:
- Removed public `nextSeed()` facade from `TwilightGameEngine+Facade.swift`.
- Added app-layer static gate checks in `CardSampleGameTests/GateTests/AuditGateTests.swift`:
  - `testAppLayersDoNotCallEngineNextSeedFacade`
  - `testTwilightGameEngineFacadeDoesNotExposePublicNextSeed`
- Kept combat seed lifecycle on canonical action path (`performAction(.startCombat)` sets `pendingExternalCombatSeed`).

Acceptance:
- App/UI code cannot call `engine.nextSeed(...)` (gate-enforced).
- `TwilightGameEngine` facade no longer exports public seed-issuing method.
- Determinism and audit gate subsets stay green under targeted test runs.

### Epic 42 [DONE] — BattleArena Sandbox RNG Isolation

Goal: ensure Quick Battle uses an isolated RNG contract and cannot regress to world-state RNG/commit coupling.

Deliverables:
- Replaced `UInt64.random(...)` seed generation in `Views/BattleArenaView.swift` with a dedicated local `WorldRNG` sandbox instance.
- Added explicit seed helper (`nextBattleSeed`) to keep battle seed generation local and deterministic within arena scope.
- Hardened static gate in `CardSampleGameTests/GateTests/AuditGateTests.swift`:
  - `testBattleArenaRemainsSandboxedFromWorldEngineCommitPath` now also forbids `UInt64.random(` in `BattleArenaView.swift`.

Acceptance:
- `BattleArenaView` no longer uses system random for battle seed generation.
- Arena flow remains isolated from world-engine mutation paths and `engine.services.rng`.
- Targeted `AuditGateTests` coverage remains green.

### Epic 43 [DONE] — External Combat Adapter De-Extension

Goal: remove app-layer `TwilightGameEngine` extensions for external combat adapters and keep adapter composition explicit.

Deliverables:
- Replaced app-layer `extension TwilightGameEngine` adapters in `Views/Combat/EchoCombatBridge.swift` and `Views/Combat/EchoEncounterBridge.swift` with plain adapter/service types.
- Migrated app and test call-sites to adapter API (`EchoCombatBridge.applyCombatResult(...)`, `EchoEncounterBridge.makeCombatConfig(...)`, `EchoEncounterBridge.storeCombatSnapshot(...)`).
- Hardened static architecture gate in `AuditGateTests` to scan all combat bridge files and fail on `extension TwilightGameEngine` regressions.

Acceptance:
- App no longer adds `extension TwilightGameEngine` in `Views/Combat`.
- Canonical adapter entry points are represented by plain mapper/service types and keep gate allowlists green.

## Pending backlog (post-Epic 50)

### Epic 44 [DONE] — Replay Fixture Governance

Goal: turn deterministic replay into a versioned fixture contract with reproducible diagnostics.

Deliverables:
- Refactored `INV_REPLAY30_GateTests` to run fixture corpus and compare expected replay fingerprints, step digests, and canonical final state snapshots.
- Added versioned replay fixtures:
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/Fixtures/Replay/epic30_smoke_seed_424242_v1.json`
  - `Packages/TwilightEngine/Tests/TwilightEngineTests/Fixtures/Replay/epic30_smoke_seed_808080_v1.json`
- Added actionable drift diagnostics with first-mismatch reporting and suggested replacement payload for the `expected` section.
- Added fixture update mode via `REPLAY_FIXTURE_UPDATE=1` in replay gate test.
- Declared replay fixtures as test resources in `Packages/TwilightEngine/Package.swift` to keep SwiftPM test runs warning-free.

Acceptance:
- Canonical replay fixtures (seed + trace + expected fingerprint) are versioned.
- Replay gate fails with actionable diff when replay drift appears (step/final fingerprints + first mismatch context).
- Determinism smoke subset (`INV_RNG_GateTests|INV_SCHEMA28_GateTests|INV_REPLAY30_GateTests|INV_RESUME47_GateTests|ContentRegistryRegistrySyncTests`) stays green.

### Epic 45 [DONE] — Gate Suite Modularization

Goal: split oversized gate suites into domain-owned modules to reduce brittleness and improve maintainability.

Deliverables:
- Extracted architecture boundary/static-scan checks (Epic 20/29/36/21) from `CardSampleGameTests/GateTests/AuditGateTests.swift` into dedicated suite `CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests.swift`.
- Kept `AuditGateTests` focused on core audit/runtime/content contracts; architecture boundary checks now have explicit suite ownership.
- Split app gate execution in CI/local release runner into dedicated budgeted gates:
  - `app_gate_2_content_validation`
  - `app_gate_2a_audit_core`
  - `app_gate_2b_audit_architecture`
- Updated release profile thresholds (`rc_app`, `rc_full`) to require both new audit suite gates.

Acceptance:
- `AuditGateTests` is decomposed into focused files/suites with stable ownership and per-suite budgets.
- Gate inventory/drift report remains fully synchronized.

### Epic 46 [DONE] — Lockfile & Artifact Cleanliness Automation

Goal: enforce clean dependency/artifact hygiene automatically in local and CI workflows.

Deliverables:
- Added repository hygiene validator: `.github/ci/validate_repo_hygiene.sh`.
  - enforces single canonical lockfile (`CardSampleGame.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`),
  - blocks tracked transient artifacts (`TestResults*`, `TestReport*`, `.xcresult`, local strict-concurrency logs).
- Wired hygiene checks into CI:
  - policy gate in `quality-governance` job,
  - budgeted quality gate `repo_hygiene` in `content-validation` job.
- Wired hygiene gate into local release runner: `.github/ci/run_release_check.sh` now emits `repo_hygiene`.
- Updated release profile thresholds (`rc_build_content`, `rc_full`) to require `repo_hygiene`.

Acceptance:
- CI/local checks enforce single canonical `Package.resolved` and block committed transient artifacts (`xcresult`, local logs, temporary reports).
- Hygiene check is part of release-readiness profile.

### Epic 47 [DONE] — Save/Resume Fault Injection Matrix

Goal: harden save/resume determinism under simulated write/read interruptions and partial lifecycle transitions.

Deliverables:
- Added gate suite `Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_RESUME47_GateTests.swift`:
  - interrupted save-write simulation with fallback resume from the last valid checkpoint plus deterministic replay of pending steps,
  - partial snapshot resume path (migration-default fields omitted from payload),
  - repeated mixed recoveries (`interruptedWrite + partialSnapshot`) across multiple seeds.
- Added deterministic parity checks against baseline:
  - final-state fingerprint parity,
  - step-digest fingerprint parity,
  - explicit no-drift assertions for `rngState`, `currentEventId`, `pendingEncounterState`, `pendingExternalCombatSeed`.
- Integrated Epic 47 suite into determinism smoke filters in:
  - `.github/workflows/tests.yml`
  - `.github/ci/run_release_check.sh`

Acceptance:
- Tests cover interrupted save write, resume after partial snapshot, and repeated recoveries with deterministic fingerprints.
- No RNG/event-lock drift versus baseline runs.

### Epic 48 [DONE] — Documentation Sync Gate

Goal: make docs/specs drift a hard quality signal, not a manual review task.

Deliverables:
- Added docs sync validator: `.github/ci/validate_docs_sync.sh`.
  - validates mandatory determinism/scheme contract tokens across:
    - `.github/workflows/tests.yml` smoke filter,
    - `Docs/QA/QUALITY_CONTROL_MODEL.md`,
    - `Docs/QA/TESTING_GUIDE.md`,
    - `Docs/plans/2026-02-07-audit-refactor-phase2-epics.md`.
  - fails on stale epic markers for critical contracts (`Epic 28`, `Epic 30`, `Epic 47`, `Epic 48`) and stale backlog epoch marker (`post-Epic N`, where `N` is auto-detected latest `DONE` epic).
- Wired budgeted docs-sync quality gate `docs_sync` into:
  - `.github/workflows/tests.yml` (`content-validation` job),
  - `.github/ci/run_release_check.sh` (local unified release run).
- Updated release profile thresholds:
  - `.github/ci/validate_release_profile.sh` now requires `docs_sync` in `rc_build_content` and `rc_full`.

Acceptance:
- CI gate validates epic ledger + QA model + testing guide consistency for mandatory contracts.
- Release profile fails if required architecture/test contract docs are stale.

### Epic 49 [DONE] — Latest-Only Quality Summary Rendering

Goal: keep dashboard summary signal clean when gates are re-run, while preserving full run history for forensics.

Deliverables:
- Updated `.github/ci/run_quality_gate.sh` summary rendering:
  - `TestResults/QualityDashboard/summary.md` is rebuilt from `gates.jsonl` on each gate run.
  - Summary keeps one row per `gate_id` (latest result wins).
  - Historical attempts remain append-only in `TestResults/QualityDashboard/gates.jsonl`.
- Updated QA docs (`QUALITY_CONTROL_MODEL.md`, `TESTING_GUIDE.md`) to document the “latest-only summary + raw history in JSONL” contract.

Acceptance:
- Re-running the same gate ID updates a single row in `summary.md` instead of appending duplicates.
- RC/profile checks continue to read latest gate state from `gates.jsonl` without behavior drift.

### Epic 50 [DONE] — Release Runner Clean-Tree Hard Gate

Goal: prevent expensive local release runs from starting on a dirty tracked tree, which invalidates release-readiness signal.

Deliverables:
- Extended `.github/ci/validate_repo_hygiene.sh` with optional mode:
  - `--require-clean-tree` fails when `git status --porcelain --untracked-files=no` is non-empty.
  - keeps canonical lockfile + transient-artifact checks unchanged.
- Wired hard preflight check into `.github/ci/run_release_check.sh`:
  - runs `validate_repo_hygiene.sh --require-clean-tree` before cleanup/preflight/test/build gates.
- Updated QA docs (`QUALITY_CONTROL_MODEL.md`, `TESTING_GUIDE.md`) to document hard clean-tree precheck behavior for local release runs.

Acceptance:
- `run_release_check.sh` aborts immediately on tracked working-tree drift.
- CI profile validation logic stays unchanged (still driven by `gates.jsonl`/RC profiles).
