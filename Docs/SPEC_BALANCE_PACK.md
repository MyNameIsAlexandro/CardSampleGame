# Balance Pack Specification

> **Version:** 1.0
> **Status:** Active
> **Last Updated:** January 2026

---

## 1. Overview

### 1.1 Purpose

A Balance Pack provides game configuration without adding new content. It adjusts numbers, weights, costs, and other tuning parameters to modify game difficulty, pacing, and feel.

### 1.2 Scope

This specification covers:
- Balance pack structure and manifest
- Configuration categories (resources, pressure, time, combat, economy)
- Parameter bounds and validation
- Difficulty presets
- Mod compatibility

### 1.3 Terminology

| Term | Definition |
|------|------------|
| **Balance** | Numerical configuration affecting gameplay |
| **Tuning** | Fine-tuning of existing parameters |
| **Difficulty** | Overall game challenge level |
| **Parameter** | Individual configurable value |
| **Override** | Replacement of default values |

---

## 2. Functional Requirements

### 2.1 Core Functionality

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-BAL-001 | Pack MUST provide balance.json | Required |
| FR-BAL-002 | Pack MUST NOT introduce new content | Required |
| FR-BAL-003 | Pack MAY override any parameter | Optional |
| FR-BAL-004 | Unspecified parameters use defaults | Required |
| FR-BAL-005 | Pack MAY define difficulty presets | Optional |

### 2.2 Resource Configuration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-RES-001 | Pack MAY configure max health | Optional |
| FR-RES-002 | Pack MAY configure starting resources | Optional |
| FR-RES-003 | Pack MAY configure regeneration rates | Optional |
| FR-RES-004 | Resource values MUST be positive | Required |

### 2.3 Pressure Configuration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-PRS-001 | Pack MAY configure pressure thresholds | Optional |
| FR-PRS-002 | Pack MAY configure pressure rates | Optional |
| FR-PRS-003 | Pressure values MUST be 0-100 | Required |
| FR-PRS-004 | Thresholds MUST be ordered | Required |

### 2.4 Time Configuration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-TIM-001 | Pack MAY configure action costs | Optional |
| FR-TIM-002 | Pack MAY configure day length | Optional |
| FR-TIM-003 | Time values MUST be positive | Required |

### 2.5 Combat Configuration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-CMB-001 | Pack MAY configure damage formulas | Optional |
| FR-CMB-002 | Pack MAY configure defense mechanics | Optional |
| FR-CMB-003 | Pack MAY configure card draw rules | Optional |

### 2.6 End Conditions

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-END-001 | Pack MAY modify loss conditions | Optional |
| FR-END-002 | Pack MAY modify victory conditions | Optional |
| FR-END-003 | At least one victory condition required | Required |

---

## 3. Non-Functional Requirements

### 3.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-PERF-001 | Config load time | < 50ms |
| NFR-PERF-002 | Maximum file size | 100KB |
| NFR-PERF-003 | Parameter lookup | O(1) |

### 3.2 Compatibility

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-COMP-001 | Core version | Semantic versioning |
| NFR-COMP-002 | Campaign compatibility | Any campaign |
| NFR-COMP-003 | Investigator compatibility | Any investigator |

### 3.3 Safety

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-SAF-001 | Parameter bounds | Validated |
| NFR-SAF-002 | Division by zero | Prevented |
| NFR-SAF-003 | Overflow protection | Enforced |

### 3.4 Usability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-USE-001 | Clear parameter names | Self-documenting |
| NFR-USE-002 | Difficulty presets | User-friendly |
| NFR-USE-003 | Default values | Always provided |

---

## 4. Data Schemas

### 4.1 Manifest Schema

```json
{
  "$schema": "balance-pack-manifest-v1",
  "id": "string (required, unique)",
  "name": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "version": "SemanticVersion (required)",
  "type": "balance (required)",
  "core_version_min": "SemanticVersion (required)",
  "core_version_max": "SemanticVersion | null",
  "balance_path": "string (required, relative path)",
  "difficulty_level": "easy | normal | hard | nightmare (optional)",
  "tags": "string[] (optional, for filtering)"
}
```

### 4.2 Balance Configuration Schema

```json
{
  "resources": "ResourceConfiguration (optional)",
  "pressure": "PressureConfiguration (optional)",
  "anchor": "AnchorConfiguration (optional)",
  "time": "TimeConfiguration (optional)",
  "combat": "CombatConfiguration (optional)",
  "economy": "EconomyConfiguration (optional)",
  "end_conditions": "EndConditionConfiguration (optional)",
  "difficulty_modifiers": "DifficultyModifiers (optional)"
}
```

### 4.3 Resource Configuration

```json
{
  "max_health": {
    "type": "integer",
    "default": 10,
    "range": [5, 20],
    "description": "Maximum player health"
  },
  "starting_health": {
    "type": "integer",
    "default": 10,
    "range": [1, "max_health"],
    "description": "Health at game start"
  },
  "max_faith": {
    "type": "integer",
    "default": 10,
    "range": [3, 15],
    "description": "Maximum faith points"
  },
  "starting_faith": {
    "type": "integer",
    "default": 3,
    "range": [0, "max_faith"],
    "description": "Faith at game start"
  },
  "health_regen_per_rest": {
    "type": "integer",
    "default": 3,
    "range": [1, 10],
    "description": "Health restored when resting"
  },
  "faith_per_anchor_visit": {
    "type": "integer",
    "default": 1,
    "range": [0, 5],
    "description": "Faith gained at anchors"
  },
  "faith_per_combat_win": {
    "type": "integer",
    "default": 1,
    "range": [0, 5],
    "description": "Faith gained from combat"
  }
}
```

### 4.4 Pressure Configuration

```json
{
  "starting_pressure": {
    "type": "integer",
    "default": 30,
    "range": [0, 100],
    "description": "Initial world pressure"
  },
  "max_pressure": {
    "type": "integer",
    "default": 100,
    "range": [50, 100],
    "description": "Maximum pressure (loss condition)"
  },
  "pressure_per_day": {
    "type": "integer",
    "default": 5,
    "range": [0, 20],
    "description": "Pressure increase per day"
  },
  "pressure_per_breach": {
    "type": "integer",
    "default": 10,
    "range": [0, 30],
    "description": "Pressure from region breach"
  },
  "pressure_reduction_per_strengthen": {
    "type": "integer",
    "default": 5,
    "range": [0, 20],
    "description": "Pressure reduced when strengthening anchor"
  },
  "thresholds": {
    "low": {
      "type": "integer",
      "default": 30,
      "range": [10, 40],
      "description": "Low pressure threshold"
    },
    "medium": {
      "type": "integer",
      "default": 50,
      "range": [30, 60],
      "description": "Medium pressure threshold"
    },
    "high": {
      "type": "integer",
      "default": 70,
      "range": [50, 80],
      "description": "High pressure threshold"
    },
    "critical": {
      "type": "integer",
      "default": 90,
      "range": [70, 95],
      "description": "Critical pressure threshold"
    }
  }
}
```

### 4.5 Anchor Configuration

```json
{
  "max_integrity": {
    "type": "integer",
    "default": 100,
    "range": [50, 200],
    "description": "Maximum anchor integrity"
  },
  "default_strengthen_amount": {
    "type": "integer",
    "default": 20,
    "range": [5, 50],
    "description": "Integrity restored per strengthen"
  },
  "default_strengthen_cost": {
    "type": "integer",
    "default": 5,
    "range": [1, 15],
    "description": "Faith cost to strengthen"
  },
  "stable_threshold": {
    "type": "integer",
    "default": 70,
    "range": [50, 90],
    "description": "Integrity for stable state"
  },
  "borderland_threshold": {
    "type": "integer",
    "default": 30,
    "range": [10, 50],
    "description": "Integrity for borderland state"
  },
  "breach_threshold": {
    "type": "integer",
    "default": 0,
    "range": [0, 20],
    "description": "Integrity for breach state"
  },
  "decay_per_turn": {
    "type": "integer",
    "default": 5,
    "range": [0, 15],
    "description": "Integrity lost per day"
  },
  "decay_in_breach": {
    "type": "integer",
    "default": 10,
    "range": [5, 25],
    "description": "Extra decay when breached"
  }
}
```

### 4.6 Time Configuration

```json
{
  "units_per_day": {
    "type": "integer",
    "default": 24,
    "range": [12, 48],
    "description": "Time units in one day"
  },
  "starting_time": {
    "type": "integer",
    "default": 8,
    "range": [0, "units_per_day"],
    "description": "Starting time of day"
  },
  "travel_cost": {
    "type": "integer",
    "default": 4,
    "range": [1, 12],
    "description": "Time to travel between regions"
  },
  "explore_cost": {
    "type": "integer",
    "default": 2,
    "range": [1, 8],
    "description": "Time to explore current region"
  },
  "rest_cost": {
    "type": "integer",
    "default": 8,
    "range": [4, 16],
    "description": "Time to rest"
  },
  "combat_cost": {
    "type": "integer",
    "default": 2,
    "range": [1, 6],
    "description": "Time for combat"
  },
  "strengthen_cost": {
    "type": "integer",
    "default": 4,
    "range": [2, 8],
    "description": "Time to strengthen anchor"
  }
}
```

### 4.7 Combat Configuration

```json
{
  "base_damage_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Global damage multiplier"
  },
  "defense_effectiveness": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Defense reduction multiplier"
  },
  "starting_hand_size": {
    "type": "integer",
    "default": 5,
    "range": [3, 7],
    "description": "Cards drawn at combat start"
  },
  "cards_per_turn": {
    "type": "integer",
    "default": 1,
    "range": [1, 3],
    "description": "Cards drawn each turn"
  },
  "max_hand_size": {
    "type": "integer",
    "default": 10,
    "range": [5, 15],
    "description": "Maximum cards in hand"
  },
  "enemy_damage_scaling": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Enemy damage multiplier"
  },
  "enemy_health_scaling": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 3.0],
    "description": "Enemy health multiplier"
  },
  "critical_hit_chance": {
    "type": "float",
    "default": 0.1,
    "range": [0.0, 0.3],
    "description": "Base critical hit chance"
  },
  "critical_hit_multiplier": {
    "type": "float",
    "default": 2.0,
    "range": [1.5, 3.0],
    "description": "Critical hit damage multiplier"
  }
}
```

### 4.8 Economy Configuration

```json
{
  "card_acquisition_enabled": {
    "type": "boolean",
    "default": true,
    "description": "Allow acquiring new cards"
  },
  "faith_cost_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Card faith cost multiplier"
  },
  "event_reward_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Event rewards multiplier"
  },
  "combat_reward_multiplier": {
    "type": "float",
    "default": 1.0,
    "range": [0.5, 2.0],
    "description": "Combat rewards multiplier"
  }
}
```

### 4.9 End Condition Configuration

```json
{
  "death_health": {
    "type": "integer",
    "default": 0,
    "range": [0, 0],
    "description": "Health that triggers death (always 0)"
  },
  "pressure_loss": {
    "type": "integer",
    "default": 100,
    "range": [80, 100],
    "description": "Pressure that triggers loss"
  },
  "victory_quests": {
    "type": "string[]",
    "default": [],
    "description": "Quests required for victory"
  },
  "max_days": {
    "type": "integer | null",
    "default": null,
    "range": [10, 100],
    "description": "Maximum days (null = unlimited)"
  },
  "all_anchors_saved": {
    "type": "boolean",
    "default": false,
    "description": "Win if all anchors stabilized"
  }
}
```

### 4.10 Difficulty Modifiers

```json
{
  "easy": {
    "health_multiplier": 1.5,
    "damage_taken_multiplier": 0.75,
    "faith_multiplier": 1.5,
    "pressure_multiplier": 0.75,
    "enemy_health_multiplier": 0.8
  },
  "normal": {
    "health_multiplier": 1.0,
    "damage_taken_multiplier": 1.0,
    "faith_multiplier": 1.0,
    "pressure_multiplier": 1.0,
    "enemy_health_multiplier": 1.0
  },
  "hard": {
    "health_multiplier": 0.9,
    "damage_taken_multiplier": 1.25,
    "faith_multiplier": 0.8,
    "pressure_multiplier": 1.5,
    "enemy_health_multiplier": 1.3
  },
  "nightmare": {
    "health_multiplier": 0.75,
    "damage_taken_multiplier": 1.5,
    "faith_multiplier": 0.6,
    "pressure_multiplier": 2.0,
    "enemy_health_multiplier": 1.5
  }
}
```

---

## 5. Validation Rules

### 5.1 Parameter Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-PRM-001 | All values must be within defined ranges | Error |
| VAL-PRM-002 | Starting values cannot exceed maximums | Error |
| VAL-PRM-003 | Thresholds must be properly ordered | Error |
| VAL-PRM-004 | Multipliers must be positive | Error |
| VAL-PRM-005 | Integer values must be integers | Error |
| VAL-PRM-006 | Float precision max 2 decimals | Warning |

### 5.2 Consistency Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-CON-001 | starting_health <= max_health | Error |
| VAL-CON-002 | starting_faith <= max_faith | Error |
| VAL-CON-003 | low < medium < high < critical (thresholds) | Error |
| VAL-CON-004 | breach < borderland < stable (anchor) | Error |
| VAL-CON-005 | starting_time < units_per_day | Error |

### 5.3 Gameplay Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-GAM-001 | Game must be winnable | Warning |
| VAL-GAM-002 | Pressure growth cannot be negative | Warning |
| VAL-GAM-003 | Rest must restore some health | Warning |
| VAL-GAM-004 | At least one victory condition | Error |

---

## 6. API Contract

### 6.1 Configuration Interface

```swift
protocol BalanceConfigurationProvider {
    func getValue<T>(_ key: String) -> T?
    func getValue<T>(_ key: String, default: T) -> T
    func getSection(_ name: String) -> [String: Any]?
}
```

### 6.2 Balance Configuration Structure

```swift
struct BalanceConfiguration: Codable {
    let resources: ResourceConfiguration
    let pressure: PressureConfiguration
    let anchor: AnchorConfiguration
    let time: TimeConfiguration
    let combat: CombatConfiguration
    let economy: EconomyConfiguration
    let endConditions: EndConditionConfiguration
    let difficultyModifiers: DifficultyModifiers?

    static let `default`: BalanceConfiguration
}
```

### 6.3 Registry Integration

```swift
extension ContentRegistry {
    func loadBalancePack(from url: URL) throws -> LoadedPack
    func getBalanceConfig() -> BalanceConfiguration?
    func applyDifficultyModifiers(_ difficulty: DifficultyLevel)
}
```

### 6.4 Runtime Access

```swift
// Accessing balance values at runtime
let maxHealth = BalanceConfig.current.resources.maxHealth
let pressurePerDay = BalanceConfig.current.pressure.pressurePerDay
let travelCost = BalanceConfig.current.time.travelCost
```

---

## 7. Extension Points

### 7.1 Custom Parameters

New parameters can be added to existing sections:

```json
{
  "resources": {
    "custom_parameter": {
      "type": "integer",
      "default": 10,
      "range": [1, 100]
    }
  }
}
```

Unknown parameters are ignored but logged.

### 7.2 Formula Overrides

Combat damage formulas can be customized:

```json
{
  "combat": {
    "damage_formula": "base_power * multiplier + bonus",
    "defense_formula": "min(incoming_damage, defense_value)"
  }
}
```

### 7.3 Conditional Modifiers

Modifiers can be conditional:

```json
{
  "conditional_modifiers": [
    {
      "condition": "pressure > 70",
      "modifier": { "enemy_damage_scaling": 1.2 }
    }
  ]
}
```

---

## 8. Difficulty Presets

### 8.1 Easy Mode

- 50% more starting health
- 25% less damage taken
- 50% more faith gain
- 25% slower pressure growth

### 8.2 Normal Mode

- Baseline values
- Standard progression
- Balanced challenge

### 8.3 Hard Mode

- 10% less starting health
- 25% more damage taken
- 20% less faith gain
- 50% faster pressure growth
- 30% stronger enemies

### 8.4 Nightmare Mode

- 25% less starting health
- 50% more damage taken
- 40% less faith gain
- 100% faster pressure growth
- 50% stronger enemies

---

## 9. Examples

### 9.1 Minimal Balance Pack

```json
// manifest.json
{
  "id": "easy-mode",
  "name": { "en": "Easy Mode" },
  "version": "1.0.0",
  "type": "balance",
  "core_version_min": "1.0.0",
  "balance_path": "balance.json",
  "difficulty_level": "easy"
}

// balance.json
{
  "resources": {
    "max_health": 15,
    "starting_health": 15
  },
  "pressure": {
    "pressure_per_day": 3
  }
}
```

### 9.2 Full Balance Override

```json
{
  "resources": {
    "max_health": 10,
    "starting_health": 10,
    "max_faith": 10,
    "starting_faith": 3,
    "health_regen_per_rest": 3
  },
  "pressure": {
    "starting_pressure": 30,
    "max_pressure": 100,
    "pressure_per_day": 5,
    "thresholds": {
      "low": 30,
      "medium": 50,
      "high": 70,
      "critical": 90
    }
  },
  "anchor": {
    "max_integrity": 100,
    "default_strengthen_amount": 20,
    "default_strengthen_cost": 5,
    "stable_threshold": 70,
    "decay_per_turn": 5
  },
  "time": {
    "units_per_day": 24,
    "starting_time": 8,
    "travel_cost": 4,
    "rest_cost": 8
  },
  "combat": {
    "starting_hand_size": 5,
    "cards_per_turn": 1,
    "enemy_damage_scaling": 1.0
  },
  "end_conditions": {
    "pressure_loss": 100,
    "victory_quests": ["main_quest"]
  }
}
```

---

## 10. Mod Compatibility

### 10.1 Load Order

1. Core defaults load first
2. Balance packs override in load order
3. Later packs override earlier packs

### 10.2 Partial Overrides

Packs only need to specify changed values:

```json
{
  "pressure": {
    "pressure_per_day": 3
  }
}
```

Other values retain defaults.

### 10.3 Inheritance

Packs can inherit from other balance packs:

```json
{
  "extends": "base-balance",
  "overrides": {
    "resources": { "max_health": 12 }
  }
}
```

---

## 11. Related Documents

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - General pack guide
- [SPEC_CAMPAIGN_PACK.md](./SPEC_CAMPAIGN_PACK.md) - Campaign pack spec
- [SPEC_INVESTIGATOR_PACK.md](./SPEC_INVESTIGATOR_PACK.md) - Investigator pack spec
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Engine architecture

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-20 | Claude | Initial specification |
