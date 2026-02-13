/// Файл: Views/WorldMap/EngineRegionCardView.swift
/// Назначение: Содержит реализацию файла EngineRegionCardView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct EngineRegionCardView: View {
    let region: EngineRegionState
    let isCurrentLocation: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(stateColor.opacity(Opacity.faint))
                    .frame(width: Sizes.iconRegion, height: Sizes.iconRegion)

                Image(systemName: region.type.icon)
                    .font(.title2)
                    .foregroundColor(stateColor)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(region.name)
                        .font(.headline)
                        .fontWeight(.bold)

                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    Text(region.state.emoji)
                        .font(.caption)
                    Text(region.state.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)

                    Spacer()

                    Text(region.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxxs)
                        .background(AppColors.secondary.opacity(Opacity.faint))
                        .cornerRadius(CornerRadius.sm)
                }

                if let anchor = region.anchor {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "flame")
                            .font(.caption2)
                            .foregroundColor(AppColors.power)
                        Text(anchor.name)
                            .font(.caption2)
                            .foregroundColor(AppColors.muted)
                        Spacer()
                        Text("\(anchor.integrity)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(anchorIntegrityColor(anchor.integrity))
                    }
                }

                if region.reputation != 0 {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: region.reputation > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.caption2)
                            .foregroundColor(region.reputation > 0 ? AppColors.success : AppColors.danger)
                        Text(L10n.regionReputation.localized + ": \(region.reputation > 0 ? "+" : "")\(region.reputation)")
                            .font(.caption2)
                            .foregroundColor(AppColors.muted)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.cardBackground)
                .shadow(color: isCurrentLocation ? AppColors.primary.opacity(Opacity.light) : .clear, radius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isCurrentLocation ? AppColors.regionCurrent : .clear, lineWidth: 2)
        )
    }

    private var stateColor: Color {
        switch region.state {
        case .stable: return AppColors.success
        case .borderland: return AppColors.warning
        case .breach: return AppColors.danger
        }
    }

    private func anchorIntegrityColor(_ integrity: Int) -> Color {
        switch integrity {
        case 70...100: return AppColors.success
        case 30..<70: return AppColors.warning
        default: return AppColors.danger
        }
    }
}
