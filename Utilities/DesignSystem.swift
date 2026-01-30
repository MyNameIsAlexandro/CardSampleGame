import SwiftUI
import UIKit

// MARK: - Design System
// Reference: AUDIT_ENGINE_FIRST_v1_1.md, Epic 9.1
// Centralized design tokens for consistent UI across the app

// MARK: - Spacing

/// Spacing constants for padding and margins
public enum Spacing {
    /// 2pt - Minimal spacing
    public static let xxxs: CGFloat = 2
    /// 4pt - Extra extra small
    public static let xxs: CGFloat = 4
    /// 6pt - Extra small
    public static let xs: CGFloat = 6
    /// 8pt - Small
    public static let sm: CGFloat = 8
    /// 10pt - Small-medium
    public static let smd: CGFloat = 10
    /// 12pt - Medium
    public static let md: CGFloat = 12
    /// 16pt - Large
    public static let lg: CGFloat = 16
    /// 20pt - Extra large
    public static let xl: CGFloat = 20
    /// 24pt - Extra extra large
    public static let xxl: CGFloat = 24
    /// 32pt - Extra extra extra large
    public static let xxxl: CGFloat = 32
}

// MARK: - Sizes

/// Size constants for frames and components
public enum Sizes {
    // MARK: - Icons
    /// 16pt - Tiny icon
    public static let iconTiny: CGFloat = 16
    /// 20pt - Small icon
    public static let iconSmall: CGFloat = 20
    /// 24pt - Medium icon
    public static let iconMedium: CGFloat = 24
    /// 32pt - Large icon
    public static let iconLarge: CGFloat = 32
    /// 40pt - Extra large icon
    public static let iconXL: CGFloat = 40
    /// 50pt - Hero icon
    public static let iconHero: CGFloat = 50
    /// 60pt - Region card icon
    public static let iconRegion: CGFloat = 60
    /// 70pt - Large region icon
    public static let iconRegionLarge: CGFloat = 70
    /// 72pt - Extra large region icon
    public static let iconRegionXL: CGFloat = 72

    // MARK: - Font Sizes
    /// 9pt - Tiny caption text
    public static let tinyCaption: CGFloat = 9
    /// 36pt - Large display icon
    public static let largeIcon: CGFloat = 36
    /// 48pt - Extra extra large icon
    public static let iconXXL: CGFloat = 48
    /// 52pt - Huge card value display
    public static let hugeCardValue: CGFloat = 52

    // MARK: - Components
    /// 4pt - Progress bar thin
    public static let progressThin: CGFloat = 4
    /// 6pt - Progress bar medium
    public static let progressMedium: CGFloat = 6
    /// 8pt - Progress bar thick
    public static let progressThick: CGFloat = 8

    /// 44pt - Minimum touch target (Apple HIG)
    public static let touchTarget: CGFloat = 44

    /// 120pt - Minimum button width
    public static let buttonMinWidth: CGFloat = 120

    /// 80pt - Card width small
    public static let cardWidthSmall: CGFloat = 80
    /// 100pt - Card width medium
    public static let cardWidthMedium: CGFloat = 100
    /// 120pt - Card width large
    public static let cardWidthLarge: CGFloat = 120

    /// 100pt - Card height small
    public static let cardHeightSmall: CGFloat = 100
    /// 140pt - Card height medium
    public static let cardHeightMedium: CGFloat = 140
    /// 180pt - Card height large
    public static let cardHeightLarge: CGFloat = 180
}

// MARK: - Corner Radius

/// Corner radius constants
public enum CornerRadius {
    /// 4pt - Small
    public static let sm: CGFloat = 4
    /// 8pt - Medium
    public static let md: CGFloat = 8
    /// 12pt - Large
    public static let lg: CGFloat = 12
    /// 16pt - Extra large
    public static let xl: CGFloat = 16
    /// 20pt - Extra extra large
    public static let xxl: CGFloat = 20
    /// Full circle
    public static let full: CGFloat = .infinity
}

// MARK: - App Colors

/// Semantic color palette — Dark Slavic Fantasy theme
public enum AppColors {
    // MARK: - Primary Actions
    /// Primary action color — ancient gold
    public static let primary = Color(red: 0.85, green: 0.65, blue: 0.20)
    /// Secondary action color — muted lavender-grey
    public static let secondary = Color(red: 0.45, green: 0.40, blue: 0.50)

    // MARK: - Game States
    /// Success/positive — forest green
    public static let success = Color(red: 0.25, green: 0.70, blue: 0.35)
    /// Warning — amber
    public static let warning = Color(red: 0.90, green: 0.60, blue: 0.15)
    /// Danger/negative — blood red
    public static let danger = Color(red: 0.80, green: 0.20, blue: 0.20)
    /// Info — twilight blue
    public static let info = Color(red: 0.30, green: 0.50, blue: 0.80)

    // MARK: - Twilight Marches Theme
    /// Light alignment — warm sunlight gold
    public static let light = Color(red: 0.95, green: 0.85, blue: 0.50)
    /// Dark alignment — deep violet
    public static let dark = Color(red: 0.40, green: 0.20, blue: 0.55)
    /// Neutral alignment — stone grey
    public static let neutral = Color(red: 0.50, green: 0.48, blue: 0.45)

    // MARK: - Resonance
    /// Nav (dark world) resonance color
    public static let resonanceNav = Color(red: 0.50, green: 0.20, blue: 0.65)
    /// Prav (light world) resonance color
    public static let resonancePrav = Color(red: 0.85, green: 0.70, blue: 0.20)
    /// Yav (neutral) resonance color
    public static let resonanceYav = Color(red: 0.50, green: 0.48, blue: 0.45)
    /// Spirit/Will track color
    public static let spirit = Color(red: 0.30, green: 0.50, blue: 0.90)

    // MARK: - Resources
    /// Health — dark blood
    public static let health = Color(red: 0.75, green: 0.15, blue: 0.15)
    /// Faith — golden faith
    public static let faith = Color(red: 0.90, green: 0.75, blue: 0.25)
    /// Power/Attack — ember orange
    public static let power = Color(red: 0.85, green: 0.40, blue: 0.15)
    /// Defense/Shield — steel blue
    public static let defense = Color(red: 0.30, green: 0.45, blue: 0.70)

    // MARK: - Backgrounds
    /// System background — deep night purple-black
    public static let backgroundSystem = Color(red: 0.08, green: 0.06, blue: 0.10)
    /// Tertiary background — slightly lighter
    public static let backgroundTertiary = Color(red: 0.12, green: 0.10, blue: 0.15)

    // MARK: - UI Elements
    /// Card background — card surface
    public static let cardBackground = Color(red: 0.14, green: 0.12, blue: 0.18)
    /// Card back (fate deck) — deep midnight
    public static let cardBack = Color(red: 0.12, green: 0.18, blue: 0.30)
    /// Overlay background
    public static let overlay = Color.black.opacity(0.7)
    /// Highlight — bright gold
    public static let highlight = Color(red: 0.90, green: 0.75, blue: 0.30)
    /// Muted text — dusty grey
    public static let muted = Color(red: 0.55, green: 0.50, blue: 0.55)

    // MARK: - Rarity Colors
    /// Common — weathered stone
    public static let rarityCommon = Color(red: 0.55, green: 0.52, blue: 0.50)
    /// Uncommon — emerald
    public static let rarityUncommon = Color(red: 0.20, green: 0.65, blue: 0.35)
    /// Rare — sapphire
    public static let rarityRare = Color(red: 0.25, green: 0.45, blue: 0.80)
    /// Epic — amethyst
    public static let rarityEpic = Color(red: 0.55, green: 0.25, blue: 0.75)
    /// Legendary — legendary gold
    public static let rarityLegendary = Color(red: 0.90, green: 0.65, blue: 0.15)

    // MARK: - Card Type Colors
    /// Item card — warm brown
    public static let cardTypeItem = Color(red: 0.60, green: 0.40, blue: 0.20)
    /// Location card — teal
    public static let cardTypeLocation = Color(red: 0.20, green: 0.55, blue: 0.60)
    /// Scenario card — indigo
    public static let cardTypeScenario = Color(red: 0.40, green: 0.30, blue: 0.75)
    /// Curse card — dark curse
    public static let cardTypeCurse = Color(red: 0.25, green: 0.10, blue: 0.10)
    /// Spirit card — cyan
    public static let cardTypeSpirit = Color(red: 0.30, green: 0.75, blue: 0.85)
    /// Ritual card — indigo
    public static let cardTypeRitual = Color(red: 0.40, green: 0.30, blue: 0.75)
    /// Resource/pink accent
    public static let cardTypeResource = Color(red: 0.75, green: 0.35, blue: 0.55)

    // MARK: - Region States
    /// Visited region
    public static let regionVisited = Color(red: 0.25, green: 0.70, blue: 0.35).opacity(0.3)
    /// Available region
    public static let regionAvailable = Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.3)
    /// Locked region
    public static let regionLocked = Color(red: 0.50, green: 0.48, blue: 0.45).opacity(0.3)
    /// Current region
    public static let regionCurrent = Color(red: 0.85, green: 0.65, blue: 0.20)
}

// MARK: - Typography

/// Font styles for the app
public enum AppTypography {
    /// Large title
    public static let largeTitle = Font.largeTitle.weight(.bold)
    /// Title 1
    public static let title1 = Font.title.weight(.bold)
    /// Title 2
    public static let title2 = Font.title2.weight(.semibold)
    /// Title 3
    public static let title3 = Font.title3.weight(.semibold)
    /// Headline
    public static let headline = Font.headline.weight(.semibold)
    /// Body
    public static let body = Font.body
    /// Callout
    public static let callout = Font.callout
    /// Subheadline
    public static let subheadline = Font.subheadline
    /// Footnote
    public static let footnote = Font.footnote
    /// Caption
    public static let caption = Font.caption
    /// Caption 2
    public static let caption2 = Font.caption2
}

// MARK: - Shadows

/// Shadow styles
public enum AppShadows {
    /// Small shadow — warm gold tint
    public static let sm = Shadow(color: Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.1), radius: 2, x: 0, y: 1)
    /// Medium shadow — warm gold tint
    public static let md = Shadow(color: Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.15), radius: 4, x: 0, y: 2)
    /// Large shadow — warm gold tint
    public static let lg = Shadow(color: Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.2), radius: 8, x: 0, y: 4)
}

/// Shadow configuration
public struct Shadow {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
}

// MARK: - View Extensions

public extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.md)
    }

    /// Apply standard button padding
    func buttonPadding() -> some View {
        self
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.smd)
    }

    /// Apply standard section padding
    func sectionPadding() -> some View {
        self
            .padding(Spacing.lg)
    }

    /// Apply shadow style
    func shadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Apply primary button style
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .buttonPadding()
            .background(AppColors.primary)
            .cornerRadius(CornerRadius.md)
    }

    /// Apply secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(AppColors.primary)
            .buttonPadding()
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Animation Durations

/// Standard animation durations
public enum AnimationDuration {
    /// 0.15s - Fast
    public static let fast: Double = 0.15
    /// 0.25s - Normal
    public static let normal: Double = 0.25
    /// 0.35s - Slow
    public static let slow: Double = 0.35
    /// 0.5s - Very slow
    public static let verySlow: Double = 0.5
}

// MARK: - Opacity Values

/// Standard opacity values
public enum Opacity {
    /// 0.0 - Invisible
    public static let invisible: Double = 0.0
    /// 0.2 - Very faint
    public static let faint: Double = 0.2
    /// 0.3 - Light
    public static let light: Double = 0.3
    /// 0.5 - Medium
    public static let medium: Double = 0.5
    /// 0.6 - Medium-high
    public static let mediumHigh: Double = 0.6
    /// 0.8 - High
    public static let high: Double = 0.8
    /// 0.95 - Almost opaque
    public static let almostOpaque: Double = 0.95
    /// 1.0 - Fully opaque
    public static let opaque: Double = 1.0
}
