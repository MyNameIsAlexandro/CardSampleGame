# Sprint Board

> Read this file at the start of every Claude session.
> Take the **Next Task**, complete it, update status, commit.

## Current Epic: 1 — RNG Normalization
Status: CLOSED (6/6 tasks done)

## Audit Result (RNG-01)

**Finding: 100% WorldRNG compliance in production code.**
- 42 RNG call sites, all via WorldRNG
- Zero Int.random / Bool.random / arc4random in production
- EncounterEngine already uses sub-stream: `WorldRNG(seed: context.rngSeed)`
- FateDeckManager uses DI: `rng: WorldRNG = .shared`
- EngineSave already serializes rngSeed + rngState

## Completed

- [x] RNG-01: Audit all RNG call sites — 100% WorldRNG, zero non-deterministic
- [x] RNG-02: N/A — already clean, no stdlib random found
- [x] RNG-03: N/A — already serialized in EngineSave
- [x] RNG-04: N/A — EncounterEngine already uses sub-stream
- [x] RNG-05: Determinism test — INV_RNG_GateTests (4 tests, 0 failures)
- [x] RNG-06: Save/load determinism — testSaveLoadDeterminism + testRNGStateRoundTrip

---

## Next Epic: 2 — Transaction Integrity
Status: NOT STARTED (0/6 tasks done)

## Next Task

**TXN-01: Audit public var in TwilightGameEngine**
- Input: `Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine.swift`
- Action: Find all `public var` without `private(set)`. List each with file:line, property name, and whether it SHOULD be externally mutable or not.
- Output: List added to this file under "TXN Audit Results".
- Test: Read-only task, no build needed.
- Ref: `docs/plans/2026-01-30-epic-driven-development-design.md` Epic 2

## Backlog (this epic)

- [ ] TXN-02: Close access control: public -> public private(set)
- [ ] TXN-03: Close access control in EncounterEngine
- [ ] TXN-04: Contract test: state snapshot before/after performAction
- [ ] TXN-05: Save round-trip test: save -> load -> all fields identical
- [ ] TXN-06: Remove all TODO/fatalError from production code

---

## Future Epics

1. ~~Epic 1: RNG Normalization~~ CLOSED
2. **Epic 2: Transaction Integrity** (current)
3. Epic 3: Encounter Engine Completion
4. Epic 4: Test Foundation Closure
5. Epic 5: World Consistency
6. Epic 6: Encounter UI Integration

Full details: `docs/plans/2026-01-30-epic-driven-development-design.md`
