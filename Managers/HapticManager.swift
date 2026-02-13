/// Файл: Managers/HapticManager.swift
/// Назначение: Содержит реализацию файла HapticManager.swift.
/// Зона ответственности: Инкапсулирует инфраструктурный сервисный функционал.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import UIKit

/// Centralized haptic feedback manager (UX-01)
/// Usage: HapticManager.shared.play(.light)
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        // Pre-warm generators for responsive feedback
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
    }

    enum HapticType {
        // Impacts
        case light          // button tap, card select
        case medium         // card play, damage dealt
        case heavy          // enemy defeated, critical hit
        // Notifications
        case success        // victory, quest complete, loot received
        case warning        // low health, dangerous choice
        case error          // insufficient resources, invalid action
        // Selection
        case selection      // picker change, tab switch
    }

    func play(_ type: HapticType) {
        switch type {
        case .light:
            lightGenerator.impactOccurred()
        case .medium:
            mediumGenerator.impactOccurred()
        case .heavy:
            heavyGenerator.impactOccurred()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        case .selection:
            selectionGenerator.selectionChanged()
        }
    }

    /// Prepare generators before a sequence of haptics (e.g. combat round)
    func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
    }
}
