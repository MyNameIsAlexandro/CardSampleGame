/// Файл: Views/Combat/CombatOutcomeAndCardsViews.swift
/// Назначение: Содержит реализацию файла CombatOutcomeAndCardsViews.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

// MARK: - Combat Over View

struct CombatOverView: View {
    let registry: ContentRegistry
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

                    if !outcomeSummary.isEmpty {
                        Text(outcomeSummary)
                            .font(.body)
                            .foregroundColor(AppColors.secondary)
                            .multilineTextAlignment(.center)
                    }

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

    @ViewBuilder
    private var rewardsSection: some View {
        VStack(spacing: Spacing.md) {
            Divider().background(AppColors.secondary.opacity(Opacity.light))

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
        registry.getCard(id: cardId)?.name.localized ?? cardId
    }

    private func lootCardColor(_ cardId: String) -> Color {
        guard let card = registry.getCard(id: cardId) else { return AppColors.secondary }
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
