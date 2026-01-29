# CardSampleGame / ECHO: Legends of the Veil — Context & Rules (v3.0)

**Project type:** Narrative Co-op Deckbuilder RPG (iOS)
**Core principle:** Engine-First + Data-Driven content (JSON)
**Non-negotiables:** no UUID for content, no system RNG, state changes only via actions, tests for Engine.

---

## 🧱 Architecture (Layered Cake)

### 1) Core Layer — `Packages/TwilightEngine`
- Pure Swift logic only. **No UI imports** (`SwiftUI`/`UIKit` запрещены в Engine).
- Single source of truth: `WorldState`, `ResonanceState`, `FateDeck` (+ derived projections).
- Any state mutation goes **only** through `GameAction` (reducers/handlers). No "reach-in and mutate".

### 2) Data Layer — `Resources/ContentPacks` (JSON)
- All gameplay entities are defined here: enemies, cards, heroes, locations, rules, etc.
- **IDs:** strict `String` (`definitionId`). **UUID for content is forbidden.**
- Instances in runtime (e.g., a spawned enemy) may have separate **instanceId**, but it must be deterministic/serializable.

### 3) App Layer — `App/`, `Views/`
- Pattern: **MVVM + Intents**.
- Views are dumb: render state, send intents/actions.
- Design System only: no hardcoded colors/sizes (`AppColors`, `Spacing`, `AppFonts`).

---

## 🛡 Hard Rules (Must Follow)

### Engine & Game Logic
- **No System RNG:** запрещено `Int.random()`, `UUID()` as randomness, `GameplayKit` RNG напрямую.
  Use only `FateDeckManager` / `WorldRNG` (seeded & serializable).
- **Time is discrete:** world time/day changes only via `TimeEngine.advance()` (one tick pipeline).
- **Stable saves:** `EngineSave` must never "fallback to uuidString".
  If a required `definitionId` is missing → fail fast (explicit error), don't silently repair.
- **Strict boundaries:** App never mutates Engine state directly; only dispatches `GameAction`.

### Concurrency & Swift
- Prefer immutability/value types in Engine.
- Be explicit about Sendable/actor boundaries where relevant (Swift 6 strictness).
- No hidden global singletons in Engine.

### UI & Assets
- No raw `Image("name")` in UI. Use `SafeImage` / `AssetRegistry`.
- No magic numbers: prefer `Spacing.*`, `AppFonts.*`, `AppColors.*`.

### Testing (Engine)
- TDD is mandatory for `Packages/TwilightEngine`.
- No `XCTSkip` as a "solution".
- Prefer `TestContentLoader` to inject deterministic content and seeds.

---

## 🧩 Patterns We Use

- **Registry pattern** for content loading:
  - `ContentRegistry` loads JSON packs → validates → exposes typed definitions by `definitionId`.
- **Provider pattern** for data access:
  - Engine depends on protocols (e.g., `ContentProviding`, `RNGProviding`), concrete impl injected.
- **Action/Reducer pipeline**:
  - `GameAction` -> `Reducer/Handler` -> new `WorldState` (+ emitted events/log).
- **Fate Deck instead of dice**:
  - `FateDeck` (-1/0/+1/Crit), modified by Resonance; deterministic & serializable.

---

## 🔑 Glossary (Canonical Meanings)

- **Resonance:** global scale (-100…100): Nav (-100) / Yav (0) / Prav (+100)
- **Fate Deck:** RNG replacement; do not bypass it.
- **Unified Resolution:** combat & diplomacy share the same resolution pipeline.
- **Dual Health:** enemies have `HP` (Body) + `Will` (Mind).

---

## 🧪 Useful Commands (Project Defaults)

- Run Engine tests:
  - `swift test --package-path Packages/TwilightEngine`
- Project dump:
  - `python3 DevTools/collect_project_v4.py`
- Update docs:
  - `python3 DevTools/update_docs_v3.py`

---

## ✅ Working Agreement for Claude

1) Before coding, identify the layer you are editing (Engine vs App vs JSON).
2) If touching JSON, validate conditions & IDs (no UUID; definitionId required).
3) If adding mechanics, route through `GameAction` and write/extend Engine tests.
4) When uncertain about a rule/meaning — **ask**, don't invent.
