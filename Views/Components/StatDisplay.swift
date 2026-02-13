/// Файл: Views/Components/StatDisplay.swift
/// Назначение: Содержит реализацию файла StatDisplay.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

struct StatDisplay: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.muted)
        }
    }
}
