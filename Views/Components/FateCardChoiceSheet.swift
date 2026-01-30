import SwiftUI
import TwilightEngine

/// Sheet for choice-type fate cards — shows safe/risk options with auto-select timer
struct FateCardChoiceSheet: View {
    let card: FateCard
    let onChoose: (Int) -> Void

    @State private var timeRemaining: Int = 3
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text(L10n.fateChoiceTitle.localized)
                .font(.headline)
                .foregroundColor(AppColors.primary)

            Text(card.name)
                .font(.title2)
                .fontWeight(.bold)

            if let options = card.choiceOptions {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button(action: { choose(index) }) {
                        VStack(spacing: Spacing.xs) {
                            Text(option.label)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(option.effect)
                                .font(.caption)
                                .foregroundColor(.white.opacity(Opacity.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(index == 0 ? AppColors.success : AppColors.danger)
                        .cornerRadius(CornerRadius.lg)
                    }
                }
            }

            Text(L10n.fateChoiceTimer.localized(with: timeRemaining))
                .font(.caption)
                .foregroundColor(AppColors.muted)
                .monospacedDigit()
        }
        .padding(Spacing.xl)
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                choose(0) // auto-select safe option
            }
        }
    }

    private func choose(_ index: Int) {
        timer?.invalidate()
        onChoose(index)
    }
}
