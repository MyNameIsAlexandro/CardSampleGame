/// Файл: Views/Combat/CombatSubviews.swift
/// Назначение: Содержит реализацию файла CombatSubviews.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

// MARK: - Mulligan Overlay

/// Full-screen overlay shown at combat start to swap initial hand cards.
struct MulliganOverlay: View {
    let hand: [Card]
    let selection: Set<String>
    let onToggle: (String) -> Void
    let onConfirm: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text(L10n.combatMulliganTitle.localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)

                Text(L10n.combatMulliganPrompt.localized)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)

                // Card selection
                HStack(spacing: Spacing.md) {
                    ForEach(hand) { card in
                        MulliganCardView(
                            card: card,
                            isSelected: selection.contains(card.id)
                        )
                        .onTapGesture { onToggle(card.id) }
                    }
                }
                .padding(.vertical, Spacing.md)

                // Action buttons
                HStack(spacing: Spacing.lg) {
                    Button(action: onSkip) {
                        Text(L10n.combatMulliganSkip.localized)
                            .font(.headline)
                            .foregroundColor(AppColors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.backgroundTertiary)
                            .cornerRadius(CornerRadius.lg)
                    }

                    if !selection.isEmpty {
                        Button(action: onConfirm) {
                            Text(L10n.combatMulliganConfirm.localized)
                                .font(.headline)
                                .foregroundColor(AppColors.backgroundSystem)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.primary)
                                .cornerRadius(CornerRadius.lg)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(Spacing.xl)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.xl)
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSystem)
    }
}

/// Card view for mulligan selection — shows highlight border when selected.
struct MulliganCardView: View {
    let card: Card
    let isSelected: Bool

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(card.name)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            VStack(spacing: Spacing.xxxs) {
                if let power = card.power, power > 0 {
                    Label("+\(power)", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.danger)
                }
                if let wisdom = card.wisdom, wisdom > 0 {
                    Label("+\(wisdom)", systemImage: "bubble.left.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.info)
                }
                if let def = card.defense, def > 0 {
                    Label("+\(def)", systemImage: "shield.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.primary)
                }
            }

            if card.faithCost > 0 {
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("\(card.faithCost)")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.warning)
            }
        }
        .frame(width: Sizes.cardFrameMediumW, height: Sizes.cardFrameMediumH)
        .padding(Spacing.xs)
        .background(isSelected ? AppColors.danger.opacity(Opacity.light) : AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(isSelected ? AppColors.danger : AppColors.muted.opacity(Opacity.light), lineWidth: isSelected ? 2 : 1)
        )
    }
}

// MARK: - Hero Deck Indicator

/// Shows hero card deck count and discard count above the hand.
struct HeroDeckIndicator: View {
    let deckCount: Int
    let discardCount: Int

    var body: some View {
        HStack(spacing: Spacing.md) {
            Label("\(deckCount)", systemImage: "rectangle.portrait.on.rectangle.portrait")
                .font(.caption2)
                .foregroundColor(AppColors.secondary)

            Label("\(discardCount)", systemImage: "tray")
                .font(.caption2)
                .foregroundColor(AppColors.muted)
        }
        .padding(.horizontal)
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Enemy Panel

/// Shows enemy intent, name, and dual health bars
struct EnemyPanel: View {
    let enemy: EncounterEnemyState?
    let intent: EnemyIntent?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Intent badge
            if let intent = intent {
                EnemyIntentBadge(intent: intent)
                    .transition(.scale.combined(with: .opacity))
            }

            // Enemy name
            if let enemy = enemy {
                Text(enemy.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)

                // Dual health bars
                DualHealthBar(
                    currentHP: enemy.hp,
                    maxHP: enemy.maxHp,
                    currentWill: enemy.wp ?? 0,
                    maxWill: enemy.maxWp ?? 0
                )
                .padding(.horizontal, Spacing.xl)
            } else {
                Text("---")
                    .font(.title2)
                    .foregroundColor(AppColors.muted)
            }
        }
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.backgroundTertiary)
    }
}

// MARK: - Round Info Bar

struct RoundInfoBar: View {
    let round: Int
    let phase: EncounterPhase

    var body: some View {
        HStack {
            Label(L10n.encounterRoundLabel.localized(with: round), systemImage: "clock")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Text(phaseLabel)
                .font(.subheadline)
                .foregroundColor(phaseColor)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.backgroundSystem)
    }

    private var phaseLabel: String {
        switch phase {
        case .intent: return L10n.encounterPhaseIntent.localized
        case .playerAction: return L10n.encounterPhasePlayerAction.localized
        case .enemyResolution: return L10n.encounterPhaseEnemyResolution.localized
        case .roundEnd: return L10n.encounterPhaseRoundEnd.localized
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .playerAction: return AppColors.success
        case .enemyResolution: return AppColors.danger
        default: return AppColors.muted
        }
    }
}

// MARK: - Hero Health Bar

struct HeroHealthBar: View {
    let currentHP: Int
    let maxHP: Int

    private var fraction: CGFloat {
        maxHP > 0 ? CGFloat(currentHP) / CGFloat(maxHP) : 0
    }

    private var barColor: Color {
        if fraction > 0.5 { return AppColors.success }
        if fraction > 0.25 { return AppColors.warning }
        return AppColors.danger
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "heart.fill")
                .foregroundColor(barColor)
                .font(.subheadline)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.secondary.opacity(Opacity.light))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction)
                        .animation(.easeInOut(duration: 0.3), value: currentHP)
                }
            }
            .frame(height: Sizes.progressThick + 2)

            Text("\(currentHP)/\(maxHP)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Action Bar

/// Three equal-weight action buttons: Attack, Influence, Wait
struct ActionBar: View {
    let canAct: Bool
    let hasSpiritTrack: Bool
    var attackBonus: Int = 0
    var influenceBonus: Int = 0
    let onAttack: () -> Void
    let onInfluence: () -> Void
    let onWait: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            actionButton(
                title: L10n.encounterActionAttack.localized,
                icon: "flame.fill",
                color: AppColors.danger,
                bonus: attackBonus,
                action: onAttack
            )

            actionButton(
                title: L10n.encounterActionInfluence.localized,
                icon: "bubble.left.fill",
                color: AppColors.primary,
                bonus: influenceBonus,
                action: onInfluence
            )
            .opacity(hasSpiritTrack ? 1.0 : 0.4)
            .disabled(!hasSpiritTrack)

            actionButton(
                title: L10n.encounterActionWait.localized,
                icon: "hourglass",
                color: AppColors.secondary,
                bonus: 0,
                action: onWait
            )
        }
        .padding(.horizontal)
        .opacity(canAct ? 1.0 : 0.4)
        .disabled(!canAct)
    }

    private func actionButton(title: String, icon: String, color: Color, bonus: Int, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.play(.light)
            action()
        } label: {
            VStack(spacing: Spacing.xxs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title2)
                    if bonus > 0 {
                        Text("+\(bonus)")
                            .font(.system(size: Sizes.tinyCaption, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.xxxs)
                            .background(AppColors.warning)
                            .cornerRadius(CornerRadius.sm)
                            .offset(x: Spacing.sm, y: -Spacing.xxs)
                    }
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(color)
            .cornerRadius(CornerRadius.lg)
        }
        .buttonStyle(ActionButtonStyle())
    }
}

/// Press-scale button style for action buttons
private struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Fate Deck Bar

struct FateDeckBar: View {
    let drawCount: Int
    let discardCount: Int
    var faith: Int = 0
    let onFlee: () -> Void

    var body: some View {
        HStack {
            Label("\(drawCount)", systemImage: "rectangle.portrait.on.rectangle.portrait.fill")
                .font(.caption)
                .foregroundColor(AppColors.muted)

            Label("\(discardCount)", systemImage: "tray.full.fill")
                .font(.caption)
                .foregroundColor(AppColors.muted)

            Label("\(faith)", systemImage: "sparkles")
                .font(.caption)
                .foregroundColor(AppColors.warning)

            Spacer()

            Button(action: onFlee) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "figure.walk")
                    Text(L10n.encounterActionFlee.localized)
                }
                .font(.caption)
                .foregroundColor(AppColors.muted)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.xs)
    }
}
