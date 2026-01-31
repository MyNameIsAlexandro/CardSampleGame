import SwiftUI
import TwilightEngine

// MARK: - DifficultyLevel UI Extension

extension DifficultyLevel {
    var localizedName: String {
        switch self {
        case .easy: return L10n.settingsDifficultyEasy.localized
        case .normal: return L10n.settingsDifficultyNormal.localized
        case .hard: return L10n.settingsDifficultyHard.localized
        }
    }
}

// MARK: - Settings View (SET-01)

struct SettingsView: View {
    @AppStorage("gameDifficulty") private var difficultyRaw = DifficultyLevel.normal.rawValue
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @Environment(\.dismiss) private var dismiss

    @State private var showingResetTutorialAlert = false
    @State private var showingResetAllAlert = false

    private var difficulty: DifficultyLevel {
        get { DifficultyLevel(rawValue: difficultyRaw) ?? .normal }
    }

    var body: some View {
        NavigationView {
            List {
                // Difficulty
                Section(header: Text(L10n.settingsDifficulty.localized)) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        Button(action: { difficultyRaw = level.rawValue }) {
                            HStack {
                                Text(level.localizedName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if level.rawValue == difficultyRaw {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                    }
                }

                // Language
                Section(header: Text(L10n.settingsLanguage.localized)) {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text(L10n.settingsLanguage.localized)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(AppColors.muted)
                        }
                    }
                }

                // Reset
                Section {
                    Button(action: { showingResetTutorialAlert = true }) {
                        Text(L10n.settingsResetTutorial.localized)
                            .foregroundColor(AppColors.warning)
                    }

                    Button(action: { showingResetAllAlert = true }) {
                        Text(L10n.settingsResetAllData.localized)
                            .foregroundColor(AppColors.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSystem)
            .navigationTitle(L10n.settingsTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.settingsDone.localized) { dismiss() }
                }
            }
            .alert(L10n.settingsResetTutorial.localized, isPresented: $showingResetTutorialAlert) {
                Button(L10n.uiCancel.localized, role: .cancel) { }
                Button(L10n.buttonOk.localized) {
                    hasCompletedTutorial = false
                }
            } message: {
                Text(L10n.settingsResetConfirm.localized)
            }
            .alert(L10n.settingsResetAllData.localized, isPresented: $showingResetAllAlert) {
                Button(L10n.uiCancel.localized, role: .cancel) { }
                Button(L10n.uiDelete.localized, role: .destructive) {
                    SaveManager.shared.deleteAllSaves()
                    hasCompletedTutorial = false
                    difficultyRaw = DifficultyLevel.normal.rawValue
                }
            } message: {
                Text(L10n.settingsResetAllConfirm.localized)
            }
        }
    }
}
