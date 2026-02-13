/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Heroes/HeroRegistry.swift
/// Назначение: Содержит реализацию файла HeroRegistry.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Hero registry - centralized storage of all hero definitions.
///
/// This type is intentionally a pure data store: it does not load from bundles,
/// disk, or global singletons. Content packs (via `ContentRegistry`) are
/// responsible for providing and registering heroes.
public final class HeroRegistry {
    // MARK: - Storage

    private var definitions: [String: HeroDefinition] = [:]
    private var displayOrder: [String] = []

    // MARK: - Init

    /// Creates an empty in-memory registry.
    public init() {}

    // MARK: - Registration

    /// Registers or replaces a hero definition by its identifier.
    /// - Parameter definition: Hero definition to store.
    public func register(_ definition: HeroDefinition) {
        definitions[definition.id] = definition
        if !displayOrder.contains(definition.id) {
            displayOrder.append(definition.id)
        }
    }

    /// Registers multiple hero definitions preserving first-seen display order.
    /// - Parameter definitions: Hero definitions to register.
    public func registerAll(_ definitions: [HeroDefinition]) {
        for definition in definitions {
            register(definition)
        }
    }

    /// Removes a hero definition from the registry.
    /// - Parameter id: Hero identifier.
    public func unregister(id: String) {
        definitions.removeValue(forKey: id)
        displayOrder.removeAll { $0 == id }
    }

    /// Clears all registered heroes.
    public func clear() {
        definitions.removeAll()
        displayOrder.removeAll()
    }

    // MARK: - Queries

    /// Returns hero definition by identifier.
    /// - Parameter id: Hero identifier.
    /// - Returns: Matching hero definition or `nil`.
    public func hero(id: String) -> HeroDefinition? {
        definitions[id]
    }

    /// Returns all heroes in stable display order.
    public var allHeroes: [HeroDefinition] {
        displayOrder.compactMap { definitions[$0] }
    }

    /// Returns first hero in display order.
    public var firstHero: HeroDefinition? {
        allHeroes.first
    }

    /// Returns heroes currently available for the provided unlock state.
    /// - Parameters:
    ///   - unlockedConditions: Unlocked condition identifiers.
    ///   - ownedDLCs: Owned DLC pack identifiers.
    /// - Returns: Filtered list of available heroes.
    public func availableHeroes(
        unlockedConditions: Set<String> = [],
        ownedDLCs: Set<String> = []
    ) -> [HeroDefinition] {
        allHeroes.filter { hero in
            switch hero.availability {
            case .alwaysAvailable:
                return true
            case .requiresUnlock(let condition):
                return unlockedConditions.contains(condition)
            case .dlc(let packID):
                return ownedDLCs.contains(packID)
            }
        }
    }
}
