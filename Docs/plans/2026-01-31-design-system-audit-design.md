# Epic 10: Design System Audit

> Full token compliance pass. 38 violations across 5 categories.

## Tasks

### DS-01: Add CardSizes tokens to DesignSystem.swift
- `tiny: (44, 60)`, `small: (70, 100)`, `medium: (90, 120)`, `large: (150, 200)`, `reveal: (160, 220)`, `arena: (180, 200)`

### DS-02: Add AppShadows system to DesignSystem.swift
- ViewModifier-based: `.sm`, `.md`, `.lg`, `.glow(color:)`

### DS-03: Extend Sizes with icon/dot/label tokens
- `iconXL: 40`, `iconXXL: 60`, `iconHero: 48`, `iconGameOver: 64`, `dotIndicator: 8`, `healthBarLabel: 40`

### DS-04: Localize hardcoded strings
- "CRITICAL" → L10n.fateCritical (FateCardRevealView + FateDeckWidget)
- "No cards in discard pile" → L10n.fateDeckEmpty (FateDeckWidget)
- "Resonance: +N" → L10n.fateResonanceModifier (FateDeckWidget)

### DS-05: Replace Color violations
- ContentManagerView: Color(.secondarySystemBackground) × 3 → AppColors.cardBackground
- WorldMapView: Color.black → AppColors.backgroundSystem
- CombatView: .shadow(color: .black) → AppColors.backgroundSystem

### DS-06: Replace hardcoded card sizes with CardSizes tokens
- FateDeckWidget: 44×60, 150×200
- FateCardRevealView: 160×220
- BattleArenaView: 180×200
- CombatSubviews: 90×120, 70×100

### DS-07: Replace hardcoded icon sizes with Sizes tokens
- GameOverView: size 64 → Sizes.iconGameOver
- TutorialOverlayView: size 48 → Sizes.iconHero
- WorldMapView: size 40 → Sizes.iconXL
- CombatSubviews: size 60 → Sizes.iconXXL

### DS-08: Replace hardcoded shadow radii with AppShadows
- CardView: 3 shadow calls → AppShadows
- CombatView: .shadow → AppShadows.sm
- FateDeckWidget: shadow → AppShadows.sm
- ResonanceWidget: shadow → AppShadows.md
- GameOverView: shadow → AppShadows.glow

### DS-09: Normalize remaining opacity values
- HeroPanel: 0.15 → Opacity.light
- EventView: 0.1 → Opacity.faint
- TutorialOverlayView: 0.3 → Opacity.low
- HeroSelectionView: 0.1 → Opacity.faint
- ContentManagerView: 0.1 → Opacity.faint
- WorldMapView: 0.1 → Opacity.faint

### DS-10: Replace hardcoded misc sizes
- TutorialOverlayView: dot 8×8 → Sizes.dotIndicator
- DualHealthBar: width 40 → Sizes.healthBarLabel

## Verification
- xcodebuild clean build
- swift test (350 pass)
- grep for remaining Color.black, Color(.system, hardcoded .frame(width: N) in Views/
