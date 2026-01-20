# Campaign Pack Specification

> **Version:** 1.0
> **Status:** Active
> **Last Updated:** January 2026

---

## 1. Overview

### 1.1 Purpose

A Campaign Pack provides story-driven content including regions, events, quests, anchors, and enemies. Campaign packs define the game world, its narrative, and progression mechanics.

### 1.2 Scope

This specification covers:
- Campaign pack structure and manifest requirements
- Content schemas (regions, events, quests, anchors, enemies)
- Functional and non-functional requirements
- Validation rules and error handling
- Extension points and APIs

### 1.3 Terminology

| Term | Definition |
|------|------------|
| **Region** | A location in the game world that can be visited |
| **Event** | A narrative encounter triggered in a region |
| **Quest** | A multi-stage objective with rewards |
| **Anchor** | A sacred point that stabilizes a region |
| **Enemy** | An adversary for combat encounters |
| **Pressure** | Global danger level affecting the world |

---

## 2. Functional Requirements

### 2.1 Core Functionality

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-CAM-001 | Pack MUST define at least one region | Required |
| FR-CAM-002 | Pack MUST specify an entry region in manifest | Required |
| FR-CAM-003 | All regions MUST form a connected graph | Required |
| FR-CAM-004 | Pack MAY define events for any region | Optional |
| FR-CAM-005 | Pack MAY define quests with multiple stages | Optional |
| FR-CAM-006 | Pack MAY define anchors for regions | Optional |
| FR-CAM-007 | Pack MAY define enemies for combat events | Optional |

### 2.2 Region Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-REG-001 | Region MUST have unique ID within pack | Required |
| FR-REG-002 | Region MUST have localized title | Required |
| FR-REG-003 | Region MUST specify neighbor connections | Required |
| FR-REG-004 | Region MUST have initial state (stable/borderland/breach) | Required |
| FR-REG-005 | Region MAY reference event pools | Optional |
| FR-REG-006 | Region MAY reference an anchor | Optional |

### 2.3 Event Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-EVT-001 | Event MUST have unique ID | Required |
| FR-EVT-002 | Event MUST have at least one choice | Required |
| FR-EVT-003 | Event MUST define availability conditions | Required |
| FR-EVT-004 | Event choices MUST define consequences | Required |
| FR-EVT-005 | Combat events MUST reference valid enemy | Required |
| FR-EVT-006 | Event MAY define required/forbidden flags | Optional |
| FR-EVT-007 | Event MAY be one-time or repeatable | Optional |

### 2.4 Quest Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-QST-001 | Quest MUST have unique ID | Required |
| FR-QST-002 | Quest MUST have at least one objective | Required |
| FR-QST-003 | Quest objectives MUST be completable | Required |
| FR-QST-004 | Quest MUST define completion rewards | Required |
| FR-QST-005 | Quest MAY have prerequisites | Optional |
| FR-QST-006 | Quest MAY be main or side type | Optional |

### 2.5 Anchor Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ANC-001 | Anchor MUST reference valid region | Required |
| FR-ANC-002 | Anchor MUST have integrity values | Required |
| FR-ANC-003 | Anchor MUST define strengthen cost | Required |
| FR-ANC-004 | One anchor per region maximum | Required |

### 2.6 Enemy Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ENM-001 | Enemy MUST have unique ID | Required |
| FR-ENM-002 | Enemy MUST have combat stats (health, power, defense) | Required |
| FR-ENM-003 | Enemy MUST have difficulty rating | Required |
| FR-ENM-004 | Enemy MAY have special abilities | Optional |
| FR-ENM-005 | Enemy MAY drop loot cards | Optional |

---

## 3. Non-Functional Requirements

### 3.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-PERF-001 | Pack load time | < 500ms |
| NFR-PERF-002 | Maximum regions | 100 per pack |
| NFR-PERF-003 | Maximum events | 500 per pack |
| NFR-PERF-004 | Maximum file size | 10MB total |

### 3.2 Compatibility

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-COMP-001 | Core version compatibility | Semantic versioning |
| NFR-COMP-002 | Backward compatibility | MINOR versions |
| NFR-COMP-003 | Cross-pack references | Via dependencies |

### 3.3 Localization

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-LOC-001 | All user-facing text | Localized |
| NFR-LOC-002 | Fallback language | English (en) |
| NFR-LOC-003 | Minimum locales | 1 (en) |

### 3.4 Validation

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-VAL-001 | Pre-load validation | All content |
| NFR-VAL-002 | Reference validation | All IDs |
| NFR-VAL-003 | Schema validation | All JSON |

---

## 4. Data Schemas

### 4.1 Manifest Schema

```json
{
  "$schema": "campaign-pack-manifest-v1",
  "id": "string (required, unique, lowercase-hyphen)",
  "name": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "version": "SemanticVersion (required, format: X.Y.Z)",
  "type": "campaign (required)",
  "core_version_min": "SemanticVersion (required)",
  "core_version_max": "SemanticVersion | null",
  "dependencies": "PackDependency[] (optional, default: [])",
  "entry_region": "string (required, must reference valid region)",
  "entry_quest": "string | null (optional, starting quest)",
  "regions_path": "string (required, relative path)",
  "events_path": "string (required, relative path)",
  "quests_path": "string (optional, relative path)",
  "anchors_path": "string (optional, relative path)",
  "enemies_path": "string (optional, relative path)",
  "locales": "string[] (optional, default: ['en'])",
  "localization_path": "string (optional, relative path)"
}
```

### 4.2 Region Schema

```json
{
  "id": "string (required, unique)",
  "title": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "neighbor_ids": "string[] (required, min: 1)",
  "initial_state": "stable | borderland | breach (required)",
  "initially_discovered": "boolean (default: false)",
  "anchor_id": "string | null (optional, reference to anchor)",
  "event_pool_ids": "string[] (optional)",
  "region_type": "settlement | forest | swamp | mountain | wasteland (optional)"
}
```

### 4.3 Event Schema

```json
{
  "id": "string (required, unique)",
  "title": "LocalizedString (required)",
  "body": "LocalizedString (required, event description)",
  "event_kind": "EventKind (required)",
  "availability": "EventAvailability (required)",
  "choices": "ChoiceDefinition[] (required, min: 1)",
  "weight": "integer (optional, default: 10)",
  "is_one_time": "boolean (optional, default: false)",
  "is_instant": "boolean (optional, default: false)",
  "pool_ids": "string[] (optional)",
  "mini_game_challenge": "MiniGameChallenge | null (for combat events)"
}
```

#### EventKind

```json
{
  "type": "inline | mini_game",
  "mini_game_kind": "combat | ritual | exploration | dialogue | puzzle (if mini_game)"
}
```

#### EventAvailability

```json
{
  "region_ids": "string[] | null (null = all regions)",
  "region_states": "string[] | null (stable/borderland/breach, null = all)",
  "min_pressure": "integer | null (0-100)",
  "max_pressure": "integer | null (0-100)",
  "required_flags": "string[] (default: [])",
  "forbidden_flags": "string[] (default: [])"
}
```

#### ChoiceDefinition

```json
{
  "id": "string (required)",
  "label": "LocalizedString (required)",
  "requirements": "ChoiceRequirements | null",
  "consequences": "ChoiceConsequences (required)"
}
```

#### ChoiceRequirements

```json
{
  "min_resources": "{ [resource]: integer } (optional)",
  "min_balance": "integer | null (0-100)",
  "max_balance": "integer | null (0-100)",
  "required_flags": "string[] (optional)",
  "required_cards": "string[] (optional)"
}
```

#### ChoiceConsequences

```json
{
  "resource_changes": "{ [resource]: integer } (optional)",
  "balance_delta": "integer (default: 0)",
  "set_flags": "string[] (optional)",
  "clear_flags": "string[] (optional)",
  "quest_progress": "QuestProgressEffect | null",
  "region_state_change": "RegionStateChange | null",
  "card_rewards": "string[] (optional)",
  "result_key": "string | null (for localized result message)"
}
```

### 4.4 Quest Schema

```json
{
  "id": "string (required, unique)",
  "title": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "quest_kind": "main | side | daily | hidden (required)",
  "objectives": "QuestObjective[] (required, min: 1)",
  "completion_rewards": "QuestRewards (required)",
  "prerequisites": "QuestPrerequisites | null",
  "region_id": "string | null (optional, quest location)",
  "time_limit_days": "integer | null (optional)"
}
```

#### QuestObjective

```json
{
  "id": "string (required)",
  "description": "LocalizedString (required)",
  "objective_type": "visit_region | complete_event | defeat_enemy | collect_item | reach_state",
  "target_id": "string (required, what to interact with)",
  "target_count": "integer (default: 1)",
  "order": "integer (optional, for sequential objectives)"
}
```

### 4.5 Anchor Schema

```json
{
  "id": "string (required, unique)",
  "title": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "region_id": "string (required, reference to region)",
  "anchor_type": "chapel | shrine | monument | tree | stone (required)",
  "initial_influence": "light | dark | neutral (required)",
  "power": "integer (required, 1-10)",
  "max_integrity": "integer (required, default: 100)",
  "initial_integrity": "integer (required, 0-max_integrity)",
  "strengthen_amount": "integer (required)",
  "strengthen_cost": "{ [resource]: integer } (required)",
  "abilities": "AnchorAbility[] (optional)"
}
```

### 4.6 Enemy Schema

```json
{
  "id": "string (required, unique)",
  "name": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "health": "integer (required, min: 1)",
  "power": "integer (required, min: 0)",
  "defense": "integer (required, min: 0)",
  "difficulty": "integer (required, 1-5)",
  "enemy_type": "beast | spirit | undead | humanoid | boss (required)",
  "rarity": "common | uncommon | rare | epic | legendary (required)",
  "abilities": "EnemyAbility[] (optional)",
  "loot_card_ids": "string[] (optional)",
  "faith_reward": "integer (default: 0)",
  "balance_delta": "integer (default: 0)"
}
```

#### EnemyAbility

```json
{
  "id": "string (required)",
  "name": "LocalizedString (required)",
  "description": "LocalizedString (required)",
  "trigger": "on_attack | on_defend | on_turn_start | on_turn_end | on_death",
  "effect": "AbilityEffect (required)",
  "cooldown": "integer (optional, 0 = always)"
}
```

---

## 5. Validation Rules

### 5.1 Structural Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-STR-001 | manifest.json must exist at pack root | Error |
| VAL-STR-002 | All referenced paths must exist | Error |
| VAL-STR-003 | All JSON must be valid syntax | Error |
| VAL-STR-004 | All required fields must be present | Error |

### 5.2 Reference Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-REF-001 | Region neighbor_ids must reference existing regions | Error |
| VAL-REF-002 | Event region_ids must reference existing regions | Error |
| VAL-REF-003 | Anchor region_id must reference existing region | Error |
| VAL-REF-004 | Quest target_id must reference valid target | Warning |
| VAL-REF-005 | Enemy loot_card_ids should reference existing cards | Warning |
| VAL-REF-006 | entry_region must reference existing region | Error |

### 5.3 Semantic Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-SEM-001 | All IDs must be unique within type | Error |
| VAL-SEM-002 | Region graph must be connected | Warning |
| VAL-SEM-003 | Combat events must have enemy reference | Error |
| VAL-SEM-004 | Quest objectives must be achievable | Warning |
| VAL-SEM-005 | Pressure ranges must be valid (0-100) | Error |

### 5.4 Localization Validation

| Rule | Description | Severity |
|------|-------------|----------|
| VAL-LOC-001 | All LocalizedString must have 'en' key | Error |
| VAL-LOC-002 | All declared locales must have strings | Warning |
| VAL-LOC-003 | Empty strings are not allowed | Warning |

---

## 6. API Contract

### 6.1 Loading Interface

```swift
// PackLoader interface for Campaign packs
protocol CampaignPackLoader {
    /// Load campaign content from pack URL
    func loadCampaign(from url: URL) throws -> CampaignContent

    /// Validate campaign before loading
    func validate(at url: URL) -> ValidationResult
}

struct CampaignContent {
    let regions: [String: RegionDefinition]
    let events: [String: EventDefinition]
    let quests: [String: QuestDefinition]
    let anchors: [String: AnchorDefinition]
    let enemies: [String: EnemyDefinition]
}
```

### 6.2 Content Provider Interface

```swift
protocol CampaignContentProvider {
    func getRegion(id: String) -> RegionDefinition?
    func getAllRegions() -> [RegionDefinition]
    func getEvent(id: String) -> EventDefinition?
    func getEvents(forRegion: String) -> [EventDefinition]
    func getQuest(id: String) -> QuestDefinition?
    func getAnchor(id: String) -> AnchorDefinition?
    func getAnchor(forRegion: String) -> AnchorDefinition?
    func getEnemy(id: String) -> EnemyDefinition?
}
```

### 6.3 Runtime Integration

```swift
// ContentRegistry integration
extension ContentRegistry {
    func loadCampaignPack(from url: URL) throws -> LoadedPack
    func getAvailableEvents(forRegion: String, pressure: Int) -> [EventDefinition]
    func getActiveQuests() -> [QuestDefinition]
}
```

---

## 7. Extension Points

### 7.1 Custom Event Types

Packs can define custom event kinds by using `event_kind.type = "mini_game"` with a custom `mini_game_kind`. The engine will attempt to route to appropriate handler.

### 7.2 Custom Abilities

Enemy abilities can define custom `effect` types that will be handled by ability processors registered with the engine.

### 7.3 Event Pools

Custom event pools can be defined and referenced by regions:

```json
{
  "pool_ids": ["common_events", "forest_spirits", "act2_special"]
}
```

---

## 8. Migration & Versioning

### 8.1 Version Compatibility

| Pack Version | Core Version | Compatibility |
|--------------|--------------|---------------|
| 1.x.x | 1.x.x | Full |
| 1.x.x | 2.x.x | Upgrade required |

### 8.2 Schema Evolution

- **Adding fields**: Always optional with defaults
- **Removing fields**: Deprecated in MINOR, removed in MAJOR
- **Changing types**: Never allowed, new field required

---

## 9. Examples

### 9.1 Minimal Campaign Pack

```
MyCampaign/
├── manifest.json
└── Campaign/
    └── ActI/
        ├── regions.json
        └── events.json
```

### 9.2 Full Campaign Pack

```
TwilightMarches/
├── manifest.json
├── Campaign/
│   ├── ActI/
│   │   ├── regions.json
│   │   ├── events.json
│   │   ├── quests.json
│   │   └── anchors.json
│   └── Enemies/
│       └── enemies.json
├── Cards/
│   └── cards.json
├── Balance/
│   └── balance.json
└── Localization/
    ├── en.json
    └── ru.json
```

---

## 10. Related Documents

- [CONTENT_PACK_GUIDE.md](./CONTENT_PACK_GUIDE.md) - General pack guide
- [SPEC_INVESTIGATOR_PACK.md](./SPEC_INVESTIGATOR_PACK.md) - Investigator pack spec
- [SPEC_BALANCE_PACK.md](./SPEC_BALANCE_PACK.md) - Balance pack spec
- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Engine architecture

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-20 | Claude | Initial specification |
