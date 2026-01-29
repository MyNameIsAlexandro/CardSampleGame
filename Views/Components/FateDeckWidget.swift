import SwiftUI
import TwilightEngine

/// Shows Fate Deck as a visual card pile with back-side up.
/// Tap deck to draw a card. Shows drawn card briefly before discarding.
struct FateDeckWidget: View {
    @ObservedObject var engine: TwilightGameEngine
    @State private var showDiscardPile = false
    @State private var drawnCard: FateCard?
    @State private var showDrawnCard = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Draw pile - visual deck stack
            Button(action: drawCard) {
                ZStack {
                    // Stack effect - multiple cards behind
                    if engine.fateDeckDrawCount > 2 {
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(AppColors.cardBack.opacity(Opacity.medium))
                            .frame(width: 44, height: 60)
                            .offset(x: 3, y: 3)
                    }
                    if engine.fateDeckDrawCount > 1 {
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(AppColors.cardBack.opacity(Opacity.high))
                            .frame(width: 44, height: 60)
                            .offset(x: 1.5, y: 1.5)
                    }
                    // Top card (back side)
                    if engine.fateDeckDrawCount > 0 {
                        cardBackView
                    } else {
                        // Empty deck placeholder
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .strokeBorder(AppColors.muted.opacity(Opacity.medium), lineWidth: 1)
                            .frame(width: 44, height: 60)
                            .overlay(
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundColor(AppColors.muted)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(engine.fateDeckDrawCount == 0 && engine.fateDeckDiscardCount == 0)

            // Deck info
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(L10n.combatFateDeckCount.localized(with: engine.fateDeckDrawCount))
                    .font(.caption2)
                    .foregroundColor(engine.fateDeckDrawCount > 0 ? AppColors.spirit : AppColors.muted)

                Button(action: { showDiscardPile = true }) {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "tray.full.fill")
                            .font(.caption2)
                        Text(L10n.combatFateDiscardCount.localized(with: engine.fateDeckDiscardCount))
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showDiscardPile) {
            FateDiscardPileView(engine: engine)
        }
        .sheet(isPresented: $showDrawnCard) {
            if let card = drawnCard {
                DrawnFateCardView(card: card, resonance: engine.resonanceValue) {
                    showDrawnCard = false
                    drawnCard = nil
                }
            }
        }
    }

    private var cardBackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(
                    LinearGradient(
                        colors: [AppColors.cardBack, AppColors.cardBack.opacity(Opacity.high)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 60)

            // Pattern on card back
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundColor(AppColors.spirit.opacity(Opacity.mediumHigh))
        }
        .shadow(color: .black.opacity(Opacity.faint), radius: 2, x: 1, y: 1)
    }

    private func drawCard() {
        guard let result = engine.fateDeck?.drawAndResolve(worldResonance: engine.resonanceValue) else {
            // If deck empty, try reshuffle
            engine.fateDeck?.reshuffle()
            return
        }
        drawnCard = result.card
        showDrawnCard = true
    }
}

/// Shows a drawn Fate Card with its effect
struct DrawnFateCardView: View {
    let card: FateCard
    let resonance: Float
    let onDismiss: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Card title
            Text(card.name)
                .font(.title2.bold())
                .foregroundColor(suitColor)

            // Card visual
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [suitColor.opacity(Opacity.light), suitColor.opacity(Opacity.faint)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .strokeBorder(suitColor, lineWidth: 2)
                    )

                VStack(spacing: Spacing.md) {
                    // Suit icon
                    if let suit = card.suit {
                        Image(systemName: suitIcon(suit))
                            .font(.system(size: 40))
                            .foregroundColor(suitColor)
                    }

                    // Value
                    Text(card.baseValue >= 0 ? "+\(card.baseValue)" : "\(card.baseValue)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(card.baseValue >= 0 ? AppColors.success : AppColors.danger)

                    // Critical indicator
                    if card.isCritical {
                        Text("CRITICAL")
                            .font(.caption.bold())
                            .foregroundColor(AppColors.resonancePrav)
                    }
                }
            }

            // Resonance zone effect
            let zone = ResonanceEngine.zone(for: resonance)
            if let rule = card.resonanceRules.first(where: { $0.zone == zone }) {
                HStack {
                    Image(systemName: "waveform.path")
                    Text("Resonance: \(rule.modifyValue >= 0 ? "+" : "")\(rule.modifyValue)")
                }
                .font(.caption)
                .foregroundColor(AppColors.spirit)
            }

            Spacer()

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
        }
        .padding()
        .presentationDetents([.medium])
    }

    private var suitColor: Color {
        guard let suit = card.suit else { return AppColors.spirit }
        return suitColorFor(suit)
    }

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

/// Shows the discard pile of played Fate Cards for card counting.
struct FateDiscardPileView: View {
    @ObservedObject var engine: TwilightGameEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if engine.fateDeckDiscardCards.isEmpty {
                    Text("No cards in discard pile")
                        .foregroundColor(AppColors.muted)
                        .italic()
                } else {
                    ForEach(engine.fateDeckDiscardCards, id: \.id) { card in
                        HStack {
                            if let suit = card.suit {
                                Image(systemName: suitIcon(suit))
                                    .foregroundColor(suitColor(suit))
                            }
                            Text(card.name)
                            Spacer()
                            Text("\(card.baseValue > 0 ? "+" : "")\(card.baseValue)")
                                .fontWeight(.bold)
                                .foregroundColor(card.baseValue >= 0 ? AppColors.success : AppColors.danger)
                        }
                    }
                }
            }
            .navigationTitle(L10n.combatFateDiscardTitle.localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.buttonOk.localized) { dismiss() }
                }
            }
        }
    }

    private func suitIcon(_ suit: FateCardSuit) -> String {
        switch suit {
        case .nav: return "moon.fill"
        case .yav: return "circle.fill"
        case .prav: return "sun.max.fill"
        }
    }

    private func suitColor(_ suit: FateCardSuit) -> Color {
        switch suit {
        case .nav: return AppColors.resonanceNav
        case .yav: return AppColors.resonanceYav
        case .prav: return AppColors.resonancePrav
        }
    }
}
