/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Localization/EngineLocaleResolver.swift
/// Назначение: Централизованный резолвер активной локали для TwilightEngine.
/// Зона ответственности: Нормализует языковые коды и определяет активный язык runtime.
/// Контекст: Используется engine-моделями вместо прямого доступа к Locale.current.

import Foundation

public enum EngineLocaleResolver {
    public static let fallbackLanguageCode = "en"

    public static func normalizedLanguageCode(_ rawValue: String?, fallback: String = fallbackLanguageCode) -> String {
        guard let rawValue else { return fallback }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        if let separator = trimmed.firstIndex(where: { $0 == "-" || $0 == "_" }) {
            return String(trimmed[..<separator]).lowercased()
        }
        return trimmed.lowercased()
    }

    public static func currentLanguageCode(fallback: String = fallbackLanguageCode) -> String {
        if let preferred = Bundle.main.preferredLocalizations.first {
            return normalizedLanguageCode(preferred, fallback: fallback)
        }

        let deviceLanguage = Locale.autoupdatingCurrent.language.languageCode?.identifier
        return normalizedLanguageCode(deviceLanguage, fallback: fallback)
    }
}
