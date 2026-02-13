/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Localization/LocalizationManager.swift
/// Назначение: Содержит реализацию файла LocalizationManager.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import Combine
import os.log

// MARK: - String Resolver Protocol

/// Protocol for resolving string keys to localized strings
public protocol StringResolver {
    func resolve(_ key: StringKey) -> String?
    func resolve(_ key: StringKey, locale: String) -> String?
    func resolve(_ key: StringKey, packContext: String?) -> String?
}

// MARK: - Localization Manager

/// Manages string tables for all loaded content packs.
/// Supports runtime locale switching and fallback resolution.
///
/// Resolution order (pack context → core fallback):
/// 1. Pack string table, current locale
/// 2. Pack string table, fallback locale (en)
/// 3. Core pack string table, current locale
/// 4. Core pack string table, fallback locale (en)
/// 5. Return nil (caller shows warning + bracketed key)
public final class LocalizationManager: ObservableObject, StringResolver {
    // MARK: - Constants

    private static let corePackId = "core"
    private static let fallbackLocale = "en"

    private static func initialLocaleCode() -> String {
        EngineLocaleResolver.currentLanguageCode(fallback: fallbackLocale)
    }

    // MARK: - Published Properties

    /// Current locale code (e.g., "en", "ru")
    @Published private(set) var currentLocale: String

    // MARK: - Private Properties

    /// String tables indexed by [packId: [locale: [key: value]]]
    private var stringTables: [String: [String: [String: String]]] = [:]

    /// Order in which packs were loaded (for fallback priority)
    private var packLoadOrder: [String] = []

    /// Logger for missing key warnings
    private let logger = Logger(subsystem: "com.cardsamplegame", category: "Localization")

    /// Track warned keys to avoid spam
    private var warnedKeys: Set<String> = []

    // MARK: - Initialization

    public init() {
        // Initialize with active app locale, then fallback to device locale.
        self.currentLocale = Self.initialLocaleCode()
    }

    // MARK: - Loading

    /// Load string tables for a pack from the localization directory
    /// - Parameters:
    ///   - packId: Unique identifier of the pack
    ///   - url: URL to the localization directory (contains en.json, ru.json, etc.)
    ///   - locales: List of supported locale codes
    /// - Throws: If string tables cannot be loaded
    public func loadStringTables(for packId: String, from url: URL, locales: [String]) throws {
        var packTables: [String: [String: String]] = [:]

        for locale in locales {
            let localeURL = url.appendingPathComponent("\(locale).json")

            guard FileManager.default.fileExists(atPath: localeURL.path) else {
                logger.warning("Missing string table for locale '\(locale)' in pack '\(packId)'")
                continue
            }

            let data = try Data(contentsOf: localeURL)
            let table = try JSONDecoder().decode([String: String].self, from: data)
            packTables[locale] = table

            logger.info("Loaded \(table.count) strings for locale '\(locale)' in pack '\(packId)'")
        }

        stringTables[packId] = packTables

        // Add to load order if not already present
        if !packLoadOrder.contains(packId) {
            // Core pack should always be first in fallback order
            if packId == Self.corePackId {
                packLoadOrder.insert(packId, at: 0)
            } else {
                packLoadOrder.append(packId)
            }
        }
    }

    /// Load string tables from raw dictionaries (for testing)
    func loadStringTables(for packId: String, tables: [String: [String: String]]) {
        stringTables[packId] = tables

        if !packLoadOrder.contains(packId) {
            if packId == Self.corePackId {
                packLoadOrder.insert(packId, at: 0)
            } else {
                packLoadOrder.append(packId)
            }
        }
    }

    /// Unload string tables for a pack
    func unloadStringTables(for packId: String) {
        stringTables.removeValue(forKey: packId)
        packLoadOrder.removeAll { $0 == packId }
        logger.info("Unloaded string tables for pack '\(packId)'")
    }

    /// Clear all loaded string tables
    public func clearAll() {
        stringTables.removeAll()
        packLoadOrder.removeAll()
        warnedKeys.removeAll()
    }

    // MARK: - Resolution

    /// Resolve a key using current locale with full fallback chain
    public func resolve(_ key: StringKey) -> String? {
        resolve(key, packContext: nil)
    }

    /// Resolve a key for a specific locale
    public func resolve(_ key: StringKey, locale: String) -> String? {
        resolve(key, locale: locale, packContext: nil)
    }

    /// Resolve a key with pack context for proper fallback
    public func resolve(_ key: StringKey, packContext: String?) -> String? {
        resolve(key, locale: currentLocale, packContext: packContext)
    }

    /// Full resolution with all parameters
    func resolve(_ key: StringKey, locale: String, packContext: String?) -> String? {
        // Build search order: context pack first, then others in reverse load order (newest first)
        var searchOrder: [String] = []

        if let context = packContext {
            searchOrder.append(context)
        }

        // Add other packs in reverse load order (excluding context pack)
        for packId in packLoadOrder.reversed() where packId != packContext {
            searchOrder.append(packId)
        }

        // Ensure core is always included at the end if not already
        if !searchOrder.contains(Self.corePackId) {
            searchOrder.append(Self.corePackId)
        }

        // Try each pack in order
        for packId in searchOrder {
            // Try requested locale first
            if let value = stringTables[packId]?[locale]?[key.rawValue] {
                return value
            }

            // Fallback to English if not the requested locale
            if locale != Self.fallbackLocale {
                if let value = stringTables[packId]?[Self.fallbackLocale]?[key.rawValue] {
                    return value
                }
            }
        }

        // Key not found - log warning once
        logMissingKey(key, packContext: packContext)
        return nil
    }

    // MARK: - Locale Switching

    /// Switch to a different locale at runtime
    /// Views observing LocalizationManager will update automatically
    func setLocale(_ locale: String) {
        guard currentLocale != locale else { return }
        currentLocale = locale
        logger.info("Locale switched to '\(locale)'")
    }

    // MARK: - Validation Support

    /// Get all keys defined in a pack across all locales
    func getAllKeys(for packId: String) -> Set<String> {
        guard let packTables = stringTables[packId] else { return [] }

        var allKeys = Set<String>()
        for (_, table) in packTables {
            allKeys.formUnion(table.keys)
        }
        return allKeys
    }

    /// Get keys that exist in reference set but are missing from a specific locale
    func getMissingKeys(for packId: String, locale: String, referencing keys: Set<String>) -> Set<String> {
        guard let table = stringTables[packId]?[locale] else {
            return keys // All keys are missing if no table exists
        }
        return keys.subtracting(table.keys)
    }

    /// Check if a key exists in any loaded pack
    func keyExists(_ key: StringKey) -> Bool {
        for (_, packTables) in stringTables {
            for (_, table) in packTables {
                if table[key.rawValue] != nil {
                    return true
                }
            }
        }
        return false
    }

    /// Get list of loaded pack IDs
    var loadedPackIds: [String] {
        packLoadOrder
    }

    /// Get string tables for caching
    func getStringTables(for packId: String) -> [String: [String: String]] {
        stringTables[packId] ?? [:]
    }

    /// Restore string tables from cache
    func restoreFromCache(packId: String, tables: [String: [String: String]]) {
        loadStringTables(for: packId, tables: tables)
    }

    // MARK: - Private Methods

    private func logMissingKey(_ key: StringKey, packContext: String?) {
        let cacheKey = "\(packContext ?? "global"):\(key.rawValue)"
        guard !warnedKeys.contains(cacheKey) else { return }

        warnedKeys.insert(cacheKey)
        let context = packContext ?? "global"
        logger.warning("Missing localization key '\(key.rawValue)' in context '\(context)'")
    }
}

// MARK: - Testing Support

#if DEBUG
extension LocalizationManager {
    /// Reset manager state for testing
    func resetForTesting() {
        stringTables.removeAll()
        packLoadOrder.removeAll()
        warnedKeys.removeAll()
        currentLocale = Self.fallbackLocale
    }

    /// Create a fresh instance for testing (bypasses singleton)
    public static func createForTesting() -> LocalizationManager {
        let manager = LocalizationManager()
        manager.resetForTesting()
        return manager
    }
}
#endif
