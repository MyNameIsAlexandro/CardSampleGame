# Epic 8: Save Safety + Onboarding + Settings

Date: 2026-01-30
Status: **IN PROGRESS**

## Goal

Eliminate all data-loss risks, add first-time tutorial, and settings screen.

## Tasks

| ID | Task | Status | Result |
|---|---|---|---|
| SAV-01 | Game Over screen: victory/defeat UI | DONE | GameOverView with victory/defeat, stats, return to menu |
| SAV-02 | Fate Deck persistence in EngineSave | DONE | fateDeckState: FateDeckState?, 3 gate tests |
| SAV-03 | Mid-combat save in EngineSave | DEFERRED | Complex — requires EncounterEngine serialization |
| SAV-04 | Auto-save every 3 days + after combat | DONE | onChange observers in WorldMapView, onAutoSave callback |
| SAV-05 | Game Over → menu navigation flow | DONE | fullScreenCover on WorldMapView, onExit() returns to menu |
| TUT-01 | First-run detection + tutorial flag | DONE | @AppStorage("hasCompletedTutorial"), trigger on first startGame |
| TUT-02 | Tutorial overlay with step-by-step hints | DONE | TutorialOverlayView, 4 steps, skip/next/finish |
| SET-01 | Settings screen: language, difficulty, reset | DONE | SettingsView with difficulty picker, language link, reset options |
| SET-02 | Difficulty system: enemy HP/power scaling | DONE | DifficultyLevel enum with hpMultiplier/powerMultiplier |

## Gate Tests: INV_SAV8_GateTests — 3 tests

| Test | Scope |
|------|-------|
| testFateDeckState_includedInSave | Fate deck state present in save |
| testFateDeckState_roundTrip | Draw/discard preserved through save/load |
| testFateDeckState_backwardCompatible | Old saves without fateDeckState load safely |

## Stats

- **Engine tests**: 350 (0 failures, 0 skips)
- **Gate tests**: 70 across 6 files
- **Simulator**: builds clean (iPhone 17 Pro)

## Files Created

- `Views/GameOverView.swift` — Victory/defeat screen with stats
- `Views/TutorialOverlayView.swift` — 4-step tutorial overlay
- `Views/SettingsView.swift` — Settings + DifficultyLevel enum

## Files Modified

### Engine:
- `EngineSave.swift` — added `fateDeckState: FateDeckState?` with backward-compatible decoding
- `TwilightGameEngine.swift` — serialize/restore fate deck in createEngineSave/restoreFromEngineSave

### App:
- `ContentView.swift` — settings button, tutorial trigger, auto-save callback
- `WorldMapView.swift` — game over fullScreenCover, auto-save onChange observers, onAutoSave callback
- `GameSave.swift` — added `deleteAllSaves()`
- `Localization.swift` — 20+ new L10n keys (settings, tutorial, game over)
- `en.lproj/Localizable.strings` — 20+ new strings
- `ru.lproj/Localizable.strings` — 20+ new strings

### Tests:
- `INV_SAV8_GateTests.swift` — 3 gate tests for fate deck persistence
