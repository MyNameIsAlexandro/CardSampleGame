import SwiftUI
import TwilightEngine

struct GameOverView: View {
    let result: GameEndResult
    let engine: TwilightGameEngine
    let onReturnToMenu: () -> Void

    private var isVictory: Bool {
        if case .victory = result { return true }
        return false
    }

    private var defeatReason: String? {
        if case .defeat(let reason) = result { return reason }
        return nil
    }

    var body: some View {
        ZStack {
            AppColors.backgroundSystem.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Icon
                Image(systemName: isVictory ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 64))
                    .foregroundColor(isVictory ? AppColors.warning : AppColors.danger)

                // Title
                Text(isVictory
                     ? L10n.gameOverVictoryTitle.localized
                     : L10n.gameOverDefeatTitle.localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(isVictory ? AppColors.warning : AppColors.danger)

                // Message / Reason
                if isVictory {
                    Text(L10n.gameOverVictoryMessage.localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                } else if let reason = defeatReason {
                    Text(L10n.gameOverDefeatReason.localized(with: reason))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }

                // Stats
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(L10n.gameOverStats.localized)
                        .font(.headline)

                    Text(L10n.gameOverDaysSurvived.localized(with: engine.currentDay))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.lg)

                Spacer()

                // Return to menu button
                Button(action: onReturnToMenu) {
                    Text(L10n.gameOverReturnToMenu.localized)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .cornerRadius(CornerRadius.lg)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }
}
