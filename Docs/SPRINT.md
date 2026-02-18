# Sprint Board

> **Назначение:** Единый центр планирования. Читать при старте каждой сессии.
> Take the **Next Task**, complete it, update status, commit.

---

## Phase 3 (Disposition Combat)

**Design:** [Disposition Combat v2.5](../docs/plans/2026-02-18-disposition-combat-design.md) — SoT для боевой механики

Source of truth:
- `docs/plans/2026-02-18-disposition-combat-design.md` (design doc, v2.5 approved)
- `Docs/Design/COMBAT_DIPLOMACY_SPEC.md` (compact reference, v2.0)
- `Docs/QA/QUALITY_CONTROL_MODEL.md` (quality policy + mandatory gates)
- `Docs/QA/TESTING_GUIDE.md` (how to run gates)

### Status: Implementation backlog ready, awaiting audit

**Завершено:**
- Design doc v2.5 утверждён (5 раундов аудита)
- Документация актуализирована (12 документов)
- Тестовая модель v5.3 утверждена (3 раунда аудита, 62 инварианта, 68 gate-тестов, sacrifice cost model finalized)
- Design doc §10.2 Surge contradiction исправлен в SoT

**Test model:** `Docs/QA/RITUAL_COMBAT_TEST_MODEL.md` v5.3

---

### Implementation Backlog

**Принцип:** TDD — сначала gate-тесты (красные), потом имплементация (зелёные). Каждый epic = один коммит с тестами + кодом. Два параллельных потока: Engine (SPM) и App (Xcode).

**Зависимости:**
```
Epic 15 (Foundation) ──→ Epic 16 (Momentum) ──→ Epic 18 (Fate Keywords)
       │                       │                         │
       │                       ↓                         ↓
       │                 Epic 17 (Energy) ──→ Epic 20 (Card Play App) + Epic 26a (Static Scans)
       │                                              │
       ↓                                              ↓
Epic 19 (Enemy Core,  ──→ Epic 21 (Enemy Modes) ──→ Epic 23 (Integration)
  NORMAL mode only)          │                      │
       │                     ↓                      ↓
       ↓                   Epic 24 (Scene)    Epic 25 (Stress+Sim)
Epic 22 (Systemic Asymmetry)                        │
                                                    ↓
                                               Epic 26b (Arena, Save, Defeat)
```

---

#### Epic 15: Disposition Foundation (P0) — БЛОКИРУЕТ ВСЁ
**Scope:** DispositionCombatSimulation, DispositionCalculator, AffinityMatrix, базовый disposition track
**Tests:** DispositionMechanicsGateTests (9 тестов)
**Invariants:** INV-DC-001..006, INV-DC-044
**Layer:** Engine (SPM)

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 15-01 | Создать `DispositionCombatSimulation` struct (disposition, outcome, seed) | `Sources/Combat/DispositionCombatSimulation.swift` | — |
| 15-02 | Создать `DispositionCalculator` (effective_power formula, hard cap 25) | `Sources/Combat/DispositionCalculator.swift` | INV-DC-002 |
| 15-03 | Создать `AffinityMatrix` (data-driven, content pack) | `Sources/Combat/AffinityMatrix.swift` | INV-DC-006, INV-DC-044 |
| 15-04 | Disposition clamping [-100, +100] | `DispositionCombatSimulation` | INV-DC-001 |
| 15-05 | Outcome resolution (-100 → .destroyed, +100 → .subjugated) | `DispositionCombatSimulation` | INV-DC-003, INV-DC-004 |
| 15-06 | Determinism (seed → identical result) | `DispositionCombatSimulation` | INV-DC-005 |
| 15-07 | Surge base_power × 1.5 в калькуляторе | `DispositionCalculator` | testSurge_onlyAffectsBasePower |
| 15-08 | Resonance zone modifiers (Nav/Yav/Prav) | `DispositionCalculator` | testResonanceZone_modifiesEffectiveness |
| 15-09 | Gate tests suite file | `Tests/GateTests/DispositionMechanicsGateTests.swift` | 9 тестов green |

---

#### Epic 16: Momentum System (P0) — блокирует Card Play, Enemy Modes
**Scope:** Streak tracking, bonus/penalty formulas
**Tests:** MomentumGateTests (5 тестов)
**Invariants:** INV-DC-007..011
**Layer:** Engine (SPM)
**Depends on:** Epic 15

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 16-01 | Momentum state (streakType, streakCount, lastActionType) в Simulation | `DispositionCombatSimulation` | — |
| 16-02 | Streak reset on switch | `DispositionCombatSimulation` | INV-DC-007 |
| 16-03 | Streak preserved across turns | `DispositionCombatSimulation` | INV-DC-008 |
| 16-04 | streak_bonus = max(0, streakCount - 1) в калькуляторе | `DispositionCalculator` | INV-DC-009 |
| 16-05 | threat_bonus = 2 (strike → influence) | `DispositionCalculator` | INV-DC-010 |
| 16-06 | switch_penalty = max(0, streakCount - 2) при streak ≥ 3 | `DispositionCalculator` | INV-DC-011 |
| 16-07 | Gate tests suite file | `Tests/GateTests/MomentumGateTests.swift` | 5 тестов green |

**Turn boundary contract:** `endPlayerTurn()` → `resolveEnemyTurn()` → `beginPlayerTurn()`. Streak persists across this entire boundary. Reset происходит **только** при смене action type (strike↔influence), не при endTurn/beginTurn/resolveEnemy.

---

#### Epic 17: Energy System (P0) — блокирует Card Play
**Scope:** Energy deduction, auto turn-end, Resonance-Sacrifice interaction
**Tests:** EnergyGateTests (6 тестов)
**Invariants:** INV-DC-045..048, INV-DC-061, INV-DC-062
**Layer:** Engine (SPM)
**Depends on:** Epic 15
**SoT для Sacrifice:** Test Model v5.3, INV-DC-061/062. Sacrifice стоит `card.cost` энергии, даёт +1 energy обратно. Nav = cost-1. Prav = extra exhaust risk. **Любое отклонение от SoT требует обновления test model первым.**

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 17-01 | Energy state в Simulation (currentEnergy, startingEnergy) | `DispositionCombatSimulation` | — |
| 17-02 | Energy deduction при card play | `DispositionCombatSimulation` | INV-DC-045 |
| 17-03 | Reject card when energy < cost | `DispositionCombatSimulation` | INV-DC-046 |
| 17-04 | Auto turn-end at 0 energy | `DispositionCombatSimulation` | INV-DC-047 |
| 17-05 | Energy reset each turn | `DispositionCombatSimulation` | INV-DC-048 |
| 17-06 | Nav sacrifice: cost = card.cost - 1, эффект +1 energy (net = break even при cost=2). ⚠️ Balance hotspot | `DispositionCombatSimulation` | INV-DC-061 |
| 17-07 | Prav sacrifice: cost = card.cost, эффект +1 energy, но RNG-шанс exhaust 1 доп. карту | `DispositionCombatSimulation` | INV-DC-062 |
| 17-08 | Gate tests suite file | `Tests/GateTests/EnergyGateTests.swift` | 6 тестов green |

**⚠️ Simulation trigger:** если Nav sacrifice usage > 25% от всех действий в симуляции → пересмотр cost model обязателен. При cost=2 Nav sacrifice = break even, что может стать бесплатным tempo-двигателем. Зависит от deck cost distribution — мониторить в Epic 25.

---

#### Epic 18: Fate Keyword System (P1)
**Scope:** Fate deck, keyword effects, disposition-dependent behavior
**Tests:** FateKeywordGateTests (13 тестов)
**Invariants:** INV-DC-017..026, INV-DC-049..051
**Layer:** Engine (SPM)
**Depends on:** Epic 15, Epic 16

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 18-01 | `FateDeck` struct (draw, reshuffle, deterministic via seed) | `Sources/Combat/FateDeck.swift` | INV-DC-025, INV-DC-026 |
| 18-02 | Surge: base_power × 1.5 (not bonuses) | `DispositionCalculator` | INV-DC-017 |
| 18-03 | Echo: free copy, 0 energy, same fate_modifier | `DispositionCombatSimulation` | INV-DC-019 |
| 18-04 | Echo: blocked after Sacrifice | `DispositionCombatSimulation` | INV-DC-018 |
| 18-05 | Echo: works after Strike/Influence | `DispositionCombatSimulation` | INV-DC-051 |
| 18-06 | Echo: continues streak, no new fate draw | `DispositionCombatSimulation` | INV-DC-020, INV-DC-021 |
| 18-07 | Focus: ignore Defend at disposition < -30 | `DispositionCalculator` | INV-DC-022 |
| 18-08 | Focus: ignore Provoke at disposition > +30 | `DispositionCalculator` | INV-DC-049 |
| 18-09 | Ward: cancel resonance backlash | `DispositionCalculator` | INV-DC-023 |
| 18-10 | Shadow: +2 switch_penalty at disposition < -30 | `DispositionCalculator` | INV-DC-024 |
| 18-11 | Shadow: disable Defend at disposition > +30 | `DispositionCalculator` | INV-DC-050 |
| 18-12 | Gate tests suite file | `Tests/GateTests/FateKeywordGateTests.swift` | 13 тестов green |

---

#### Epic 19: Enemy Action Core (P1)
**Scope:** Base enemy actions (Attack, Defend, Provoke, Adapt), momentum reading
**Tests:** EnemyActionGateTests (5 тестов)
**Invariants:** INV-DC-056..060
**Layer:** Engine (SPM)
**Depends on:** Epic 15, Epic 16

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 19-01 | `EnemyActionResolver` (resolve action → effect on hero/disposition) | `Sources/Combat/EnemyActionResolver.swift` | — |
| 19-02 | Attack: reduce hero HP | `EnemyActionResolver` | INV-DC-056 |
| 19-03 | Defend: reduce next Strike effective_power | `EnemyActionResolver` | INV-DC-057 |
| 19-04 | Provoke: penalize Influence | `EnemyActionResolver` | INV-DC-058 |
| 19-05 | Adapt: soft-block streak type. **Soft-block =** действие разрешено, penalty = `max(3, streak_bonus)` к effective_power (при streak=5 penalty=4, не 3). effective_power может стать 0, но действие выполняется (discard, energy списывается). UI никогда не блокирует drag-drop. Игрок всегда может выбрать другой тип | `EnemyActionResolver` | INV-DC-059 |
| 19-06 | Enemy reads momentum **в NORMAL mode only** (streak ≥ 3 → Adapt/Defend/Provoke). Режимные ветки (Survival/Desperation/Weakened) → Epic 21 | `Sources/Combat/EnemyAI.swift` | INV-DC-060 |
| 19-07 | Gate tests suite file | `Tests/GateTests/EnemyActionGateTests.swift` | 5 тестов green |

**Acceptance constraint:** INV-DC-060 проверяется **только при enemyMode = .normal**. В SURVIVAL/DESPERATION/WEAKENED контр-логика определяется Epic 21. Имплементация momentum-reading ОБЯЗАНА иметь guard `mode == .normal` — иначе modes будут конфликтовать.

**⚠️ Adapt frequency hotspot:** если в симуляции Adapt срабатывает > 30% ходов в NORMAL mode → пересмотреть AI weights или penalty. "Soft-block каждый третий ход" = постоянная давилка, убивающая player agency.

---

#### Epic 20: Card Play App Integration (P1) — **парный с Epic 26a**
**Scope:** Strike/Influence/Sacrifice через app layer, drag-drop commands
**Tests:** DispositionCardPlayGateTests (5 тестов)
**Invariants:** INV-DC-012..016
**Layer:** App (Xcode)
**Depends on:** Epic 15, Epic 16, Epic 17
**Paired with:** Epic 26a — static scan gates включаются в тот же PR. Без green 26a gates → PR не мержится.

**⛔ Запрещено:** прямые вызовы `DispositionCombatSimulation.*` из Scene/View/ViewModel. Только через engine action + bridge. Нарушение ловится Epic 26a gates (INV-DC-039, INV-DC-040).

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 20-01 | `playCardAsStrike(cardId:targetId:)` action | Engine action + Bridge | INV-DC-012 |
| 20-02 | `playCardAsInfluence(cardId:)` action | Engine action + Bridge | INV-DC-013 |
| 20-03 | `playCardAsSacrifice(cardId:)` action (1/turn, exhaust, enemy buff) | Engine action + Bridge | INV-DC-014, INV-DC-015, INV-DC-016 |
| 20-04 | Gate tests suite file | `CardSampleGameTests/GateTests/DispositionCardPlayGateTests.swift` | 5 тестов green |

---

#### Epic 21: Enemy Mode System (P1)
**Scope:** Survival, Desperation, Weakened, Normal — transitions, hysteresis, AI
**Tests:** EnemyModeGateTests (12 тестов)
**Invariants:** INV-DC-027..034, INV-DC-052..055
**Layer:** Engine (SPM)
**Depends on:** Epic 15, Epic 19

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 21-01 | Dynamic thresholds (seed_hash % 11) | `EnemyAI` | INV-DC-027, INV-DC-028, INV-DC-029 |
| 21-02 | Hysteresis (hold 1 turn after leaving threshold) | `EnemyAI` | INV-DC-030 |
| 21-03 | Weakened trigger (±30 swing) + deterministic selection (min weight, deck-order tie-break) | `EnemyAI` | INV-DC-031, INV-DC-032 |
| 21-04 | Rage: ATK ×2, disposition += 5 | `EnemyActionResolver` | INV-DC-033 |
| 21-05 | Plea: disposition +10, strike backlash -5 HP | `EnemyActionResolver` | INV-DC-034 |
| 21-06 | Survival player bonus: Strike +3 | `DispositionCalculator` | INV-DC-052 |
| 21-07 | Desperation: ATK ×2, Defend disabled, Provoke strengthened | `EnemyAI + EnemyActionResolver` | INV-DC-053, INV-DC-054, INV-DC-055 |
| 21-08 | Gate tests suite file | `Tests/GateTests/EnemyModeGateTests.swift` | 12 тестов green |

---

#### Epic 22: Systemic Asymmetry (P2)
**Scope:** Vulnerability/resistance matrix, resonance overrides, content pack format
**Tests:** SystemicAsymmetryGateTests (4 теста)
**Invariants:** INV-DC-035..038
**Layer:** Engine (SPM)
**Depends on:** Epic 15

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 22-01 | `EnemyVulnerabilityDefinition` с resonanceOverrides | `Sources/Content/EnemyVulnerabilityDefinition.swift` | — |
| 22-02 | Vulnerability lookup (enemy × action × zone) | `DispositionCalculator` | INV-DC-035, INV-DC-036 |
| 22-03 | Resonance changes vulnerability | content pack | INV-DC-037 |
| 22-04 | No absolute vulnerability validation | content pack | INV-DC-038 |
| 22-05 | Gate tests suite file | `Tests/GateTests/SystemicAsymmetryGateTests.swift` | 4 теста green |

**Minimum dataset (тесты не считаются green на игрушечном контенте):**
- ≥ 5 enemy types (Бандит, Дух, Зверь, Торговец, Нежить — как в Design §7.2)
- Каждый тип: resonanceOverrides минимум в 2 из 3 зон (Nav/Yav/Prav)
- ≥ 1 тип с flip (слабость → резист между зонами, например Дух: Sacrifice weak в Nav → resist в Prav)
- ≥ 1 тип с провокацией (Торговец: Strike → вызывает стражу)

---

#### Epic 23: Integration & Save/Restore (P2-P3)
**Scope:** End-to-end scenarios, snapshot round-trip, mid-combat save
**Tests:** DispositionIntegrationTests (13 тестов) + CombatSnapshot (3 теста)
**Layer:** Engine (SPM) + App (Xcode)
**Depends on:** Epics 15–21

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 23-01 | CombatSnapshot: encode all required fields | `Sources/Combat/CombatSnapshot.swift` | testSnapshotContainsAllRequiredFields |
| 23-02 | CombatSnapshot: encode/decode round-trip | `CombatSnapshot` | testSnapshotRoundTrip_encode_decode |
| 23-02a | **🔒 SNAPSHOT CONTRACT FREEZE:** после green 23-02 любое изменение snapshot полей требует: 1) обновить test model, 2) обновить 23-02 тест, 3) review. Без этого — PR блокируется. | — | — |
| 23-03 | CombatSnapshot: resume deterministic | `DispositionCombatSimulation` | testSnapshotRoundTrip_resume_deterministic |
| 23-04 | Full destroy path (1v1) | Integration | testFullDestroyPath |
| 23-05 | Full subjugate path (1v1) | Integration | testFullSubjugatePath |
| 23-06 | Mixed strategy path | Integration | testMixedStrategyPath |
| 23-07 | Sacrifice recovery path | Integration | testSacrificeRecoveryPath |
| 23-08 | Defeat path (HP → 0) | Integration | testDefeatPath |
| 23-09 | Resonance Nav/Prav combat | Integration | testResonanceNavCombat, testResonancePravCombat |
| 23-10 | Enemy mode transitions (all 4 modes) | Integration | testEnemyModeTransitions |
| 23-11 | Mid-combat save/resume | Integration | testMidCombatSaveResume |
| 23-12 | Affinity matrix impact (3 heroes) | Integration | testAffinityMatrixImpact |

---

#### Epic 24: SpriteKit Scene (P2)
**Scope:** RitualCombatScene drag-drop zones, visual feedback, enemy mode animations
**Tests:** DispositionSceneGateTests (4 теста)
**Layer:** App (Xcode)
**Depends on:** Epic 20, Epic 21

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 24-01 | Drag-drop → canonical commands (Strike/Influence/Sacrifice) | `RitualCombatScene` | testDragDropProducesCanonicalCommands |
| 24-02 | Scene uses only CombatSimulation API | `RitualCombatScene` | testRitualSceneUsesOnlyCombatSimulationAPI |
| 24-03 | ResonanceAtmosphereController read-only | `ResonanceAtmosphereController` | testResonanceAtmosphereIsReadOnly |
| 24-04 | Enemy mode transition animations: **duration ≥ 0.3s, aura state changed, queued before next action**. Visual Communication Contract из Design §7.8 | `RitualCombatScene` | testEnemyModeTransitionAnimated |
| 24-05 | Transition depth: tooltip shown on first occurrence in session, transition не перекрывается следующей анимацией (queue ordering), rapid consecutive triggers не теряют events (Normal→Survival→Weakened за 2 хода = 2 visible transitions) | `RitualCombatScene` | testModeTransitionQueueOrdering |

---

#### Epic 25: Stress Tests & Simulation (P3-P4)
**Scope:** 5 exploit scenarios, 5 simulation agents, balance validation
**Tests:** DispositionStressTests (5) + CombatSimulationAgentTests (30+)
**Layer:** Engine (SPM)
**Depends on:** Epics 15–22

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 25-01 | Stress: sacrifice cycle | StressTests | testStress_sacrificeCycle |
| 25-02 | Stress: echo snowball | StressTests | testStress_echoSnowball |
| 25-03 | Stress: threshold dancing | StressTests | testStress_thresholdDancing |
| 25-04 | Stress: influence lock | StressTests | testStress_influenceLock |
| 25-05 | Stress: all-sacrifice opener | StressTests | testStress_allSacrificeOpener |
| 25-06 | 5 simulation agents (Random, Greedy Strike, Greedy Influence, Adaptive, Sacrifice-heavy) | `Tests/IntegrationTests/CombatSimulationAgentTests.swift` | 6 acceptance criteria |
| 25-07 | Balance hotspot monitoring: Nav sacrifice (>25% → пересмотр), Adapt frequency, threshold distribution | Simulation output | Metrics in TestResults/CombatSimulation/ |
| 25-08 | **Ritual baseline comparison:** same enemy × hero × zone, Ritual (old dual-track) vs Disposition. Метрики: avg combat length, outcome variety (σ), % dominant path, **decision diversity** (распределение Strike/Influence/Sacrifice — энтропия ≥ 1.0 бит). Disposition должна превосходить по variety и path diversity | `Tests/IntegrationTests/RitualBaselineComparisonTests.swift` | Disposition variety > Ritual variety |

---

#### Epic 26a: Architecture Boundary — Static Scans (P1) — раннее предохранение
**Scope:** Static analysis gates, защита от утечек в App/Bridge с первого дня Stream B
**Tests:** 2 из DispositionArchBoundaryGateTests
**Invariants:** INV-DC-039, INV-DC-040
**Layer:** App (Xcode)
**Depends on:** Epic 20 (стартует одновременно с началом Stream B)

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 26a-01 | Scan: no direct disposition mutation from App/Views | Static analysis | INV-DC-039 |
| 26a-02 | Scan: no fate draw outside engine action | Static analysis | INV-DC-040 |
| 26a-03 | Gate tests (2 теста) | `CardSampleGameTests/GateTests/DispositionArchBoundaryGateTests.swift` | 2 теста green |

---

#### Epic 26b: Architecture Boundary — Runtime (P2)
**Scope:** Save/restore, arena isolation, defeat consequences
**Tests:** 3 из DispositionArchBoundaryGateTests
**Invariants:** INV-DC-041..043
**Layer:** App (Xcode) + Engine
**Depends on:** Epic 23

| # | Task | Файлы | Тесты |
|---|------|-------|-------|
| 26b-01 | Save/restore disposition state | Bridge + Engine | INV-DC-041 |
| 26b-02 | Arena isolation (no world commit, local state OK) | Arena module | INV-DC-042 |
| 26b-03 | Defeat changes world state | Engine | INV-DC-043 |
| 26b-04 | Gate tests (3 теста) | `CardSampleGameTests/GateTests/DispositionArchBoundaryGateTests.swift` | 3 теста green |

---

### Parallel Streams

**Stream A (Engine — SPM):** Epics 15 → 16 → 17 → 18 → 19 → 21 → 22 → 23 → 25
**Stream B (App — Xcode):** Epic 20 + 26a (параллельно) → 24 → 26b

Stream B начинается когда Epics 15-17 завершены (foundation ready).
Epic 26a стартует сразу с Stream B — защищает от утечек с первого коммита.

### Summary

| Metric | Value |
|--------|-------|
| Epics | 13 (15–26b) |
| Tasks | ~75 |
| Gate tests | 68 |
| Stress tests | 5 |
| Integration tests | 16 |
| Simulation agents | 5 |
| Balance hotspots | 3 (Nav sacrifice, Adapt, threshold hash) |

### Definition of Done (каждый Epic)

1. **Все заявленные gate-тесты GREEN** — ни один skip, ни один XCTFail("TODO")
2. **Каждый тест:** deterministic (fixed seed), < 2s, не flakey (100 прогонов без расхождений)
3. **Traceability:** PR description содержит список `INV-DC-xxx`, которые закрыты этим epic'ом
4. **SoT lock:** запрещено менять контракт "в коде" без обновления test model v5.3 первым. Код следует test model, не наоборот
5. **Paired gates:** Epic 20 не мержится без green 26a. Epic 23 snapshot freeze после 23-02
6. **SoT — инструмент, не догма:** если прототип показывает, что mechanica не работает (weaken threshold, sacrifice model, surge multiplier) — обновляем test model **первой**, потом код. Тесты фиксируют контракт, а не мешают дизайну эволюционировать. Процесс: propose change → update test model → update code → verify
7. **Complexity freeze:** система уже на грани допустимой сложности (8 подсистем: Momentum, Enemy Modes, Vulnerability, Resonance, Adapt, Fate Keywords, Energy, Sacrifice). **Добавление новых механик запрещено** до завершения Epic 25 (Simulation) и подтверждения баланса. "Маленькая фича" в системе с 8 взаимодействующими подсистемами — это не маленькая фича.

### Priority Balance Hotspots (отслеживать с первых симуляций)

| Hotspot | Trigger | Action |
|---------|---------|--------|
| **Nav sacrifice opener** | Usage > 25% от всех действий, ИЛИ sacrifice-on-turn-1 > 40% боёв в Nav | Пересмотр: либо Nav discount → +0 (вместо cost-1), либо sacrifice стоит card.cost во всех зонах |
| **Adapt давилка** | Adapt срабатывает > 30% ходов в NORMAL mode | Снизить AI weight для Adapt или уменьшить penalty |
| **Threshold clustering** | > 50% seeds дают threshold в 3 значениях | Пересмотреть hash function |
| **Complexity canary** | Средний бой > 15 ходов ИЛИ игрок совершает > 2 "нулевых" действий (effective_power = 0) за бой | Система слишком сложная — упростить взаимодействия, не добавлять новые |

---

## Phase 2 (Audit/Refactor Stream): Complete

Source of truth:
- `Docs/plans/2026-02-07-audit-refactor-phase2-epics.md` (epic ledger + backlog)

Completed epics: 15–68 (all DONE). No open backlog.

---

## Phase 1 (Epics 1-14): Complete

Total: 14 epics, 123 tasks, 606 SPM tests + 96 PackEditorKit tests = 702+ total (0 failures), iOS + macOS builds clean.

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
13. ~~Epic 13: Post-Game System~~ CLOSED — PlayerProfile persistence, Witcher-3 style bestiary (progressive reveal), 15 achievements (4 categories), enhanced statistics, 13 gate tests, 60 L10n keys (en+ru)
14. ~~Epic 14: Encounter Module — Production Completion~~ CLOSED — weakness/strength modifiers, enemy abilities, mid-combat save UI, legacy deprecation, 19 new tests

### Epic 14: Encounter Module — Production Completion
- **Status**: Complete
- **Commit**: 0282852
- EC-01: Weakness/Strength damage modifiers (×1.5/×0.67)
- EC-02: Enemy ability execution (bonusDamage, armor, regeneration)
- EC-03: Behavior content (6 patterns, already wired)
- EC-04: Mid-combat Save & Exit UI
- EC-05: Legacy combat code deprecated
- EC-06: 19 new tests (702+ total, 0 failures)

## Epic 13: Post-Game System — CLOSED (2026-01-31)

**Scope**: PlayerProfile persistence, Witcher-3 style bestiary with progressive reveal, 15 achievements across 4 categories, enhanced statistics, 13 gate tests, 60 L10n keys (en+ru)

**Tasks completed**: 16 tasks across 5 tiers
- Tier 1 (Foundation): PlayerProfile model, ProfileManager singleton, UserDefaults persistence
- Tier 2 (Bestiary): CreatureKnowledge, KnowledgeLevel progression (unknown→glimpsed→studied→mastered), BestiaryView + CreatureDetailView
- Tier 3 (Achievements): AchievementDefinition, AchievementEngine with unlock/progress tracking, AchievementsView, 15 launch achievements
- Tier 4 (Integration): EnemyDefinition bestiary extensions (6 optional fields), encounter hooks, statistics tracking
- Tier 5 (Testing): 13 gate tests in AuditGateTests

**Key deliverables**:
- ProfileManager singleton with UserDefaults key `twilight_profile`
- Bestiary unlock progression: 1 encounter = glimpsed, 3 = studied, 7 = mastered
- 15 achievements: First Steps (4), Combat Mastery (4), Resonance (4), Exploration (3)
- Enhanced statistics: encounters, kills, deaths, victories, playtime, resonance extremes
- 6 bestiary fields: bestiaryName, category, lore, tactics, habitat, weakness
- 60 localization keys (30 en + 30 ru)

**Test results**: 702+ total (606 SPM + 96 PackEditorKit), 0 failures
- 13 new gate tests in AuditGateTests
- Coverage: persistence, progression, achievement unlock, statistics tracking

**Files**: 8 new, 12 modified
- New: PlayerProfile.swift, ProfileManager.swift, AchievementDefinition.swift, AchievementEngine.swift, BestiaryView.swift, CreatureDetailView.swift, AchievementsView.swift, AuditGateTests.swift
- Modified: EnemyDefinition.swift, EncounterBridge.swift, WorldMapView.swift, Localization.swift, 2 .lproj files, 6 content pack files

## Post-Epic: WCAG Contrast Pass

- Brightened ~20 AppColors to meet WCAG AA 4.5:1 on dark backgrounds
- Replaced `.foregroundColor(.secondary)` → `AppColors.muted` across all Views
- Changed white button text to dark on gold (primary) buttons (2.2:1 → 7:1)
- Added ContrastComplianceTests: 7 gate tests (WCAG 2.1 math)

## Post-Epic: Stabilization Pass (2026-01-31)

**Dead code removal** (~1780 lines):
- GameLoop.swift (~330 lines) — moved EngineGamePhase and GameEndResult to EngineProtocols.swift, deleted unused GameLoopBase class and StandardAction enum
- Legacy combat code (~1450 lines) — removed 9 deprecated actions and 4 test files from pre-EncounterEngine era

**Test coverage expansion** (104 new tests):
- EconomyManager: 17 tests
- PressureEngine: 16 tests
- RequirementsEvaluator: 13 tests
- EventPipeline: 21 tests
- QuestTriggerEngine: 24 tests
- MiniGameDispatcher: 13 tests

**Final metrics**:
- Engine tests: 335 → 439
- Total tests: 702+ (606 SPM + 96 PackEditorKit), 0 failures
- Coverage: ~97% of engine source files (up from 87%)

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
| ContrastComplianceTests | 7 | WCAG AA 4.5:1 on cardBackground + backgroundSystem, button contrast, muted text, math validation |
| AuditGateTests | 13 | PlayerProfile persistence, bestiary progression, achievement unlock/progress, statistics tracking, ProfileManager singleton |

## Final Stats

- **SPM tests**: 606 (0 failures, 0 skips)
- **PackEditorKit tests**: 96 (0 failures)
- **Total tests**: 702+
- **Gate tests**: 98 across 9 files
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
- Epic 13: `Docs/plans/2026-01-31-post-game-system-design.md` (plan file)
- Epic 14: `Docs/plans/2026-01-31-encounter-completion-design.md`

## Milestone: PackEditor v2.3.0

- PackEditorKit extracted as standalone SPM package (96 tests)
- Fate Deck, Resonance, EnemyIntent systems fully integrated
- Total test coverage: 606 SPM + 96 PackEditorKit = 702+ tests

## Post-Epic: Tech Debt Closure (2026-02-03)

**F1) Legacy Adapters — CLOSED**
- WorldMapView uses pure Engine-First architecture
- No legacy init/branches/comments remain
- Gate test: `testNoLegacyInitializationInViews()` passes

**F2) AssetRegistry Safety — CLOSED**
- 3-level fallback chain: primary asset → fallback asset → SF Symbol
- No direct `UIImage(named:)` in Views/ViewModels
- Gate tests: `testMissingAssetHandling_returnsPlaceholder()`, `testAssetRegistry_returnsFallbackForMissingAssets()`, `testNoDirectUIImageNamedInViewsAndViewModels()` pass

**All technical debt from AUDIT_FIXLIST.md is now resolved.**

## Post-Epic: Binary Pack v2 (2026-02-03)

**B2) Binary Pack v2 with SHA256 Checksum — COMPLETE**

Implemented full binary pack infrastructure with integrity verification:

1. **Pack Format v2** (42-byte header):
   - Magic: "TWPK" (4 bytes)
   - Version: 2 (little-endian)
   - Original size: 4 bytes
   - SHA256 checksum: 32 bytes (of compressed data)
   - Payload: zlib compressed JSON

2. **CLI Commands**:
   - `pack-compiler compile <dir> <file.pack>` — JSON → binary
   - `pack-compiler decompile <file.pack> <dir>` — binary → JSON
   - `pack-compiler validate <dir>` — validate pack
   - `pack-compiler info <file.pack>` — show format info

3. **Features**:
   - SHA256 integrity verification at load time
   - Backward compatible (reads v1 and v2)
   - Decompile roundtrip (pack → JSON → pack)
   - Quick header inspection via `getFileInfo()`

4. **New Tests** (22 total):
   - BinaryPackV2Tests: 10 tests (format, checksum, corruption detection)
   - PackDecompilerTests: 12 tests (manifest, structure, roundtrip)

**Files modified/created**:
- `BinaryPack.swift` — v2 format with CryptoKit SHA256
- `PackDecompiler.swift` — new file for pack → JSON
- `main.swift` — added decompile command
- `BinaryPackV2Tests.swift` — new test file
- `PackDecompilerTests.swift` — new test file
