/// Файл: App/Screens/SaveSlotSelectionScreen.swift
/// Назначение: Содержит реализацию файла SaveSlotSelectionScreen.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Экран выбора слота для старта новой игры или загрузки существующего сохранения.
/// Отвечает только за представление списка слотов и делегирует действия наружу через колбэки.
struct SaveSlotSelectionScreen: View {
    let registry: ContentRegistry
    let selectedHeroId: String?
    @ObservedObject var saveManager: SaveManager

    let onBack: () -> Void
    let onNewGame: (Int) -> Void
    let onLoadGame: (Int) -> Void
    let onDelete: (Int) -> Void

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
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(L10n.uiSlotSelection.localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let heroId = selectedHeroId,
                       let hero = registry.heroRegistry.hero(id: heroId) {
                        Text(hero.name.localized)
                            .font(.subheadline)
                            .foregroundColor(AppColors.muted)
                    }
                }
            }
            .padding()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    ForEach(1...3, id: \.self) { slotNumber in
                        SaveSlotCard(
                            slotNumber: slotNumber,
                            saveData: saveManager.getSave(from: slotNumber),
                            onNewGame: { onNewGame(slotNumber) },
                            onLoadGame: { onLoadGame(slotNumber) },
                            onDelete: { onDelete(slotNumber) }
                        )
                    }
                }
                .padding()
            }
        }
        .background(AppColors.backgroundSystem)
        .navigationBarHidden(true)
    }
}
