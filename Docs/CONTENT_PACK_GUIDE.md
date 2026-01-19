# Content Pack Development Guide

> **Version:** 1.0
> **Last Updated:** January 2026

This guide explains how to create content packs for CardSampleGame. Content packs allow you to add new campaigns, heroes, cards, and balance configurations without modifying the game engine.

---

## Table of Contents

1. [Overview](#overview)
2. [Pack Structure](#pack-structure)
3. [Manifest File](#manifest-file)
4. [Content Types](#content-types)
5. [Localization](#localization)
6. [Balance Configuration](#balance-configuration)
7. [Validation](#validation)
8. [Best Practices](#best-practices)

---

## Overview

### What is a Content Pack?

A content pack is a self-contained directory containing game content:
- **Campaign Packs**: Regions, events, quests, anchors
- **Investigator Packs**: Heroes with starting decks
- **Balance Packs**: Game balance configuration
- **Full Packs**: All of the above

### Key Principles

1. **No Engine Changes**: Adding a pack should never require modifying `Engine/`
2. **Validation First**: All content is validated before use
3. **Localization Built-In**: All text supports multiple languages
4. **Version Compatibility**: Packs declare required engine versions

---

## Pack Structure

```
ContentPacks/
└── YourPack/
    ├── manifest.json           # Required: Pack metadata
    ├── Campaign/               # Campaign content
    │   └── ActI/
    │       ├── regions.json    # Region definitions
    │       ├── events.json     # Event definitions
    │       ├── quests.json     # Quest definitions
    │       └── anchors.json    # Anchor definitions
    ├── Investigators/          # Hero content
    │   └── heroes.json         # Hero definitions
    ├── Cards/                  # Card content
    │   └── cards.json          # Card definitions
    ├── Balance/                # Game balance
    │   └── balance.json        # Balance configuration
    └── Localization/           # Translations
        ├── en.json             # English strings
        └── ru.json             # Russian strings
```

---

## Manifest File

Every pack requires a `manifest.json` at its root:

```json
{
  "id": "your-pack-id",
  "name": {
    "en": "Your Pack Name",
    "ru": "Название Вашего Пака"
  },
  "description": {
    "en": "Description of your pack",
    "ru": "Описание вашего пака"
  },
  "version": "1.0.0",
  "type": "campaign",
  "core_version_min": "1.0.0",
  "core_version_max": null,
  "dependencies": [],
  "entry_region": "starting_region_id",
  "locales": ["en", "ru"],
  "regions_path": "Campaign/ActI/regions.json",
  "events_path": "Campaign/ActI/events.json",
  "quests_path": "Campaign/ActI/quests.json",
  "anchors_path": "Campaign/ActI/anchors.json",
  "heroes_path": "Investigators/heroes.json",
  "cards_path": "Cards/cards.json",
  "balance_path": "Balance/balance.json",
  "localization_path": "Localization"
}
```

### Manifest Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique pack identifier (no spaces, lowercase) |
| `name` | Yes | Localized pack name |
| `description` | Yes | Localized pack description |
| `version` | Yes | Semantic version (MAJOR.MINOR.PATCH) |
| `type` | Yes | Pack type: `campaign`, `investigator`, `balance`, `full` |
| `core_version_min` | Yes | Minimum required engine version |
| `core_version_max` | No | Maximum supported engine version |
| `dependencies` | No | List of required packs |
| `entry_region` | Campaign only | Starting region ID |
| `locales` | No | Supported languages (default: `["en"]`) |
| `*_path` | No | Paths to content files |

### Dependencies

```json
"dependencies": [
  {
    "pack_id": "base-pack",
    "min_version": "1.0.0",
    "max_version": "2.0.0",
    "optional": false
  }
]
```

---

## Content Types

### Regions

```json
{
  "village": {
    "id": "village",
    "title": {
      "en": "Village",
      "ru": "Деревня"
    },
    "description": {
      "en": "A small village",
      "ru": "Небольшая деревня"
    },
    "neighbor_ids": ["forest", "road"],
    "initial_state": "stable",
    "initially_discovered": true,
    "anchor_id": "village_chapel",
    "event_pool_ids": ["village_events"]
  }
}
```

### Events

```json
{
  "mysterious_stranger": {
    "id": "mysterious_stranger",
    "title": {
      "en": "Mysterious Stranger",
      "ru": "Таинственный Незнакомец"
    },
    "description": {
      "en": "A hooded figure approaches...",
      "ru": "К вам приближается фигура в капюшоне..."
    },
    "availability": {
      "region_ids": ["village", "road"],
      "min_pressure": 0,
      "max_pressure": 50
    },
    "choices": [
      {
        "id": "greet",
        "label": {
          "en": "Greet them",
          "ru": "Поприветствовать"
        },
        "consequences": {
          "resource_changes": { "faith": 1 },
          "set_flags": ["met_stranger"]
        }
      },
      {
        "id": "ignore",
        "label": {
          "en": "Walk away",
          "ru": "Уйти"
        },
        "consequences": {}
      }
    ],
    "weight": 10,
    "is_one_time": true
  }
}
```

### Heroes

```json
[
  {
    "id": "warrior_ragnar",
    "name": "Ragnar",
    "hero_class": "warrior",
    "description": "A brave warrior",
    "icon": "shield.lefthalf.filled",
    "base_stats": {
      "health": 12,
      "faith": 3,
      "strength": 4,
      "agility": 2,
      "wisdom": 1
    },
    "special_ability": {
      "id": "battle_cry",
      "name": "Battle Cry",
      "description": "Boost attack power",
      "cooldown": 3
    },
    "starting_deck": ["strike_basic", "strike_basic", "defend_basic", "rage_strike"],
    "availability": "always"
  }
]
```

### Cards

```json
[
  {
    "id": "strike_basic",
    "name": "Strike",
    "name_ru": "Удар",
    "card_type": "attack",
    "rarity": "common",
    "description": "Deal 3 damage",
    "description_ru": "Нанести 3 урона",
    "icon": "sword",
    "expansion_set": "baseSet",
    "ownership": "universal",
    "abilities": [],
    "faith_cost": 0,
    "balance": "neutral",
    "power": 3
  }
]
```

### Anchors

```json
{
  "village_chapel": {
    "id": "village_chapel",
    "title": {
      "en": "Chapel of Light",
      "ru": "Часовня Света"
    },
    "description": {
      "en": "A sacred chapel",
      "ru": "Священная часовня"
    },
    "region_id": "village",
    "anchor_type": "chapel",
    "initial_influence": "light",
    "power": 5,
    "max_integrity": 100,
    "initial_integrity": 80,
    "strengthen_amount": 15,
    "strengthen_cost": { "faith": 5 }
  }
}
```

---

## Localization

### Inline Localization

Most text fields support inline localization:

```json
{
  "title": {
    "en": "English text",
    "ru": "Русский текст"
  }
}
```

### Localization Files

For additional strings, use `Localization/{locale}.json`:

```json
{
  "region.village.name": "Village by the Road",
  "region.village.description": "A small village on the edge of the borderlands",
  "anchor.chapel.name": "Chapel of Light"
}
```

---

## Balance Configuration

The `balance.json` file controls game mechanics:

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
    "strengthen_amount": 20,
    "strengthen_cost": 5,
    "stable_threshold": 70,
    "breach_threshold": 0,
    "decay_per_turn": 5
  },
  "time": {
    "units_per_day": 24,
    "starting_time": 8,
    "travel_cost": 4,
    "explore_cost": 2,
    "rest_cost": 8
  },
  "end_conditions": {
    "death_health": 0,
    "pressure_loss": 100,
    "victory_quests": ["main_quest"]
  }
}
```

---

## Validation

### Using PackValidator

Run validation on your pack:

```swift
let validator = PackValidator(packURL: packURL)
let summary = validator.validate()
print(summary.description)

if !summary.isValid {
    // Handle errors
}
```

### Using CLI Tool

```bash
# Validate single pack
swift DevTools/PackCompiler/main.swift validate ContentPacks/YourPack

# Validate all packs
swift DevTools/PackCompiler/main.swift validate-all ContentPacks/

# Show pack info
swift DevTools/PackCompiler/main.swift info ContentPacks/YourPack
```

### Common Validation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Broken reference | ID references non-existent content | Check spelling, ensure content exists |
| Missing manifest | No manifest.json found | Create manifest.json at pack root |
| Invalid version | Version string malformed | Use MAJOR.MINOR.PATCH format |
| Missing entry region | Campaign has no entry_region | Add entry_region to manifest |

---

## Best Practices

### IDs

- Use lowercase with underscores: `village_square`, not `VillageSquare`
- Be descriptive: `mysterious_stranger_event`, not `event1`
- Use prefixes for organization: `act1_quest_main`, `act1_region_forest`

### Content Organization

- Group related content in subdirectories
- Use consistent naming across files
- Keep JSON files reasonably sized (< 1000 lines)

### Version Management

- Start at `1.0.0` for release
- Increment PATCH for bug fixes
- Increment MINOR for new content
- Increment MAJOR for breaking changes

### Testing

1. Run validation before testing in-game
2. Test all event choices
3. Verify all hero starting decks work
4. Check localization in all supported languages

### Performance

- Avoid circular region references
- Keep event pools focused (10-20 events per pool)
- Use `is_one_time: true` for unique events

---

## Example: Creating a New Campaign Pack

1. **Create directory structure:**
   ```
   ContentPacks/MyCampaign/
   ├── manifest.json
   ├── Campaign/ActI/
   ├── Cards/
   └── Localization/
   ```

2. **Create manifest.json:**
   ```json
   {
     "id": "my-campaign",
     "name": { "en": "My Campaign" },
     "version": "1.0.0",
     "type": "campaign",
     "core_version_min": "1.0.0",
     "entry_region": "starting_village"
   }
   ```

3. **Add content files**

4. **Validate:**
   ```bash
   swift DevTools/PackCompiler/main.swift validate ContentPacks/MyCampaign
   ```

5. **Test in-game**

---

## Related Documents

- [ENGINE_ARCHITECTURE.md](./ENGINE_ARCHITECTURE.md) - Core engine architecture
- [MIGRATION_PLAN.md](./MIGRATION_PLAN.md) - Migration roadmap
- [INDEX.md](./INDEX.md) - Documentation index

---

**Questions?** Check the example pack at `ContentPacks/TwilightMarches/` for reference.
