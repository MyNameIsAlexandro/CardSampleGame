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

/// Semantic color palette for the app
public enum AppColors {
    // MARK: - Primary Actions
    /// Primary action color (buttons, links)
    public static let primary = Color.blue
    /// Secondary action color
    public static let secondary = Color.gray

    // MARK: - Game States
    /// Success/positive state
    public static let success = Color.green
    /// Warning state
    public static let warning = Color.orange
    /// Danger/negative state
    public static let danger = Color.red
    /// Info state
    public static let info = Color.blue

    // MARK: - Twilight Marches Theme
    /// Light alignment
    public static let light = Color.yellow
    /// Dark alignment
    public static let dark = Color.purple
    /// Neutral alignment
    public static let neutral = Color.gray

    // MARK: - Resonance
    /// Nav (dark world) resonance color
    public static let resonanceNav = Color.purple
    /// Prav (light world) resonance color
    public static let resonancePrav = Color(red: 0.85, green: 0.7, blue: 0.2)
    /// Yav (neutral) resonance color
    public static let resonanceYav = Color.gray
    /// Spirit/Will track color
    public static let spirit = Color(red: 0.3, green: 0.5, blue: 0.9)

    // MARK: - Resources
    /// Health color
    public static let health = Color.red
    /// Faith color
    public static let faith = Color.yellow
    /// Power/Attack color
    public static let power = Color.orange
    /// Defense/Shield color
    public static let defense = Color.blue

    // MARK: - Backgrounds
    /// System background
    public static let backgroundSystem = Color(UIColor.systemBackground)
    /// Tertiary system background
    public static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)

    // MARK: - UI Elements
    /// Card background
    public static let cardBackground = Color(UIColor.secondarySystemBackground)
    /// Card back (fate deck)
    public static let cardBack = Color(red: 0.15, green: 0.25, blue: 0.4)
    /// Overlay background
    public static let overlay = Color.black.opacity(0.5)
    /// Highlight color
    public static let highlight = Color.blue
    /// Muted text
    public static let muted = Color.secondary

    // MARK: - Rarity Colors
    /// Common rarity
    public static let rarityCommon = Color.gray
    /// Uncommon rarity
    public static let rarityUncommon = Color.green
    /// Rare rarity
    public static let rarityRare = Color.blue
    /// Epic rarity
    public static let rarityEpic = Color.purple
    /// Legendary rarity
    public static let rarityLegendary = Color.orange

    // MARK: - Region States
    /// Visited region
    public static let regionVisited = Color.green.opacity(0.3)
    /// Available region
    public static let regionAvailable = Color.blue.opacity(0.3)
    /// Locked region
    public static let regionLocked = Color.gray.opacity(0.3)
    /// Current region
    public static let regionCurrent = Color.blue
}

// MARK: - Typography

/// Font styles for the app
public enum AppTypography {
    /// Large title
    public static let largeTitle = Font.largeTitle
    /// Title 1
    public static let title1 = Font.title
    /// Title 2
    public static let title2 = Font.title2
    /// Title 3
    public static let title3 = Font.title3
    /// Headline
    public static let headline = Font.headline
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
    /// Small shadow
    public static let sm = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    /// Medium shadow
    public static let md = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    /// Large shadow
    public static let lg = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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
