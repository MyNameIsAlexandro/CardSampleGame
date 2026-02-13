/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/ValidationBadge.swift
/// Назначение: Содержит реализацию файла ValidationBadge.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI

/// A small badge component displaying validation status with colored indicator and tooltip.
///
/// Presents a colored circle (error: red, warning: yellow, info: blue) with an optional
/// help icon. Hovering reveals a tooltip with the validation message.
///
/// Example usage:
/// ```swift
/// ValidationBadge(
///     level: .error,
///     message: "Missing required field"
/// )
///
/// ValidationBadge(
///     level: .warning,
///     message: "Content exceeds recommended length"
/// )
/// ```
struct ValidationBadge: View {
    /// Severity level of the validation message
    enum Level {
        case error
        case warning
        case info
    }

    /// Validation severity level
    let level: Level

    /// Human-readable validation message shown in tooltip
    let message: String

    @State private var showTooltip = false

    var body: some View {
        HStack(spacing: 6) {
            // Colored indicator circle
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)

            // Help icon that shows tooltip on hover
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(badgeColor)
                .onHover { isHovering in
                    showTooltip = isHovering
                }
                .help(message) // Native macOS tooltip
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - Computed Properties

    private var badgeColor: Color {
        switch level {
        case .error:
            return Color(red: 1.0, green: 0.3, blue: 0.3) // macOS-style red
        case .warning:
            return Color(red: 1.0, green: 0.8, blue: 0.0) // macOS-style yellow
        case .info:
            return Color(red: 0.0, green: 0.5, blue: 1.0) // macOS-style blue
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 8) {
            Text("Error Status:")
                .font(.caption)
            ValidationBadge(
                level: .error,
                message: "Missing required field: Name is empty"
            )
            Spacer()
        }

        HStack(spacing: 8) {
            Text("Warning Status:")
                .font(.caption)
            ValidationBadge(
                level: .warning,
                message: "Content length exceeds recommended maximum of 200 characters"
            )
            Spacer()
        }

        HStack(spacing: 8) {
            Text("Info Status:")
                .font(.caption)
            ValidationBadge(
                level: .info,
                message: "This field supports markdown formatting"
            )
            Spacer()
        }

        Spacer()
    }
    .padding()
    .frame(width: 400, height: 200)
}
