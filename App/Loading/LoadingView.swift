/// Файл: App/Loading/LoadingView.swift
/// Назначение: Экран прогресса загрузки контента при старте приложения.
/// Зона ответственности: Отображает статус ContentLoader и агрегированный итог загрузки.
/// Контекст: Используется CardGameApp до готовности AppServices.

import SwiftUI
import TwilightEngine

struct LoadingView: View {
    @ObservedObject var loader: ContentLoader

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.appTitle.localized)
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView(value: loader.loadingProgress)
                .progressViewStyle(.linear)
                .frame(width: 280)

            Text(loader.loadingMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !loader.loadingItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(loader.loadingItems) { item in
                        LoadingItemRow(item: item)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            if !loader.loadingSummary.isEmpty {
                Text(loader.loadingSummary)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
}
