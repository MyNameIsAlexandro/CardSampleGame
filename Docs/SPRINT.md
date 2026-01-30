# Sprint Board

> Read this file at the start of every Claude session.
> Take the **Next Task**, complete it, update status, commit.

## Current Epic: 1 — RNG Normalization
Status: NOT STARTED (0/6 tasks done)

## Next Task

**RNG-01: Audit all RNG call sites in engine**
- Input: `Packages/TwilightEngine/Sources/`
- Action: Find every usage of `WorldRNG`, `Int.random`, `Bool.random`, `randomElement`, `.shuffled()`, `arc4random` in engine sources. Produce a list grouped by module (Core, Encounter, Events, Combat, etc.) with file:line and classification (deterministic via WorldRNG / non-deterministic / test-only).
- Output: List added to this file under "RNG Audit Results" section below.
- Test: Read-only task, no build needed.
- Ref: `docs/plans/2026-01-30-epic-driven-development-design.md` Epic 1

## Backlog (this epic)

- [ ] RNG-02: Replace all Int.random/Bool.random with WorldRNG
- [ ] RNG-03: Serialize RNG state in EngineSave
- [ ] RNG-04: Encounter sub-stream: seed from WorldRNG at context creation
- [ ] RNG-05: Determinism test: seed -> full run -> identical result
- [ ] RNG-06: Smoke: save -> load -> same event on explore

## Completed

_(none yet)_

---

## Future Epics

1. ~~Epic 1: RNG Normalization~~ (current)
2. Epic 2: Transaction Integrity
3. Epic 3: Encounter Engine Completion
4. Epic 4: Test Foundation Closure
5. Epic 5: World Consistency
6. Epic 6: Encounter UI Integration

Full details: `docs/plans/2026-01-30-epic-driven-development-design.md`
