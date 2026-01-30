# Sprint Board

> Read this file at the start of every Claude session.
> Take the **Next Task**, complete it, update status, commit.

## Current Epic: 2 — Transaction Integrity
Status: CLOSED (6/6 tasks done)

## Audit Result (TXN-01)

**Finding: access control already locked down.**
- All 30+ `@Published` properties in TwilightGameEngine: `public private(set)`
- All stored properties in EncounterEngine: `public private(set)`
- `public var` in EngineRegionState/EngineAnchorState are struct fields (value types — copies don't affect engine)
- Computed properties are read-only by nature
- No `internal var` or unprotected stored properties on engine classes

**fatalError audit:**
- `EncounterEngine.swift:111` — mulligan case in playerAction switch → replaced with `.fail(.actionNotAllowed)`
- `HeroRegistry.swift:308` — missing ability ID → valid data integrity check (pack corrupt), kept
- `PackLoader.swift:549` — same pattern, valid data integrity check, kept
- `EncounterEngine.swift:6` — outdated comment "all stubs (fatalError)" → updated
- TODOs: 3 minor (playerArmor, gameDuration, rulesExtension) — non-blocking

## Completed

- [x] TXN-01: Audit public var — all already `public private(set)`
- [x] TXN-02: N/A — access control already closed
- [x] TXN-03: N/A — EncounterEngine already locked
- [x] TXN-04: Contract tests — 4 tests (rest/explore/skipTurn/actionResult)
- [x] TXN-05: Save round-trip — 4 tests (player/world/events/RNG state)
- [x] TXN-06: fatalError cleanup — 1 replaced, 2 kept (valid), 1 comment updated

---

## Current Epic: 3 — Encounter Engine Completion
Status: IN PROGRESS (7/12 tasks done)

## Completed (this epic)

- [x] ENC-01: Keyword surge — +2 bonus damage (physical), resonance push (spiritual)
- [x] ENC-02: Keyword focus — ignore armor (physical), WP pierce (spiritual)
- [x] ENC-03: Keyword echo — return last card from discard to hand
- [x] ENC-04: Keyword shadow — vampirism heal (physical), evade halves damage (defense)
- [x] ENC-05: Keyword ward — fortify prevents failure (defense), parry bonus (physical)
- [x] ENC-06: Match Bonus — already implemented (isSuitMatch/Mismatch + matchMultiplier 1.5x), added 5 e2e gate tests

- [x] ENC-07: Pacify control — already safe (spirit attack only touches WP), added 2 gate tests

Gate tests: 19 tests in INV_KW_GateTests (all pass).

## Next Task

**ENC-08: Resonance zone effects on card costs (+1 faith in wrong zone)**
- Input: `EncounterEngine.swift`
- Action: Cards cost +1 faith when resonance zone opposes card alignment.
- Test: `swift test --package-path Packages/TwilightEngine --filter KW`

## Backlog (this epic)

- [ ] ENC-07: Pacify control tool
- [ ] ENC-08: Resonance zone effects on card costs (+1 faith in wrong zone)
- [ ] ENC-09: Enemy resonance modifiers from JSON
- [ ] ENC-10: Phase automation: intent auto-generated at round start
- [ ] ENC-11: Critical defense: CRIT fate card = 0 damage
- [ ] ENC-12: Integration test: full encounter from context to result

---

## Closed Epics

1. ~~Epic 1: RNG Normalization~~ CLOSED — 100% WorldRNG, 4 gate tests
2. ~~Epic 2: Transaction Integrity~~ CLOSED — access locked, 8 gate tests, fatalError cleanup

## Future Epics

3. **Epic 3: Encounter Engine Completion** (current)
4. Epic 4: Test Foundation Closure
5. Epic 5: World Consistency
6. Epic 6: Encounter UI Integration

Full details: `docs/plans/2026-01-30-epic-driven-development-design.md`
