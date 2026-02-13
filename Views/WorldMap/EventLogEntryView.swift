/// Файл: Views/WorldMap/EventLogEntryView.swift
/// Назначение: Содержит реализацию файла EventLogEntryView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct EventLogEntryView: View {
    let entry: EventLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: entry.type.icon)
                    .foregroundColor(typeColor)

                Text(L10n.dayNumber.localized(with: entry.dayNumber))
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                Text(entry.regionName)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            Text(entry.eventTitle)
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.muted)
                Text(entry.choiceMade)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            Text(entry.outcome)
                .font(.caption)
                .italic()
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var typeColor: Color {
        switch entry.type {
        case .combat: return AppColors.danger
        case .exploration: return AppColors.primary
        case .choice: return AppColors.warning
        case .quest: return AppColors.dark
        case .travel: return AppColors.success
        case .worldChange: return AppColors.light
        }
    }
}
