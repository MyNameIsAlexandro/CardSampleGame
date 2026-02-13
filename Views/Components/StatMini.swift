/// Файл: Views/Components/StatMini.swift
/// Назначение: Содержит реализацию файла StatMini.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

struct StatMini: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
        }
    }
}
