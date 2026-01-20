# Investigator Pack Specification

> **Version:** 1.0
> **Status:** Active
> **Last Updated:** January 2026

---

## 1. Overview

### 1.1 Purpose

An Investigator Pack provides playable hero characters with their starting decks, abilities, and associated player cards. These packs focus on character customization and deck-building options.

### 1.2 Scope

This specification covers:
- Investigator pack structure and manifest requirements
- Hero definition schemas
- Card definition schemas
- Starting deck composition rules
- Functional and non-functional requirements

### 1.3 Terminology

| Term | Definition |
|------|------------|
| **Hero** | A playable character with stats and abilities |
| **Starting Deck** | The initial set of cards a hero begins with |
| **Hero Class** | The archetype defining hero playstyle |
| **Ability** | A special power unique to a hero |
| **Card** | A playable item in combat and events |

---

## 2. Functional Requirements

### 2.1 Core Functionality

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-INV-001 | Pack MUST define at least one hero | Required |
| FR-INV-002 | Each hero MUST have a valid starting deck | Required |
| FR-INV-003 | Pack MAY define additional player cards | Optional |
| FR-INV-004 | All cards in starting deck MUST exist | Required |
| FR-INV-005 | Pack MAY depend on other packs for cards | Optional |

### 2.2 Hero Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-HRO-001 | Hero MUST have unique ID | Required |
| FR-HRO-002 | Hero MUST have localized name and description | Required |
| FR-HRO-003 | Hero MUST belong to a hero class | Required |
| FR-HRO-004 | Hero MUST have base stats | Required |
| FR-HRO-005 | Hero MUST have a starting deck (min 6 cards) | Required |
| FR-HRO-006 | Hero SHOULD have a special ability | Recommended |
| FR-HRO-007 | Hero MAY have multiple abilities | Optional |
| FR-HRO-008 | Hero MAY have unlock conditions | Optional |

### 2.3 Card Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-CRD-001 | Card MUST have unique ID | Required |
| FR-CRD-002 | Card MUST have localized name | Required |
| FR-CRD-003 | Card MUST have a card type | Required |
| FR-CRD-004 | Card MUST have a rarity | Required |
| FR-CRD-005 | Card MUST define ownership rules | Required |
| FR-CRD-006 | Card MAY have special abilities | Optional |
| FR-CRD-007 | Card MAY have class restrictions | Optional |

### 2.4 Deck Building Rules

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-DEC-001 | Starting deck MUST have 6-12 cards | Required |
| FR-DEC-002 | Starting deck SHOULD match hero's playstyle | Recommended |
| FR-DEC-003 | Starting deck MAY have duplicate cards | Optional |
| FR-DEC-004 | Deck MUST respect card ownership rules | Required |

---

## 3. Non-Functional Requirements

### 3.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-PERF-001 | Pack load time | < 200ms |
| NFR-PERF-002 | Maximum heroes per pack | 20 |
| NFR-PERF-003 | Maximum cards per pack | 200 |
| NFR-PERF-004 | Maximum file size | 5MB |

### 3.2 Compatibility

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-COMP-001 | Core version compatibility | Semantic versioning |
| NFR-COMP-002 | Card availability check | Runtime validation |
| NFR-COMP-003 | Cross-pack card references | Via dependencies |

### 3.3 Balance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-BAL-001 | Hero stats must be within bounds | Validated |
| NFR-BAL-002 | Starting deck power level | Comparable to base heroes |
| NFR-BAL-003 | Ability cooldowns | Minimum 1 turn |

### 3.4 Accessibility

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-ACC-001 | Hero descriptions | Clear and informative |
| NFR-ACC-002 | Ability descriptions | Unambiguous effects |
| NFR-ACC-003 | Card text | Consistent terminology |

---

## 4. Data Schemas

### 4.1 Manifest Schema

```json
{
  "$schema": "investigator-pack-manifest-v1",
  "id": "string (required, unique, lowercase-hyphen)",
  "name": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "version": "SemanticVersion (required)",
  "type": "investigator (required)",
  "core_version_min": "SemanticVersion (required)",
  "core_version_max": "SemanticVersion | null",
  "dependencies": "PackDependency[] (optional)",
  "heroes_path": "string (required, relative path)",
  "cards_path": "string (optional, relative path)",
  "locales": "string[] (default: ['en'])",
  "localization_path": "string (optional)",
  "recommended_campaigns": "string[] (optional, campaign pack IDs)"
}
```

### 4.2 Hero Schema

```json
{
  "id": "string (required, unique)",
  "name": "string (required, display name)",
  "name_ru": "string (optional, Russian name)",
  "hero_class": "HeroClass (required)",
  "description": "string (required)",
  "description_ru": "string (optional)",
  "icon": "string (required, SF Symbol name)",
  "base_stats": "HeroStats (required)",
  "special_ability": "HeroAbility (required)",
  "passive_abilities": "HeroAbility[] (optional)",
  "starting_deck": "string[] (required, card IDs, min: 6)",
  "availability": "HeroAvailability (required)",
  "recommended_cards": "string[] (optional)",
  "lore": "LocalizedString (optional, background story)"
}
```

#### HeroClass

```
warrior | mage | ranger | priest | shadow | alchemist | bard | monk
```

Each class defines a playstyle:

| Class | Focus | Typical Stats |
|-------|-------|---------------|
| warrior | Melee combat, defense | High strength, health |
| mage | Spells, area effects | High wisdom |
| ranger | Ranged, mobility | High agility |
| priest | Healing, support | High faith, wisdom |
| shadow | Stealth, critical hits | High agility |
| alchemist | Items, buffs | Balanced |
| bard | Buffs, debuffs | High charisma |
| monk | Balance, combos | Balanced |

#### HeroStats

```json
{
  "health": "integer (required, range: 8-15)",
  "faith": "integer (required, range: 1-10)",
  "strength": "integer (optional, range: 1-5)",
  "agility": "integer (optional, range: 1-5)",
  "wisdom": "integer (optional, range: 1-5)",
  "charisma": "integer (optional, range: 1-5)"
}
```

#### HeroAbility

```json
{
  "id": "string (required)",
  "name": "string (required)",
  "name_ru": "string (optional)",
  "description": "string (required)",
  "description_ru": "string (optional)",
  "ability_type": "active | passive | triggered (required)",
  "cooldown": "integer (optional, turns, min: 1)",
  "uses_per_combat": "integer | null (null = unlimited)",
  "faith_cost": "integer (optional, default: 0)",
  "effect": "AbilityEffect (required)",
  "icon": "string (optional, SF Symbol)"
}
```

#### AbilityEffect

```json
{
  "effect_type": "damage | heal | buff | debuff | draw | discard | special",
  "target": "self | enemy | all_enemies | ally | all",
  "value": "integer | null",
  "duration": "integer (turns, optional)",
  "modifier_type": "string (optional, for buffs/debuffs)",
  "special_effect": "string (optional, custom effect ID)"
}
```

#### HeroAvailability

```json
{
  "type": "always | unlock | purchase | campaign",
  "unlock_condition": "UnlockCondition | null (if type = unlock)",
  "campaign_id": "string | null (if type = campaign)",
  "purchase_cost": "{ currency: integer } | null (if type = purchase)"
}
```

#### UnlockCondition

```json
{
  "condition_type": "complete_quest | defeat_boss | reach_day | collect_cards",
  "target_id": "string (what to complete)",
  "target_count": "integer (default: 1)"
}
```

### 4.3 Card Schema

```json
{
  "id": "string (required, unique)",
  "name": "string (required)",
  "name_ru": "string (optional)",
  "card_type": "CardType (required)",
  "rarity": "CardRarity (required)",
  "description": "string (required)",
  "description_ru": "string (optional)",
  "icon": "string (required, SF Symbol)",
  "expansion_set": "string (required, pack identifier)",
  "ownership": "CardOwnership (required)",
  "class_restriction": "HeroClass | null (optional)",
  "abilities": "CardAbility[] (optional)",
  "faith_cost": "integer (default: 0)",
  "balance": "light | dark | neutral (default: neutral)",
  "power": "integer (optional, for attack cards)",
  "defense": "integer (optional, for defense cards)",
  "health_effect": "integer (optional, for healing cards)"
}
```

#### CardType

```
attack | defense | skill | item | spell | ritual | blessing | curse
```

| Type | Description |
|------|-------------|
| attack | Deals damage to enemies |
| defense | Blocks incoming damage |
| skill | Utility effects |
| item | Consumable or equipment |
| spell | Magical effects |
| ritual | Powerful multi-turn effects |
| blessing | Positive effects from faith |
| curse | Negative effects |

#### CardRarity

```
common | uncommon | rare | epic | legendary
```

| Rarity | Drop Rate | Starting Deck |
|--------|-----------|---------------|
| common | 50% | Allowed |
| uncommon | 30% | Allowed |
| rare | 15% | Limited (max 2) |
| epic | 4% | Limited (max 1) |
| legendary | 1% | Not allowed |

#### CardOwnership

```json
{
  "type": "universal | class_specific | hero_specific | unlockable",
  "hero_id": "string | null (if hero_specific)",
  "hero_class": "HeroClass | null (if class_specific)",
  "unlock_condition": "UnlockCondition | null (if unlockable)"
}
```

#### CardAbility

```json
{
  "id": "string (required)",
  "name": "string (required)",
  "trigger": "on_play | on_discard | on_draw | passive",
  "effect": "AbilityEffect (required)",
  "condition": "string | null (optional, when ability triggers)"
}
```

---

## 5. Validation Rules

### 5.1 Hero Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-HRO-001 | Hero ID must be unique | Error |
| VAL-HRO-002 | Hero class must be valid | Error |
| VAL-HRO-003 | Base stats must be within bounds | Error |
| VAL-HRO-004 | Starting deck must have 6-12 cards | Error |
| VAL-HRO-005 | All starting deck cards must exist | Error |
| VAL-HRO-006 | Special ability must be defined | Error |
| VAL-HRO-007 | Icon must be valid SF Symbol | Warning |

### 5.2 Card Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-CRD-001 | Card ID must be unique | Error |
| VAL-CRD-002 | Card type must be valid | Error |
| VAL-CRD-003 | Rarity must be valid | Error |
| VAL-CRD-004 | Attack cards must have power | Warning |
| VAL-CRD-005 | Defense cards must have defense | Warning |
| VAL-CRD-006 | Faith cost must be non-negative | Error |

### 5.3 Deck Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-DEC-001 | All cards must be available to hero | Error |
| VAL-DEC-002 | Legendary cards not in starting deck | Error |
| VAL-DEC-003 | Max 2 rare cards in starting deck | Warning |
| VAL-DEC-004 | Max 1 epic card in starting deck | Warning |

### 5.4 Localization Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-LOC-001 | Name must not be empty | Error |
| VAL-LOC-002 | Description must not be empty | Error |
| VAL-LOC-003 | Russian translation recommended | Info |

---

## 6. API Contract

### 6.1 Loading Interface

```swift
protocol InvestigatorPackLoader {
    func loadInvestigators(from url: URL) throws -> InvestigatorContent
    func validate(at url: URL) -> ValidationResult
}

struct InvestigatorContent {
    let heroes: [String: StandardHeroDefinition]
    let cards: [String: StandardCardDefinition]
}
```

### 6.2 Hero Provider Interface

```swift
protocol HeroProvider {
    func getHero(id: String) -> StandardHeroDefinition?
    func getAllHeroes() -> [StandardHeroDefinition]
    func getHeroes(forClass: HeroClass) -> [StandardHeroDefinition]
    func getAvailableHeroes() -> [StandardHeroDefinition]
    func getStartingDeck(forHero: String) -> [StandardCardDefinition]
}
```

### 6.3 Card Provider Interface

```swift
protocol CardProvider {
    func getCard(id: String) -> StandardCardDefinition?
    func getAllCards() -> [StandardCardDefinition]
    func getCards(ofType: CardType) -> [StandardCardDefinition]
    func getCards(forClass: HeroClass) -> [StandardCardDefinition]
    func getCards(forHero: String) -> [StandardCardDefinition]
}
```

### 6.4 Registry Integration

```swift
extension ContentRegistry {
    func loadInvestigatorPack(from url: URL) throws -> LoadedPack
    func getHero(id: String) -> StandardHeroDefinition?
    func getCard(id: String) -> StandardCardDefinition?
    func getStartingDeck(forHero: String) -> [StandardCardDefinition]
}
```

---

## 7. Extension Points

### 7.1 Custom Hero Classes

New hero classes can be defined by extending the HeroClass enum. Engine must be updated to support new classes, but packs can prepare hero data for future classes.

### 7.2 Custom Card Types

Card types can be extended. Unknown card types are handled as "skill" type by default.

### 7.3 Custom Abilities

Custom ability effects can be registered:

```swift
AbilityRegistry.register("my_custom_effect") { context in
    // Custom effect implementation
}
```

### 7.4 Card Synergies

Cards can reference synergies with other cards:

```json
{
  "synergies": [
    { "card_id": "flame_strike", "bonus": "+2 damage" }
  ]
}
```

---

## 8. Best Practices

### 8.1 Hero Design

1. **Clear Identity**: Each hero should have a distinct playstyle
2. **Balanced Stats**: Total stat points should be similar across heroes
3. **Thematic Abilities**: Abilities should match hero's lore
4. **Starting Deck Synergy**: Cards should work well together

### 8.2 Card Design

1. **Clear Effects**: Card effects should be unambiguous
2. **Power Budget**: Higher costs = stronger effects
3. **Class Identity**: Class-specific cards should reinforce playstyle
4. **Combo Potential**: Some cards should synergize

### 8.3 Naming Conventions

```
Heroes:    {class}_{name}         e.g., warrior_ragnar
Cards:     {type}_{name}          e.g., strike_flame
Abilities: {hero}_{ability}       e.g., ragnar_battle_cry
```

---

## 9. Examples

### 9.1 Minimal Investigator Pack

```json
// manifest.json
{
  "id": "new-hero-pack",
  "name": { "en": "New Hero Pack" },
  "version": "1.0.0",
  "type": "investigator",
  "core_version_min": "1.0.0",
  "heroes_path": "heroes.json"
}
```

### 9.2 Complete Hero Definition

```json
{
  "id": "warrior_ragnar",
  "name": "Ragnar the Bold",
  "name_ru": "Рагнар Смелый",
  "hero_class": "warrior",
  "description": "A fearless warrior from the northern lands.",
  "description_ru": "Бесстрашный воин с северных земель.",
  "icon": "shield.lefthalf.filled",
  "base_stats": {
    "health": 12,
    "faith": 3,
    "strength": 4,
    "agility": 2,
    "wisdom": 1
  },
  "special_ability": {
    "id": "ragnar_battle_cry",
    "name": "Battle Cry",
    "name_ru": "Боевой Клич",
    "description": "Boost attack power by 50% for 2 turns.",
    "description_ru": "Увеличивает силу атаки на 50% на 2 хода.",
    "ability_type": "active",
    "cooldown": 3,
    "effect": {
      "effect_type": "buff",
      "target": "self",
      "value": 50,
      "duration": 2,
      "modifier_type": "attack_percent"
    }
  },
  "starting_deck": [
    "strike_basic",
    "strike_basic",
    "strike_basic",
    "defend_basic",
    "defend_basic",
    "rage_strike"
  ],
  "availability": {
    "type": "always"
  }
}
```

---

## 10. Related Documents

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - General pack guide
- [SPEC_CAMPAIGN_PACK.md](./SPEC_CAMPAIGN_PACK.md) - Campaign pack spec
- [SPEC_BALANCE_PACK.md](./SPEC_BALANCE_PACK.md) - Balance pack spec
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Engine architecture

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-20 | Claude | Initial specification |
