/// Файл: Views/GameOverView.swift
/// Назначение: Содержит реализацию файла GameOverView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct GameOverView: View {
    let result: GameEndResult
    let vm: GameEngineObservable
    let onReturnToMenu: () -> Void

    @State private var showContent = false
    @State private var iconScale: CGFloat = 0.3

    private var isVictory: Bool {
        if case .victory = result { return true }
        return false
    }

    private var defeatReason: GameEndDefeatReason? {
        if case .defeat(let reason) = result { return reason }
        return nil
    }

    private func localizedDefeatReason(_ reason: GameEndDefeatReason) -> String {
        switch reason {
        case .worldTensionMax:
            return L10n.gameOverDefeatReasonWorldTensionMax.localized
        case .heroDied:
            return L10n.gameOverDefeatReasonHeroDied.localized
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundSystem.ignoresSafeArea()

            // UX-08: Victory glow / defeat vignette
            if isVictory {
                AppGradient.victoryGlow.ignoresSafeArea()
            } else {
                AppGradient.defeatVignette.ignoresSafeArea()
            }

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Icon with scale animation
                Image(systemName: isVictory ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: Sizes.iconGameOver))
                    .foregroundColor(isVictory ? AppColors.warning : AppColors.danger)
                    .scaleEffect(iconScale)
                    .shadow(AppShadows.glow(isVictory ? AppColors.warning : AppColors.danger))

                // Title
                Text(isVictory
                     ? L10n.gameOverVictoryTitle.localized
                     : L10n.gameOverDefeatTitle.localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(isVictory ? AppColors.warning : AppColors.danger)
                    .opacity(showContent ? 1 : 0)

                // Message / Reason
                if isVictory {
                    Text(L10n.gameOverVictoryMessage.localized)
                        .font(.body)
                        .foregroundColor(AppColors.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                        .opacity(showContent ? 1 : 0)
                } else if let reason = defeatReason {
                    Text(L10n.gameOverDefeatReason.localized(with: localizedDefeatReason(reason)))
                        .font(.body)
                        .foregroundColor(AppColors.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                        .opacity(showContent ? 1 : 0)
                }

                // Stats
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(L10n.gameOverStats.localized)
                        .font(.headline)

                    Text(L10n.gameOverDaysSurvived.localized(with: vm.engine.currentDay))
                        .font(.subheadline)
                        .foregroundColor(AppColors.muted)
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.lg)
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Return to menu button
                Button(action: {
                    HapticManager.shared.play(.light)
                    onReturnToMenu()
                }) {
                    Text(L10n.gameOverReturnToMenu.localized)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.backgroundSystem)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .cornerRadius(CornerRadius.lg)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            // Staged entrance animation (UX-08)
            withAnimation(AppAnimation.bouncy.delay(0.2)) {
                iconScale = 1.0
            }
            withAnimation(AppAnimation.standard.delay(0.6)) {
                showContent = true
            }
            // Haptic + sound
            if isVictory {
                HapticManager.shared.play(.success)
                SoundManager.shared.play(.victory)
            } else {
                HapticManager.shared.play(.error)
                SoundManager.shared.play(.defeat)
            }
        }
    }
}
