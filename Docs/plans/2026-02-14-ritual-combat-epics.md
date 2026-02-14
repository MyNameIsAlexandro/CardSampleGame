# Phase 3: Ritual Combat — Epic Ledger

**Scope:** Visual combat overhaul — единая SpriteKit-сцена в стиле "Grim Slavic Noir"
**Status:** Planning
**Design doc:** `Docs/plans/2026-02-13-ritual-combat-design.md` (v1.2, approved)
**Policy sync:** CLAUDE.md v4.1
**Last updated:** 2026-02-14
**TDD workflow:** Тестовая модель → Gate-тесты (RED) → Код (GREEN) → Полировка
**Fate Deck audit:** `Design/COMBAT_DIPLOMACY_SPEC.md` Приложение D (F1–F6)

---

## Нумерация

Epics Phase 3 начинаются с **R1** (Ritual), чтобы не пересекаться с Phase 1 (1–14) и Phase 2 (15–68).

---

## Граф зависимостей

```
R0 (Fate Balance) ──→ R1 (Effort) ────────────────┐
                                                    ├──→ R5 (Ritual Zone)
                      R2 (Scene Foundation) ──┬────┤
                                               │    ├──→ R9 (Integration) ──→ R10a (Validation) ──→ R10b (Retirement)
                                               ├──→ R3 (Cards & Drag) ──→ R5
                                               ├──→ R4 (Enemy Idols)
                                               ├──→ R6 (Fate Reveal)
                                               ├──→ R7 (Resonance Atmosphere)
                                               └──→ R8 (HUD & Info)
```

**Параллельные потоки:**
- R0 → R1 (engine, sequential: R0 фиксит math, R1 строит поверх)
- R2 (scene foundation) параллельно с R0 + R1
- R3, R4, R6, R7, R8 параллельны после R2
- R5 ждёт R1 + R2 + R3
- R9 ждёт R1–R8
- R10 ждёт R9

---

## Status Snapshot

- `R0`: PENDING — Fate Deck Balance Hardening (F1–F6)
- `R1`: PENDING — Effort mechanic (engine extension)
- `R2`: PENDING — RitualCombatScene foundation
- `R3`: PENDING — Card system & Drag-Drop
- `R4`: PENDING — Enemy Idols
- `R5`: PENDING — Ritual Zone (Seals, Circle, Bonfire)
- `R6`: PENDING — Fate Reveal
- `R7`: PENDING — Resonance Atmosphere
- `R8`: PENDING — HUD & Info Layer
- `R9`: PENDING — Integration & Migration
- `R10a`: PENDING — Vertical Slice Validation
- `R10b`: PENDING — Legacy Retirement & Cleanup

---

## Epics

### R0 [PENDING] — Fate Deck Balance Hardening

**Goal:** Закрыть математические дефекты F1–F5 из стресс-аудита Fate Deck (Приложение D COMBAT_DIPLOMACY_SPEC) до построения визуальной надстройки. Только контентные и конфигурационные изменения — без изменения семантики engine runtime.

**Dependencies:** Нет (первый epic Phase 3).

**Design ref:** `COMBAT_DIPLOMACY_SPEC.md` Приложение D

**Scope boundary:** Только balance/content/config. Никаких изменений в `FateDeckManager.drawAndResolve()` или resolution pipeline. F6 (bonusValue/special consumption) вынесен в R6 как contract verification.

**Deliverables:**

**F5 (P3) — matchMultiplier drift fix:**
- Подключить `KeywordInterpreter.resolve()` к существующему SoT-ключу `combat.balance.matchMultiplier` (default = **1.5** по COMBAT_DIPLOMACY_SPEC Приложение C)
- Текущий код hardcoded **2.0** — это drift с SoT. Fix: читать из BalancePack config
- Не вводить новый ключ — использовать существующий `combat.balance.matchMultiplier`

**F3 (P2) — deepNav doom spiral mitigation (content-only):**
- Обновить `curse_navi` resonanceRules: deepNav modifyValue **-2 → -1**, nav modifyValue **-1 → -1** (без изменения)
- Добавить правило в `ContentValidationTests`: `if card.isSticky == true → ∀ resonanceRules: abs(modifyValue) ≤ 1`
- Никаких runtime floor/cap в engine — решение чисто через контент + автоматическую валидацию

**F1 (P1) — Surge suit distribution:**
- Изменить 1 surge-карту с prav на yav (рекомендация: `fate_prav_light_b` → `fate_yav_surge_a`, suit=yav)
- Kill-путь получает 1/12 surge вместо 0/12
- Общий баланс: surge 3 prav + 1 yav (вместо 4 prav)

**F2 (P1) — Crit card balance:**
- `fate_crit`: изменить suit с prav на yav (нейтральный, одинаково работает на оба пути)
- Или: убрать keyword (crit и так +3 base, keyword сверху = overkill)
- Рекомендация: suit=yav, keyword=surge (нейтральный surge crit)

**F4 (P2) — deepPrav snowball:** Monitor. Kill→Nav самокоррекция. Контрольная точка — R10a vertical slice.

**Acceptance (gate-тесты):**
- `testMatchMultiplierFromBalancePack` — matchMultiplier читается из `combat.balance.matchMultiplier`, default = 1.5
- `testSurgeSuitDistribution` — ≥1 surge-карта с suit ≠ prav в fate_deck_core
- `testCritCardNeutralSuit` — crit card имеет suit=yav (нейтральный)
- `testStickyCardResonanceModifyCapped` — `ContentValidationTests`: `if card.isSticky → ∀ resonanceRules: abs(modifyValue) ≤ 1`
- `testNoStaleCardIdsInContent` — старый id (`fate_prav_light_b`) отсутствует, новый (`fate_yav_surge_a`) присутствует, нет dangling refs в локализациях/fixtures

---

### R1 [PENDING] — Effort Mechanic (Engine Extension)

**Goal:** Реализовать каноническую механику Effort (PROJECT_BIBLE: `Stat + FateCard + Effort >= Difficulty`) в CombatSimulation.

**Dependencies:** R0 (matchMultiplier fix и content changes должны быть завершены до расширения CombatSimulation).

**Design ref:** §3.5 (SoT), §11.2 (API)

**Deliverables:**
- `burnForEffort(cardId:) → Bool` в CombatSimulation
- `undoBurnForEffort(cardId:) → Bool` в CombatSimulation
- Internal state: `effortBonus`, `effortCardIds`, `maxEffort`
- `maxEffort` из `HeroDefinition` (default = 2)
- `commitAttack()` / `commitInfluence()` читают `self.effortBonus` (internal state, не параметр)
- Snapshot extension: `effortBonus`, `effortCardIds` в mid-combat save
- Effort reset после commit

**Acceptance (gate-тесты):**
- `testEffortBurnMovesToDiscard` — карта в discardPile, не exhaustPile
- `testEffortDoesNotSpendEnergy` — energy/reservedEnergy не меняются
- `testEffortDoesNotAffectFateDeck` — fateDeckCount не меняется
- `testEffortBonusPassedToFateResolve` — effortBonus → CombatCalculator → FateAttackResult
- `testEffortUndoReturnsCardToHand` — undo возвращает карту, effortBonus -= 1
- `testCannotBurnSelectedCard` — burnForEffort(selectedCardId) → false
- `testEffortLimitRespected` — burn при effortCardIds.count >= maxEffort → false
- `testEffortDefaultZero` — commitAttack без burn = effortBonus 0
- `testEffortDeterminism` — replay с Effort + seed → идентичный результат
- `testEffortMidCombatSaveLoad` — save/restore с Effort → состояние сохранено
- `testSnapshotContainsEffortFields` — snapshot хранит все 4 поля

---

### R2 [PENDING] — RitualCombatScene Foundation

**Goal:** Создать каркас новой боевой сцены с базовой визуальной средой "Стол Волхва".

**Dependencies:** Нет (параллельно с R1).

**Design ref:** §4 (ориентация/концепт), §5 (layout/zPosition/освещение), §11.3 (файловая структура)

**Deliverables:**
- `RitualCombatScene.swift` — SKScene lifecycle, portrait 390×700
- `RitualCombatSceneView.swift` — SwiftUI bridge (SpriteView)
- Текстура стола (тёмное дерево, программная)
- SKLightNode с мерцанием (синусоида 0.3Hz)
- Виньетка (SKSpriteNode, alpha по резонансу)
- zPosition layers (фон → атмосфера → объекты → карты → drag → HUD → fate → overlays)
- Базовая node hierarchy (пустые placeholder-ноды для зон)

**Acceptance:**
- `testRitualSceneUsesOnlyCombatSimulationAPI` — сцена не мутирует ECS напрямую
- `testRitualSceneHasNoStrongEngineReference` — `RitualCombatScene` не хранит strong reference на `TwilightGameEngine` и bridge-объекты (`EchoEncounterBridge`, `EchoCombatBridge`); хранит только config/snapshot DTO
- Scene создаётся без crash, отображает стол с освещением
- SwiftUI bridge принимает `EchoCombatConfig`, передаёт в сцену
- Portrait orientation locked

---

### R3 [PENDING] — Card System & Drag-Drop

**Goal:** Карты как физические объекты на столе. Drag & drop с gesture priority.

**Dependencies:** R2

**Design ref:** §7 (карты, drag lifecycle, arc layout, gesture priority)

**Deliverables:**
- `RitualCardNode.swift` — визуал карты (100×140, береста, неровные края)
- `DragDropController.swift` — gesture management, 5px threshold
- Arc layout (веер): rotation ±8°, overlap 40%, staggered breathing
- Drag lifecycle: IDLE → LIFT → DRAG → DROP (3 исхода)
- Drop zones: Ritual Circle (selectCard), Bonfire (burnForEffort), invalid (return spring)
- `TargetingArrowNode.swift` — магическая нить (8-12 SKShapeNode точек)
- Dimmed state для карт без энергии (alpha 0.4, haptic `.error`)

**Acceptance:**
- `testDragDropProducesCanonicalCommands` — drag → selectCard / burnForEffort
- `testDragDropDoesNotMutateECSDirectly` — drag path не мутирует ECS-компоненты напрямую (только через CombatSimulation API)
- `testDragDropControllerHasNoEngineImports` — `DragDropController` зависит только от протокола CombatSimulation, не импортирует/не хранит ссылку на `TwilightGameEngine`
- `testLongPressDoesNotFireAfterDragStart` — long-press gesture не активируется после начала drag (5px threshold)
- Gesture priority: drag (5px) всегда побеждает tooltip (400ms)
- Drop на Circle → snap + selectCard()
- Drop на Bonfire → burn particles + burnForEffort()
- Drop вне зоны → spring return в руку

---

### R4 [PENDING] — Enemy Idols

**Goal:** Враги как вырезанные из дерева/камня идолы с диегетическим HP/WP.

**Dependencies:** R2

**Design ref:** §6 (идолы, HP notches, WP rune chain, Kill vs Pacify, woodcut shader)

**Deliverables:**
- `IdolNode.swift` — 70×100, вертикальный, текстура дерева/камня
- HP-насечки (shader fill при уроне, скалывание при крите)
- WP-рунная цепь (fade out при spirit-уроне)
- Intent-токен (drop + bounce, 200ms, staggered для multi-enemy)
- Visual states: Idle, Intent shown, HP damage, WP damage, Kill, Pacify, Hover, Anticipation
- Kill анимация: раскалывается, трещина, дым
- Pacify анимация: свечение гаснет, идол склоняется, тишина
- Woodcut shader pipeline (threshold → noise → edge → colorize) для SF Symbol арта
- Multi-enemy layout (до 3, spacing 15)

**Acceptance:**
- Kill и Pacify визуально различимы (Go/No-Go #3)
- Intent token отображается для каждого врага
- HP notches и WP runes обновляются при уроне

---

### R5 [PENDING] — Ritual Zone (Seals, Circle, Bonfire)

**Goal:** Механика "Запечатывания" — физические объекты заменяют кнопки Attack/Influence/Wait.

**Dependencies:** R1, R2, R3

**Design ref:** §3.4 (печати), §3.5.6 (костёр), §5.1 (layout)

**Deliverables:**
- `SealNode.swift` — 3 тотема: ⚔ Удар, 💬 Слово, ⏳ Выждать
- `RitualCircleNode.swift` — commit zone, glow ∝ effortBonus
- `BonfireNode.swift` — Effort burn zone с particles
- Contextual visibility: печати скрыты (alpha 0.15) до карты в Circle → fade in + scale pulse
- ⏳ Выждать всегда доступен (тусклее без карты в Circle)
- Seal drag → commitAttack() / commitInfluence() / skipTurn()
- Seal drag на врага: targeting arrow + anticipation state на IdolNode
- Seal drag на алтарь/центр: skipTurn

**Acceptance:**
- Печати появляются только при карте в Circle
- Seal drag вызывает корректные CombatSimulation методы
- ⏳ Wait доступен без карты (Go/No-Go #5)

---

### R6 [PENDING] — Fate Reveal & Keyword Outcome Contract

**Goal:** Вскрытие Fate-карты как драматический момент раунда. Верификация keyword outcome contract (F6).

**Dependencies:** R2

**Contract note:** R6 не вводит новых полей в `FateResolution` без отдельного мини-эпика, но допускает минимальную правку структуры, если иначе невозможно обеспечить contract (consumed or documented). Если R1 расширяет FateResolution (Effort-поля) — R6 адаптируется, но не блокируется.

**Design ref:** §8 (Fate Moment, Dynamic Tempo, 3D flip, keyword effects, Fate Choice)

**Deliverables:**
- `FateCardNode.swift` — 80×120, рубашка с руной, лицо с значением
- `FateRevealDirector.swift` — orchestration, timeline
- 3D flip (xScale collapse + colorBlendFactor shadow)
- Dynamic Tempo: Major (2.5s), Minor (1.0s), Wait (0.6s)
- Keyword visual effects: Surge (волна), Shadow (темнота), Ward (руна-щит), Focus (лучи), Echo (ghost copy)
- Suit Match: вспышка по контуру, руна пульсирует
- Fate Choice overlay (2 карты парят, тап выбирает)
- Defensive fate (меньше, быстрее, без затемнения)

**F6 (P3) — Keyword outcome contract verification:**
- Аудит: `CombatSystem` в EchoEngine — используется ли `keywordEffect.bonusValue` и `keywordEffect.special` из `FateResolution`?
- Если используется → документировать, добавить gate-тест
- Если не используется → решение: подключить (bonusValue → доп. урон, special → effect dispatch) или документированно отключить ("bonusValue intentionally unused in combat formula, effects via special only")
- Результат: контракт зафиксирован, gate-тест добавлен

**Acceptance:**
- `testFateRevealPreservesExistingDeterminism` — визуал не влияет на FateResolution
- `testRitualCombatNoSystemRNGSources` — статический скан `RitualCombat/*`: запрет `random()`/`UUID()`/`Date()` кроме явно разрешённых animation-only timestamps
- `testKeywordEffectConsumedOrDocumented` — bonusValue/special из KeywordEffect применяются в CombatSystem или документированно отключены
- Major fate = затемнение + полный flip + keyword
- Minor fate = быстрый flip без затемнения
- Wait = без Fate-карты
- Keyword scope: только канонические 5 FateKeyword

---

### R7 [PENDING] — Resonance Atmosphere

**Goal:** Резонанс как живая атмосфера сцены (Навь/Явь/Правь).

**Dependencies:** R2

**Design ref:** §9 (резонанс, HSL interpolation, RTPC audio, particles)

**Deliverables:**
- `ResonanceAtmosphereController.swift` — observer, read-only
- HSL-интерполяция (2-segment: Навь↔Явь, Явь↔Правь, без грязных цветов)
- `AudioLayerController.swift` — RTPC crossfade (3 трека: whispers/bells/wind)
- Particle systems: туман/пепел (Навь), пыль/угольки (Явь), золотые пылинки (Правь)
- Виньетка: alpha 0.15 (Правь) → 0.6 (Навь)
- Руны на столе: цвет + пульсация по резонансу
- Fate-рубашка стиль по резонансу (не механика)
- Threshold crossing FX (shader ripple при ±30)

**Acceptance:**
- `testResonanceAtmosphereIsPurePresentation` — controller read-only
- `testAtmosphereControllerIsReadOnly` — разрешены только getter-свойства CombatSimulation (`.resonance`, `.phase`, `.isOver`, computed properties); запрещены любые `func` вызовы на simulation
- Screenshot test: -50 и +50 визуально не спутать (Go/No-Go #6)
- Все параметры интерполируются плавно (без дискретных переключений)

---

### R8 [PENDING] — HUD & Info Layer

**Goal:** Диегетический HUD — амулеты и камни на столе, числа доминантные.

**Dependencies:** R2

**Design ref:** §10 (HUD, амулеты, типографика, combat log, info-on-demand)

**Deliverables:**
- `AmuletNode.swift` — HP-амулет (left), Faith-камень (right)
- `ResonanceRuneNode.swift` — центральная руна ☽/☯/☀
- Phase indicator (верхняя кромка: "Раунд N · Фаза")
- Fate deck counter (🂠 сверху справа)
- Числа доминантные: 18pt, белый, text shadow, WCAG AA
- HP critical pulse (< 25% → красная пульсация)
- Combat log overlay (tap по руне → "свиток" с 10 событиями)
- Info-on-demand: tap/long-press на каждом HUD-элементе

**Acceptance:**
- Читаемость за 3 секунды (Go/No-Go #1)
- ≤ 5 текстовых элементов на основном экране (Go/No-Go #9)
- WCAG AA контраст для всех чисел

---

### R9 [PENDING] — Integration & Migration

**Goal:** Подключить RitualCombatScene к обоим путям (Arena + Campaign), проверить save/load.

**Dependencies:** R1–R8

**Design ref:** §11.4 (data flow), §11.5 (миграция), §3.5.4 (snapshot-контракт)

**Deliverables:**
- Arena (BattleArenaView) → RitualCombatScene (первая, sandbox)
- Campaign (EventView) → RitualCombatScene (вторая, через bridge)
- Mid-combat save/load с Effort snapshot
- RitualCombatScene восстанавливает UI из snapshot (Костёр, Круг, Печати, Рука)
- Resume path verification
- Data flow: TwilightEngine → Bridge → Config → Scene → Simulation → Result → Bridge → Engine

**Acceptance:**
- `testRitualSceneRestoresFromSnapshot` — восстановление UI из snapshot
- `testOldCombatSceneNotImportedInProduction` — deprecated файлы не в production graph
- `testBattleArenaDoesNotCallCommitPathWhenUsingRitualScene` — Arena sandbox не вызывает `commitExternalCombat` после миграции на RitualCombatScene
- Save → kill → restore → тот же state (Go/No-Go #10)
- Arena не коммитит в world-engine state (§1.5 CLAUDE.md)

---

### R10a [PENDING] — Vertical Slice Validation

**Goal:** Проверить Go/No-Go на реальном девайсе. Никакого удаления deprecated-кода — только валидация.

**Dependencies:** R9

**Design ref:** §12 (вертикальный срез), §13 (TDD workflow)

**Vertical slice scope:**
- 1 враг (Волколак), 1 герой (5 карт), 1 бой (3-5 раундов)
- 2 состояния резонанса (Навь и Явь)

**Go/No-Go checklist (10 критериев):**

| # | Критерий | Тип проверки |
|---|---|---|
| 1 | Читаемость за 3 секунды | Playtest |
| 2 | Один Fate-момент = драма | Playtest |
| 3 | Kill ≠ Pacify по ощущению | A/B |
| 4 | Pacify жизнеспособен | Gameplay |
| 5 | Wait ≠ стыдный скип | UI review |
| 6 | Резонанс живёт | Screenshot test |
| 7 | "Я положил карту на стол" | Haptic test |
| 8 | Детерминизм сохранён | Автотест |
| 9 | Не стена текста | UI review |
| 10 | Encounter изолирован и сериализуем | Автотест |

**Deliverables:**
- Go/No-Go report по всем 10 критериям
- Финальный прогон всех gate-тестов
- F4 monitoring checkpoint: deepPrav snowball проверка на vertical slice
- Smoke test: кампания + arena + resume path на реальном девайсе
- Фиксация seed + сохранение replay trace как артефакт (для воспроизводимости найденных багов)

**Acceptance:**
- Все 10 Go/No-Go пройдены
- Все gate-тесты зелёные
- Старый боевой путь остаётся рабочим как fallback

---

### R10b [PENDING] — Legacy Retirement & Cleanup

**Goal:** Удаление deprecated боевого кода после подтверждённой стабильности нового пути.

**Dependencies:** R10a + 1–2 дня smoke-тестирования кампании и resume path на реальном девайсе

**Safety gate:** R10b начинается **только** после:
1. R10a Go/No-Go пройдены
2. Smoke test на реальном девайсе (кампания: 3+ боёв, resume: save→kill→restore)
3. Явное одобрение на удаление

**Deliverables:**
- Удаление deprecated: `CombatScene.swift`, `CombatScene+*.swift`
- Удаление EncounterViewModel combat path (SwiftUI path)
- Удаление неиспользуемых imports
- Финальный прогон gate-тестов после удаления

**Acceptance:**
- `testOldCombatSceneNotImportedInProduction` — 0 deprecated imports
- Все gate-тесты зелёные после удаления
- Build clean: iOS + macOS

---

## Что НЕ входит в Phase 3

- Multi-enemy (1vN) — только layout-подготовка в R4, без полной реализации
- Mulligan redesign
- Кастомные шрифты (используем system + Cormorant Garamond)
- Реальный арт (SF Symbols + woodcut shader)
- Звуковые ассеты (placeholder)
- Landscape-режим
- Расширение набора FateKeyword (только канонические 5)
- Effort в Exploration/Investigation (отдельный эпик)
- Effort maxEffort > 2 через hero abilities (design space, не реализация)

---

## Gate-тесты Phase 3 (planned)

| Тест | Epic | Scope |
|---|---|---|
| `testMatchMultiplierFromBalancePack` | R0 | matchMultiplier из `combat.balance.matchMultiplier`, default 1.5 |
| `testSurgeSuitDistribution` | R0 | ≥1 surge != prav |
| `testCritCardNeutralSuit` | R0 | crit suit=yav |
| `testStickyCardResonanceModifyCapped` | R0 | sticky |modifyValue| ≤ 1 |
| `testNoStaleCardIdsInContent` | R0 | no dangling refs after card rename |
| `testEffortBurnMovesToDiscard` | R1 | Effort → discardPile |
| `testEffortDoesNotSpendEnergy` | R1 | Effort не тратит energy |
| `testEffortDoesNotAffectFateDeck` | R1 | Effort не меняет Fate Deck |
| `testEffortBonusPassedToFateResolve` | R1 | effortBonus → CombatCalculator |
| `testEffortUndoReturnsCardToHand` | R1 | undo возвращает карту |
| `testCannotBurnSelectedCard` | R1 | нельзя сжечь selected card |
| `testEffortLimitRespected` | R1 | max 2 соблюдается |
| `testEffortDefaultZero` | R1 | без burn = effortBonus 0 |
| `testEffortDeterminism` | R1 | replay с seed → идентично |
| `testEffortMidCombatSaveLoad` | R1 | save/restore с Effort |
| `testSnapshotContainsEffortFields` | R1 | snapshot хранит все поля |
| `testRitualSceneUsesOnlyCombatSimulationAPI` | R2 | scene → только CombatSimulation |
| `testRitualSceneHasNoStrongEngineReference` | R2 | no strong ref to TwilightGameEngine |
| `testDragDropProducesCanonicalCommands` | R3 | drag → canonical API |
| `testDragDropDoesNotMutateECSDirectly` | R3 | drag path → no direct ECS mutation |
| `testDragDropControllerHasNoEngineImports` | R3 | DragDropController → only CombatSimulation protocol |
| `testLongPressDoesNotFireAfterDragStart` | R3 | gesture priority edge-case |
| `testFateRevealPreservesExistingDeterminism` | R6 | визуал не влияет на Fate |
| `testRitualCombatNoSystemRNGSources` | R6 | static scan: no random()/UUID()/Date() in RitualCombat/ |
| `testKeywordEffectConsumedOrDocumented` | R6 | bonusValue/special consumed или документированно отключены |
| `testResonanceAtmosphereIsPurePresentation` | R7 | controller read-only |
| `testAtmosphereControllerIsReadOnly` | R7 | no mutation calls |
| `testRitualSceneRestoresFromSnapshot` | R9 | UI восстановление из snapshot |
| `testBattleArenaDoesNotCallCommitPathWhenUsingRitualScene` | R9 | Arena sandbox → no commitExternalCombat |
| `testOldCombatSceneNotImportedInProduction` | R9 | deprecated не в production |
