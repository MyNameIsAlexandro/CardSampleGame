# СПЕЦИФИКАЦИЯ БОЕВОЙ И ДИПЛОМАТИЧЕСКОЙ СИСТЕМЫ v2.0

**Проект:** ECHO: Legends of the Veil (Сумрачные Пределы)
**Модуль:** Disposition Combat — единая шкала конфликтов
**Статус:** Draft (Disposition Combat v2.5 — концептуально готов к MVP)
**Дата:** 18 февраля 2026

**Заменяет:** COMBAT_DIPLOMACY_SPEC v1.1 (HP/WP Dual Track) → [архив](../Archive/COMBAT_DIPLOMACY_SPEC_v1.1.md)
**Source of Truth:** [`docs/plans/2026-02-18-disposition-combat-design.md`](../../docs/plans/2026-02-18-disposition-combat-design.md) (полный дизайн-документ v2.5)
**Зависимости:** `PROJECT_BIBLE.md` (Столпы), `ENGINE_ARCHITECTURE.md`, `EXPLORATION_CORE_DESIGN.md`

---

## Что изменилось (v1.1 → v2.0)

| Аспект | Было (v1.1 — Dual Track) | Стало (v2.0 — Disposition) |
|--------|--------------------------|---------------------------|
| **Модель конфликта** | Два отдельных HP/WP бара | Единая шкала -100…+100 |
| **Пути победы** | Kill (HP→0) / Pacify (WP→0) | Уничтожить (-100) / Подчинить (+100) |
| **Ввод игрока** | Кнопки Атака/Влияние/Ожидание | Drag-and-drop: Strike/Influence/Sacrifice |
| **Формула урона** | Stat + Card + Effort + FateCard - Armor | effective_power = min(raw_power, 25) через momentum |
| **Momentum** | Нет (переключение через эскалацию/деэскалацию) | Streak bonus + switch penalty (детерминистичный) |
| **Fate keywords** | 5 универсальных (по контексту) | 5 disposition-зависимых (Surge/Shadow/Ward/Focus/Echo) |
| **Вражеские режимы** | Статичные behavior rules | Survival / Desperation / Weakened (динамический порог) |
| **Sacrifice** | Нет | Exhaust карту → heal + enemy buff |
| **Hard cap** | Нет | effective_power ≤ 25 (quarter of scale) |

---

## 1. Core Model — Disposition Track

```
-100 ←————————— 0 ——————————→ +100
 УНИЧТОЖЕН     НЕЙТРАЛЕН      ПОДЧИНЁН
```

Единая шкала вместо двух независимых баров. Каждый край — победа с разной ценой и последствиями.

**Подробности:** Design doc §3 (Core Loop)

---

## 2. Card Play — 3 режима через drag

| Действие | Жест | Эффект | Карта после |
|----------|------|--------|-------------|
| **Strike** | Drag → на врага | disposition -= effective_power | Discard |
| **Influence** | Drag → на алтарь | disposition += effective_power | Discard |
| **Sacrifice** | Drag → на костёр | Heal hero + enemy buff | Exhaust (навсегда) |

**Подробности:** Design doc §4 (Card Play)

---

## 3. Формула effective_power

```
surged_base     = fate.keyword == .surge ? (base_power * 3 / 2) : base_power
fate_modifier   = fateCard.baseModifier + fateCard.keyword.contextEffect(disposition)
raw_power       = surged_base + streak_bonus + threat_bonus - switch_penalty + fate_modifier
effective_power = min(raw_power, 25)   // hard cap
```

**streak_bonus** = max(0, streakCount - 1)
**threat_bonus** = 2 if (lastAction == .strike AND current == .influence)
**switch_penalty** = max(0, streakCount - 2) if switching AND streakCount >= 3

**Подробности:** Design doc §5.1 (Momentum)

---

## 4. Fate Keywords (Disposition-зависимые)

| Keyword | Базовый эффект | При disposition < -30 | При disposition > +30 |
|---------|---------------|----------------------|----------------------|
| **Surge** | +50% base_power | То же | То же |
| **Shadow** | -1 | switch_penalty += 2 | Враг теряет Defend |
| **Ward** | 0 | Backlash отменяется | Backlash отменяется |
| **Focus** | +1 | Ignore enemy Defend | Ignore enemy Provoke |
| **Echo** | 0 | Бесплатный повтор (не после Sacrifice) | Бесплатный повтор |

**Echo safety:** не срабатывает после Sacrifice, не тянет новую Fate, продолжает streak.

**Подробности:** Design doc §5.3 (Fate Keywords)

---

## 5. Resonance — контекст меняет правила

| Зона Resonance | Strike | Influence | Sacrifice |
|---------------|--------|-----------|-----------|
| **Навь** (тьма) | +2 бонус, враг +1 ATK | -1 штраф | На 1 дешевле |
| **Правь** (свет) | Backlash: -1 HP | +2 бонус | Рискован: exhaust 2 карты |
| **Явь** (баланс) | Нейтрально | Нейтрально | Нейтрально |

**Подробности:** Design doc §5.2 (Resonance)

---

## 6. Enemy System

### 6.1 Динамические режимы

| Режим | Условие | Поведение | Telegraph |
|-------|---------|-----------|-----------|
| **Survival** | disposition < -threshold | Агрессия, rage-действия | Красная аура |
| **Desperation** | disposition > +threshold | Мольба, plea-действия | Синяя аура |
| **Weakened** | swing ±30 за 2 хода | Ослаблен, выбирает слабые действия | Серая аура + "?" |

**Dynamic thresholds:** `survivalThreshold = -(65 + seed_hash % 11)`, hysteresis 1 turn.

### 6.2 Systemic Asymmetry

Каждый враг имеет `vulnerabilities` (массив) × текущая `ResonanceZone` → модификаторы из 3D lookup таблицы. Это предотвращает запоминание "всегда бей X".

**Подробности:** Design doc §7 (Enemy System), §8 (Anti-Meta)

---

## 7. Структуры данных (Tech Spec)

Полная спецификация типов — Design doc §11 (Tech Spec). Ключевые:

```swift
enum DispositionCombatAction {
    case strike(cardId: String, targetId: String)
    case influence(cardId: String)
    case sacrifice(cardId: String)
    case endTurn
}

struct CombatSnapshot: Codable {
    let disposition: Int          // -100...+100
    let heroHP: Int
    let streakType: ActionType?
    let streakCount: Int
    let enemyMode: EnemyMode
    let fateDeckState: FateDeckSnapshot
    let lastFateKeyword: FateKeyword?
    // ... fingerprint для replay
}
```

---

## 8. Fate Deck (общая система — без изменений)

Fate Deck остаётся глобальной для кампании. Анатомия карты (value/suit/keyword/intensity), snapshot-обмен с Encounter Engine, resolution order — без изменений от v1.1.

**FateKeyword enum:** surge, focus, echo, shadow, ward (закрытый набор из 5 значений).

**Подробности:** `ENCOUNTER_SYSTEM_DESIGN.md` §5

---

## 9. Balance Pack Keys

### Disposition Combat

| Ключ | По умолчанию | Описание |
|------|--------------|----------|
| `combat.disposition.hardCap` | 25 | Max effective_power per action |
| `combat.disposition.switchPenaltyThreshold` | 3 | Streak count before penalty applies |
| `combat.disposition.threatBonus` | 2 | Bonus for Strike→Influence switch |
| `combat.disposition.sacrificeHealBase` | 3 | Base heal from Sacrifice |
| `combat.disposition.sacrificeEnemyBuff` | 2 | Enemy ATK buff from Sacrifice |

### Resonance & Fate (без изменений от v1.1)

| Ключ | По умолчанию | Описание |
|------|--------------|----------|
| `combat.balance.matchMultiplier` | 1.5 | Множитель Match Bonus |
| `fate.balance.synergyMultiplier` | 0.5 | Множитель сдвига при Synergy |
| `fate.balance.dissonanceMultiplier` | 1.5 | Множитель сдвига при Dissonance |

### Enemy Modes

| Ключ | По умолчанию | Описание |
|------|--------------|----------|
| `combat.enemy.survivalThresholdBase` | 65 | Base for survival threshold |
| `combat.enemy.survivalThresholdRange` | 11 | Seed-based range added to base |
| `combat.enemy.hysteresisTurns` | 1 | Turns before mode can switch again |
| `combat.enemy.weakenedSwingThreshold` | 30 | Disposition swing to trigger Weakened |

---

## 10. Gate-тесты (35+)

Полный список — Design doc §10.2. Категории:

| Категория | Кол-во | Примеры |
|-----------|--------|---------|
| Disposition mechanics | 6 | Шкала -100…+100, hard cap 25 |
| Momentum system | 5 | Streak bonus, switch penalty, threat bonus |
| Card play modes | 4 | Strike/Influence/Sacrifice contracts |
| Fate keywords | 5 | Surge +50%, Echo not after Sacrifice |
| Enemy modes | 5 | Survival/Desperation/Weakened transitions |
| Resonance effects | 5 | Zone modifiers, backlash cancellation |
| Anti-meta | 5 | Vulnerability × Resonance 3D lookup |

**Stress-test scenarios:** 5 сценариев (Design doc §10.3)
**Simulation requirements:** 5 agent types × 6 acceptance metrics (Design doc §10.4)

---

## Appendix: Auditor Response Matrix

Все аудиторские замечания и их покрытие существующими механизмами — Design doc §12.

**Verdict:** v2.5 — концептуально готова к MVP. Можно переходить к прототипированию.

---

**Версия документа:** 2.0
**Дата:** 18 февраля 2026
**Статус:** Draft (awaiting implementation)
