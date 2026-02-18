# Disposition Combat Test Model (Phase 3)

**Scope:** Комплексная тестовая модель Phase 3 — Disposition Combat.
**Status:** v5.3 — sacrifice cost model finalized (card.cost based), auditor rounds 1-3 complete.
**Policy sync:** CLAUDE.md v4.1, QUALITY_CONTROL_MODEL.md §2a, ENCOUNTER_TEST_MODEL.md
**Design ref:** [`docs/plans/2026-02-18-disposition-combat-design.md`](../../docs/plans/2026-02-18-disposition-combat-design.md) (v2.5, SoT)
**Last updated:** 2026-02-18

---

## 1. Организация файлов

Тесты разделены на два корня по принципу зависимостей:
- **Engine gates** — pure logic, без SpriteKit/SwiftUI → SPM engine tests
- **App gates** — требуют SpriteKit/View типы → Xcode app tests

```
Packages/TwilightEngine/Tests/
├── GateTests/
│   ├── DispositionMechanicsGateTests.swift     (9 тестов)
│   ├── MomentumGateTests.swift                 (5 тестов)
│   ├── EnergyGateTests.swift                   (6 тестов)   ← NEW
│   ├── FateKeywordGateTests.swift              (13 тестов)
│   ├── EnemyModeGateTests.swift                (12 тестов)
│   ├── EnemyActionGateTests.swift              (5 тестов)   ← NEW
│   ├── SystemicAsymmetryGateTests.swift        (4 тестов)
│   └── DispositionStressTests.swift            (5 тестов)
├── LayerTests/
│   ├── DispositionCombatSimulationTests.swift   (unit-тесты фасада)
│   ├── DispositionCombatCalculatorTests.swift   (unit-тесты формулы)
│   ├── EnemyAITests.swift                       (unit-тесты AI mode selection)
│   └── AffinityMatrixTests.swift                (unit-тесты стартовой disposition)
└── IntegrationTests/
    ├── DispositionIntegrationTests.swift        (end-to-end сценарии)
    └── CombatSimulationAgentTests.swift         (5 агентов × метрики)

CardSampleGameTests/
├── GateTests/
│   ├── DispositionCardPlayGateTests.swift       (5 тестов)
│   ├── DispositionArchBoundaryGateTests.swift   (5 тестов)
│   └── DispositionSceneGateTests.swift          (4 тестов)
└── Views/
    └── DispositionCombatViewTests.swift         (UI snapshot tests)
```

**Итого:** 68 gate-тестов + 5 stress + layer + integration + simulation.

---

## 2. Инварианты (INV-DC-xxx)

Каждый инвариант имеет уникальный ID формата `INV-DC-{NNN}`.

### 2.1 Disposition Track

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-001 | **Disposition Range** | disposition ∈ [-100, +100], clamped | disposition выходит за пределы |
| INV-DC-002 | **Hard Cap** | effective_power ≤ 25 при любой комбинации модификаторов | effective_power > 25 |
| INV-DC-003 | **Destroy Outcome** | disposition = -100 → outcome = .destroyed | Неверный outcome при -100 |
| INV-DC-004 | **Subjugate Outcome** | disposition = +100 → outcome = .subjugated | Неверный outcome при +100 |
| INV-DC-005 | **Determinism** | один seed → идентичный результат (100 прогонов) | Расхождение при повторном запуске |
| INV-DC-006 | **Start Position** | initialDisposition = affinityMatrix[heroWorld][enemyType] + situationModifier | Стартовая позиция не соответствует матрице |
| INV-DC-044 | **Situation Modifier** | situationModifier корректно учитывает предыдущие взаимодействия, мировые флаги, квестовый контекст | situationModifier игнорируется или не влияет на стартовую позицию |

### 2.2 Momentum

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-007 | **Streak Reset** | смена типа действия → streakCount = 1 | streak не сброшен |
| INV-DC-008 | **Streak Persist** | одинаковый тип через ходы → streak растёт | streak сбрасывается между ходами |
| INV-DC-009 | **Streak Bonus** | streak_bonus = max(0, streakCount - 1) | Неверный бонус |
| INV-DC-010 | **Threat Bonus** | lastAction=strike → текущий influence → +2 | threat_bonus отсутствует |
| INV-DC-011 | **Switch Penalty** | streak≥3 + switch → penalty = max(0, streakCount-2) | Неверный штраф или отсутствие |

### 2.3 Card Play

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-012 | **Strike Direction** | Strike → disposition уменьшается | disposition не уменьшается |
| INV-DC-013 | **Influence Direction** | Influence → disposition увеличивается | disposition не увеличивается |
| INV-DC-014 | **Sacrifice Limit** | максимум 1 sacrifice за ход | Второй sacrifice проходит |
| INV-DC-015 | **Sacrifice Exhaust** | sacrifice → карта exhaust навсегда | Карта возвращается в колоду |
| INV-DC-016 | **Sacrifice Enemy Buff** | sacrifice → враг +1 к следующему действию | Buff отсутствует |
| INV-DC-045 | **Energy Deduction** | каждая карта стоит `cost` энергии; после розыгрыша energy -= cost | energy не списывается |
| INV-DC-046 | **Insufficient Energy** | card.cost > currentEnergy → карта отклонена, остаётся в руке | Карта сыграна без энергии |
| INV-DC-047 | **Auto Turn-End** | energy = 0 → ход завершается автоматически | Игрок продолжает играть при 0 энергии |
| INV-DC-048 | **Energy Reset** | начало каждого хода: energy = N (определяется колодой/прогрессией) | energy не восстанавливается |

### 2.4 Fate Keywords

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-017 | **Surge Base Only** | Surge: base_power × 1.5, не умножает streak/threat | Surge умножает bonus'ы |
| INV-DC-018 | **Echo Block After Sacrifice** | Echo не срабатывает после Sacrifice | Echo срабатывает после Sacrifice |
| INV-DC-019 | **Echo Free Copy** | Echo → повтор с 0 energy, тот же fate_modifier | Echo стоит энергию или тянет новую Fate |
| INV-DC-020 | **Echo Continues Streak** | Echo продолжает streak | Echo сбрасывает streak |
| INV-DC-021 | **Echo No Fate Draw** | Echo не тянет новую Fate-карту | Echo тянет новую карту |
| INV-DC-022 | **Focus Ignores Defend** | Focus при disposition < -30 → ignore enemy Defend | Defend не игнорируется |
| INV-DC-023 | **Ward Cancels Backlash** | Ward → отменяет resonance backlash | Backlash не отменён |
| INV-DC-024 | **Shadow Increases Penalty** | Shadow при disposition < -30 → switch_penalty += 2 | Penalty не увеличен |
| INV-DC-025 | **Fate Deck Reshuffle** | пустая deck → reshuffle, бой продолжается | Crash или остановка при пустой deck |
| INV-DC-026 | **Fate Deck Determinism** | один seed → идентичный порядок fate cards | Разный порядок при том же seed |
| INV-DC-049 | **Focus Ignores Provoke** | Focus при disposition > +30 → ignore enemy Provoke | Provoke не игнорируется при положительной disposition |
| INV-DC-050 | **Shadow Disables Defend** | Shadow при disposition > +30 → враг теряет Defend на следующий ход | Defend не отключается при положительной disposition |
| INV-DC-051 | **Echo After Strike/Influence** | Echo срабатывает нормально после Strike или Influence | Echo не срабатывает после валидного действия |

### 2.5 Enemy Modes

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-027 | **Survival Threshold** | disposition ≤ -(65 + seed_hash % 11) → SURVIVAL | Режим не активирован или неверный порог |
| INV-DC-028 | **Desperation Threshold** | disposition ≥ (65 + seed_hash % 11) → DESPERATION | Режим не активирован или неверный порог |
| INV-DC-029 | **Threshold Determinism** | один seed → идентичные пороги | Пороги отличаются при том же seed |
| INV-DC-030 | **Hysteresis** | режим держится минимум 1 ход после выхода за порог | Мгновенное переключение обратно |
| INV-DC-031 | **Weakened Trigger** | ±30 swing за ход → WEAKENED | WEAKENED не активирован |
| INV-DC-032 | **Weakened Selection** | WEAKENED → выбирается слабейшее действие (min weight); при tie → первое по порядку в deck definition (deterministic) | Выбрано не минимальное по weight, или tie-break нестабилен |
| INV-DC-033 | **Rage Effect** | Rage: ATK ×2, disposition += 5 | Неверный урон или shift |
| INV-DC-034 | **Plea Effect** | Plea: disposition +10, Strike после Plea → -5 HP герою | Отсутствие shift или backlash |
| INV-DC-052 | **Survival Player Bonus** | враг в Survival → каждый Strike игрока получает +3 бонус | Бонус отсутствует в Survival mode |
| INV-DC-053 | **Desperation ATK Double** | враг в Desperation → ATK ×2 | ATK не удвоен в Desperation |
| INV-DC-054 | **Desperation Defend Disabled** | враг в Desperation → Defend недоступен (не выбирается AI) | Defend используется в Desperation |
| INV-DC-055 | **Desperation Provoke Strengthened** | враг в Desperation → Provoke усилен (отчаянное сопротивление подчинению) | Provoke не усилен в Desperation |

### 2.6 Systemic Asymmetry

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-035 | **Vulnerability Exists** | каждый тип врага уязвим к ≥1 типу действия | Нет уязвимостей |
| INV-DC-036 | **Resistance Exists** | каждый тип врага резистентен к ≥1 типу действия | Нет резистенций |
| INV-DC-037 | **Resonance Changes Vulnerability** | одна уязвимость отличается в Nav/Yav/Prav | Идентичные уязвимости во всех зонах |
| INV-DC-038 | **No Absolute Vulnerability** | ни один враг не уязвим к одному типу одинаково во всех зонах | Абсолютная уязвимость найдена |

### 2.7 Architecture Boundary

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-039 | **Engine Owns Disposition** | App/Views не мутируют disposition напрямую | Прямая мутация из App/Views |
| INV-DC-040 | **Engine Owns Fate Draw** | fate draw только внутри engine action (engine RNG) | Fate draw из App-слоя |
| INV-DC-041 | **Save/Restore Disposition** | save/load сохраняет disposition + streak + enemyMode | Потеря состояния при save/restore |
| INV-DC-042 | **Arena Isolation** | arena не коммитит результат в world-engine state (resonance, enemyStates, flags); локальный arena state (RNG cursor, stats) может меняться | Arena коммитит resonance/enemyStates/flags в world state |
| INV-DC-043 | **Defeat Changes World** | поражение меняет resonance / enemy state / narrative | Поражение не меняет мир |

### 2.8 Enemy Actions (Base Effects)

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-056 | **Attack Effect** | enemy Attack → hero HP уменьшается на ATK value | HP не уменьшается |
| INV-DC-057 | **Defend Effect** | enemy Defend → следующий Strike игрока получает -N к effective_power | Strike не ослаблен после Defend |
| INV-DC-058 | **Provoke Effect** | enemy Provoke → Influence в этом ходу получает штраф | Influence не штрафуется после Provoke |
| INV-DC-059 | **Adapt Effect** | enemy Adapt при streak ≥ 3 → soft-block: penalty = `max(3, streak_bonus)` к effective_power streak-типа. Действие разрешено, но ослаблено | Penalty не применён, или hard block |
| INV-DC-060 | **Enemy Reads Momentum** | streak ≥ 3 → враг переходит к counter-действиям (Defend+Adapt при strike streak, Provoke при influence streak) | Враг не реагирует на streak |

### 2.9 Resonance-Sacrifice Interaction

| ID | Инвариант | Проверка | Критерий FAIL |
|----|-----------|----------|---------------|
| INV-DC-061 | **Nav Sacrifice Discount** | Sacrifice в Навь стоит card.cost - 1 энергии (вместо card.cost); эффект +1 energy тот же | Nav discount не применяется |
| INV-DC-062 | **Prav Sacrifice Risk** | Sacrifice в зоне Правь может exhaust 1 дополнительную случайную карту | Дополнительный exhaust не происходит в Правь |

---

## 3. Gate-тесты — спецификации

### 3.1 DispositionMechanicsGateTests (engine) — 9 тестов

**Setup:**
```swift
let sim = DispositionCombatSimulation.create(
    enemyDefinition: TestEnemies.bandit,
    heroDefinition: TestHeroes.yavHero,
    resonanceZone: .yav,
    seed: 42
)
```

**INV-DC-001: testDispositionRange_clamped**
```
GIVEN: disposition = -95
WHEN:  strike с effective_power = 10
THEN:  disposition = -100 (clamped, не -105)

GIVEN: disposition = +95
WHEN:  influence с effective_power = 10
THEN:  disposition = +100 (clamped, не +105)
```

**INV-DC-002: testEffectivePower_hardCap25**
```
GIVEN: карта с base_power = 20
  AND: streakCount = 5 (streak_bonus = 4)
  AND: threat_bonus = 2
  AND: fate keyword = .surge (+50% base = 30)
WHEN:  strike
THEN:  effective_power = 25 (capped)
  AND: disposition сдвинулась ровно на 25, не больше
```

**INV-DC-003: testDestroyOutcome**
```
GIVEN: disposition = -95
WHEN:  strike с effective_power достаточным для -100
THEN:  outcome = .victory(.destroyed)
  AND: combatResult.resonanceDelta < 0 (сдвиг к Нави)
```

**INV-DC-004: testSubjugateOutcome**
```
GIVEN: disposition = +95
WHEN:  influence с effective_power достаточным для +100
THEN:  outcome = .victory(.subjugated)
  AND: combatResult.resonanceDelta > 0 (сдвиг к Прави)
```

**INV-DC-005: testDispositionDeterminism**
```
FOR seed IN [42, 100, 999, 0, UInt64.max]:
  GIVEN: 100 прогонов одного боя с одним seed
  THEN:  все 100 результатов идентичны (Equatable)
```

**INV-DC-006: testAffinityMatrix_startDisposition**
```
GIVEN: hero.world = .nav, enemy.type = "нечисть"
THEN:  sim.disposition = +30 (из affinityMatrix)

GIVEN: hero.world = .prav, enemy.type = "нечисть"
THEN:  sim.disposition = -40

GIVEN: hero.world = .yav, enemy.type = "человек"
THEN:  sim.disposition = +20
```

**testSurge_onlyAffectsBasePower**
```
GIVEN: карта с base_power = 6
  AND: streak_bonus = 3, threat_bonus = 2
  AND: fate keyword = .surge
WHEN:  вычислить effective_power
THEN:  surged_base = 6 * 3 / 2 = 9
  AND: raw_power = 9 + 3 + 2 + fate_modifier (НЕ (6+3+2) * 1.5)
```

**testResonanceZone_modifiesEffectiveness**
```
GIVEN: zone = .nav
WHEN:  strike с base_power = 5
THEN:  effective_power включает +2 бонус (Nav strike bonus)
  AND: enemy ATK получает +1 (Nav enemy bonus)

GIVEN: zone = .prav
WHEN:  strike с base_power = 5
THEN:  hero теряет 1 HP (backlash)
  AND: influence получает +2 бонус
```

**INV-DC-044: testAffinityMatrix_situationModifier**
```
GIVEN: hero.world = .yav, enemy.type = "нечисть"
  AND: worldFlags содержат "previous_encounter_friendly" → situationModifier = +15
WHEN:  создать CombatSimulation
THEN:  sim.disposition = affinityMatrix[.yav]["нечисть"] + 15 = 0 + 15 = +15

GIVEN: hero.world = .nav, enemy.type = "бандит"
  AND: situationModifier = 0 (нет контекста)
WHEN:  создать CombatSimulation
THEN:  sim.disposition = affinityMatrix[.nav]["человек"] + 0 = -10
```

### 3.2 MomentumGateTests (engine) — 5 тестов

**INV-DC-007: testMomentumStreak_resetsOnSwitch**
```
GIVEN: 3 × strike → streakCount = 3
WHEN:  influence
THEN:  streakType = .influence, streakCount = 1
```

**INV-DC-008: testMomentumStreak_preservedAcrossTurns**
```
GIVEN: ход 1: strike → endTurn → resolveEnemyTurn
WHEN:  ход 2: strike
THEN:  streakCount = 2 (не сброшен между ходами)
```

**INV-DC-009: testStreakBonus_formula**
```
FOR streakCount IN [1, 2, 3, 5]:
  streak_bonus = max(0, streakCount - 1)
  // streak=1 → bonus=0, streak=2 → bonus=1, streak=3 → bonus=2, streak=5 → bonus=4
```

**INV-DC-010: testThreatBonus_afterStrike**
```
GIVEN: lastAction = .strike
WHEN:  influence
THEN:  threat_bonus = 2 в формуле effective_power
  AND: (без threat): strike → strike → threat_bonus = 0
```

**INV-DC-011: testSwitchPenalty_longStreak**
```
GIVEN: streakCount = 3, streakType = .strike
WHEN:  influence (switch)
THEN:  switch_penalty = max(0, 3 - 2) = 1

GIVEN: streakCount = 5, streakType = .strike
WHEN:  influence (switch)
THEN:  switch_penalty = max(0, 5 - 2) = 3

GIVEN: streakCount = 2, streakType = .strike
WHEN:  influence (switch)
THEN:  switch_penalty = 0 (порог не достигнут)
```

### 3.3 DispositionCardPlayGateTests (app) — 5 тестов

**INV-DC-012: testStrikeReducesDisposition**
```
GIVEN: disposition = 0, карта с strikePower = 5
WHEN:  playCardAsStrike(cardId: card.id, targetId: enemy.id)
THEN:  disposition < 0
  AND: карта в discardPile
```

**INV-DC-013: testInfluenceIncreasesDisposition**
```
GIVEN: disposition = 0, карта с influencePower = 5
WHEN:  playCardAsInfluence(cardId: card.id)
THEN:  disposition > 0
  AND: карта в discardPile
```

**INV-DC-014: testSacrifice_limitOnePerTurn**
```
GIVEN: рука [card_a, card_b]
WHEN:  playCardAsSacrifice(card_a) → success
  AND: playCardAsSacrifice(card_b)
THEN:  второй sacrifice → error / false
  AND: card_b всё ещё в руке
```

**INV-DC-015: testSacrifice_exhaustsPermanently**
```
GIVEN: рука [card_a], deckSize = D
WHEN:  playCardAsSacrifice(card_a)
THEN:  card_a не в hand, не в discardPile, не в drawPile
  AND: общий размер колоды (draw + discard + hand + exhaust) не изменился
  AND: exhaustPile содержит card_a
```

**INV-DC-016: testSacrifice_strengthensEnemy**
```
GIVEN: enemy.nextActionValue = V
WHEN:  playCardAsSacrifice(card_a)
THEN:  enemy.buffedAmount >= 1
  // Враг получает +1 к следующему действию
```

### 3.4 FateKeywordGateTests (engine) — 13 тестов

**INV-DC-017: testSurge_appliedToBasePowerOnly**
```
GIVEN: card.strikePower = 6, fate.keyword = .surge
WHEN:  вычислить surged_base
THEN:  surged_base = 6 * 3 / 2 = 9
  AND: streak_bonus, threat_bonus НЕ умножены
```

**INV-DC-018: testEcho_blockedAfterSacrifice**
```
GIVEN: lastAction = .sacrifice, fate.keyword = .echo
WHEN:  resolve fate keyword
THEN:  echo не срабатывает (no free copy)
```

**INV-DC-019: testEcho_freeCopy**
```
GIVEN: lastAction = .strike, fate.keyword = .echo
WHEN:  resolve echo
THEN:  повтор strike с 0 energy cost
  AND: тот же fate_modifier (не тянет новую)
```

**INV-DC-020: testEcho_continuesStreak**
```
GIVEN: streakType = .strike, streakCount = 2
WHEN:  echo срабатывает (повтор strike)
THEN:  streakCount = 3 (продолжает streak)
```

**INV-DC-021: testEcho_noNewFateDraw**
```
GIVEN: fateDeck.count = N, fate.keyword = .echo
WHEN:  echo срабатывает
THEN:  fateDeck.count = N (не тянули новую карту)
```

**INV-DC-022: testFocus_ignoresDefendAtNegative**
```
GIVEN: disposition = -40, enemy intent = .defend, fate.keyword = .focus
WHEN:  strike
THEN:  defend НЕ уменьшает effective_power

GIVEN: disposition = 0, enemy intent = .defend, fate.keyword = .focus
WHEN:  strike
THEN:  defend работает нормально (disposition > -30 → focus = просто +1)
```

**INV-DC-023: testWard_cancelsBacklash**
```
GIVEN: resonanceZone = .prav, fate.keyword = .ward
WHEN:  strike (в Прави strike → backlash -1 HP)
THEN:  heroHP не изменился (backlash отменён)
```

**INV-DC-024: testShadow_increasesPenaltyAtNegative**
```
GIVEN: disposition = -40, streakCount = 3, fate.keyword = .shadow
WHEN:  switch action
THEN:  switch_penalty = max(0, 3-2) + 2 = 3 (shadow добавляет +2)
```

**INV-DC-025: testFateDeck_reshuffleWhenEmpty**
```
GIVEN: fateDeck.drawPile = [] (пустая)
WHEN:  strike (тянет fate card)
THEN:  reshuffle happened
  AND: бой продолжается нормально
  AND: drawPile.count > 0
```

**INV-DC-026: testFateDeck_deterministicShuffle**
```
FOR seed IN [42, 100, 999]:
  GIVEN: два боя с одним seed
  WHEN:  тянуть все fate cards по порядку
  THEN:  оба боя выдают идентичную последовательность
```

**INV-DC-049: testFocus_ignoresProvokeAtPositive**
```
GIVEN: disposition = +40, enemy intent = .provoke, fate.keyword = .focus
WHEN:  influence
THEN:  provoke penalty НЕ применяется (Focus при disposition > +30 → ignore Provoke)

GIVEN: disposition = 0, enemy intent = .provoke, fate.keyword = .focus
WHEN:  influence
THEN:  provoke penalty применяется нормально (disposition < +30 → focus = просто +1)
```

**INV-DC-050: testShadow_disablesDefendAtPositive**
```
GIVEN: disposition = +40, fate.keyword = .shadow
WHEN:  resolve fate keyword
THEN:  враг теряет Defend на следующий ход (Shadow при disposition > +30)

GIVEN: disposition = 0, fate.keyword = .shadow
WHEN:  resolve fate keyword
THEN:  Shadow даёт -1 к текущему действию (базовый эффект, Defend не отключается)
```

**INV-DC-051: testEcho_worksAfterStrikeOrInfluence**
```
GIVEN: lastAction = .strike, fate.keyword = .echo
WHEN:  resolve echo
THEN:  echo срабатывает → повтор strike с 0 energy cost

GIVEN: lastAction = .influence, fate.keyword = .echo
WHEN:  resolve echo
THEN:  echo срабатывает → повтор influence с 0 energy cost

// Контраст с INV-DC-018: echo NOT after sacrifice
```

### 3.5 EnemyModeGateTests (engine) — 12 тестов

**INV-DC-027: testEnemyMode_survivalAtDynamicThreshold**
```
GIVEN: seed → survivalThreshold = -70
WHEN:  disposition снижается до -70
THEN:  enemyMode = .survival
  AND: enemy выбирает Attack/Rage действия
```

**INV-DC-028: testEnemyMode_desperationAtDynamicThreshold**
```
GIVEN: seed → desperationThreshold = +72
WHEN:  disposition растёт до +72
THEN:  enemyMode = .desperation
  AND: enemy выбирает Provoke/Plea действия
```

**INV-DC-029: testEnemyMode_thresholdDeterministic**
```
FOR seed IN [42, 100, 999, 0]:
  GIVEN: два боя с одним seed
  THEN:  survivalThreshold идентичен
  AND:   desperationThreshold идентичен
  AND:   survivalThreshold ∈ [-75, -65]
  AND:   desperationThreshold ∈ [+65, +75]
```

**INV-DC-030: testEnemyMode_hysteresis**
```
GIVEN: disposition = -72 (в survival), survivalThreshold = -70
WHEN:  influence → disposition = -60 (выше порога)
THEN:  enemyMode всё ещё .survival (hysteresis 1 ход)

WHEN:  следующий ход: disposition остаётся -60
THEN:  enemyMode = .normal (hysteresis закончился)
```

**INV-DC-031: testEnemyMode_weakenedOnSwing**
```
GIVEN: disposition = 0 в начале хода
WHEN:  strike → disposition = -35 (swing = 35 > 30)
THEN:  enemyMode = .weakened

GIVEN: disposition = 0 в начале хода
WHEN:  strike → disposition = -20 (swing = 20 < 30)
THEN:  enemyMode ≠ .weakened
```

**INV-DC-032: testEnemyMode_weakenedNotRandom**
```
GIVEN: enemyMode = .weakened, enemy deck с actions [ATK:5/w:3, DEF:2/w:1, ATK:3/w:2]
WHEN:  resolveEnemyTurn()
THEN:  выбрано действие с наименьшим weight (DEF:2/w:1)
  AND: НЕ случайный выбор из пула

// Tie-break test:
GIVEN: enemyMode = .weakened, enemy deck с actions [ATK:3/w:1, DEF:3/w:1, PRV:3/w:1]
WHEN:  resolveEnemyTurn()
THEN:  выбрано ATK:3 (первое по порядку в deck definition)
  AND: результат стабилен при повторных вызовах (deterministic tie-break)
  // Правило: при равном weight → порядок в deck definition (index 0 первый)
```

**INV-DC-033: testEnemyRage_doubleATKplusDispositionShift**
```
GIVEN: enemyMode = .survival, enemy ATK = 4
WHEN:  resolveEnemyTurn() → Rage
THEN:  heroHP -= 8 (ATK × 2)
  AND: disposition += 5 (ошибка врага — сдвиг в пользу subjugate)
```

**INV-DC-034: testEnemyPlea_dispositionPlusBacklash**
```
GIVEN: enemyMode = .desperation
WHEN:  resolveEnemyTurn() → Plea
THEN:  disposition += 10

WHEN:  игрок отвечает strike после Plea
THEN:  heroHP -= 5 (backlash за жестокость)
```

**INV-DC-052: testSurvival_playerStrikeBonusPlus3**
```
GIVEN: enemyMode = .survival
WHEN:  player plays strike с base_power = 5
THEN:  effective_power включает +3 бонус (враг раскрывается в ярости)
  AND: total = base_power + streak_bonus + threat_bonus + 3 + fate_modifier (capped at 25)

GIVEN: enemyMode = .normal
WHEN:  player plays strike с base_power = 5
THEN:  effective_power НЕ включает +3 бонус
```

**INV-DC-053: testDesperation_doubleATK**
```
GIVEN: enemyMode = .desperation, enemy ATK = 4
WHEN:  resolveEnemyTurn() → Attack
THEN:  heroHP -= 8 (ATK × 2)
```

**INV-DC-054: testDesperation_defendDisabled**
```
GIVEN: enemyMode = .desperation
  AND: enemy action deck содержит Defend
WHEN:  resolveEnemyTurn()
THEN:  Defend НИКОГДА не выбирается (исключён из пула)
  AND: выбрано Provoke/Plea/Attack
```

**INV-DC-055: testDesperation_provokeStrengthened**
```
GIVEN: enemyMode = .desperation, enemy Provoke value = P
WHEN:  resolveEnemyTurn() → Provoke
THEN:  influence penalty > P (усиленный Provoke)
  // Отчаянное сопротивление подчинению
```

### 3.6 SystemicAsymmetryGateTests (engine) — 4 теста

**INV-DC-035: testSystemicAsymmetry_vulnerabilities**
```
FOR enemy IN allEnemyTypes:
  THEN: enemy.vulnerabilities содержит хотя бы один modifier > 0
  // Каждый тип врага уязвим к ≥1 типу действия
```

**INV-DC-036: testSystemicAsymmetry_resistances**
```
FOR enemy IN allEnemyTypes:
  THEN: enemy.vulnerabilities содержит хотя бы один modifier < 0
  // Каждый тип врага резистентен к ≥1 типу действия
```

**INV-DC-037: testSystemicAsymmetry_resonanceChangesVulnerability**
```
FOR enemy IN allEnemyTypes:
  LET base = enemy.vulnerabilities(zone: nil)
  LET nav  = enemy.vulnerabilities(zone: .nav)
  LET prav = enemy.vulnerabilities(zone: .prav)
  THEN: base ≠ nav OR base ≠ prav
  // Resonance меняет хотя бы одну уязвимость
```

**INV-DC-038: testSystemicAsymmetry_noAbsoluteVulnerability**
```
FOR enemy IN allEnemyTypes:
  FOR actionType IN [.strike, .influence, .sacrifice]:
    LET mods = [zone: .nav, .yav, .prav].map { enemy.modifier(actionType, zone: $0) }
    THEN: NOT (mods[0] == mods[1] AND mods[1] == mods[2] AND mods[0] > 0)
    // Ни один враг не уязвим к одному типу одинаково во всех зонах
```

### 3.7 DispositionArchBoundaryGateTests (app) — 5 тестов

**INV-DC-039: testDispositionTransaction_engineOwns**
```
SCAN: App/**, Views/**, ViewModels/**
THEN: нет прямых присваиваний disposition-полей
  AND: нет прямых вызовов CombatSimulation.disposition = ...
  // Вся мутация — через actions
```

**INV-DC-040: testFateDraw_insideEngineAction**
```
SCAN: App/**, Views/**
THEN: нет вызовов fateDeck.draw() вне engine action path
  AND: нет доступа к engine.services.rng из App-слоя
```

**INV-DC-041: testSaveRestore_dispositionState**
```
GIVEN: бой в процессе: disposition=-30, streakCount=2, enemyMode=.survival
WHEN:  save → restore → resume
THEN:  sim.disposition = -30
  AND: sim.streakCount = 2
  AND: sim.enemyMode = .survival
  AND: sim.fateDeckState идентичен
```

**INV-DC-042: testArena_doesNotCommitDisposition**
```
GIVEN: world.resonance = R, world.enemyStates = S, world.flags = F
WHEN:  arena бой завершён (destroy)
THEN:  world.resonance = R (не изменился)
  AND: world.enemyStates = S (не изменились)
  AND: world.flags = F (arena-флаги не добавлены)
  // Проверяем именно отсутствие world commit.
  // Arena может менять локальный state (simulation RNG cursor, arena stats) —
  // это допустимо и НЕ является fail condition.
```

**INV-DC-043: testDefeatChangesWorldState**
```
GIVEN: бой проигран (heroHP = 0)
THEN:  world.resonance изменился
  AND: enemy state обновлён (враг усилился)
  AND: nарративная развилка доступна
```

### 3.8 DispositionSceneGateTests (app) — 4 теста

**testRitualSceneUsesOnlyCombatSimulationAPI**
```
SCAN: RitualCombatScene.swift и дочерние
THEN: все мутации через CombatSimulation methods
  AND: нет прямого доступа к engine полям
```

**testDragDropProducesCanonicalCommands**
```
GIVEN: drag карты → enemy zone
THEN:  вызван sim.playCardAsStrike(cardId:targetId:)

GIVEN: drag карты → altar zone
THEN:  вызван sim.playCardAsInfluence(cardId:)

GIVEN: drag карты → bonfire zone
THEN:  вызван sim.playCardAsSacrifice(cardId:)
```

**testResonanceAtmosphereIsReadOnly**
```
SCAN: ResonanceAtmosphereController.swift
THEN: нет вызовов mutation-методов CombatSimulation
  AND: только read-access к resonanceZone, disposition, enemyMode
```

**testEnemyModeTransitionAnimated**
```
GIVEN: enemyMode переключается normal → survival
THEN:  animation event добавлен в queue
  AND: длительность ≥ 0.3s
  AND: aura change видима
```

### 3.9 EnergyGateTests (engine) — 6 тестов

**Setup:**
```swift
let sim = DispositionCombatSimulation.create(
    enemyDefinition: TestEnemies.bandit,
    heroDefinition: TestHeroes.yavHero,
    resonanceZone: .yav,
    seed: 42,
    startingEnergy: 3
)
```

**INV-DC-045: testEnergyDeduction**
```
GIVEN: energy = 3, card.cost = 2
WHEN:  playCardAsStrike(card)
THEN:  energy = 1 (3 - 2)
  AND: карта сыграна успешно
```

**INV-DC-046: testInsufficientEnergyRejected**
```
GIVEN: energy = 1, card.cost = 2
WHEN:  playCardAsStrike(card)
THEN:  error / false (карта отклонена)
  AND: energy = 1 (не изменилась)
  AND: card всё ещё в руке
  AND: disposition не изменилась
```

**INV-DC-047: testAutoTurnEndAtZeroEnergy**
```
GIVEN: energy = 2, card.cost = 2
WHEN:  playCardAsStrike(card)
THEN:  energy = 0
  AND: ход автоматически завершён (или End Turn доступен как единственное действие)
  AND: играть ещё карты невозможно
```

**INV-DC-048: testEnergyResetEachTurn**
```
GIVEN: startingEnergy = 3
WHEN:  ход 1: play cards → energy = 0 → endTurn → resolveEnemyTurn
  AND: ход 2 начинается
THEN:  energy = 3 (полный сброс)
```

**INV-DC-061: testNavSacrificeDiscount**
```
// Sacrifice cost model (из SoT §4.3 + §6.2):
// Sacrifice стоит card.cost энергии (как любой card play).
// Эффект sacrifice: +1 энергия обратно.
// "На 1 энергию дешевле" в Навь = cost - 1.
// Net: Yav = -(card.cost) + 1, Nav = -(card.cost - 1) + 1

GIVEN: resonanceZone = .yav, energy = 3, card.cost = 2
WHEN:  playCardAsSacrifice(card)
THEN:  energy = 3 - 2 + 1 = 2 (net: -1)
  AND: card в exhaustPile

GIVEN: resonanceZone = .nav, energy = 3, card.cost = 2
WHEN:  playCardAsSacrifice(card)
THEN:  energy = 3 - 1 + 1 = 3 (net: 0, break even — тьма питается жертвой)
  AND: card в exhaustPile

// ⚠️ BALANCE HOTSPOT: Nav sacrifice break-even — следить в симуляции,
// не становится ли Nav sacrifice opener доминантным (особенно с героями Nav).
```

**INV-DC-062: testPravSacrificeRisk**
```
GIVEN: resonanceZone = .prav, hand = [cardA, cardB, cardC]
WHEN:  playCardAsSacrifice(cardA)
THEN:  cardA в exhaustPile
  AND: с вероятностью (определяемой RNG) ещё 1 случайная карта exhaust
  AND: если дополнительный exhaust произошёл — hand.count = 1, exhaustPile.count = 2

GIVEN: resonanceZone = .yav, hand = [cardA, cardB, cardC]
WHEN:  playCardAsSacrifice(cardA)
THEN:  только cardA в exhaustPile (нет доп. exhaust)
```

### 3.10 EnemyActionGateTests (engine) — 5 тестов

**Setup:**
```swift
let sim = DispositionCombatSimulation.create(
    enemyDefinition: TestEnemies.bandit,  // deck: [ATK:5, DEF:3, PRV:4, ADP:2]
    heroDefinition: TestHeroes.yavHero,
    resonanceZone: .yav,
    seed: 42
)
```

**INV-DC-056: testAttack_reducesHeroHP**
```
GIVEN: heroHP = 20, enemy выбирает Attack(value: 5)
WHEN:  resolveEnemyTurn()
THEN:  heroHP = 15 (20 - 5)
```

**INV-DC-057: testDefend_reducesNextStrike**
```
GIVEN: enemy выбирает Defend(value: 3)
WHEN:  resolveEnemyTurn()
  AND: player plays strike с effective_power = 8
THEN:  actual disposition shift = 8 - 3 = 5 (Defend поглощает часть)
  AND: после одного strike Defend эффект заканчивается
```

**INV-DC-058: testProvoke_penalizesInfluence**
```
GIVEN: enemy выбирает Provoke(value: 4)
WHEN:  resolveEnemyTurn()
  AND: player plays influence с effective_power = 7
THEN:  actual disposition shift = 7 - 4 = 3 (Provoke штрафует Influence)
```

**INV-DC-059: testAdapt_blocksStreakType**
```
GIVEN: streakType = .strike, streakCount = 3, base_power = 8
  AND: enemy выбирает Adapt
WHEN:  resolveEnemyTurn()
  AND: player пытается strike
THEN:  adapt_penalty = max(3, streak_bonus) = max(3, 2) = 3
  AND: effective_power уменьшен на 3
  AND: действие выполняется (карта в discard, energy списана)
  AND: UI drag-drop НЕ заблокирован

GIVEN: streakType = .strike, streakCount = 5, base_power = 8
  AND: enemy выбирает Adapt
WHEN:  player пытается strike
THEN:  adapt_penalty = max(3, 4) = 4 (streak_bonus = max(0, 5-1) = 4)
  AND: effective_power уменьшен на 4 (масштабируется с длиной streak)
```

// ⚠️ BALANCE HOTSPOT: Adapt не должен стать "AI hard counter machine".
// В симуляции: % ходов с активным Adapt и win rate Adapt-heavy enemies.
// Если Adapt dominates → снизить частоту в AI weights.

**INV-DC-060: testEnemyReadsMomentum_countersStreak**
```
GIVEN: streakType = .strike, streakCount = 3
WHEN:  resolveEnemyTurn() (AI decision в NORMAL mode)
THEN:  выбрано Adapt(50%) или Defend(50%) — контрит strike-streak

GIVEN: streakType = .influence, streakCount = 3
WHEN:  resolveEnemyTurn() (AI decision в NORMAL mode)
THEN:  выбрано Provoke — контрит influence-streak

GIVEN: streakCount < 3
WHEN:  resolveEnemyTurn() (AI decision)
THEN:  Adapt НЕ выбирается (порог не достигнут)
```

---

## 4. Stress-тесты (exploit-сценарии) — 5 тестов

Каждый сценарий проверяет конкретную цепочку, которая может стать exploit'ом.

### 4.1 testStress_sacrificeCycle
```
SCENARIO: sacrifice → strike → enemy rage → strike +3 → weaken trigger
VERIFY:
  - disposition не уходит за [-100, +100]
  - weaken не даёт бесконечный loop
  - после 10 ходов бой завершается или стабилизируется
```

### 4.2 testStress_echoSnowball
```
SCENARIO: strike ×3 (streak=3) → echo → surge
VERIFY:
  - effective_power каждого хода ≤ 25
  - суммарный disposition shift за ход ≤ 40 (action + echo)
  - echo не создаёт каскад (один echo = один повтор)
```

### 4.3 testStress_thresholdDancing
```
SCENARIO: держать disposition на 64–66, не триггеря mode
VERIFY:
  - dynamic threshold (65-75) делает это ненадёжным
  - для 100 seeds: (max_threshold - min_threshold) ≥ 5
    // разброс между наименьшим и наибольшим порогом ≥ 5 единиц
    // формула: threshold = 65 + seed_hash % 11 → теоретический range = 10
  - невозможно точно предсказать порог для конкретного seed без знания hash

// ⚠️ BALANCE HOTSPOT: если hash function skewed, реальный range может быть < 10.
// В симуляции построить гистограмму threshold distribution для 10000 seeds.
// Если distribution кластеризуется (>50% в 3 значениях) → пересмотреть hash function.
```

### 4.4 testStress_influenceLock
```
SCENARIO: influence ×5 → enemy provoke → sacrifice → influence
VERIFY:
  - sacrifice + provoke достаточно наказывают
  - disposition не растёт линейно (penalty + provoke замедляют)
  - после 10 ходов чистого influence: average effective_power < 15
```

### 4.5 testStress_allSacrificeOpener
```
SCENARIO: sacrifice на ходу 1 → sacrifice на ходу 2 → sacrifice на ходу 3
  (по одному sacrifice за ход = 3 хода, 3 sacrifice)
VERIFY:
  - лимит 1/ход соблюдён (только 1 sacrifice за ход)
  - за 3 хода: 3 sacrifice прошли успешно
  - враг накопил buff (+1 за каждый sacrifice = +3 к действиям)
  - рука уменьшена на 3 карты (все в exhaustPile)
  - героHP пострадал от enemy turns (враг бил 3 хода подряд, с усилением)
  - disposition двигалась только от enemy actions (sacrifice не двигает шкалу)
```

---

## 5. Integration Tests — End-to-End сценарии

### 5.1 DispositionIntegrationTests

| Тест | Сценарий | Ожидаемый результат |
|------|----------|---------------------|
| `testFullDestroyPath` | 1v1, Strike-действия до disposition=-100 | outcome = .destroyed, resonance shift < 0 |
| `testFullSubjugatePath` | 1v1, Influence-действия до disposition=+100 | outcome = .subjugated, resonance shift > 0 |
| `testMixedStrategyPath` | Strike ×3 → switch → Influence ×5 | switch_penalty применён, subjugate достигнут |
| `testSacrificeRecoveryPath` | Low HP → sacrifice → heal → strike to destroy | sacrifice exhaust, heal applied, enemy buff applied |
| `testDefeatPath` | heroHP → 0 | outcome = .defeat, world state changed |
| `testResonanceNavCombat` | Полный бой в зоне Навь | Nav modifiers применены, backlash correct |
| `testResonancePravCombat` | Полный бой в зоне Правь | Prav modifiers applied, strike backlash |
| `testEnemyModeTransitions` | Бой с проходом через все 4 режима | Все режимы активированы и deactivated по правилам |
| `testMidCombatSaveResume` | Save mid-combat → restore → complete | Результат идентичен непрерывному бою |
| `testAffinityMatrixImpact` | Один враг vs 3 героя (Nav/Yav/Prav) | Разные стартовые disposition, разная тактика |

### 5.2 CombatSnapshot Round-Trip

| Тест | Что проверяет |
|------|---------------|
| `testSnapshotContainsAllRequiredFields` | disposition, streakType, streakCount, lastActionType, sacrificeUsedThisTurn, enemyActionDeckState, enemyMode, hysteresisRemaining, thresholds, fateDeckState, lastFateKeyword, resonanceZone |
| `testSnapshotRoundTrip_encode_decode` | encode → decode → поля идентичны |
| `testSnapshotRoundTrip_resume_deterministic` | snapshot → resume → complete → результат = непрерывный бой |

---

## 6. Simulation Requirements (перед балансом)

### 6.1 Агенты

| Агент | Стратегия | Что проверяет |
|-------|-----------|---------------|
| **Random** | Случайные действия | Baseline — если >60% побед, система не требует навыка |
| **Greedy Strike** | Всегда strike | Anti-strike мета работает |
| **Greedy Influence** | Всегда influence | Anti-influence мета работает |
| **Adaptive** | Strike пока streak<3, затем influence | Наказание за переключение |
| **Sacrifice-heavy** | Sacrifice каждый ход + strike | Exploit-потенциал sacrifice |

### 6.2 Acceptance Criteria

| Параметр | Метрика | Acceptance |
|----------|---------|------------|
| Win path distribution | % побед через -100 vs +100 | Ни один путь не >70% **для каждой конкретной комбинации** hero × enemy × resonance (не в aggregate) |
| Average combat length | Ходы до завершения | 5–15 ходов |
| Action type distribution | % Strike/Influence/Sacrifice | Sacrifice <20%; Strike и Influence 30–60% каждый |
| Echo impact | % disposition shift от Echo | <30% от общего shift |
| Mode trigger frequency | Survival/Desperation/Weakened | S/D: 40–70% боёв; W: 10–30% |
| Variety across seeds | Разница исходов для 100 seeds | σ(combat length) > 2 хода |

### 6.3 Запуск

```
Матрица: 5 agents × N enemy types × 3 resonance zones × 3 hero worlds
Прогонов: 1000 боёв для каждой комбинации
Результаты: TestResults/CombatSimulation/
```

---

## 7. Traceability Matrix — Design → Test

| Design Section | Тесты | Suite |
|----------------|-------|-------|
| §3.1 Шкала | INV-DC-001, INV-DC-003, INV-DC-004 | DispositionMechanicsGateTests |
| §3.4 Affinity Matrix | INV-DC-006, INV-DC-044 | DispositionMechanicsGateTests |
| §4.2 Card Play | INV-DC-012…016 | DispositionCardPlayGateTests |
| §4.3 Энергия | INV-DC-045…048 | EnergyGateTests |
| §5.1 Momentum | INV-DC-007…011 | MomentumGateTests |
| §5.2 Resonance | testResonanceZone_modifiesEffectiveness | DispositionMechanicsGateTests |
| §5.2 Resonance × Sacrifice | INV-DC-061, INV-DC-062 | EnergyGateTests |
| §5.3 Fate Keywords | INV-DC-017…026, INV-DC-049…051 | FateKeywordGateTests |
| §6 Sacrifice | INV-DC-014…016, INV-DC-061, INV-DC-062 | DispositionCardPlayGateTests + EnergyGateTests |
| §7.2 Systemic Asymmetry | INV-DC-035…038 | SystemicAsymmetryGateTests |
| §7.3 Enemy Modes | INV-DC-027…034, INV-DC-052…055 | EnemyModeGateTests |
| §7.4 Enemy Actions | INV-DC-056…060 | EnemyActionGateTests |
| §7.5 Enemy Reads Momentum | INV-DC-060 | EnemyActionGateTests |
| §10.2 Gate Tests | Все INV-DC-* | All gate suites |
| §10.3 Stress Tests | 5 stress scenarios | DispositionStressTests |
| §10.4 Simulation | 5 agents × criteria | CombatSimulationAgentTests |
| §11.1 Engine Actions | INV-DC-039, INV-DC-040 | DispositionArchBoundaryGateTests |
| §11.3 CombatSnapshot | Snapshot round-trip | DispositionIntegrationTests |
| §11.5 Arena | INV-DC-042 | DispositionArchBoundaryGateTests |
| CLAUDE.md §1.1 | INV-DC-039, INV-DC-040 | DispositionArchBoundaryGateTests |
| CLAUDE.md §1.3 | INV-DC-005, INV-DC-026, INV-DC-029 | Determinism tests |
| CLAUDE.md §1.5 | INV-DC-042 | DispositionArchBoundaryGateTests |

---

## 8. Запуск тестов

### Engine gates (SPM)
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test \
  --package-path Packages/TwilightEngine \
  --filter "DispositionMechanicsGateTests|MomentumGateTests|EnergyGateTests|FateKeywordGateTests|EnemyModeGateTests|EnemyActionGateTests|SystemicAsymmetryGateTests|DispositionStressTests"
```

### App gates (Xcode)
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash .github/ci/run_xcodebuild.sh test \
  -scheme CardSampleGame \
  -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" \
  -only-testing:CardSampleGameTests/DispositionCardPlayGateTests \
  -only-testing:CardSampleGameTests/DispositionArchBoundaryGateTests \
  -only-testing:CardSampleGameTests/DispositionSceneGateTests
```

### Simulation (отдельный запуск)
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test \
  --package-path Packages/TwilightEngine \
  --filter "CombatSimulationAgentTests"
```

---

## 9. Priority и порядок реализации

| Priority | Suite | Блокирует | Тестов |
|----------|-------|-----------|--------|
| **P0** | DispositionMechanicsGateTests | Всё остальное | 9 |
| **P0** | MomentumGateTests | Card Play, Enemy Modes | 5 |
| **P0** | EnergyGateTests | Card Play, Integration | 6 |
| **P1** | DispositionCardPlayGateTests | Scene, Integration | 5 |
| **P1** | FateKeywordGateTests | Integration, Balance | 13 |
| **P1** | EnemyModeGateTests | Integration, Stress | 12 |
| **P1** | EnemyActionGateTests | Integration, Stress | 5 |
| **P2** | SystemicAsymmetryGateTests | Balance | 4 |
| **P2** | DispositionArchBoundaryGateTests | Release | 5 |
| **P2** | DispositionSceneGateTests | Release | 4 |
| **P3** | DispositionStressTests | Balance | 5 |
| **P3** | DispositionIntegrationTests | Release | 13 |
| **P4** | CombatSimulationAgentTests | Balance tuning | 30+ |

---

---

## 10. Known Design Doc Issues

| ID | Проблема | Решение в тестовой модели |
|----|----------|--------------------------|
| MISMATCH-1 | §10.2 `testFateKeyword_surgeDoublesMomentum` говорит "streak_bonus ×2", но §5.1 формула показывает Surge = `base_power * 3/2` (только base) | Тестовая модель следует §5.1 формуле (INV-DC-017). §10.2 требует исправления в дизайн-документе |

---

**Версия документа:** 5.3
**Дата:** 18 февраля 2026
**Статус:** Auditor rounds 1-3 complete — ready for implementation

**Changelog:**
- v5.0 → v5.1: +19 invariants, +2 suites (Energy, EnemyAction), audit gaps closed
- v5.1 → v5.2: tie-break rule, arena scope, threshold metrics, simulation granularity
- v5.2 → v5.3: sacrifice cost model finalized (`card.cost` based, not free). Nav = cost-1, Prav = extra exhaust. Adapt = soft-block formalized. SPRINT.md synced.
