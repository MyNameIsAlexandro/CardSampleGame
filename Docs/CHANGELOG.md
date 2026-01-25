# Changelog

All notable changes to the CardSampleGame project.

## [Unreleased]

### Engine Architecture (Epic 0-3)
- **Epic 0.1**: Asset Registry for centralized asset management
- **Epic 0.2**: TwilightEngine Swift Package migration with modular structure
- **Epic 0.3**: Content Pack system with checksums and validation

### Content Pack System (Epic 4-5)
- **Epic 4**: Season/Campaign organization for content packs
- **Epic 5**: Localization system with StringKey and LocalizedString support

### Combat & Gameplay (Epic 6-8)
- **Epic 6**: Engine-First combat system with deterministic RNG
- **Epic 7**: Data-driven hero system (JSON-based hero definitions)
- **Epic 8**: Event system with mini-game support

### UI & Design System (Epic 9)
- **Epic 9.1**: DesignSystem.swift with Spacing, Sizes, CornerRadius, AppColors, Opacity tokens
- **Epic 9.1**: DesignSystemComplianceTests for automated enforcement
- All View files migrated to use design tokens

### Documentation & Code Hygiene (Epic 10)
- **Epic 10.1**: Swift doc comments on all public API (CardRegistry, HeroRegistry, ContentRegistry)
- **Epic 10.2**: File organization - "1 file = 1 main type" principle
- CodeHygieneTests for automated enforcement

### QA & Testing (Epic 11)
- **Epic 11.1**: Legacy test cleanup (WorldState tests removed)
- **Epic 11.2**: Negative tests for content loader (broken JSON, missing fields)
- **Epic 11.3**: State round-trip serialization test

---

## [1.0.0] - Engine-First Architecture

### Added
- TwilightGameEngine as single source of truth
- ContentRegistry for pack-based content loading
- CardRegistry and HeroRegistry for runtime content
- AbilityRegistry for hero abilities
- EngineSave for deterministic save/load
- WorldRNG for reproducible randomness

### Changed
- Views read from Engine, not WorldState
- All game data loaded from Content Packs (JSON)
- Heroes defined in JSON, not Swift enums

### Removed
- Direct WorldState manipulation in Views
- Hardcoded hero classes (HeroClass enum)
- Hardcoded card definitions

---

## Architecture Principles

1. **Engine-First**: TwilightGameEngine is the single source of truth
2. **Data-Driven**: All content from JSON Content Packs
3. **Deterministic**: WorldRNG ensures reproducible gameplay
4. **Modular**: TwilightEngine as separate Swift Package
5. **Testable**: 127+ tests with automated compliance checks

---

## File Structure

```
Packages/
├── TwilightEngine/          # Core game engine
├── CharacterPacks/          # Hero definitions
│   └── CoreHeroes/
└── StoryPacks/              # Campaign content
    └── Season1/
        └── TwilightMarchesActI/
```

See [INDEX.md](INDEX.md) for full documentation map.
