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

// MARK: - Combat Over View

struct CombatOverView: View {
    let result: EncounterResult
    var turnsPlayed: Int = 0
    var totalDamageDealt: Int = 0
    var cardsPlayed: Int = 0
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Image(systemName: iconName)
                        .font(.system(size: Sizes.iconRegion))
                        .foregroundColor(outcomeColor)

                    Text(outcomeTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(outcomeColor)

                    // HP summary
                    if !outcomeSummary.isEmpty {
                        Text(outcomeSummary)
                            .font(.body)
                            .foregroundColor(AppColors.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Rewards section (only on victory)
                    if case .victory = result.outcome {
                        rewardsSection
                    }

                    Button(action: onDismiss) {
                        Text(L10n.encounterOutcomeContinue.localized)
                            .font(.headline)
                            .foregroundColor(AppColors.backgroundSystem)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primary)
                            .cornerRadius(CornerRadius.lg)
                    }
                    .padding(.horizontal, Spacing.xl)
                }
                .padding(Spacing.xl)
            }
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.xl)
            .padding(.horizontal, Spacing.xl)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.7)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSystem.opacity(Opacity.mediumHigh))
    }

    // MARK: - Rewards Section

    @ViewBuilder
    private var rewardsSection: some View {
        VStack(spacing: Spacing.md) {
            Divider().background(AppColors.secondary.opacity(0.3))

            // Faith reward
            if result.transaction.faithDelta > 0 {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppColors.faith)
                    Text(L10n.encounterOutcomeFaith.localized(with: result.transaction.faithDelta))
                        .font(.body)
                        .foregroundColor(AppColors.faith)
                    Spacer()
                }
            }

            // Resonance shift
            if abs(result.transaction.resonanceDelta) > 0.01 {
                HStack {
                    let isNav = result.transaction.resonanceDelta < 0
                    Image(systemName: isNav ? "arrow.left" : "arrow.right")
                        .foregroundColor(isNav ? AppColors.resonanceNav : AppColors.resonancePrav)
                    Text(isNav
                        ? L10n.encounterOutcomeResonanceNav.localized(with: result.transaction.resonanceDelta)
                        : L10n.encounterOutcomeResonancePrav.localized(with: result.transaction.resonanceDelta))
                        .font(.body)
                        .foregroundColor(isNav ? AppColors.resonanceNav : AppColors.resonancePrav)
                    Spacer()
                }
            }

            // Combat stats
            if turnsPlayed > 0 {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(AppColors.muted)
                    Text(L10n.encounterOutcomeStats.localized(with: turnsPlayed, totalDamageDealt, cardsPlayed))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Spacer()
                }
            }

            // Loot cards
            if !result.transaction.lootCardIds.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(L10n.encounterOutcomeLoot.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)

                    ForEach(result.transaction.lootCardIds, id: \.self) { cardId in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(lootCardColor(cardId))
                                .font(.caption)
                            Text(lootCardName(cardId))
                                .font(.body)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private func lootCardName(_ cardId: String) -> String {
        ContentRegistry.shared.getCard(id: cardId)?.name.localized ?? cardId
    }

    private func lootCardColor(_ cardId: String) -> Color {
        guard let card = ContentRegistry.shared.getCard(id: cardId) else { return AppColors.secondary }
        switch card.rarity {
        case .common: return AppColors.secondary
        case .uncommon: return AppColors.success
        case .rare: return AppColors.info
        case .epic: return AppColors.dark
        case .legendary: return AppColors.primary
        }
    }

    private var iconName: String {
        switch result.outcome {
        case .victory(.pacified): return "heart.circle.fill"
        case .victory: return "checkmark.circle.fill"
        case .defeat: return "xmark.circle.fill"
        case .escaped: return "figure.walk.circle.fill"
        }
    }

    private var outcomeColor: Color {
        switch result.outcome {
        case .victory: return AppColors.success
        case .defeat: return AppColors.danger
        case .escaped: return AppColors.warning
        }
    }

    private var outcomeTitle: String {
        switch result.outcome {
        case .victory(.pacified): return L10n.encounterOutcomePacified.localized
        case .victory: return L10n.encounterOutcomeVictory.localized
        case .defeat: return L10n.encounterOutcomeDefeat.localized
        case .escaped: return L10n.encounterOutcomeEscaped.localized
        }
    }

    private var outcomeSummary: String {
        let hp = result.transaction.hpDelta
        if hp < 0 {
            return L10n.encounterOutcomeHpLost.localized(with: -hp)
        } else if hp > 0 {
            return L10n.encounterOutcomeHpGained.localized(with: hp)
        }
        return ""
    }
}

// MARK: - Card Hand View

/// Horizontal scrollable row of playable combat cards
struct CardHandView: View {
    let cards: [Card]
    var heroFaith: Int = 0
    var insufficientFaithCardId: String? = nil
    var lastDrawnCardId: String? = nil
    let isEnabled: Bool
    let onPlay: (Card) -> Void

    var body: some View {
        if !cards.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(cards) { card in
                        let isAffordable = card.faithCost <= heroFaith || card.faithCost == 0
                        let isNewlyDrawn = lastDrawnCardId == card.id
                        let isInsufficientShake = insufficientFaithCardId == card.id

                        CombatCardView(card: card, isAffordable: isAffordable)
                            .onTapGesture { if isEnabled { onPlay(card) } }
                            .opacity(isEnabled ? (isAffordable ? Opacity.opaque : Opacity.medium) : Opacity.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(isNewlyDrawn ? AppColors.success : Color.clear, lineWidth: 2)
                            )
                            .offset(x: isInsufficientShake ? -4 : 0)
                            .animation(.default.speed(6).repeatCount(3, autoreverses: true), value: isInsufficientShake)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.xs)
        }
    }
}

/// Compact combat card (60x90) showing name, effect, and cost
struct CombatCardView: View {
    let card: Card
    var isAffordable: Bool = true

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(card.name)
                .font(.caption2)
                .fontWeight(.bold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Combat & Diplomacy stats
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
                if (card.power ?? 0) == 0 && (card.wisdom ?? 0) == 0 && (card.defense ?? 0) == 0 {
                    if let firstAbility = card.abilities.first {
                        abilityLabel(firstAbility.effect)
                    }
                }
            }

            if card.faithCost > 0 {
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("\(card.faithCost)")
                        .font(.caption2)
                }
                .foregroundColor(isAffordable ? AppColors.warning : AppColors.danger)
            }
        }
        .frame(width: Sizes.cardFrameSmallW, height: Sizes.cardFrameSmallH)
        .padding(Spacing.xxs)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(isAffordable ? AppColors.muted.opacity(Opacity.light) : AppColors.danger.opacity(Opacity.medium), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func abilityLabel(_ effect: AbilityEffect) -> some View {
        switch effect {
        case .damage(let amount, _):
            Label("+\(amount)", systemImage: "flame.fill")
                .font(.caption)
                .foregroundColor(AppColors.danger)
        case .heal(let amount):
            Label("+\(amount)", systemImage: "heart.fill")
                .font(.caption)
                .foregroundColor(AppColors.success)
        case .temporaryStat(let stat, let amount, _):
            Label("+\(amount)", systemImage: statIcon(stat))
                .font(.caption)
                .foregroundColor(statColor(stat))
        case .drawCards(let count):
            Label("+\(count)", systemImage: "rectangle.on.rectangle")
                .font(.caption)
                .foregroundColor(AppColors.primary)
        default:
            Text(card.description)
                .font(.caption2)
                .foregroundColor(AppColors.muted)
                .lineLimit(2)
        }
    }

    private func statIcon(_ stat: String) -> String {
        switch stat {
        case "attack", "strength": return "flame.fill"
        case "defense", "armor": return "shield.fill"
        case "influence", "wisdom": return "bubble.left.fill"
        default: return "star.fill"
        }
    }

    private func statColor(_ stat: String) -> Color {
        switch stat {
        case "attack", "strength": return AppColors.danger
        case "defense", "armor": return AppColors.primary
        case "influence", "wisdom": return AppColors.success
        default: return AppColors.muted
        }
    }
}

// MARK: - Combat Log View

struct CombatLogView: View {
    let entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            ForEach(Array(entries.suffix(5).enumerated()), id: \.offset) { _, entry in
                HStack(spacing: Spacing.xxxs) {
                    if let icon = logIcon(for: entry) {
                        Image(systemName: icon)
                            .font(.system(size: Sizes.tinyCaption))
                            .foregroundColor(logColor(for: entry))
                    }
                    Text(entry)
                        .font(.caption2)
                        .foregroundColor(logColor(for: entry))
                }
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func logColor(for entry: String) -> Color {
        let lower = entry.lowercased()
        if lower.contains("weak") || lower.contains("слабость") { return AppColors.success }
        if lower.contains("resist") || lower.contains("блок") { return AppColors.muted }
        if lower.contains("heal") || lower.contains("лечен") || lower.contains("regen") { return AppColors.success }
        if lower.contains("damage") || lower.contains("урон") || lower.contains("takes") || lower.contains("получ") { return AppColors.danger }
        if lower.contains("body") || lower.contains("тел") || lower.contains("will") || lower.contains("дух") { return AppColors.warning }
        return AppColors.muted
    }

    private func logIcon(for entry: String) -> String? {
        let lower = entry.lowercased()
        if lower.contains("weak") || lower.contains("слабость") { return "arrow.up.circle.fill" }
        if lower.contains("resist") || lower.contains("блок") { return "arrow.down.circle.fill" }
        return nil
    }
}
