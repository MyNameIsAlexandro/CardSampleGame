# Ritual Combat Test Model (Phase 3)

**Scope:** Полная тестовая модель Phase 3 — Effort, RitualCombatScene, visual combat overhaul.
**Status:** Draft v3 — P0/P1/P2 аудиторские правки (раунд 2) применены.
**Policy sync:** CLAUDE.md v4.1, QUALITY_CONTROL_MODEL.md §2a, ENCOUNTER_TEST_MODEL.md
**Design ref:** `plans/2026-02-13-ritual-combat-design.md` (v1.2), `plans/2026-02-14-ritual-combat-epics.md`
**Last updated:** 2026-02-14

---

## 1. Организация файлов

Тесты разделены на два корня по принципу зависимостей:
- **Engine gates (R0, R1)** — pure logic, без SpriteKit/SwiftUI → SPM engine tests
- **App gates (R2, R3, R6, R7, R9)** — требуют SpriteKit/View типы → Xcode app tests

```
Packages/TwilightEngine/Tests/TwilightEngineTests/
├── RitualCombatGates/
│   ├── FateDeckBalanceGateTests.swift       (R0: 5 тестов)
│   └── RitualEffortGateTests.swift          (R1: 11 тестов)
├── LayerTests/
│   └── EffortMechanicTests.swift            (R1: unit-тесты CombatSimulation)
└── IntegrationTests/
    └── RitualCombatIntegrationTests.swift   (R9: e2e scenario с ContentRegistry)

CardSampleGameTests/
├── GateTests/RitualCombatGates/
│   ├── RitualSceneGateTests.swift           (R2+R3: 6 тестов, static scan + SpriteKit)
│   ├── RitualAtmosphereGateTests.swift      (R7: 2 теста, SpriteKit controller)
│   └── RitualIntegrationGateTests.swift     (R6+R9+R10a: 8 тестов, FateReveal + Scene + Replay)
└── Unit/RitualCombat/
    ├── FateRevealTests.swift                (R6: unit-тесты FateRevealDirector)
    └── DragDropControllerTests.swift        (R3: unit-тесты DragDropController)
```

**Обоснование разделения:** SPM target `TwilightEngine` не может импортировать SpriteKit/SwiftUI.
Тесты R2/R3/R7 сканируют или инстанцируют Scene/Controller типы, которые зависят от SpriteKit.
R6 (FateRevealDirector) и R9 (integration с Scene) тоже требуют View-зависимостей.

**Правила (наследуются от ENCOUNTER_TEST_MODEL.md):**
- Gate < 2 сек per test (hard limit), без system RNG, fixtures hardcoded + fixed seeds
- Suite-level target budget: ≤ 60 сек на suite (soft — CI jitter допустим, но систематическое превышение = красный флаг)
- 1 файл = 1 компонент (не по фиче)
- Каждый файл ≤ 600 строк (CLAUDE.md §5.1)
- INV-{MODULE}-{NNN} именование для инвариантов

---

## 2. Инвентаризация изменений

### 2.1 Новые тесты (32)

| # | Тест | Suite | Epic | Тип | Что проверяет |
|---|------|-------|------|-----|---------------|
| 1 | `testMatchMultiplierFromBalancePack` | FateDeckBalanceGateTests | R0 | Gate+ | пропорциональность: два BalancePack (1.0 vs 2.0) → effect × 2; default = 1.5 (surge в combatPhysical) |
| 2 | `testSurgeSuitDistribution` | FateDeckBalanceGateTests | R0 | Gate+ | ≥1 surge-карта с suit ≠ prav |
| 3 | `testCritCardNeutralSuit` | FateDeckBalanceGateTests | R0 | Gate+ | crit card: suit = yav |
| 4 | `testStickyCardResonanceModifyCapped` | FateDeckBalanceGateTests | R0 | Gate+ | `if card.isSticky → ∀ resonanceRules: abs(modifyValue) ≤ 1` |
| 5 | `testNoStaleCardIdsInContent` | FateDeckBalanceGateTests | R0 | Gate+ | нет dangling refs после rename карт |
| 6 | `testEffortBurnMovesToDiscard` | RitualEffortGateTests | R1 | Gate+ | карта → discardPile, не exhaustPile |
| 7 | `testEffortDoesNotSpendEnergy` | RitualEffortGateTests | R1 | Gate− | energy/reservedEnergy не меняются |
| 8 | `testEffortDoesNotAffectFateDeck` | RitualEffortGateTests | R1 | Gate− | fateDeckCount не меняется |
| 9 | `testEffortBonusPassedToFateResolve` | RitualEffortGateTests | R1 | Gate+ | effortBonus → CombatCalculator → FateAttackResult |
| 10 | `testEffortUndoReturnsCardToHand` | RitualEffortGateTests | R1 | Gate+ | undo: карта в hand, effortBonus -= 1 |
| 11 | `testCannotBurnSelectedCard` | RitualEffortGateTests | R1 | Gate− | burnForEffort(selectedCardId) → false, no side effect |
| 12 | `testEffortLimitRespected` | RitualEffortGateTests | R1 | Gate− | burn при count >= maxEffort → false, no side effect |
| 13 | `testEffortDefaultZero` | RitualEffortGateTests | R1 | Gate+ | commitAttack без burn = effortBonus 0 |
| 14 | `testEffortDeterminism` | RitualEffortGateTests | R1 | Gate+ | replay с Effort + seed → идентичный результат |
| 15 | `testEffortMidCombatSaveLoad` | RitualEffortGateTests | R1 | Gate+ | save/restore → effortBonus + effortCardIds сохранены |
| 16 | `testSnapshotContainsEffortFields` | RitualEffortGateTests | R1 | Gate+ | snapshot содержит effortBonus, effortCardIds, selectedCardIds, phase |
| 17 | `testRitualSceneUsesOnlyCombatSimulationAPI` | RitualSceneGateTests | R2 | Gate− | сцена не обращается к ECS напрямую (ни мутации, ни чтения component(for:)) |
| 18 | `testRitualSceneHasNoStrongEngineReference` | RitualSceneGateTests | R2 | Gate− | нет strong ref на TwilightGameEngine и bridge (Echo*Bridge); только config/snapshot DTO |
| 19 | `testDragDropProducesCanonicalCommands` | RitualSceneGateTests | R3 | Gate+ | drag → selectCard / burnForEffort / commitAttack через CombatSimulation |
| 20 | `testDragDropDoesNotMutateECSDirectly` | RitualSceneGateTests | R3 | Gate− | drag path → нет прямой ECS mutation |
| 21 | `testDragDropControllerHasNoEngineImports` | RitualSceneGateTests | R3 | Gate− | DragDropController → только протокол CombatSimulation |
| 22 | `testLongPressDoesNotFireAfterDragStart` | RitualSceneGateTests | R3 | Gate− | long-press не активируется после 5px drag threshold |
| 23 | `testFateRevealPreservesExistingDeterminism` | RitualIntegrationGateTests | R6 | Gate+ | FateRevealDirector как observer не вносит side effects в CombatSimulation |
| 24 | `testRitualCombatNoSystemRNGSources` | RitualIntegrationGateTests | R6 | Gate− | static scan RitualCombat/: запрет random()/UUID()/Date()/arc4random/SystemRandomNumberGenerator/CFAbsoluteTimeGetCurrent/DispatchTime.now/CACurrentMediaTime |
| 25 | `testKeywordEffectConsumedOrDocumented` | RitualIntegrationGateTests | R6 | Gate+ | bonusValue/special из KeywordEffect применяются или документированно отключены |
| 26 | `testResonanceAtmosphereIsPurePresentation` | RitualAtmosphereGateTests | R7 | Gate− | controller read-only |
| 27 | `testAtmosphereControllerIsReadOnly` | RitualAtmosphereGateTests | R7 | Gate− | 0 мутационных вызовов (commit/burn/select/advance/resolve); read-only func допустимы |
| 28 | `testRitualSceneRestoresFromSnapshot` | RitualIntegrationGateTests | R9 | Gate+ | UI восстановление Bonfire/Circle/Seals/Hand из snapshot |
| 29 | `testBattleArenaDoesNotCallCommitPathWhenUsingRitualScene` | RitualIntegrationGateTests | R9 | Gate− | Arena sandbox → не вызывает commitExternalCombat |
| 30 | `testOldCombatSceneNotImportedInProduction` | RitualIntegrationGateTests | R9 | Gate− | deprecated CombatScene файлы не в production graph |
| 31 | `testFateRevealDirectorHasNoSimulationReference` | RitualIntegrationGateTests | R6 | Gate− | FateRevealDirector не хранит ссылку на CombatSimulation (static scan stored properties) |
| 32 | `testVerticalSliceReplayTrace` | RitualIntegrationGateTests | R10a | Gate+ | Replay trace: fixture `Tests/Fixtures/ritual_replay_trace.json` (seed + action sequence + CombatSnapshot.fingerprint); gate сравнивает replay output fingerprint с эталоном |

**Легенда:** Gate+ = позитивный (контракт выполняется), Gate− = негативный (запрещённое действие не происходит).

### 2.2 Модифицируемые тесты (3)

| Тест | Файл | Что меняется | Причина |
|------|------|-------------|---------|
| `testMatchBonusEnhanced` | KeywordInterpreterTests.swift | matchMultiplier: 2.0 → 1.5 (из BalancePack config) | R0 F5: matchMultiplier drift fix |
| `testSurge_physicalAttack_bonusDamage` | INV_KW_GateTests+KeywordEffects.swift | Проверить, что surge-карта с yav suit работает в combatPhysical (после F1 rebalance) | R0 F1: surge suit redistribution |
| `testFateCardSuit` | FateDeckManagerTests.swift | Обновить ожидания suit-distribution при изменении fate_prav_light_b → fate_yav_surge_a | R0 F1: card rename |

### 2.3 Удаляемые тесты (R10b — только после smoke test)

| Тест | Файл | Когда | Причина |
|------|------|-------|---------|
| `testConfigure` | CombatSceneTests.swift | R10b | CombatScene заменяется на RitualCombatScene |
| `testDidMove` | CombatSceneTests.swift | R10b | CombatScene заменяется на RitualCombatScene |
| `testFullCombat` | CombatSceneTests.swift | R10b | CombatScene заменяется на RitualCombatScene |
| `testThemeColors` | CombatSceneThemeTests.swift | R10b | Тема CombatScene заменяется на Ritual тему |

> **Safety gate:** Удаление только после R10a Go/No-Go + 1–2 дня smoke-тестирования. Старые тесты — fallback до подтверждённой стабильности.

---

## 3. Gate-тесты: подробная спецификация

### 3.1 FateDeckBalanceGateTests (R0) — 5 тестов

**INV-FATE-BAL-001: testMatchMultiplierFromBalancePack**

Тест проверяет, что multiplier читается из BalancePack и пропорционально влияет на эффект.
Не привязан к конкретному полю (bonusDamage / valueDelta / special) — проверяем через
пропорциональность двух конфигураций на keyword `surge` в combatPhysical (гарантированно
даёт числовой damageDelta).

```
GIVEN: BalancePack_A: combat.balance.matchMultiplier = 1.0
       BalancePack_B: combat.balance.matchMultiplier = 2.0
       Одинаковые начальные условия, keyword = surge, suit matches combatPhysical path
       CombatSimulation создан стандартным путём (multiplier не передаётся как параметр)
WHEN:  resolve_A = resolve surge с BalancePack_A → числовой effect_A
       resolve_B = resolve surge с BalancePack_B → числовой effect_B
THEN:  effect_B == effect_A * 2  (пропорциональность: multiplier 2.0 / 1.0 = 2x)
       — верифицируем, что система читает multiplier из BalancePack внутренне
       — тест не зависит от конкретного поля (bonusDamage vs damageDelta)

GIVEN: BalancePack БЕЗ ключа combat.balance.matchMultiplier
WHEN:  resolve surge → effect_default
THEN:  effect_default == effect_A * 1.5  (default = 1.5, не hardcoded 2.0)
```

**INV-FATE-BAL-002: testSurgeSuitDistribution**
```
GIVEN: fate_deck_core.json загружен
WHEN:  фильтруем карты с keyword == "surge"
THEN:  surgeCards.contains { $0.suit != "prav" } == true
       (минимум 1 surge-карта доступна Kill-пути через non-prav suit)
```

**INV-FATE-BAL-003: testCritCardNeutralSuit**
```
GIVEN: fate_deck_core.json загружен
WHEN:  находим карту fate_crit
THEN:  card.suit == "yav" (нейтральный — одинаково для Kill и Pacify)
```

**INV-FATE-BAL-004: testStickyCardResonanceModifyCapped**
```
GIVEN: fate_deck_core.json загружен
WHEN:  фильтруем карты с isSticky == true
THEN:  ∀ card in stickyCards:
         ∀ rule in card.resonanceRules:
           abs(rule.modifyValue) <= 1
```

**INV-FATE-BAL-005: testNoStaleCardIdsInContent**
```
GIVEN: fate_deck_core.json + все локализации + все fixtures
WHEN:  ищем старый id "fate_prav_light_b"
THEN:  0 вхождений

WHEN:  ищем новый id "fate_yav_surge_a"
THEN:  ≥1 вхождение в fate_deck_core.json
       0 dangling refs в Localizable.strings и тестовых fixtures
```

### 3.2 RitualEffortGateTests (R1) — 11 тестов

**Fixture:**
```swift
// Стандартный setup: герой с 5 картами, 1 враг, seed = 42
let sim = CombatSimulationFixtures.standard(seed: 42)
// sim.hand = [card_a, card_b, card_c, card_d, card_e]
// sim.maxEffort = 2
```

**INV-EFF-001: testEffortBurnMovesToDiscard**
```
GIVEN: sim, card_a в руке
WHEN:  sim.selectCard(card_b)
       sim.burnForEffort(card_a)
THEN:  card_a ∈ sim.discardPile
       card_a ∉ sim.hand
       card_a ∉ sim.exhaustPile
```

**INV-EFF-002: testEffortDoesNotSpendEnergy**
```
GIVEN: sim, energyBefore = sim.energy
WHEN:  sim.burnForEffort(card_a)
THEN:  sim.energy == energyBefore
       sim.reservedEnergy == 0
```

**INV-EFF-003: testEffortDoesNotAffectFateDeck**
```
GIVEN: sim, deckCountBefore = sim.fateDeckCount
WHEN:  sim.burnForEffort(card_a)
THEN:  sim.fateDeckCount == deckCountBefore
       sim.fateDiscardCount unchanged
```

**INV-EFF-004: testEffortBonusPassedToFateResolve**
```
GIVEN: sim, card selected, 2 cards burned (effortBonus = 2)
WHEN:  sim.commitAttack(targetId: enemy)
THEN:  result.totalAttack == hero.strength + cardPower + 2 + fateValue
       result.effortBonus == 2
```

**INV-EFF-005: testEffortUndoReturnsCardToHand**
```
GIVEN: sim, card_a burned (effortBonus = 1)
WHEN:  sim.undoBurnForEffort(card_a)
THEN:  card_a ∈ sim.hand
       card_a ∉ sim.discardPile
       sim.effortBonus == 0
       sim.effortCardIds.isEmpty
```

**INV-EFF-006: testCannotBurnSelectedCard (NEGATIVE)**
```
GIVEN: sim, sim.selectCard(card_a)
WHEN:  result = sim.burnForEffort(card_a)
THEN:  result == false
       sim.effortBonus == 0
       card_a still selected (not in discard)
```

**INV-EFF-007: testEffortLimitRespected (NEGATIVE)**
```
GIVEN: sim, maxEffort = 2, card_a и card_b burned
WHEN:  result = sim.burnForEffort(card_c)
THEN:  result == false
       sim.effortBonus == 2 (не 3)
       card_c ∈ sim.hand (не перемещён)
```

**INV-EFF-008: testEffortDefaultZero**
```
GIVEN: sim, card selected, NO cards burned
WHEN:  sim.commitAttack(targetId: enemy)
THEN:  result.effortBonus == 0
       result.totalAttack == hero.strength + cardPower + fateValue (без effort)
```

**INV-EFF-009: testEffortDeterminism**
```
GIVEN: seed = 42, одна и та же последовательность действий
WHEN:  прогон 1: select → burn card_a → burn card_b → commitAttack → результат_1
       прогон 2: select → burn card_a → burn card_b → commitAttack → результат_2
THEN:  результат_1 == результат_2 (семантически: Equatable, не побитово — порядок словарей не гарантирован)
```

**INV-EFF-010: testEffortMidCombatSaveLoad**
```
GIVEN: sim, card_a burned, card_b selected
WHEN:  snapshot = sim.snapshot()
       sim2 = CombatSimulation.restore(from: snapshot)
THEN:  sim2.effortBonus == 1
       sim2.effortCardIds == [card_a.id]
       sim2.selectedCardIds contain card_b.id
       sim2.hand does NOT contain card_a
```

**INV-EFF-011: testSnapshotContainsEffortFields**
```
GIVEN: sim, card_a burned
WHEN:  snapshot = sim.snapshot()
THEN:  snapshot.effortBonus != nil
       snapshot.effortCardIds != nil
       snapshot.selectedCardIds != nil
       snapshot.phase != nil
```

### 3.3 RitualSceneGateTests (R2+R3) — 6 тестов

**INV-SCENE-001: testRitualSceneUsesOnlyCombatSimulationAPI (STATIC SCAN)**
```
GIVEN: исходный код RitualCombatScene.swift
WHEN:  static scan на прямые обращения к ECS-компонентам:
       - типы: Deck, DeckCard, CombatEntity, etc.
       - мутации: .assign(), .create(), .destroy()
       - чтения: component(for:), getComponent(
THEN:  0 прямых обращений (ни мутаций, ни чтений ECS)
       все взаимодействия через: selectCard(), burnForEffort(), commitAttack(), commitInfluence(), skipTurn()
```

**INV-SCENE-002: testRitualSceneHasNoStrongEngineReference (STATIC SCAN)**
```
GIVEN: исходный код RitualCombatScene.swift + RitualCombatSceneView.swift
WHEN:  scan на типы: TwilightGameEngine, EchoEncounterBridge, EchoCombatBridge
THEN:  0 stored properties с этими типами
       допустимо: EchoCombatConfig (DTO), CombatSnapshot (DTO)
```

**INV-INPUT-001: testDragDropProducesCanonicalCommands**
```
GIVEN: DragDropController с mock CombatSimulation
WHEN:  simulate drag card_a → RitualCircle zone
THEN:  mock.selectCard(card_a) called
WHEN:  simulate drag card_b → Bonfire zone
THEN:  mock.burnForEffort(card_b) called
WHEN:  simulate drag Seal ⚔ → enemy idol
THEN:  mock.commitAttack(targetId: enemy) called
```

**INV-INPUT-002: testDragDropDoesNotMutateECSDirectly (STATIC SCAN)**
```
GIVEN: исходный код DragDropController.swift
WHEN:  scan на ECS mutation: .assign(), .create(), .destroy(), component access
THEN:  0 прямых мутаций
```

**INV-INPUT-003: testDragDropControllerHasNoEngineImports (STATIC SCAN)**
```
GIVEN: исходный код DragDropController.swift
WHEN:  scan на запрещённые символы/типы:
       - import TwilightEngine
       - TwilightGameEngine / WorldState / WorldRNG
       - EchoEncounterBridge / EchoCombatBridge
THEN:  0 вхождений запрещённых символов
       допустимо: import EchoEngine (для протоколов/DTO)
       допустимо: CombatSimulationProtocol, CombatSnapshot, EchoCombatConfig
       — проверка по символам/типам, не только по import строке
```

**INV-INPUT-004: testLongPressDoesNotFireAfterDragStart**
```
GIVEN: DragDropController, card node в позиции
WHEN:  touch began → move 6px (> 5px threshold) → hold 500ms (> 400ms tooltip)
THEN:  drag state == .dragging
       tooltip state == .hidden (не .showing)
       long-press handler NOT called
```

### 3.4 RitualAtmosphereGateTests (R7) — 2 теста

**INV-ATM-001: testResonanceAtmosphereIsPurePresentation (STATIC SCAN)**
```
GIVEN: исходный код ResonanceAtmosphereController.swift
WHEN:  scan на вызовы CombatSimulation API
THEN:  только getter-свойства: .resonance, .phase, .isOver, computed properties
       0 вызовов: selectCard, burnForEffort, commitAttack, commitInfluence, skipTurn, resolveEnemyTurn
```

**INV-ATM-002: testAtmosphereControllerIsReadOnly**
```
GIVEN: ResonanceAtmosphereController с mock CombatSimulation
WHEN:  controller.update(resonance: -50)
       controller.update(resonance: 0)
       controller.update(resonance: +50)
THEN:  mock: 0 вызовов мутационных методов:
       selectCard, burnForEffort, commitAttack, commitInfluence, skipTurn,
       resolveEnemyTurn, advancePhase, resetRound
       read-only func допустимы (snapshot(), resonance getter и т.п.)
       controller output: только visual parameters (color, alpha, particle config)
```

### 3.5 RitualIntegrationGateTests (R6+R9+R10a) — 8 тестов

**INV-DET-001: testFateRevealPreservesExistingDeterminism**
```
GIVEN: seed = 42, одинаковые начальные условия (hero, enemy, hand, fateDeck)
WHEN:  прогон A: CombatSimulation + FateRevealDirector подписан → commitAttack → simState_A
       прогон B: CombatSimulation БЕЗ FateRevealDirector → commitAttack → simState_B
THEN:  simState_A == simState_B
       Сравнение по CombatSnapshot.fingerprint (SHA-256 от canonical JSON, sorted keys):
       — fateResult (value, keyword, suit)
       — deck states (hand, discard, fateDeck order)
       — RNG cursor (nextSeedValue)
       — effortBonus, selectedCardIds, phase
       FateRevealDirector как observer не вносит side effects в CombatSimulation
```

**INV-DET-001a: testFateRevealDirectorHasNoSimulationReference (STATIC SCAN)**
```
GIVEN: исходный код FateRevealDirector.swift
WHEN:  scan на stored properties типа CombatSimulation / CombatSimulationProtocol / any *Simulation*
THEN:  0 stored properties
       допустимо: получение данных через method parameters (event-driven / callback)
       — FateRevealDirector = pure observer, не хранит ссылку на simulation
```

**INV-DET-002: testRitualCombatNoSystemRNGSources (STATIC SCAN)**
```
GIVEN: все .swift файлы в RitualCombat/ папке
WHEN:  scan на паттерны:
       - random() / .random(in:) / .random(using:)
       - UUID()
       - Date() / Date.now
       - arc4random / arc4random_uniform
       - SystemRandomNumberGenerator
       - CFAbsoluteTimeGetCurrent
       - DispatchTime.now()
       - CACurrentMediaTime()
THEN:  0 вхождений (кроме строк с маркером ANIMATION-ONLY)

WHITELIST FORMAT (единственный допустимый маркер исключения):
       // ANIMATION-ONLY: <reason>
       Маркер должен быть на ТОЙ ЖЕ строке, что и вызов.
       <reason> обязателен и не пустой (regex: `// ANIMATION-ONLY: \S+`).
       Пример: let now = CFAbsoluteTimeGetCurrent() // ANIMATION-ONLY: particle spawn timestamp
       Тест: regex `(random|UUID|Date\(\)|arc4random|SystemRandomNumberGenerator|CFAbsoluteTimeGetCurrent|DispatchTime\.now|CACurrentMediaTime)`
             на строки БЕЗ `// ANIMATION-ONLY: \S` → 0 matches
```

**INV-CONTRACT-001: testKeywordEffectConsumedOrDocumented**
```
GIVEN: CombatSystem в EchoEngine
WHEN:  анализ использования KeywordEffect.bonusValue и KeywordEffect.special
THEN:  EITHER:
         bonusValue применяется в CombatCalculator (gate: result.totalAttack includes bonusValue)
       OR:
         маркер в исходном коде (inline comment, формат ниже) + gate проверяет наличие маркера

MARKER FORMAT:
       // INTENTIONALLY_UNUSED: <fieldName> — <reason>
       Размещается в файле, где поле могло бы использоваться (CombatCalculator / CombatSystem).
       Пример: // INTENTIONALLY_UNUSED: bonusValue — applied via keyword-specific handler, not generic path
       Gate scan: regex `INTENTIONALLY_UNUSED: bonusValue` → ≥1 match если bonusValue не в totalAttack
```

**INV-INT-001: testRitualSceneRestoresFromSnapshot**
```
GIVEN: snapshot с effortBonus=1, effortCardIds=[card_a], selectedCardIds=[card_b], phase=.playerAction
       полная рука = [card_a, card_b, card_c, card_d, card_e]
WHEN:  RitualCombatScene.restore(from: snapshot)
THEN:  bonfireNode.isGlowing == true (effort > 0)
       circleNode.hasCard == true (selectedCardIds.count > 0)
       sealNodes.isVisible == true (card in circle → seals visible)
       handNode.cardIds contains [card_c, card_d, card_e]
       handNode.cardIds does NOT contain card_a (burned) and card_b (selected/in circle)
       phaseHUD shows "playerAction"

NEGATIVE: inconsistent snapshot
GIVEN: snapshot с effortBonus=0, effortCardIds=[card_a] (count mismatch)
WHEN:  CombatSimulation.restore(from: snapshot)
THEN:  validation error / assert failure
       — effortBonus MUST == effortCardIds.count (snapshot internal consistency invariant)
```

**INV-INT-002: testBattleArenaDoesNotCallCommitPathWhenUsingRitualScene**
```
GIVEN: BattleArenaView с RitualCombatScene (после миграции)
WHEN:  полный бой: start → play → victory
THEN:  0 вызовов по всем commit-путям:
       - commitExternalCombat()
       - engine.performAction(.commitExternalCombat(...))
       - EchoCombatBridge.applyCombatResult(...)
       Arena допускает только локальный result (display-only), без world commit
```

**INV-INT-003: testOldCombatSceneNotImportedInProduction (STATIC SCAN)**
```
GIVEN: все .swift файлы в production targets (не в Tests/)
WHEN:  scan на символ-использование:
       - CombatScene( (инстанцирование)
       - CombatSceneView / SpriteView(scene: ...CombatScene)
       - CombatScene+ (extension файлы)
       - typealias к CombatScene
       + target membership проверка: CombatScene*.swift не входят в production target
         (через pbxproj анализ или аналогичный gate из AuditArchitectureBoundaryGateTests)
THEN:  0 символ-использований в production source
       0 CombatScene*.swift файлов в production target membership
```

**INV-REPLAY-001: testVerticalSliceReplayTrace (R10a)**
```
GIVEN: fixture файл Tests/Fixtures/ritual_replay_trace.json содержит:
       {
         "seed": 42,
         "actions": ["selectCard:card_b", "burnForEffort:card_a", "commitAttack:enemy_1"],
         "expectedFingerprint": "<sha256 CombatSnapshot после выполнения>"
       }
WHEN:  CombatSimulation(seed: fixture.seed) → выполнить fixture.actions → snapshot
THEN:  snapshot.fingerprint == fixture.expectedFingerprint
       — fixture генерируется однократно gate-скриптом при R10a Go/No-Go
       — формат fingerprint: SHA-256 от canonical JSON CombatSnapshot (sorted keys, no whitespace)
       — fingerprint пишется gate-скриптом, не вручную
```

---

## 4. Layer-тесты (unit, не gate)

### 4.1 EffortMechanicTests.swift (R1)

Юнит-тесты CombatSimulation — покрывают edge cases не вошедшие в gate.

| Тест | Тип | Что проверяет |
|------|-----|---------------|
| `testBurnExhaustCardGoesToDiscard` | + | exhaust:true карта через Effort → discardPile (не exhaustPile) |
| `testBurnLastCardLeavesEmptyHand` | + | burn всех карт кроме selected → hand.count == 1 (selected) |
| `testUndoNonExistentCardReturnsFalse` | − | undo карты не в effortCardIds → false, no side effect |
| `testUndoAlreadyReturnedCardReturnsFalse` | − | double undo → false |
| `testEffortResetAfterCommit` | + | после commitAttack: effortBonus = 0, effortCardIds = [] |
| `testEffortResetAfterSkip` | + | skipTurn() не сбрасывает Effort (Effort не применяется к skip) |
| `testEffortWithMultiEnemy` | + | Effort bonus применяется к одной цели, не ко всем |
| `testMaxEffortFromHeroDefinition` | + | HeroDefinition.maxEffort = 3 → можно сжечь 3 карты |
| `testEffortBonusInInfluence` | + | burnForEffort + commitInfluence → effortBonus в spirit damage |
| `testBurnDuringWrongPhase` | − | burnForEffort вне playerAction → false |

### 4.2 FateRevealTests.swift (R6)

Юнит-тесты FateRevealDirector.

| Тест | Тип | Что проверяет |
|------|-----|---------------|
| `testMajorFateUsesFullTimeline` | + | commitAttack с высоким значением → Major tempo (2.5s) |
| `testMinorFateUsesShortTimeline` | + | commitAttack с малым значением → Minor tempo (1.0s) |
| `testWaitSkipsFateReveal` | + | skipTurn → нет Fate-анимации, tempo 0.6s |
| `testDefenseFateUsesCompactReveal` | + | enemy attack phase → compact reveal (меньше, быстрее) |
| `testKeywordVisualMatchesResolution` | + | surge карта → surge visual effect (не shadow и т.п.) |
| `testSuitMatchShowsGlowEffect` | + | matched suit → контур вспышка + руна пульсация |
| `testSuitMismatchShowsNoGlow` | − | mismatched suit → нет вспышки |

### 4.3 DragDropControllerTests.swift (R3)

Юнит-тесты DragDropController.

| Тест | Тип | Что проверяет |
|------|-----|---------------|
| `testDragThreshold5px` | + | movement < 5px → состояние IDLE (не LIFT) |
| `testDragBeyondThreshold` | + | movement ≥ 5px → состояние LIFT → DRAG |
| `testDropOnCircleSnaps` | + | drop в зону Circle → snap animation + selectCard |
| `testDropOnBonfireBurns` | + | drop в зону Bonfire → burn particles + burnForEffort |
| `testDropOutsideReturnsToHand` | + | drop вне зон → spring return animation |
| `testDimmedCardNotDraggable` | − | карта без энергии (dimmed) → drag rejected |
| `testSealDragOnEnemyCommitsAttack` | + | Seal ⚔ → enemy idol → commitAttack(targetId:) |
| `testSealDragOnAltarCommitsSkip` | + | Seal ⏳ → altar → skipTurn() |
| `testSealVisibilityAfterCardInCircle` | + | card в Circle → seals fade in (alpha 0.15 → 1.0) |
| `testWaitSealAlwaysVisible` | + | ⏳ видим даже без карты в Circle (dimmed) |

---

## 5. Integration-тесты

### 5.1 RitualCombatIntegrationTests.swift (R9)

End-to-end сценарии с реальным ContentRegistry.

| Тест | Что проверяет |
|------|---------------|
| `testFullKillPathWithEffort` | Hero → select card → burn 2 → Seal ⚔ → enemy HP=0 → KILLED outcome |
| `testFullPacifyPathWithEffort` | Hero → select card → burn 1 → Seal 💬 → enemy WP=0 → PACIFIED outcome |
| `testWaitPathNoFateDraw` | Hero → ⏳ Wait → нет Fate draw → enemy resolves |
| `testMidCombatSaveRestoreResume` | Round 1 → burn card → save → restore → Round 2 continues from snapshot |
| `testArenaDoesNotCommitToWorldEngine` | Arena → full fight → victory → 0 world-state changes |
| `testCampaignCommitsThroughBridge` | Campaign → full fight → victory → commitExternalCombat called |
| `testResonanceShiftDuringCombat` | Kill action → resonance shifts to Nav → atmosphere updates |
| `testPacifyShiftsTowardPrav` | Pacify action → resonance shifts to Prav → atmosphere updates |

---

## 6. Негативные тесты (сводка)

Все тесты типа Gate− и unit-негативные, собранные в одном месте для аудита полноты.

### 6.1 Effort — что НЕ должно происходить

| Сценарий | Ожидание | Тест |
|----------|----------|------|
| Burn selected card | → false, no side effect | testCannotBurnSelectedCard |
| Burn beyond max limit | → false, card stays in hand | testEffortLimitRespected |
| Burn changes energy | energy unchanged | testEffortDoesNotSpendEnergy |
| Burn changes Fate Deck | fateDeckCount unchanged | testEffortDoesNotAffectFateDeck |
| Undo non-existent card | → false, no side effect | testUndoNonExistentCardReturnsFalse |
| Double undo same card | → false | testUndoAlreadyReturnedCardReturnsFalse |
| Burn during wrong phase | → false | testBurnDuringWrongPhase |

### 6.2 Architecture — что НЕ должно быть в коде

| Что запрещено | Где сканируем | Тест |
|---------------|---------------|------|
| Прямой ECS-доступ в Scene (мутация+чтение) | RitualCombatScene.swift | testRitualSceneUsesOnlyCombatSimulationAPI |
| Strong ref на Engine/Bridge | RitualCombatScene*.swift | testRitualSceneHasNoStrongEngineReference |
| Прямая ECS-мутация в Drag | DragDropController.swift | testDragDropDoesNotMutateECSDirectly |
| Engine import в Controller | DragDropController.swift | testDragDropControllerHasNoEngineImports |
| Long-press после drag | gesture state | testLongPressDoesNotFireAfterDragStart |
| Мутационные вызовы в Atmosphere (commit/burn/select/advance) | ResonanceAtmosphereController | testAtmosphereControllerIsReadOnly |
| System RNG в RitualCombat/ | all .swift in folder | testRitualCombatNoSystemRNGSources |
| FateRevealDirector хранит ref на Simulation | FateRevealDirector.swift | testFateRevealDirectorHasNoSimulationReference |
| Deprecated import в prod | production targets | testOldCombatSceneNotImportedInProduction |
| Arena commits to world (direct + bridge) | BattleArenaView | testBattleArenaDoesNotCallCommitPathWhenUsingRitualScene |

---

## 7. Boundary и edge cases

### 7.1 Effort boundary

| Граница | Значение | Ожидание |
|---------|----------|----------|
| effortBonus = 0 | baseline | totalAttack = str + card + 0 + fate |
| effortBonus = 1 | +1 | totalAttack = str + card + 1 + fate |
| effortBonus = 2 (max) | hard cap | totalAttack = str + card + 2 + fate |
| effortBonus = 3 (rejected) | over limit | burnForEffort → false |
| hand = 1 card (selected) | no cards to burn | burnForEffort → false (0 eligible) |
| hand = 2 cards, 1 selected | 1 eligible | max 1 burn (min of maxEffort and eligible) |

### 7.2 Resonance interpolation boundary

| Значение | Зона | Ожидание |
|----------|------|----------|
| -100 | deepNav | max vignette, violet light, fog particles |
| -30 | Nav→Yav boundary | threshold crossing FX (shader ripple) |
| 0 | Yav center | neutral atmosphere |
| +30 | Yav→Prav boundary | threshold crossing FX |
| +100 | deepPrav | min vignette, gold light, spark particles |
| rapid -50→+50 | cross 2 zones | smooth lerp, no jitter |

### 7.3 Snapshot restore edge cases

| Состояние | Ожидание |
|-----------|----------|
| effortBonus=2, hand=3 → restore | 1 card in hand (5-2effort-2selected... adjust) |
| Restore after enemy defeated | victory state, не replay |
| Restore to playerAction with selected card | Circle glow, seals visible |
| Restore to intent phase | seals hidden, intent token visible |
| Restore with empty hand | no cards displayed, Wait always available |
| effortBonus=0, effortCardIds=[card_a] (inconsistent) | assert fail / snapshot validation error — инвариант внутренней согласованности |

### 7.4 Determinism edge cases

| Сценарий | Ожидание |
|----------|----------|
| Same seed + same Effort actions → same outcome | семантическое совпадение (Equatable) |
| Effort на defeated enemy | no crash, victory state |
| Save → restore → new action → determinism from restore point | consistent forward |

---

## 8. Fixture strategy

### 8.1 Новые fixture-файлы

```swift
// CombatSimulationFixtures.swift
enum CombatSimulationFixtures {
    /// 1 hero (str=5, will=4, maxEffort=2), 5 cards, 1 enemy (hp=10, wp=8), seed=42
    static func standard(seed: UInt64 = 42) → CombatSimulation

    /// standard + 2 enemies
    static func multiEnemy(seed: UInt64 = 42) → CombatSimulation

    /// standard + hero.maxEffort = customMax
    static func withMaxEffort(_ max: Int, seed: UInt64 = 42) → CombatSimulation

    /// standard + specific hand cards
    static func withHand(_ cardIds: [String], seed: UInt64 = 42) → CombatSimulation
}
```

```swift
// SnapshotFixtures.swift
enum SnapshotFixtures {
    /// Mid-combat: 1 card burned, 1 selected, playerAction phase
    static func midEffort() → CombatSnapshot

    /// After victory: enemy HP=0, roundEnd phase
    static func afterVictory() → CombatSnapshot

    /// Empty hand, intent phase
    static func emptyHand() → CombatSnapshot
}
```

### 8.2 Seed contract

Все gate-тесты используют **hardcoded seeds** (42, 424242, 808080). Системный RNG запрещён в тестах.

---

## 9. Матрица покрытия инвариантов

| Инвариант | Gate-тест | Layer-тест | Integration-тест |
|-----------|-----------|------------|------------------|
| effortBonus ≤ maxEffort | INV-EFF-007 | testMaxEffortFromHeroDefinition | — |
| effortCardIds ⊆ hand до commit | INV-EFF-001, -006 | testBurnLastCardLeavesEmptyHand | — |
| Effort не задействует RNG | INV-EFF-009 | — | — |
| Effort не влияет на Fate Deck | INV-EFF-003 | — | — |
| Scene → только CombatSimulation API | INV-SCENE-001 | — | — |
| Scene → no engine/bridge refs | INV-SCENE-002 | — | — |
| Drag → canonical commands only | INV-INPUT-001, -002 | DragDropControllerTests | — |
| Atmosphere → read-only | INV-ATM-001, -002 | — | — |
| Snapshot → visual restore (no replay) | INV-INT-001 | — | testMidCombatSaveRestoreResume |
| Arena sandbox → no world commit | INV-INT-002 | — | testArenaDoesNotCommitToWorldEngine |
| matchMultiplier пропорциональность | INV-FATE-BAL-001 | testMatchBonusEnhanced (modified) | — |
| Sticky modifyValue ≤ 1 | INV-FATE-BAL-004 | — | — |
| No system RNG in RitualCombat/ | INV-DET-002 | — | — |
| FateRevealDirector = pure observer | INV-DET-001a | — | — |
| Determinism preserved | INV-DET-001, INV-EFF-009 | — | testMidCombatSaveRestoreResume |
| Replay trace fingerprint stable | INV-REPLAY-001 | — | — |

---

## 10. Порядок реализации (TDD workflow)

```
1. R0: FateDeckBalanceGateTests (RED) → content changes (GREEN) → commit
2. R1: RitualEffortGateTests (RED) → CombatSimulation extension (GREEN) → commit
3. R2: RitualSceneGateTests (RED, static scan) → scene foundation (GREEN) → commit
4. R3: DragDropControllerTests (RED) → DragDropController (GREEN) → commit
5. R6: RitualIntegrationGateTests partial (RED) → FateRevealDirector (GREEN) → commit
6. R7: RitualAtmosphereGateTests (RED) → ResonanceAtmosphereController (GREEN) → commit
7. R9: RitualIntegrationGateTests full (RED) → integration wiring (GREEN) → commit
8. R10a: все gate-тесты GREEN + Go/No-Go report
```

---

## 11. Счётчик тестов

| Категория | Новых | Модифицированных | Удаляемых (R10b) | Итого новых |
|-----------|-------|-----------------|------------------|-------------|
| Gate-тесты | 32 | 0 | 0 | 32 |
| Layer-тесты | 27 | 3 | 0 | 27 |
| Integration-тесты | 8 | 0 | 4 (R10b) | 8 |
| **Итого** | **67** | **3** | **4** | **67** |

> **Примечание:** 4 удаляемых теста (CombatSceneTests, CombatSceneThemeTests) — только после R10b safety gate.
