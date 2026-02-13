/// Файл: Views/Components/FateCardChoiceSheet.swift
/// Назначение: Содержит реализацию файла FateCardChoiceSheet.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Sheet for choice-type fate cards — shows safe/risk options with auto-select timer
struct FateCardChoiceSheet: View {
    let card: FateCard
    let onChoose: (Int) -> Void

    @State private var timeRemaining: Int = 3
    @State private var countdownTask: Task<Void, Never>?

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
        .onAppear { startCountdown() }
        .onDisappear {
            countdownTask?.cancel()
            countdownTask = nil
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        timeRemaining = 3

        countdownTask = Task { @MainActor in
            while timeRemaining > 1 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
            }

            if !Task.isCancelled {
                choose(0)
            }
        }
    }

    private func choose(_ index: Int) {
        countdownTask?.cancel()
        countdownTask = nil
        onChoose(index)
    }
}
