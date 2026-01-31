# PackEditor: User Guide

PackEditor is a macOS SwiftUI application for editing content packs for the game **ECHO: Legends of the Veil**. It provides a streamlined interface for managing enemies, cards, events, regions, heroes, fate cards, quests, behaviors, anchors, and balance configurations.

---

## 1. Getting Started

### Opening a Pack

To begin editing a content pack:

1. Launch PackEditor
2. Press **Cmd+O** (or select **File > Open**)
3. Navigate to the folder containing your pack's `manifest.json`
4. Click **Open**

The editor will load all entities from the pack and display them in the interface.

### Understanding the UI Layout

PackEditor uses a **3-column NavigationSplitView** for intuitive navigation:

- **Column 1 (Sidebar):** Content categories (Enemies, Cards, Events, etc.)
- **Column 2 (Entity List):** Entities within the selected category
- **Column 3 (Detail Editor):** Form editor for the selected entity or manifest

---

## 2. Navigation

### Selecting Categories

Click any category in the sidebar to view its entities:

- **Enemies** — Monster definitions
- **Cards** — Player and deck cards
- **Events** — Story events and encounters
- **Regions** — Explorable locations
- **Heroes** — Playable characters
- **FateCards** — Special card mechanics
- **Quests** — Mission and objective definitions
- **Behaviors** — AI and NPC behavior patterns
- **Anchors** — World markers and waypoints
- **Balance** — Game balance and difficulty settings

### Selecting Entities

Click any entity in the list to open its editor in the detail column. The entity name and icon (if applicable) are displayed for quick identification.

### Global Search

Use **Cmd+F** to open the global search. Search terms will match across:

- Entity names
- Entity IDs
- Entity descriptions
- All categories

Search results update in real-time as you type.

---

## 3. Editing Entities

### Form Editor Overview

Each entity type has a specialized form editor with typed fields:

- **Text Fields** — Single-line text input (names, IDs)
- **Localized Text** — Language-specific fields with tabs for EN (English) and RU (Russian)
- **Number Fields** — Integer or decimal values (health, damage, cost)
- **Enums** — Dropdown pickers with predefined options (rarity, type, element)
- **Lists** — Add/remove items (tags, abilities, rewards)

### Tracking Changes

Unsaved changes are indicated by the **isDirty** indicator in the toolbar. Save your work frequently to avoid data loss.

### Undoing Changes

Press **Cmd+Z** to undo your last action. The editor maintains an undo history for the current session.

---

## 4. Pack Manifest

### Accessing the Manifest

Click **Manifest** in the sidebar (or deselect all entities) to edit pack metadata.

### Manifest Settings

The manifest editor allows you to configure:

#### Pack Identity
- **Pack ID** — Unique identifier for the pack
- **Pack Name** — Display name (localized: EN/RU)
- **Version** — Semantic version (e.g., 1.0.0)
- **Pack Type** — Category type (e.g., "Character", "Story")
- **Author** — Creator name

#### Compatibility
- **Core Version** — Required game engine version
- **Supported Locales** — Languages (e.g., EN, RU)

#### Story Settings (if applicable)
- **Entry Points** — Starting scene or chapter
- **Difficulty Range** — Min/max difficulty level
- **Playtime** — Estimated hours to complete

Save manifest changes via **Cmd+S**.

---

## 5. CRUD Operations

### Create (Add New Entity)

1. Select a category in the sidebar
2. Click the **+** button in the toolbar, or press **Cmd+N**
3. If templates are available, choose a template (e.g., "Beast Enemy", "Attack Card")
4. Fill in the form fields
5. Save with **Cmd+S**

#### Available Templates

- **Enemies:** Beast, Undead, Boss
- **Cards:** Attack, Defense, Spell, Item
- **Regions:** Settlement, Wilderness, Dungeon

### Read (Open Entity)

Click any entity in the list to view and edit it in the detail column.

### Update (Edit Entity)

Modify fields in the detail editor and save with **Cmd+S**. Changes are tracked in the isDirty indicator.

### Duplicate Entity

1. Select the entity you want to duplicate
2. Click the **doc.on.doc** button in the toolbar, or press **Cmd+D**
3. A new entity with the same properties (and a new ID) is created
4. Edit and save the duplicate

### Delete Entity

1. Select the entity you want to delete
2. Click the **-** button in the toolbar
3. Confirm the deletion in the dialog
4. The entity is removed from the pack

---

## 6. Import / Export

### Import from Clipboard

1. Copy a JSON entity to your clipboard
2. Open the category where you want to import
3. Press **Cmd+V** (or select **Edit > Paste**)
4. The entity is created in the pack
5. Save with **Cmd+S**

### Export to Clipboard

1. Select an entity in the detail editor
2. Click the **Export** button in the toolbar
3. The entity's JSON is copied to your clipboard
4. Paste into any text editor, other tools, or another pack

### Import from File

1. Select a category
2. Click **File > Import Entity** or use the toolbar import button
3. Select a `.json` file from your file system
4. The entity is created in the pack
5. Save with **Cmd+S**

---

## 7. Drag & Reorder

### Reordering Entities

Click and drag any entity in the list to reorder it within the category. The editor updates the visual order immediately.

### Saving Order

Entity order is persisted to `_editor_order.json` in the pack folder. This allows you to:

- Organize entities by priority or narrative flow
- Maintain a custom sort order across sessions
- Group related entities visually

Order is saved per-category, so each category maintains its own sequence.

---

## 8. Validation

### Running Validation

Click the **Validate** button in the toolbar to check all entities in the pack for errors and warnings.

### Understanding Results

- **Error Badges** — Red badges on categories indicate validation failures (e.g., missing required fields)
- **Warning Badges** — Yellow badges on categories indicate non-critical issues (e.g., unused entities)
- **Inline Validation** — Form fields display validation feedback as you edit

### Common Issues

- Missing required fields (name, ID, type)
- Duplicate entity IDs
- Invalid references (e.g., broken links to other entities)
- Incompatible field types or values

Fix validation errors before compiling the pack.

---

## 9. JSON Preview

### Viewing Entity JSON

1. Select an entity in the detail editor
2. Click the **Curlybraces** ({}) button in the toolbar
3. A sheet opens displaying the entity's raw JSON

### Copying JSON

In the JSON preview sheet, click the **Copy** button to copy the entire entity JSON to your clipboard.

This is useful for:

- Sharing entities with team members
- Debugging serialization issues
- Comparing versions of an entity
- Manual inspection of field values

---

## 10. Compile

### Building a Binary Pack

Once you've edited and validated your entities, compile them into a binary runtime format:

1. Click the **Compile** button in the toolbar
2. The editor processes all entities and generates a `.pack` binary file
3. The binary is optimized for runtime performance

### Output

The compiled `.pack` file is saved in the pack directory and can be:

- Distributed with the game
- Loaded dynamically at runtime
- Version-controlled separately from source files

Compilation automatically validates the pack before building. Fix any validation errors first.

---

## 11. Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| **Cmd+O** | Open pack folder |
| **Cmd+S** | Save all changes |
| **Cmd+N** | New entity (in selected category) |
| **Cmd+D** | Duplicate selected entity |
| **Cmd+Z** | Undo last action |
| **Cmd+F** | Global search |
| **Cmd+V** | Import entity from clipboard |
| **Cmd+C** | Copy selected entity JSON (in detail editor) |
| **Cmd+,** | Open preferences |
| **Cmd+Q** | Quit PackEditor |

---

## Tips & Best Practices

### Organizing Content

- Use meaningful entity IDs (e.g., `enemy_goblin_scout` instead of `enemy_1`)
- Add descriptions and tags to make entities easy to find
- Use the global search (Cmd+F) to quickly locate entities

### Saving & Backup

- Save frequently with **Cmd+S** to avoid losing work
- Use version control (Git) to track pack changes
- Keep backups of important packs before major edits

### Validation & Quality

- Validate your pack (toolbar button) before compiling
- Check for unused or orphaned entities
- Test entities in-game after compilation

### Performance

- Keep entity lists organized and sorted by name or category
- Use drag & reorder to arrange high-priority entities at the top
- Close unused packs to reduce memory usage

---

## Troubleshooting

### Pack Won't Load

- Verify the folder contains a valid `manifest.json`
- Check that `manifest.json` is valid JSON (use a JSON validator)
- Ensure all referenced entity files exist

### Entities Not Appearing

- Confirm entities are in the correct category folder
- Validate the pack (Cmd+V) to check for errors
- Reload the pack by closing and reopening

### Changes Not Saving

- Check the isDirty indicator to confirm changes were made
- Ensure you've pressed **Cmd+S** to save
- Verify the pack folder has write permissions

### Compilation Fails

- Run validation (toolbar button) to identify errors
- Fix all validation errors before compiling
- Check system disk space and write permissions

---

## Support

For additional help with PackEditor:

- Consult the **ARCHITECTURE.md** for technical details
- Review **INDEX.md** for project documentation
- Check the game's developer documentation for entity format specifications

---

**PackEditor v1.0** — A tool for creating rich content for ECHO: Legends of the Veil
