# Combat Module

## Обзор

Модуль боя обеспечивает детализированный расчёт боевых столкновений с полной прозрачностью результатов для игрока.

## Ключевые файлы

| Файл | Назначение |
|------|------------|
| `CombatCalculator.swift` | Основной калькулятор боя |

## CombatCalculator

### Структуры результата

```swift
struct CombatResult {
    let attackRoll: AttackRoll      // Детали броска атаки
    let damageCalculation: DamageCalculation?  // Расчёт урона (если попал)
    let isHit: Bool                 // Попал ли удар
    let specialEffects: [CombatEffect]  // Спецэффекты
}

struct AttackRoll {
    let baseStrength: Int           // Базовая сила игрока
    let diceRolls: [Int]            // Результаты бросков d6
    let bonusDice: Int              // Бонусные кубики
    let bonusDamage: Int            // Бонусный урон
    let modifiers: [CombatModifier] // Модификаторы атаки

    var total: Int                  // Итоговое значение атаки
}

struct DamageCalculation {
    let baseDamage: Int             // Базовый урон
    let modifiers: [CombatModifier] // Модификаторы урона
    let finalDamage: Int            // Итоговый урон
}
```

### Модификаторы

```swift
enum CombatModifierSource {
    case weapon          // От оружия
    case spell           // От заклинания
    case heroAbility     // От способности героя
    case curse           // От проклятия
    case blessing        // От благословения
    case terrain         // От местности
    case enemy           // От особенности врага
}

struct CombatModifier {
    let source: CombatModifierSource
    let value: Int
    let description: String
}
```

## Детерминизм

**ВАЖНО:** Все броски кубиков используют `WorldRNG.shared.nextInt(in: 1...6)` для обеспечения детерминизма при фиксированном seed.

```swift
// До (недетерминировано):
diceRolls.append(Int.random(in: 1...6))

// После (детерминировано):
diceRolls.append(WorldRNG.shared.nextInt(in: 1...6))
```

Это позволяет:
- Воспроизводить бои при regression-тестировании
- Реплеить игровые сессии
- Отлаживать баланс с фиксированными seed

## Формула расчёта

```
Атака = Сила + sum(d6 × кол-во_кубиков) + бонусы - штрафы

Попадание: Атака >= Защита_монстра

Урон = max(1, Атака - Защита + 2 + модификаторы_урона)
```

## Модификаторы героев

| Герой | Способность | Эффект |
|-------|-------------|--------|
| Ranger | Выслеживание | +1 кубик при первой атаке |
| Warrior | Ярость | +бонус урона при low HP |
| Priest | Благословение | Нет штрафа от проклятий |

## Проклятия

| Проклятие | Эффект |
|-----------|--------|
| Weakness | -1 к урону |
| ShadowOfNav | -1 к атаке |

## Интеграция

```swift
let result = CombatCalculator.calculate(
    player: player,
    monsterDefense: monster.defense,
    monsterMaxHP: monster.health,
    monsterCurrentHP: currentHP,
    bonusDice: weaponBonusDice,
    bonusDamage: spellBonusDamage,
    isFirstAttack: turnState.isFirstAttack
)

// Показать игроку детали
print("Бросок: \(result.attackRoll.diceRolls)")
print("Модификаторы: \(result.attackRoll.modifiers)")
print("Итого: \(result.attackRoll.total)")
if result.isHit {
    print("Урон: \(result.damageCalculation!.finalDamage)")
}
```

## Тесты

- `CombatSystemTests.swift` — базовые расчёты
- `CombatModifiersTests.swift` — модификаторы и проклятия
- `WorldStateTests.testWorldDeterminismWithSeed()` — детерминизм

---

**Последнее обновление:** 19 января 2026
