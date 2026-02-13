/// Файл: Views/Components/LoadSlotCard.swift
/// Назначение: Содержит реализацию файла LoadSlotCard.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import SwiftUI
import TwilightEngine

// MARK: - Load Slot Card (for Continue flow)

struct LoadSlotCard: View {
    let slot: Int
    let saveData: EngineSave
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(L10n.uiSlotNumber.localized(with: slot))
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(saveData.playerName)
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(spacing: Spacing.lg) {
                    Label("\(saveData.playerHealth)/\(saveData.playerMaxHealth)", systemImage: "heart.fill")
                        .foregroundColor(AppColors.danger)
                    Label("\(saveData.playerFaith)", systemImage: "sparkles")
                        .foregroundColor(AppColors.faith)
                    Label("\(saveData.playerBalance)", systemImage: "scale.3d")
                        .foregroundColor(AppColors.dark)
                }
                .font(.subheadline)

                Text(L10n.dayNumber.localized(with: saveData.currentDay))
                    .font(.caption)
                    .foregroundColor(AppColors.muted)

                Text(formatDate(saveData.savedAt))
                    .font(.caption2)
                    .foregroundColor(AppColors.muted)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
        .onTapGesture {
            onLoad()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
