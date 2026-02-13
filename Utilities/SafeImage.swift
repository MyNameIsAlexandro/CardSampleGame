/// Файл: Utilities/SafeImage.swift
/// Назначение: Содержит реализацию файла SafeImage.swift.
/// Зона ответственности: Предоставляет вспомогательные утилиты и общие примитивы.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

// MARK: - Safe Image Loading
// Audit 2.0 Requirement: Fallback System for missing icons
// If icon not found in Assets → show default placeholder

/// Safe image view that handles missing assets gracefully
struct SafeImage: View {
    let name: String
    let fallbackSystemName: String

    init(_ name: String, fallback: String = "questionmark.circle") {
        self.name = name
        self.fallbackSystemName = fallback
    }

    var body: some View {
        if let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            // Fallback: show SF Symbol placeholder
            Image(systemName: fallbackSystemName)
                .foregroundColor(.secondary)
        }
    }
}

/// Safe async image loading with fallback
struct SafeAsyncImage: View {
    let name: String
    let fallbackSystemName: String

    init(_ name: String, fallback: String = "questionmark.circle") {
        self.name = name
        self.fallbackSystemName = fallback
    }

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: fallbackSystemName)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Image Validation Utility

/// Utility to validate asset availability at runtime
enum AssetValidator {

    /// Check if asset exists in bundle
    static func assetExists(_ name: String, in bundle: Bundle = .main) -> Bool {
        return UIImage(named: name, in: bundle, compatibleWith: nil) != nil
    }

    /// Validate all icons referenced in content pack
    static func validatePackIcons(icons: [String], in bundle: Bundle = .main) -> [String] {
        return icons.filter { !assetExists($0, in: bundle) }
    }

    /// Get safe icon name with fallback
    static func safeIconName(_ name: String?, fallback: String = "questionmark.circle") -> String {
        guard let name = name, !name.isEmpty else {
            return fallback
        }

        // If it looks like an SF Symbol (contains period), assume it exists
        if name.contains(".") {
            return name
        }

        // For custom assets, check if they exist
        if assetExists(name) {
            return name
        } else {
            return fallback
        }
    }
}

// MARK: - View Extension for Safe Images

extension View {
    /// Apply safe icon with fallback
    func safeIcon(_ name: String?, fallback: String = "questionmark.circle") -> some View {
        let safeName = AssetValidator.safeIconName(name, fallback: fallback)
        return AnyView(
            Group {
                if safeName.contains(".") {
                    // SF Symbol
                    Image(systemName: safeName)
                } else {
                    // Custom asset
                    SafeImage(safeName, fallback: fallback)
                }
            }
        )
    }
}

// MARK: - Preview

#if DEBUG
struct SafeImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Existing asset (should show image)
            SafeImage("AppIcon", fallback: "star.fill")
                .frame(width: 50, height: 50)

            // Missing asset (should show fallback)
            SafeImage("nonexistent_icon", fallback: "exclamationmark.triangle")
                .frame(width: 50, height: 50)

            // SF Symbol style
            Image(systemName: AssetValidator.safeIconName("valid.symbol", fallback: "questionmark"))
                .font(.largeTitle)
        }
        .padding()
    }
}
#endif
