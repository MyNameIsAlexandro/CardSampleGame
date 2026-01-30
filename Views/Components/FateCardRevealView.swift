import SwiftUI
import TwilightEngine

/// Context for fate card reveal (determines visual styling and text)
public enum FateContext: Equatable {
    case attack   // Player attacking enemy
    case defense  // Player defending from enemy
}

/// Animated reveal of a Fate Card with value and resonance effects.
/// Used in Active Defense combat system.
struct FateCardRevealView: View {
    let result: FateDrawResult
    let context: FateContext
    let worldResonance: Float
    let onDismiss: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var showCard = false
    @State private var showValue = false
    @State private var showEffects = false
    @State private var flipAngle: Double = 180  // UX-07: 3D flip

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Context header
            HStack {
                Image(systemName: context == .attack ? "burst.fill" : "shield.fill")
                    .font(.title2)
                Text(context == .attack
                    ? L10n.combatFateAttack.localized
                    : L10n.combatFateDefense.localized)
                    .font(.headline)
            }
            .foregroundColor(context == .attack ? AppColors.power : AppColors.defense)

            Spacer()

            // Card visual
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [suitColor.opacity(Opacity.light), suitColor.opacity(Opacity.faint)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .strokeBorder(suitColor, lineWidth: 2)
                    )
                    .scaleEffect(showCard ? 1.0 : 0.5)
                    .opacity(showCard ? 1.0 : 0.0)
                    .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
                    .opacity(flipAngle > 90 ? 0 : 1)

                VStack(spacing: Spacing.md) {
                    // Card name
                    Text(result.card.name)
                        .font(.caption.bold())
                        .foregroundColor(suitColor)
                        .opacity(showCard ? 1.0 : 0.0)

                    // Suit icon
                    if let suit = result.card.suit {
                        Image(systemName: suitIcon(suit))
                            .font(.system(size: Sizes.largeIcon))
                            .foregroundColor(suitColor)
                            .opacity(showCard ? 1.0 : 0.0)
                    }

                    // Value display
                    Text(valueText)
                        .font(.system(size: Sizes.hugeCardValue, weight: .bold, design: .rounded))
                        .foregroundColor(valueColor)
                        .scaleEffect(showValue ? 1.0 : 0.3)
                        .opacity(showValue ? 1.0 : 0.0)

                    // Critical indicator
                    if result.isCritical {
                        Text("CRITICAL")
                            .font(.caption.bold())
                            .foregroundColor(AppColors.resonancePrav)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxxs)
                            .background(AppColors.resonancePrav.opacity(Opacity.faint))
                            .cornerRadius(CornerRadius.sm)
                            .opacity(showValue ? 1.0 : 0.0)
                    }
                }
            }

            // Resonance effect (if rule was applied)
            if let rule = result.appliedRule {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "waveform.path")
                        .foregroundColor(AppColors.spirit)
                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        Text(resonanceZoneName)
                            .font(.caption.bold())
                        Text("\(rule.modifyValue >= 0 ? "+" : "")\(rule.modifyValue)")
                            .font(.caption)
                    }
                    .foregroundColor(AppColors.spirit)
                }
                .padding(Spacing.sm)
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.md)
                .opacity(showEffects ? 1.0 : 0.0)
            }

            // Result interpretation
            Text(resultInterpretation)
                .font(.subheadline)
                .foregroundColor(AppColors.muted)
                .multilineTextAlignment(.center)
                .opacity(showEffects ? 1.0 : 0.0)

            Spacer()

            // Dismiss button
            Button(action: {
                dismiss()
                onDismiss()
            }) {
                Text(L10n.buttonOk.localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(CornerRadius.lg)
            }
            .padding(.horizontal)
            .opacity(showEffects ? 1.0 : 0.0)
        }
        .padding()
        .presentationDetents([.medium])
        .onAppear {
            animateReveal()
        }
    }

    // MARK: - Computed Properties

    private var suitColor: Color {
        guard let suit = result.card.suit else { return AppColors.spirit }
        return suitColorFor(suit)
    }

    private var valueText: String {
        let value = result.effectiveValue
        return value >= 0 ? "+\(value)" : "\(value)"
    }

    private var valueColor: Color {
        // In Active Defense, high values are ALWAYS good
        // Attack: +2 = more damage to enemy
        // Defense: +2 = less damage to player
        return result.effectiveValue >= 0 ? AppColors.success : AppColors.danger
    }

    private var resonanceZoneName: String {
        let zone = ResonanceEngine.zone(for: worldResonance)
        switch zone {
        case .deepNav: return L10n.resonanceDeepNav.localized
        case .nav: return L10n.resonanceNav.localized
        case .yav: return L10n.resonanceYav.localized
        case .prav: return L10n.resonancePrav.localized
        case .deepPrav: return L10n.resonanceDeepPrav.localized
        }
    }

    private var resultInterpretation: String {
        let value = result.effectiveValue
        if context == .attack {
            if value >= 3 {
                return L10n.combatFateAttackGreat.localized
            } else if value >= 0 {
                return L10n.combatFateAttackGood.localized
            } else {
                return L10n.combatFateAttackWeak.localized
            }
        } else {
            if value >= 3 {
                return L10n.combatFateDefenseGreat.localized
            } else if value >= 0 {
                return L10n.combatFateDefenseGood.localized
            } else {
                return L10n.combatFateDefenseWeak.localized
            }
        }
    }

    // MARK: - Animation

    private func animateReveal() {
        withAnimation(.spring(response: AnimationDuration.normal, dampingFraction: 0.7)) {
            showCard = true
        }

        // UX-07: 3D flip after card appears
        withAnimation(.easeInOut(duration: AnimationDuration.slow).delay(0.1)) {
            flipAngle = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationDuration.normal + 0.15) {
            withAnimation(.spring(response: AnimationDuration.normal, dampingFraction: 0.6)) {
                showValue = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationDuration.slow) {
            withAnimation(.easeOut(duration: AnimationDuration.normal)) {
                showEffects = true
            }
        }
    }

    // MARK: - Helpers

    private func suitIcon(_ suit: FateCardSuit) -> String {
        switch suit {
        case .nav: return "moon.fill"
        case .yav: return "circle.fill"
        case .prav: return "sun.max.fill"
        }
    }

    private func suitColorFor(_ suit: FateCardSuit) -> Color {
        switch suit {
        case .nav: return AppColors.resonanceNav
        case .yav: return AppColors.resonanceYav
        case .prav: return AppColors.resonancePrav
        }
    }
}
