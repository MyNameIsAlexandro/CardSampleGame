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

## Next Epic: 3 — Encounter Engine Completion
Status: NOT STARTED (0/12 tasks done)

## Next Task

**ENC-01: Keyword surge (attack: bleed, diplomacy: pressure+rep)**
- Input: `Packages/TwilightEngine/Sources/TwilightEngine/Encounter/KeywordInterpreter.swift`
- Action: Implement surge keyword effect: in attack context adds bleeding (extra damage over turns), in diplomacy context adds pressure + reputation penalty. Add gate test.
- Output: KeywordInterpreter updated, new test in INV_ENC or dedicated file.
- Test: `swift test --package-path Packages/TwilightEngine --filter Keyword`
- Ref: COMBAT_DIPLOMACY_SPEC.md §3.5, `docs/plans/2026-01-30-epic-driven-development-design.md` Epic 3

## Backlog (this epic)

- [ ] ENC-02: Keyword focus (attack: ignore armor)
- [ ] ENC-03: Keyword echo (card returns to hand)
- [ ] ENC-04: Keyword shadow (vampirism: heal on damage)
- [ ] ENC-05: Keyword ward (defense: prevent failure)
- [ ] ENC-06: Match Bonus: suit matches action type → 1.5x
- [ ] ENC-07: Pacify control tool: prevent accidental kill during spirit attack
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
