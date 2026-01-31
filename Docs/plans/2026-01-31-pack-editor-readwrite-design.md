# PackEditor Read-Write Editors Design

## Goal
Convert all 8 PackEditor editors from read-only (LabeledContent/Text) to fully editable (TextField/Stepper/Toggle/Picker) while keeping Binding<T> pattern.

## Field Type Mapping

| Swift Type | UI Control |
|---|---|
| String / LocalizableText | TextField / LocalizedTextField |
| Int | IntField (custom) |
| Bool | Toggle |
| enum | Picker |
| [String] | StringListEditor (custom) |
| [ComplexStruct] | ForEach + inline editor + add/remove |
| Optional<T> | OptionalSection toggle + content |

## Shared Components (Views/Shared/)

### IntField
TextField with numeric formatting, label, optional range validation.

### StringListEditor
Editable list of strings with add/remove buttons. Used for lootCardIds, poolIds, neighborIds, startingDeckCardIDs, etc.

### OptionalSection<Content>
Toggle to enable/disable + content view when enabled. Used for optional fields (will, anchorId, combat config, etc.)

## Implementation Order (simple → complex)

1. **Shared components** — IntField, StringListEditor, OptionalSection
2. **RegionEditor** — flat fields, string arrays, optional anchorId
3. **CardEditor** — optional stats, enum pickers, abilities array
4. **EventEditor** — LocalizedTextField multiline, choices array with consequences
5. **EnemyEditor** — stats, abilities array, resonanceBehavior dict
6. **HeroEditor** — baseStats section (11 fields), specialAbility nested, availability
7. **FateCardEditor** — resonanceRules/onDrawEffects/choiceOptions arrays
8. **QuestEditor** — objectives with CompletionCondition, rewards/penalties
9. **BalanceEditor** — 7 sections with optional nested structs

## Architecture

- Each editor stays in one file
- Binding mutation via SwiftUI `$entity.field` propagation
- No new view models — Binding<T> is the contract
- PackEditorState.isDirty set on any mutation (already wired via Binding set closures in PackEditorApp)
