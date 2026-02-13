/// Файл: App/Loading/LoadingItemRow.swift
/// Назначение: UI-строка статуса отдельного элемента загрузки контента.
/// Зона ответственности: Визуализирует иконку, название, счётчик и статус LoadingItem.
/// Контекст: Используется внутри LoadingView.

import SwiftUI

struct LoadingItemRow: View {
    let item: LoadingItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundColor(iconColor)
                .frame(width: 20)

            Text(item.name)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            if let count = item.count {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            statusIcon
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .pending: return .gray
        case .loading: return .blue
        case .loaded: return .green
        case .failed: return .red
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .font(.caption2)
        case .loading:
            ProgressView()
                .scaleEffect(0.7)
        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}
