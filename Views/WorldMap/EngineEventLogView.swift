/// Файл: Views/WorldMap/EngineEventLogView.swift
/// Назначение: Содержит реализацию файла EngineEventLogView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct EngineEventLogView: View {
    @ObservedObject var vm: GameEngineObservable
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if vm.engine.publishedEventLog.isEmpty {
                    Text(L10n.journalEmpty.localized)
                        .foregroundColor(AppColors.muted)
                        .padding()
                } else {
                    ForEach(vm.engine.publishedEventLog.reversed()) { entry in
                        EventLogEntryView(entry: entry)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSystem)
            .navigationTitle(L10n.journalTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.uiClose.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}
