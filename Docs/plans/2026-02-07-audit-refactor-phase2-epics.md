# Phase 2 (Post-Epic 14) — Audit & Refactor Backlog

Scope: architecture correctness + quality gates. This is **not** gameplay/product polishing.
Policy sync baseline: `CLAUDE.md` v4.1 engineering contract.

## What’s already done (post-Epic 14)

- External combat determinism hardening: external combat seed allocated in `performAction(.startCombat)` and reused (UI reads no longer advance RNG); bridges commit results via `performAction(.combatFinish)`.

## Status snapshot (2026-02-12)

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
- `Epic 42`: DONE (BattleArena sandbox RNG hardening: arena-local deterministic seed generator in arena flow + static gate ban for `UInt64.random` in `BattleArenaView`).
- `Epic 43`: DONE (app-layer external-combat bridges de-extended: `EchoCombatBridge`/`EchoEncounterBridge` are adapter types, call-sites migrated, and static gate blocks `extension TwilightGameEngine` reintroduction in `Views/Combat`).
- `Epic 47`: DONE (save/resume fault-injection matrix added with interrupted-write fallback recovery, partial snapshot resume, and deterministic fingerprint parity checks).
- `Epic 48`: DONE (documentation sync validator gate added; CI/RC now fail on mandatory contract drift across epic ledger + QA model + testing guide).
- `Epic 49`: DONE (`run_quality_gate.sh` now renders `summary.md` as latest-only per gate ID; duplicate historical attempts remain in `gates.jsonl` only).
- `Epic 50`: DONE (local release runner now hard-gates on clean tracked working tree via `validate_repo_hygiene.sh --require-clean-tree` before any gate execution).
- `Epic 58`: DONE (removed compatibility overload shim for `registerMockContent(...)`; tests now rely on a single canonical API with explicit `abilities` support and default empty value).
- `Epic 59`: DONE (runtime flake stabilization in `GameplayFlowTests`/`MiniGameDispatcherTests`: config-driven initial tension assertion, narrative-text coupling removed in favor of `outcome`, deterministic RNG seed in suite setup/teardown).
- `Epic 60`: DONE (test-only `ContentRegistry` helpers moved behind SPI boundary; app-level tests decoupled from test-support API; architecture gate added for SPI visibility).
- `Epic 61`: DONE (absolute engine type-gate expansion with decomposition: split Story/Combat/Quest/Config type carriers so all audited engine directories satisfy `<=5` top-level types per file without legacy exemptions).
- `Epic 68`: DONE (file-header contract coverage: canonical 4-line Russian header enforced by `CodeHygieneTests` and backfilled across all first-party Swift files).
- `Epic 53`: DONE (decomposition baseline stabilized: `TwilightGameEngine.swift` reduced to `505` lines; action/query/persistence surfaces split into focused modules; architecture + quality gates green).
- `Cleanup checkpoint (2026-02-09)`: DONE (removed duplicated BattleArena sandbox gate from `AuditGateTests`; canonicalized it in `AuditArchitectureBoundaryGateTests`; added anti-duplicate gate `testAuditGateSuitesDoNotDuplicateTestNames` to prevent future drift).
- `App strict-concurrency note`: app strict build baseline is green (no compiler file/line warnings/errors) with local `Packages/ThirdParty/FirebladeECS` override.
- `Release readiness checkpoint (local)`: `run_release_check.sh` passed with `rc_engine_twilight`, `rc_app`, `rc_build_content`, and `rc_full`.
- `Current verification checkpoint (2026-02-11)`: green on focused hard gates (`AuditArchitectureBoundaryGateTests` 27/27 incl. `testBattleArenaRemainsSandboxedFromWorldEngineCommitPath`, `AuditGateTests`, `CodeHygieneTests`) + full `swift test --package-path Packages/TwilightEngine` (603/603) + `swift test --package-path Packages/EchoEngine`.
- `BattleArena RNG/state finding`: CLOSED (`testBattleArenaRemainsSandboxedFromWorldEngineCommitPath` green; arena flow does not call engine RNG or world-state commit path).
- `Epic 62`: DONE (checkpoint #1: removed dead legacy `CombatView` screen implementation; extracted app-level combat summary models into `AppCombatOutcome`/`AppCombatStats`; event/arena call-sites migrated. checkpoint #2: removed dead external-combat legacy adapter methods from `ExternalCombatSnapshot` extension and finalized architecture gate run with `AuditArchitectureBoundaryGateTests` green).
- `Epic 63`: DONE (checkpoint #1 complete: decomposed `JSONContentProvider+SchemaQuests.swift` into focused schema modules for quests/conditions/rewards/challenges; checkpoint #2 complete: decomposed `JSONContentProvider+SchemaEvents.swift` into event-core/regions-anchors/availability/choices/combat modules; checkpoint #3 complete: decomposed `CodeContentProvider+JSONLoading.swift` into event/availability/choice loading modules; checkpoint #4 complete: decomposed `EncounterViewModel.swift` into player-actions/phase-machine/state-sync modules; checkpoint #5 complete: decomposed `Localization.swift` into `Localization+CoreAndRules`, `Localization+WorldAndNavigation`, `Localization+AdvancedSystems`, `Localization+RemainingKeys` with symbol-compatibility; checkpoint #6 complete: decomposed `INV_KW_GateTests.swift` into helpers + keyword-effects/flow extensions without behavior changes; checkpoint #7 complete: decomposed `SafeContentAccessTests.swift` into access/readiness-validation extensions with 22/22 suite pass; checkpoint #8 complete: extracted card presentation mapping into `Views/CardPresentation.swift` and split `HandCardView`/`CompactCardView` into dedicated files; checkpoint #9 complete: split `CombatScene+Flow.swift` into orchestration (`CombatScene+Flow.swift`) and low-level arena/effects helpers (`CombatScene+ArenaEffects.swift`) with targeted EchoScenes tests green; checkpoint #10 complete: started app root-menu decomposition by extracting `CharacterSelectionScreen`/`SaveSlotSelectionScreen`/`LoadSlotSelectionScreen` under `App/Screens`, wiring them into `CardSampleGame.xcodeproj`, and stabilizing compile contracts (`SaveManager.isLoaded`, missing design tokens) with focused `xcodebuild` gates green; checkpoint #11 complete: integrated `ContentFlow` as the single navigation model in `ContentView` (removed duplicated start/load/continue state and boolean screen flags), added load-alert UI binding, and confirmed `CodeHygieneTests` + `AuditArchitectureBoundaryGateTests` green after the refactor; checkpoint #12 complete: closed remaining `>=550` near-limit offenders via bounded splits (`TwilightGameEngine+ActionPipeline` time helpers, `EncounterEngine` suit-matching helpers, `ManagedPack` equatable extraction, gate-suite helper relocation), resulting in zero first-party files at `>=550` with `CodeHygieneTests`, `AuditArchitectureBoundaryGateTests`, and `AuditGateTests` green).
- `Epic 64`: DONE (test observability hardening: noisy test-helper diagnostics are now gated by `TWILIGHT_TEST_VERBOSE`, `GameplayFlowTests` dropped residual ad-hoc stdout logging, and content-loading debug traces in app/engine (`ContentLoader`, `ContentRegistry`) are quiet by default while remaining opt-in for deep diagnostics; focused validations green: `ContentValidationTests`, `AuditGateTests/testAllPrintStatementsAreDebugOnly`, `swift test --filter ContentLoadingIntegrationTests`, `swift test --filter GameplayFlowTests`).
- `Epic 65`: DONE (documentation single-control-point hardening: `validate_docs_sync.sh` now validates source-of-truth date parity (`Last updated` / `Status snapshot` / `Last updated (ISO)`), Phase-2 checkpoint parity (`**Phase 2 checkpoint:** Epic N`) across QA/testing/architecture docs, and requires ledger `DONE` marker for that checkpoint epic).
- `Epic 66`: DONE (release hygiene hard-stop is mandatory in CI and local release runner: `validate_repo_hygiene.sh --require-clean-tree` is enforced both before and after release profile execution; docs-sync gate validates this contract in workflow + release runner scripts).
- `Localization runtime checkpoint`: DONE (external-combat resume payload relocalization hardened via active registry/locale resolution; service/icon token leakage is covered by static UI gate and save/load regression suite).

## Pending backlog (post-Epic 68)

Priority is architectural simplification and long-term maintainability, not feature expansion.

- На текущем срезе открытых epics нет.
- `Epic 67` и `Epic 68` закрыты и зафиксированы в секции `## Epics` ниже как каноническая детализация deliverables/acceptance.

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
- Route strict diagnostics through `.github/ci/spm_twilightengine_strict_concurrency_gate.sh` in build-only mode (`swift build --build-tests`) to isolate compiler contracts from runtime test flakiness.
- Fail CI when compiler emits strict-concurrency diagnostics (`warning`/`error`) under:
  - `-Xswiftc -strict-concurrency=complete`
  - `-Xswiftc -warn-concurrency`

Acceptance:
- CI fails on new strict-concurrency compiler diagnostics in `TwilightEngine`.
- Runtime package behavior remains covered by the regular TwilightEngine test matrix gate.

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
- Replaced `UInt64.random(...)` seed generation in `Views/BattleArenaView.swift` with an arena-local deterministic seed generator.
- Added explicit seed helper (`nextArenaSeed`) to keep battle seed generation local and deterministic within arena scope.
- Hardened static gate `testBattleArenaRemainsSandboxedFromWorldEngineCommitPath`:
  - actively enforced in `CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests.swift` (canonical architecture gate target).
  - gate forbids `UInt64.random(` in `BattleArenaView.swift`.

Acceptance:
- `BattleArenaView` no longer uses system random for battle seed generation.
- Arena flow remains isolated from world-engine mutation paths and `engine.services.rng`.
- Targeted `AuditArchitectureBoundaryGateTests` coverage remains green.

### Epic 43 [DONE] — External Combat Adapter De-Extension

Goal: remove app-layer `TwilightGameEngine` extensions for external combat adapters and keep adapter composition explicit.

Deliverables:
- Replaced app-layer `extension TwilightGameEngine` adapters in `Views/Combat/EchoCombatBridge.swift` and `Views/Combat/EchoEncounterBridge.swift` with plain adapter/service types.
- Migrated app and test call-sites to adapter API (`EchoCombatBridge.applyCombatResult(...)`, `EchoEncounterBridge.makeCombatConfig(...)`, `EncounterBridge.storeCombatSnapshot(...)`).
- Hardened static architecture gate in `AuditGateTests` to scan all combat bridge files and fail on `extension TwilightGameEngine` regressions.
- Added explicit static gate to forbid app-layer direct `combat.setupCombatEnemy(...)` calls (combat start must go through `.startCombat`).

Acceptance:
- App no longer adds `extension TwilightGameEngine` in `Views/Combat`.
- Canonical adapter entry points are represented by plain mapper/service types and keep gate allowlists green.

## Historical backlog snapshot (post-Epic 61)

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

### Epic 51 [DONE] — Core Journal/Resonance Primitive Canonicalization

Goal: remove compatibility shims in core/journal paths and codify a single canonical mutation API for journal and resonance state.

Deliverables:
- Added explicit core-state primitives in `TwilightGameEngine`:
  - `resolveRegionName(forRegionId:)`
  - `appendEventLogEntry(dayNumber:...)`
  - `setWorldResonance(_:)` (canonical clamp path)
- Reworked `TwilightGameEngine+Journal.swift` to use core primitives only and avoid UI mirror state coupling (`publishedRegions`, `publishedEventLog`, `setEventLog`).
- Replaced action-path resonance updates to use `setWorldResonance(_:)` instead of legacy helper semantics.
- Added active architecture gate `AuditGateTests.testEngineJournalUsesCoreStatePrimitives` to block regression.
- Updated QA docs (`QUALITY_CONTROL_MODEL.md`, `TESTING_GUIDE.md`) with the core mutation contract.

Acceptance:
- Journal extension no longer depends on UI mirror state fields.
- Resonance mutation path in action execution is canonical and explicit.
- Static gate fails if journal/resonance paths regress to mirror-state or legacy helper usage.

### Epic 52 [DONE] — Test Host Runtime De-Duplication Gate

Goal: eliminate duplicate `TwilightEngine` runtime loading in hosted app tests and lock the fix with a static project gate.

Deliverables:
- Removed direct `TwilightEngine` linkage from `CardSampleGameTests` target in `CardSampleGame.xcodeproj/project.pbxproj` (tests now consume the host app runtime copy).
- Added active architecture gate `AuditGateTests.testCardSampleGameTestsDoesNotLinkTwilightEngineDirectly`.
  - Validates test target package dependencies do not include `TwilightEngine`.
  - Validates test target frameworks phase does not link `TwilightEngine in Frameworks`.
- Verified target build graph remains valid (`CardSampleGameTests` still imports TwilightEngine via host-app framework search paths).

Acceptance:
- Hosted test runs no longer emit `Class ... is implemented in both` for `TwilightEngine`.
- Gate fails on any reintroduction of direct `TwilightEngine` linkage in `CardSampleGameTests`.

### Epic 53 [DONE] — TwilightGameEngine Monolith Decomposition (Phase A)

Goal: reduce `TwilightGameEngine.swift` complexity without weakening encapsulation or action-pipeline invariants.

Deliverables:
- [x] Extracted read-only query surface from `TwilightGameEngine.swift` to `Core/TwilightGameEngine+ReadOnlyQueries.swift`.
- [x] Extracted world bootstrap state model to `Core/EngineWorldBootstrapState.swift` and switched new game/fallback initialization to this model.
- [x] Extracted exploration availability query + combat/resonance/external-commit support into `Core/TwilightGameEngine+ExplorationQueries.swift` and `Core/TwilightGameEngine+StateSupport.swift`.
- [x] Extracted action validation/time/execution pipeline helpers into `Core/TwilightGameEngine+ActionPipeline.swift`.
- [x] Extracted save snapshot builder into `Core/TwilightGameEngine+PersistenceSnapshot.swift` without widening engine private-state visibility.
- [x] Extracted bootstrap/mapping/validation helpers into `Core/TwilightGameEngine+BootstrapAndValidation.swift`.
- [x] Preserved mutation-heavy persistence/action internals in `TwilightGameEngine.swift` (no forced `private -> internal` widening).
- [x] Added decomposition checkpoint updates in QA docs with file-size trend tracking.
- [x] Phase A completed (monolith reduced below the hard gate; helpers extracted without widening private state).

Acceptance:
- `TwilightGameEngine.swift` size decreases in measurable steps (`2139 -> 2071 -> 1998 -> 1916 -> 1855 -> 1085 -> 505` through checkpoints #1/#6).
- No new app-layer direct state mutation paths are introduced (`AuditArchitectureBoundaryGateTests` green).
- Determinism/schema smoke gates remain green (`INV_RNG`, `INV_SCHEMA28`, `INV_REPLAY30`, `INV_RESUME47`, `ContentRegistryRegistrySyncTests` green).

### Epic 54 [DONE] — ContentRegistry Monolith Decomposition (Phase A)

Goal: reduce `ContentRegistry.swift` size while preserving atomic reload and registry-sync contracts.

Deliverables:
- Extract independent value types/utilities (`BalancePackAccess` and other non-state-coupled helpers) into standalone files.
- Keep merge/reload internals co-located with private state until dedicated mutation services are introduced.
- Maintain deterministic ordering guarantees for registry iteration APIs.

Acceptance:
- `ContentRegistry.swift` remains below the hard line-limit gate and stays behaviorally equivalent.
- `ContentRegistryRegistrySyncTests` and replay smoke remain green.

### Epic 55 [DONE] — Large View Decomposition (`WorldMapView`)

Goal: split oversized view composition into domain subviews without moving engine mutations into UI.

Deliverables:
- Decompose `Views/WorldMapView.swift` into focused view components (status/header/map/actions/overlays).
- Extracted subviews into dedicated files:
  - `Views/WorldMap/EventLogEntryView.swift`
  - `Views/WorldMap/EngineRegionCardView.swift`
  - `Views/WorldMap/EngineRegionDetailView.swift`
  - `Views/WorldMap/EngineEventLogView.swift`
- Keep all world-state commits routed via `performAction`/engine facade methods.
- Add static gate checks preventing direct engine state assignment from new view components.

Acceptance:
- `WorldMapView.swift` reduced to `287` lines.
- App architecture gates continue to pass.

### Epic 56 [DONE] — Gate Suite Modularization (Phase B)

Goal: reduce maintenance risk in giant gate files and improve ownership boundaries.

Deliverables:
- Split `AuditGateTests.swift` by contract domains (determinism/l10n/content/arch boundaries).
- Keep gate IDs and CI profile mapping stable.
- Update quality inventory report expectations if suite names change.

Acceptance:
- `AuditGateTests.swift` reduced below the hard line-limit gate with no contract loss.
- `app_gate_2a_audit_core` and `app_gate_2b_audit_architecture` remain profile-compliant.

### Epic 57 [DONE] — Legacy Cleanup Hard Gate

Goal: make dead-code and compatibility-shim drift a failing quality signal.

Deliverables:
- Removed dead app-layer combat facade:
  - deleted `Views/Combat/EncounterBridge.swift` (no call-sites; superseded by canonical engine/bridge entry points).
- Added static hygiene validator:
  - `.github/ci/validate_legacy_cleanup.sh`
  - blocks TODO/FIXME markers in first-party sources,
  - enforces that bridge/adapter entry points have call-sites in production sources,
  - enforces that `COMPAT_REMOVE_BY: YYYY-MM-DD` markers are not expired (policy hook for future compatibility shims).
- Added CI/local gate integration under quality dashboard:
  - `legacy_cleanup` gate in `.github/workflows/tests.yml` (`content-validation` job),
  - local runner integration in `.github/ci/run_release_check.sh`,
  - RC profile enforcement via `.github/ci/validate_release_profile.sh` (`rc_build_content`, `rc_full`).
- Updated QA operational docs:
  - `Docs/QA/QUALITY_CONTROL_MODEL.md`
  - `Docs/QA/TESTING_GUIDE.md`

Acceptance:
- CI fails on reintroduction of blocked legacy patterns.
- Cleanup status becomes visible in `QualityDashboard` artifacts.

### Epic 58 [DONE] — Test API Shim Removal (`registerMockContent`)

Goal: remove temporary compatibility shim from test content API before release hardening.

Deliverables:
- Removed backward-compatible overload of `registerMockContent(...)` from `ContentRegistry`.
- Kept one canonical test API:
  - `registerMockContent(..., abilities: [String: HeroAbility] = [:], ...)`.
- Verified existing tests use canonical signature and remain green.

Acceptance:
- No compatibility overload remains in `ContentRegistry` test-support path.
- Targeted engine tests (`ContentLoadingIntegrationTests`, `SafeContentAccessTests`, `ContentRegistryRegistrySyncTests`, `INV_REPLAY30_GateTests`) pass.

### Epic 59 [DONE] — Runtime Flake Stabilization (GameplayFlow/MiniGameDispatcher)

Goal: remove non-deterministic and locale-coupled assertions from core runtime suites before further architecture decomposition.

Deliverables:
- Replaced hardcoded initial tension assertion (`30`) in `GameplayFlowTests.testNewGameCreatesFreshWorldState` with balance-driven expectation from active content config.
- Removed locale-dependent narrative string matching in `MiniGameDispatcherTests` (e.g., `"разгадана"`, `"пройдена"`, `"Победа"`, `"Поражение"`) and switched to semantic `MiniGameOutcome` checks.
- Added deterministic suite-level RNG control in `MiniGameDispatcherTests` by injecting a seeded RNG (`TestRNG.make(seed: 42)`) to isolate tests from RNG drift.
- Verified repeatability with repeated targeted suite runs (`GameplayFlowTests|MiniGameDispatcherTests`) without intermittent failures.

Acceptance:
- `GameplayFlowTests` no longer assumes fixed initial tension independent of loaded balance packs.
- `MiniGameDispatcherTests` validate gameplay semantics via typed outcome/state, not localized copy.
- Repeated targeted runs stay green under unchanged code and environment.

### Epic 60 [DONE] — ContentRegistry Test API Surface Hardening (SPI)

Goal: remove test-only `ContentRegistry` helpers from regular production API visibility without breaking deterministic test workflows.

Deliverables:
- Marked testing helpers in `ContentRegistry` as SPI-only:
  - `@_spi(Testing) public func resetForTesting(...)`
  - `@_spi(Testing) public func registerMockContent(...)`
  - `@_spi(Testing) public func loadMockPack(...)`
  - `@_spi(Testing) public func checkIdCollisions(...)`
- Updated engine content-validation tests to import `TwilightEngine` via SPI (`@_spi(Testing) @testable import TwilightEngine`).
- Removed app-layer dependency on testing-only API:
  - `CardSampleGameTests` switched setup/teardown cleanup from `resetForTesting()` to `unloadAllPacks()`.
  - Removed app-side mock-content test that depended on `registerMockContent(...)`.
- Added architecture gate: `testContentRegistryTestingHelpersAreSpiOnly`.

Acceptance:
- Regular `import TwilightEngine` in production code cannot access test helpers.
- Targeted suites remain green:
  - `ContentLoadingIntegrationTests`, `SafeContentAccessTests`, `ContentRegistryRegistrySyncTests`,
  - `ContentRegistryTests`, `ContentManagerTests`, `CodeHygieneTests`,
  - `AuditArchitectureBoundaryGateTests/testContentRegistryTestingHelpersAreSpiOnly`.

### Epic 61 [DONE] — Absolute Engine Type-Gate Expansion (Top-Level, No Legacy Exemptions)

Goal: make `<=5` top-level-types-per-file gate truly absolute across audited `TwilightEngine` source directories by removing remaining structural offenders.

Deliverables:
- Decomposed `StoryDirector.swift` by extracting context/check/event-pool types into dedicated files:
  - `StoryContextModels.swift`
  - `StoryChecks.swift`
  - `StoryEventPool.swift`
- Decomposed `CombatCalculator.swift` by extracting result/effect/context carriers:
  - `CombatResultModels.swift`
  - `CombatEffectTypes.swift`
  - `FateAttackResults.swift`
  - `CombatPlayerContext.swift`
- Decomposed `QuestTriggerEngine.swift` by extracting trigger/update models:
  - `QuestTriggerModels.swift`
- Decomposed `TwilightMarchesConfig.swift` by extracting curse definitions:
  - `TwilightMarchesCurseConfig.swift`
- Expanded `CodeHygieneTests` type-gate coverage to include previously unguarded engine directories:
  - `Combat`, `Config`, `Encounter`, `Quest`, `Story`.

Acceptance:
- No file in audited engine directories exceeds `maxTypesPerFile = 5` top-level types.
- `CodeHygieneTests/testFilesDoNotHaveTooManyTypes` stays green without legacy/type allowlists.
- `AuditArchitectureBoundaryGateTests` remains green after decomposition.

### Epic 67 [DONE] — Xcode Project Structure Canonicalization

Goal: align the entire Xcode project hierarchy with domain architecture, eliminating mixed/legacy grouping patterns and fragile path references.

Deliverables:
- Checkpoint 1: canonicalize `App` file references to use group-relative paths and enforce via gate:
  - `CodeHygieneTests/testXcodeProjectAppGroupUsesGroupRelativePaths`
- Checkpoint 2: canonicalize `Models/Combat` subgroup and enforce via gate:
  - `CodeHygieneTests/testXcodeProjectModelsCombatGroupUsesGroupRelativePaths`
- Checkpoint 3: canonicalize `Views/WorldMap` subgroup and enforce via gate:
  - `CodeHygieneTests/testXcodeProjectViewsWorldMapGroupUsesGroupRelativePaths`
- Checkpoint 4: canonicalize `Views/Components` + `ViewModels` file references and enforce via gates:
  - `CodeHygieneTests/testXcodeProjectViewsComponentsGroupUsesGroupRelativePaths`
  - `CodeHygieneTests/testXcodeProjectViewModelsGroupUsesGroupRelativePaths`
- Checkpoint 5: add a non-brittle pbxproj integrity gate + normalize tests group naming:
  - `CodeHygieneTests/testXcodeProjectHasNoDanglingObjectReferences`
  - `CardSampleGameTests` group uses `GateTests` naming consistently in pbxproj
- Checkpoint 6: eliminate duplicated UI components + canonicalize debug pack discovery:
  - `Views/Components` owns reusable UI cards (`HeroSelectionCard`, `SaveSlotCard`, `LoadSlotCard`, `StatDisplay`, `StatMini`)
  - `App/BundledPackURLs.swift` replaces legacy `ContentViewComponents.swift`
  - `CodeHygieneTests/testXcodeProjectViewsComponentsGroupUsesGroupRelativePaths` expanded to cover the new component file refs
- Checkpoint 7: harden canonical hierarchy gates for root/tests groups:
  - `CodeHygieneTests/testXcodeProjectRootGroupStaysFeatureOriented`
  - `CodeHygieneTests/testXcodeProjectTestsGroupUsesCanonicalSubgroups`
  - `CodeHygieneTests/testXcodeProjectGateTestsGroupAvoidsSourceRootDrift`
- Build and apply a canonical hierarchy for app + tests + package integration areas:
  - `App`, `Views` (feature-first), `ViewModels`, `Models`, `Managers`, `Utilities`,
  - `CardSampleGameTests` (gate/unit/integration/helpers),
  - package bridge groups with consistent `SOURCE_ROOT`/`<group>` usage rules.
- Remove stale/orphaned PBX references and duplicate logical entries.
- Add a static gate that checks:
  - group-path consistency,
  - no orphaned file refs in app/test targets,
  - no reintroduction of flat top-level sprawl in feature folders.

Acceptance:
- `CardSampleGame.xcodeproj/project.pbxproj` matches canonical structure contract.
- App/test build phases contain only valid, non-orphaned source references.
- New structure gate fails on hierarchy drift.

### Epic 68 [DONE] — File Header Contract Coverage

Goal: make file intent explicit across the first-party codebase to reduce reverse-engineering cost and improve maintainability.

Deliverables:
- Defined a single canonical header format for first-party Swift files (Russian language):
  - `/// Файл: <relative path>`
  - `/// Назначение: ...`
  - `/// Зона ответственности: ...`
  - `/// Контекст: ...`
- Extended `CodeHygieneTests` with hard gate:
  - `testFirstPartySwiftFilesHaveCanonicalFileHeaders`
  - scope includes app/tests/packages first-party files,
  - exclusions are only vendor/build/internal agent paths (`Packages/ThirdParty`, `.build`, `.codex_home`) and `Package.swift` manifests.
- Applied project-wide backfill of canonical headers to all first-party Swift files.

Acceptance:
- First-party Swift files satisfy 100% header coverage with explicit exclusions only.
- `CodeHygieneTests/testFirstPartySwiftFilesHaveCanonicalFileHeaders` fails on missing/invalid headers.
