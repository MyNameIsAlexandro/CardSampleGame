/// Файл: App/Screens/LoadSlotSelectionScreen.swift
/// Назначение: Содержит реализацию файла LoadSlotSelectionScreen.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

/// Экран выбора сохранения для сценария «Продолжить игру».
/// Отображает только существующие слоты и передаёт выбранный слот наружу через колбэк.
struct LoadSlotSelectionScreen: View {
    @ObservedObject var saveManager: SaveManager

    let onBack: () -> Void
    let onLoad: (Int) -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                        Text(L10n.uiBack.localized)
                    }
                    .foregroundColor(AppColors.primary)
                }
                Spacer()
                Text(L10n.uiContinueGame.localized)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    ForEach(Array(saveManager.saveSlots.keys.sorted()), id: \.self) { slot in
                        if let save = saveManager.getSave(from: slot) {
                            LoadSlotCard(
                                slot: slot,
                                saveData: save,
                                onLoad: { onLoad(slot) }
                            )
                        }
                    }

                    if saveManager.isLoaded, !saveManager.hasSaves {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(AppColors.muted)
                            Text(L10n.uiNoSaves.localized)
                                .foregroundColor(AppColors.muted)
                        }
                        .padding(.top, Spacing.xxxl + Spacing.sm)
                    }
                }
                .padding()
            }
        }
        .background(AppColors.backgroundSystem)
        .navigationBarHidden(true)
    }
}
