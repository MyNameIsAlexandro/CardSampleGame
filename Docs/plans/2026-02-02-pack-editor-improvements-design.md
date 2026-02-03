# Pack Editor Improvements — Design Document

**Date:** 2026-02-02
**Status:** Draft
**Scope:** PackEditorApp, PackEditorKit

---

## Problem

The Pack Editor has critical compatibility issues with the game's actual content packs:

1. **Path mismatch:** PackStore uses hardcoded paths (`Heroes/heroes.json`, `FateDeck/fate_deck.json`) but real packs use flexible paths from manifest.json (`Characters/heroes.json`, `Cards/fate_deck_core.json`)
2. **Pack types:** Game has two pack types (`character` and `campaign`) with different manifest fields — editor doesn't distinguish
3. **Localization model:** Some game entities use inline strings (`"Strike"`), others use localized objects (`{"en": "...", "ru": "..."}`), and packs have separate `Localization/en.json` files — editor assumes everything is inline LocalizedString
4. **No pack creation:** Must manually create directory structure
5. **No autosave, no tabs, no UI localization**

---

## Goals

0. **Manifest-driven loading** — read paths from manifest.json, support both pack types, match game's JSON models exactly
1. **Pack Browser** — start screen showing all available packs with "New Pack" creation
2. **Tabs** — multiple packs open simultaneously in tabs within one window
3. **Autosave** — automatic save on tab switch, pack open, tab close, app quit
4. **Validation** — automatic structural and referential integrity checks on save
5. **Export to Game** — one-click export compiled pack into the game's ContentPacks
6. **UI Localization** — editor interface in EN/RU following system locale

---

## Design

### 0. Manifest-Driven Loading (Priority — blocks everything else)

**Problem:** `PackStore.loadPack()` currently hardcodes file paths. Real packs define paths in manifest.json.

**Real pack structures:**

Character pack (`core-heroes`):
```
CoreHeroes/
├── manifest.json          → { heroes_path: "Characters/heroes.json", cards_path: "Cards/cards.json", ... }
├── Characters/
│   ├── heroes.json
│   └── hero_abilities.json
├── Cards/
│   └── cards.json
└── Localization/
    ├── en.json
    └── ru.json
```

Campaign pack (`twilight-marches-act1`):
```
TwilightMarchesActI/
├── manifest.json          → { regions_path: "Campaign/regions.json", enemies_path: "Enemies/enemies.json", ... }
├── Campaign/
│   ├── regions.json
│   ├── events.json
│   ├── quests.json
│   └── anchors.json
├── Cards/
│   ├── fate_deck_core.json
│   └── story_rewards.json
├── Enemies/
│   ├── enemies.json
│   └── behaviors.json
├── Balance/
│   └── balance.json
└── Localization/
    ├── en.json
    └── ru.json
```

**Solution:**

1. **`PackStore.loadPack(from url:)`** reads `manifest.json` first, then loads files using paths from the manifest
2. Manifest fields: `heroes_path`, `cards_path`, `enemies_path`, `regions_path`, `events_path`, `quests_path`, `anchors_path`, `behaviors_path`, `fate_deck_path`, `balance_path`, `abilities_path`, `localization_path` — all optional (pack type determines which are present)
3. Pack type (`character` vs `campaign`) determines which editors/categories are shown in sidebar
4. `PackStore.savePack()` writes back to the same paths from the manifest
5. JSON models must match TwilightEngine's Codable types exactly — reuse them directly via import

**Where:** Rewrite `PackStore.loadPack()` and `PackStore.savePack()` in PackEditorKit.

**Localization handling:**
- Packs with `Localization/en.json` + `ru.json`: editor loads/saves these as a `[String: String]` dictionary
- Entity fields reference keys from these dictionaries
- Editor shows resolved localized text alongside the key

---

### 1. Pack Browser (Start Screen)

**New view: `PackBrowserView`**

Replaces the current empty "Open a pack folder to begin" placeholder. Shown as the first (non-closable) tab.

**Behavior:**
- On launch, scans `Resources/ContentPacks/` for directories containing `manifest.json`
- Displays each pack as a card: pack ID, version, entity counts (enemies, cards, events, etc.)
- Click a pack card → opens it in a new tab
- "New Pack" button → `NSSavePanel` to choose location → generates full directory structure:
  ```
  <pack-name>/
  ├── manifest.json        (template with packId, version: "1.0.0")
  ├── Enemies/enemies.json (empty array)
  ├── Cards/cards.json
  ├── Events/events.json
  ├── Regions/regions.json
  ├── Heroes/heroes.json
  ├── FateDeck/fate_deck.json
  ├── Quests/quests.json
  ├── Behaviors/behaviors.json
  └── Anchors/anchors.json
  ```
- "Open Other..." button → current `NSOpenPanel` behavior for packs outside standard path

**Where:** `PackEditorApp/Sources/PackEditorApp/Views/PackBrowserView.swift` (new file)

**Data:** `PackBrowserState` or extension of `PackEditorState` — scans directory, builds list of `PackSummary` structs.

### 2. Tabs

**Model: `TabItem`**

```swift
enum TabItem: Identifiable, Hashable {
    case browser                    // always first, non-closable
    case pack(id: String, url: URL) // one per open pack
}
```

**Behavior:**
- Tab bar at the top of the window showing open packs
- Pack Browser tab is always first and cannot be closed
- Each pack tab shows: pack name + dirty indicator (dot) for unsaved changes
- Closing a tab triggers autosave before removal
- Switching tabs triggers autosave of the previous tab

**State changes:**
- `PackEditorState` gains `openTabs: [TabItem]`, `activeTab: TabItem`
- Each pack tab has its own `PackStore` instance (already works this way since `PackStore` is a value container)
- New type `OpenPack` bundles `PackStore` + `URL` + `isDirty` per tab

**Where:** Modify `PackEditorRootView` to use `TabView` or custom tab bar + switching logic.

### 3. Autosave

**Triggers (event-based, no timer):**
- Switching between tabs
- Opening another pack
- Closing a tab
- Quitting the application (`onDisappear` / `NSApplication` delegate)

**Behavior:**
- Only saves if `isDirty == true`
- Calls existing `store.savePack()` which writes JSON files back to the pack directory
- On save failure — shows alert, does NOT lose the in-memory state
- Dirty indicator (dot on tab) clears after successful save

**Where:** Hook into tab switching logic in `PackEditorState`. Add `NSApplication.willTerminateNotification` observer for quit.

### 4. Validation (Enhanced)

**Current state:** Validate button exists, runs basic checks.

**Enhancements:**
- **Auto-validate on save:** after each autosave, run validation in background
- **Structural checks:** JSON ↔ Codable round-trip (encode then decode each entity)
- **Referential integrity:**
  - Card references valid enemy IDs
  - Event choice outcomes reference valid region/event IDs
  - Behavior IDs referenced by enemies exist
  - Hero ability references are valid
- **Completeness checks:**
  - Required LocalizedString fields have both `en` and `ru` filled
  - No empty `definitionId`
  - No duplicate IDs within a category
- **Results panel:** bottom panel (like Xcode Issue Navigator) with errors/warnings, click navigates to the entity

**Where:**
- `PackEditorKit`: new `PackValidator` type with `validate(store:) -> [ValidationIssue]`
- `PackEditorApp`: `ValidationPanelView` at bottom of editor

### 5. Export to Game

**Button: "Export to Game" in toolbar**

**Behavior:**
1. Autosave current pack
2. Run validation — if errors, show them and abort
3. Compile pack via existing `PackCompiler.compile(from:to:)`
4. Copy compiled output to `Resources/ContentPacks/<packId>/` in the game project
5. Show success message with instructions:
   > "Pack exported. To test: open CardSampleGame.xcodeproj, select CardSampleGame scheme, Cmd+R."

**Configuration:**
- Game project path stored in `UserDefaults` — first time asks via `NSOpenPanel`
- Remembers path between sessions

**Where:**
- `PackEditorState.exportToGame()` method
- Settings for game project path in `PackEditorState` (persisted via `@AppStorage` or `UserDefaults`)

### 6. UI Localization

**Approach:** Standard Apple localization via `String(localized:)` and `.strings` files.

**Scope — all hardcoded UI strings in PackEditorApp:**
- Sidebar labels: "Enemies", "Cards", "Events", "Regions", "Heroes", "Fate Cards", "Quests", "Behaviors", "Anchors", "Balance"
- Toolbar: "Open", "Save", "Validate", "Compile", "New Pack", "Export to Game"
- Placeholders: "Open a pack folder to begin", "Select an entity to edit", "Search all entities"
- Editor labels: "Name", "Description", "Health", "Power", "Defense", etc.
- Validation messages: "Missing required field", "Duplicate ID", etc.
- Pack Browser: "New Pack", "Open Other...", "Recent Packs"

**Files:**
- `PackEditorApp/Sources/PackEditorApp/Resources/en.lproj/Localizable.strings`
- `PackEditorApp/Sources/PackEditorApp/Resources/ru.lproj/Localizable.strings`

**Language selection:** automatic from macOS system locale (System Settings > Language & Region).

---

## Implementation Order

**Phase 0 — Foundation (blocks everything else):**
1. Rewrite `PackStore.loadPack()` to be manifest-driven (read paths from manifest.json)
2. Rewrite `PackStore.savePack()` to write back using manifest paths
3. Support both pack types (character, campaign) — show only relevant categories in sidebar
4. Handle localization files (Localization/en.json, ru.json) — load, display, save
5. Test: load real CoreHeroes and TwilightMarchesActI packs successfully

**Phase 1 — Core Editor Workflow (after Phase 0):**
1. Pack Browser view — scan known pack locations, show pack cards
2. New Pack creation — choose type (character/campaign), generate directory + manifest
3. Tab system — TabItem model, tab bar, per-tab PackStore
4. Autosave — event-based triggers
5. Export to Game

**Phase 2 — Quality & Localization (parallel with Phase 1):**
1. Enhanced validation (PackValidator, ValidationPanelView)
2. UI localization (extract strings, create .strings files, add ru translations)

---

## Testing Strategy

**PackEditorKit (unit tests):**
- Manifest-driven loading: load real CoreHeroes pack, verify all entities parsed
- Manifest-driven loading: load real TwilightMarchesActI pack, verify all entities parsed
- Round-trip: load pack → save → load again → compare (no data loss)
- `PackValidator` tests: valid pack passes, missing ID fails, broken references fail, duplicate IDs fail
- New pack template generation: correct directory structure, valid manifest

**PackEditorApp (unit tests where possible, manual for UI):**
- Tab management: open/close/switch tabs
- Pack Browser: scanning, filtering
- Export: path resolution, copy verification

---

## Out of Scope

- In-editor content preview (rendering cards/enemies as they appear in-game)
- Multiple windows (one window with tabs is sufficient)
- Undo/redo system
- Git integration from within the editor
- Auto-launch of the game after export
