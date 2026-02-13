/// Файл: Views/Components/SaveSlotCard.swift
/// Назначение: Содержит реализацию файла SaveSlotCard.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import SwiftUI
import TwilightEngine

// MARK: - Save Slot Card

struct SaveSlotCard: View {
    let slotNumber: Int
    let saveData: EngineSave?
    let onNewGame: () -> Void
    let onLoadGame: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false
    @State private var showingOverwriteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(L10n.uiSlotNumber.localized(with: slotNumber))
                    .font(.headline)
                Spacer()
                if saveData != nil {
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }

            if let save = saveData {
                // Existing save
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(save.playerName)
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: Spacing.lg) {
                        Label("\(save.playerHealth)/\(save.playerMaxHealth)", systemImage: "heart.fill")
                            .foregroundColor(AppColors.danger)
                        Label("\(save.playerFaith)", systemImage: "sparkles")
                            .foregroundColor(AppColors.faith)
                        Label("\(save.playerBalance)", systemImage: "scale.3d")
                            .foregroundColor(AppColors.info)
                    }
                    .font(.subheadline)

                    Text(L10n.dayNumber.localized(with: save.currentDay))
                        .font(.caption)
                        .foregroundColor(AppColors.muted)

                    Text(formatDate(save.savedAt))
                        .font(.caption2)
                        .foregroundColor(AppColors.muted)

                    Divider()

                    HStack(spacing: Spacing.md) {
                        Button(action: onLoadGame) {
                            Text(L10n.uiLoad.localized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.backgroundSystem)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.smd)
                                .background(AppColors.primary)
                                .cornerRadius(CornerRadius.md)
                        }

                        Button(action: { showingOverwriteAlert = true }) {
                            Text(L10n.uiNewGame.localized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.smd)
                                .background(AppColors.primary.opacity(0.1))
                                .cornerRadius(CornerRadius.md)
                        }
                    }
                }
            } else {
                // Empty slot
                VStack(spacing: Spacing.md) {
                    Image(systemName: "square.dashed")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.muted)

                    Text(L10n.uiEmptySlot.localized)
                        .font(.subheadline)
                        .foregroundColor(AppColors.muted)

                    Button(action: onNewGame) {
                        Text(L10n.uiStartNewGame.localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.smd)
                            .background(AppColors.success)
                            .cornerRadius(CornerRadius.md)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
        .alert(L10n.uiDeleteSave.localized, isPresented: $showingDeleteAlert) {
            Button(L10n.uiCancel.localized, role: .cancel) { }
            Button(L10n.uiDelete.localized, role: .destructive) {
                onDelete()
            }
        } message: {
            Text(L10n.uiDeleteConfirm.localized)
        }
        .alert(L10n.uiOverwriteSave.localized, isPresented: $showingOverwriteAlert) {
            Button(L10n.uiCancel.localized, role: .cancel) { }
            Button(L10n.uiOverwrite.localized, role: .destructive) {
                onDelete()
                onNewGame()
            }
        } message: {
            Text(L10n.uiOverwriteConfirm.localized)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
