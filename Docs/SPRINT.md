# Sprint Board

> Read this file at the start of every Claude session.
> Take the **Next Task**, complete it, update status, commit.

---

## ALL EPICS COMPLETE

Total: 12 epics, 101 tasks, 358 engine tests (0 failures), iOS + macOS builds clean.

---

## Closed Epics

1. ~~Epic 1: RNG Normalization~~ CLOSED — 100% WorldRNG, 4 gate tests
2. ~~Epic 2: Transaction Integrity~~ CLOSED — access locked, 8 gate tests, fatalError cleanup
3. ~~Epic 3: Encounter Engine Completion~~ CLOSED — 12 tasks, 31 gate tests (keywords, match, pacify, resonance, phase automation, critical defense, integration)
4. ~~Epic 4: Test Foundation Closure~~ CLOSED — 0 red, 0 skip, determinism verified (100 runs)
5. ~~Epic 5: World Consistency~~ CLOSED — degradation, tension, anchors, 12 gate tests, 30-day simulation
6. ~~Epic 6: Encounter UI Integration~~ CLOSED — CombatView + EncounterViewModel + all widgets, simulator build clean
7. ~~Epic 7: Encounter Module Completion~~ CLOSED — defend, flee, loot, multi-enemy, summon, RNG seed, 11 gate tests
8. ~~Epic 8: Save Safety + Onboarding + Settings~~ CLOSED — fate deck persistence, game over, auto-save, tutorial, settings, 3 gate tests
9. ~~Epic 9: UI/UX Polish~~ CLOSED — HapticManager, SoundManager, floating damage, damage flash, 3D card flip, travel transition, ambient menu, game over animations, AppAnimation + AppGradient tokens
10. ~~Epic 10: Design System Audit~~ CLOSED — 38 violations fixed across 14 files, CardSizes tokens, AppShadows.glow, localized fate strings (en+ru), full token compliance
11. ~~Epic 11: Debt Closure~~ CLOSED — mid-combat save (SAV-03), difficulty wiring (SET-02), Codable on 11 types, EncounterEngine snapshot/restore, view-layer resume, 8 gate tests
12. ~~Epic 12: Pack Editor~~ CLOSED — macOS SwiftUI content authoring tool, 17 source files, 8 editors (enemy/card/event/region/hero/fate/quest/balance), combat simulator with Charts histogram, validate + compile toolbar, NavigationSplitView

## Remaining Debt

None — all debt items resolved.

## Gate Test Files

| File | Tests | Scope |
|------|-------|-------|
| INV_RNG_GateTests | 4 | RNG determinism, seed isolation, save/load |
| INV_TXN_GateTests | 8 | Contract tests, save round-trip |
| INV_KW_GateTests | 32 | Keywords, match/mismatch, pacify, resonance costs, enemy mods, phase automation, critical defense, integration, determinism |
| INV_WLD_GateTests | 12 | Degradation rules, state chains, tension game-over, escalation formula, 30-day simulation |
| INV_ENC7_GateTests | 11 | Defend, flee rules, loot distribution, RNG seed, summon |
| INV_SAV8_GateTests | 3 | Fate deck save/load, round-trip, backward compatibility |
| INV_DEBT11_GateTests | 8 | VictoryType Codable, EncounterSaveState round-trip, snapshot/restore, backward compat, difficulty |

## Final Stats

- **Engine tests**: 358 (0 failures, 0 skips)
- **Gate tests**: 78 across 7 files
- **iOS Simulator**: builds clean (iPhone 17 Pro)
- **macOS**: builds clean (PackEditor)
- **Architecture**: Engine-First, all state via performAction(), deterministic RNG

Full details:
- Epics 1-6: `docs/plans/2026-01-30-epic-driven-development-design.md`
- Epic 7: `docs/plans/2026-01-30-encounter-completion-design.md`
- Epic 8: `docs/plans/2026-01-30-save-onboarding-design.md`
- Epic 9: `Docs/plans/2026-01-30-ui-ux-polish-design.md`
- Epic 10: `Docs/plans/2026-01-31-design-system-audit-design.md`
- Epic 11: `Docs/plans/2026-01-31-debt-closure-design.md` (plan file)
- Epic 12: `Docs/plans/2026-01-31-pack-editor-design.md` (plan file)
