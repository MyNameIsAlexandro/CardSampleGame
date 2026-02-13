/// Файл: Utilities/AssetRegistry.swift
/// Назначение: Содержит реализацию файла AssetRegistry.swift.
/// Зона ответственности: Предоставляет вспомогательные утилиты и общие примитивы.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

// MARK: - Asset Registry
// Reference: AUDIT_ENGINE_FIRST_v1_1.md, Epic 0.1
// Single point of access for all images with fallback support

/// AssetRegistry provides centralized access to all image assets with automatic fallback.
/// This ensures UI never shows broken/missing images.
///
/// Usage:
/// ```swift
/// AssetRegistry.image(for: .region("forest"))
/// AssetRegistry.image(for: .hero("warrior"))
/// AssetRegistry.image(for: .card("fireball"))
/// ```
public enum AssetRegistry {

    // MARK: - Asset Types

    /// Types of assets with their fallback SF Symbol
    public enum AssetType {
        case region(String)
        case hero(String)
        case card(String)
        case custom(name: String, fallback: String)

        /// The asset name to look up
        var assetName: String {
            switch self {
            case .region(let id): return "region_\(id)"
            case .hero(let id): return "hero_\(id)"
            case .card(let id): return "card_\(id)"
            case .custom(let name, _): return name
            }
        }

        /// Fallback asset name if primary not found
        var fallbackAssetName: String {
            switch self {
            case .region: return "unknown_region"
            case .hero: return "unknown_hero"
            case .card: return "unknown_card"
            case .custom(_, let fallback): return fallback
            }
        }

        /// SF Symbol fallback if no asset found at all
        var sfSymbolFallback: String {
            switch self {
            case .region: return "mappin.circle"
            case .hero: return "person.circle"
            case .card: return "rectangle.portrait"
            case .custom: return "questionmark.circle"
            }
        }
    }

    // MARK: - Public API

    /// Get image for asset type with automatic fallback chain:
    /// 1. Try exact asset name (e.g., "region_forest")
    /// 2. Try fallback asset (e.g., "unknown_region")
    /// 3. Use SF Symbol as last resort
    public static func image(for type: AssetType) -> Image {
        // Try primary asset
        if hasAsset(named: type.assetName) {
            return Image(type.assetName)
        }

        // Try fallback asset
        if hasAsset(named: type.fallbackAssetName) {
            return Image(type.fallbackAssetName)
        }

        // Last resort: SF Symbol
        #if DEBUG
        print("⚠️ AssetRegistry: Missing asset '\(type.assetName)', using SF Symbol fallback")
        #endif
        return Image(systemName: type.sfSymbolFallback)
    }

    /// Get SF Symbol image (no fallback needed - SF Symbols always exist)
    public static func systemImage(_ name: String) -> Image {
        Image(systemName: name)
    }

    /// Get region icon - convenience method
    public static func regionIcon(_ regionId: String) -> Image {
        image(for: .region(regionId))
    }

    /// Get hero portrait - convenience method
    public static func heroPortrait(_ heroId: String) -> Image {
        image(for: .hero(heroId))
    }

    /// Get card art - convenience method
    public static func cardArt(_ cardId: String) -> Image {
        image(for: .card(cardId))
    }

    // MARK: - Asset Checking

    /// Check if an asset exists in the asset catalog
    public static func hasAsset(named name: String) -> Bool {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        return UIImage(named: name) != nil
        #elseif os(macOS)
        return NSImage(named: name) != nil
        #else
        return false
        #endif
    }

    /// Get list of all placeholder assets that should exist
    public static var requiredPlaceholders: [String] {
        ["unknown_region", "unknown_hero", "unknown_card"]
    }

    /// Validate that all required placeholder assets exist
    /// Returns list of missing placeholders
    public static func validatePlaceholders() -> [String] {
        requiredPlaceholders.filter { !hasAsset(named: $0) }
    }
}

// MARK: - SwiftUI View Extension

public extension View {
    /// Apply asset image as overlay with fallback support
    func assetOverlay(_ type: AssetRegistry.AssetType, alignment: Alignment = .center) -> some View {
        self.overlay(alignment: alignment) {
            AssetRegistry.image(for: type)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}
