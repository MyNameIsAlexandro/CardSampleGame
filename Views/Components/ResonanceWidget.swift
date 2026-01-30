import SwiftUI
import TwilightEngine

/// Displays current world resonance as an animated horizontal gauge.
/// Color shifts from purple (Nav) through gray (Yav) to gold (Prav).
/// Engine-First: reads `engine.resonanceValue` directly.
struct ResonanceWidget: View {
    @ObservedObject var engine: TwilightGameEngine

    /// Compact mode: shows only icon + value badge (for combat HUD)
    var compact: Bool = false

    /// Normalized position 0...1 (0 = deepNav -100, 0.5 = Yav 0, 1 = deepPrav +100)
    private var normalizedValue: CGFloat {
        CGFloat((engine.resonanceValue + 100) / 200)
    }

    /// Current zone label based on resonance value
    private var zoneLabel: String {
        let v = engine.resonanceValue
        switch v {
        case ...(-60): return L10n.resonanceZoneDeepNav.localized
        case ...(-20): return L10n.resonanceZoneNav.localized
        case ..<20:    return L10n.resonanceZoneYav.localized
        case ..<60:    return L10n.resonanceZonePrav.localized
        default:       return L10n.resonanceZoneDeepPrav.localized
        }
    }

    /// Zone color based on resonance value
    private var zoneColor: Color {
        let v = engine.resonanceValue
        switch v {
        case ...(-60): return AppColors.resonanceNav
        case ...(-20): return AppColors.resonanceNav.opacity(Opacity.high)
        case ..<20:    return AppColors.resonanceYav
        case ..<60:    return AppColors.resonancePrav.opacity(Opacity.high)
        default:       return AppColors.resonancePrav
        }
    }

    /// Zone icon based on resonance value
    private var zoneIcon: String {
        let v = engine.resonanceValue
        switch v {
        case ...(-20): return "moon.fill"       // Nav
        case ..<20:    return "circle.fill"      // Yav
        default:       return "sun.max.fill"     // Prav
        }
    }

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - Compact View (for combat HUD)

    private var compactView: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: zoneIcon)
                .font(.caption)
                .foregroundColor(zoneColor)

            Text(String(format: "%+.0f", engine.resonanceValue))
                .font(.caption.bold())
                .foregroundColor(zoneColor)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(zoneColor.opacity(Opacity.faint))
        .cornerRadius(CornerRadius.sm)
    }

    // MARK: - Full View (for world map)

    private var fullView: some View {
        VStack(spacing: Spacing.xxs) {
            // Zone label
            Text(zoneLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(zoneColor)

            // Gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.resonanceNav, AppColors.resonanceYav, AppColors.resonancePrav],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(Opacity.light)

                    // Indicator dot
                    Circle()
                        .fill(zoneColor)
                        .frame(width: Sizes.progressThick * 2, height: Sizes.progressThick * 2)
                        .shadow(color: zoneColor.opacity(Opacity.mediumHigh), radius: AppShadows.md.radius)
                        .offset(x: max(0, min(geo.size.width - Sizes.progressThick * 2, normalizedValue * geo.size.width - Sizes.progressThick)))
                        .animation(.easeInOut(duration: AnimationDuration.slow), value: normalizedValue)
                }
            }
            .frame(height: Sizes.progressThick * 2)

            // Value label
            Text(String(format: "%+.0f", engine.resonanceValue))
                .font(.caption2)
                .foregroundColor(AppColors.muted)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xxs)
    }
}
