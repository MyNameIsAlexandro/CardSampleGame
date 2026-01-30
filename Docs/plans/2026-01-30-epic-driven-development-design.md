# Epic-Driven Development: Process & Roadmap

Date: 2026-01-30
Status: Approved

## Problem

Documentation outpaces implementation. Context lost between Claude sessions. Combat/diplomacy module incomplete despite extensive specs. Audit identified P0/P1 architectural and product risks.

## Solution: Two-File System

### `docs/SPRINT.md` — Operational (what to do now)

- Current epic + task backlog
- Each task: ID, title, input files, expected output, test criteria
- One task = one Claude session
- Epic not closed until all tasks `[x]` + smoke test passed
- New epic does not start until current is closed

### `docs/ARCHITECTURE.md` — Strategic (how things connect)

- Module contracts and boundaries
- Data flow between systems
- Invariants that must hold
- Updated only when epic closes
- Max 500 lines — not a spec, a map

### Rules

1. Claude reads SPRINT.md + ARCHITECTURE.md at session start
2. Old specs (COMBAT_DIPLOMACY_SPEC.md etc.) remain as reference, not primary context
3. Each task ends with `xcodebuild build` + test verification
4. SPRINT.md updated at end of each session

## Epic Roadmap

### Epic 1: RNG Normalization (P0-A)

Two RNG philosophies in codebase: WorldRNG.shared singleton vs rngSeed in EncounterContext. Must unify before any determinism guarantees.

| ID | Task | Scope |
|---|---|---|
| RNG-01 | Audit all RNG call sites in engine | Read-only: find WorldRNG, Int.random, Bool.random, randomElement |
| RNG-02 | Replace all Int.random/Bool.random with WorldRNG | Clean up raw random() calls |
| RNG-03 | Serialize RNG state in EngineSave | Add rngState to save/load |
| RNG-04 | Encounter sub-stream: seed from WorldRNG at context creation | EncounterContext gets seed |
| RNG-05 | Determinism test: seed -> full run -> identical result | Gate test |
| RNG-06 | Smoke: save -> load -> same event on explore | Integration test |

### Epic 2: Transaction Integrity (P0-B)

performAction is the only entry point, but public var allows direct state mutation. Save/load can desync.

| ID | Task | Scope |
|---|---|---|
| TXN-01 | Audit public var in TwilightGameEngine | Find all public var without private(set) |
| TXN-02 | Close access control: public -> public private(set) | Mass replace, fix compile errors |
| TXN-03 | Close access control in EncounterEngine | Same for encounter |
| TXN-04 | Contract test: state snapshot before/after performAction | Gate test: only performAction changes state |
| TXN-05 | Save round-trip test: save -> load -> all fields identical | Full serialization check |
| TXN-06 | Remove all TODO/fatalError from production code | Replace with graceful handling |

### Epic 3: Encounter Engine Completion (P0 Product + P1-C)

Keywords are stubs, match bonus incomplete, pacify path non-viable, phase automation not guaranteed.

| ID | Task | Scope |
|---|---|---|
| ENC-01 | Keyword: surge (attack: bleed, diplomacy: pressure+rep) | KeywordInterpreter |
| ENC-02 | Keyword: focus (attack: ignore armor) | KeywordInterpreter |
| ENC-03 | Keyword: echo (card returns to hand) | KeywordInterpreter + EncounterEngine |
| ENC-04 | Keyword: shadow (vampirism: heal on damage) | KeywordInterpreter |
| ENC-05 | Keyword: ward (defense: prevent failure) | KeywordInterpreter |
| ENC-06 | Match Bonus: suit matches action type -> 1.5x | EncounterEngine fate resolution |
| ENC-07 | Pacify control tool: prevent accidental kill during spirit attack | Design + implement |
| ENC-08 | Resonance zone effects on card costs (+1 faith in wrong zone) | EncounterEngine card play |
| ENC-09 | Enemy resonance modifiers from JSON | BehaviorEvaluator |
| ENC-10 | Phase automation: intent auto-generated at round start | EncounterEngine contract |
| ENC-11 | Critical defense: CRIT fate card = 0 damage | EncounterEngine enemy resolution |
| ENC-12 | Integration test: full encounter from context to result | End-to-end |

### Epic 4: Test Foundation Closure (P0-T, P1-T)

Gate tests depend on unready components. Migration incomplete. Without green gates, no regression guarantee.

| ID | Task | Scope |
|---|---|---|
| TST-01 | Audit: list all red/skipped tests | Read-only |
| TST-02 | Close gate test dependencies on ContentRegistry | Mock or real fixtures |
| TST-03 | Close gate test dependencies on BalancePack | Fixtures |
| TST-04 | Close gate test dependencies on ConditionParser | Fixtures or impl |
| TST-05 | Remove/rewrite all XCTSkip in gate tests | Gate = no skip |
| TST-06 | Determinism simulation: 100 runs with seed -> stats | Integration test |
| TST-07 | Final run: 0 red, 0 skip in gate + layer | CI-ready |

### Epic 5: World Consistency (P1 Product)

World degradation described differently across docs. Stable regions: contradictory rules. Tension 100% game over not implemented.

| ID | Task | Scope |
|---|---|---|
| WLD-01 | Normalize degradation algorithm in one place | TwilightGameEngine |
| WLD-02 | Stable->Borderland: define single rule | Code + test |
| WLD-03 | Tension 100% -> Game Over | Engine + UI alert |
| WLD-04 | Anchor auto-degradation every 3 days | TimeEngine integration |
| WLD-05 | Test: full 30-day simulation, verify degradation | Integration test |

### Epic 6: Encounter UI Integration

Engine ready (after Epic 3), but CombatView uses legacy bridge. No dual bars, intent display, proper action buttons.

| ID | Task | Scope |
|---|---|---|
| EUI-01 | CombatView -> EncounterViewModel full integration | Remove legacy path |
| EUI-02 | DualHealthBar: HP + WP simultaneously | New component |
| EUI-03 | EnemyIntentView: intent icon above enemy | Integrate existing |
| EUI-04 | Action buttons: Attack Body / Influence Spirit / Wait | ActionBar redesign |
| EUI-05 | Fate card reveal animation on draw | FateCardRevealView integration |
| EUI-06 | Resonance shift feedback in combat | Visual indicator |
| EUI-07 | Smoke test on simulator: full combat start to finish | Manual QA |

## Totals

- 6 epics
- 42 tasks
- Each task = 1 Claude session
- Strict sequential epic order (no parallelism between epics)
