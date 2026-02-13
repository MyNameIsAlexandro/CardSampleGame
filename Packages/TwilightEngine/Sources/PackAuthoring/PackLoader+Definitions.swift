/// Файл: Packages/TwilightEngine/Sources/PackAuthoring/PackLoader+Definitions.swift
/// Назначение: Содержит реализацию файла PackLoader+Definitions.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

// MARK: - Pack Hero Definition

/// JSON структура для stats героя
struct PackHeroStats: Codable {
    let health: Int
    let maxHealth: Int
    let strength: Int
    let dexterity: Int
    let constitution: Int
    let intelligence: Int
    let wisdom: Int
    let charisma: Int
    let faith: Int
    let maxFaith: Int
    let startingBalance: Int

    func toHeroStats() -> HeroStats {
        HeroStats(
            health: health,
            maxHealth: maxHealth,
            strength: strength,
            dexterity: dexterity,
            constitution: constitution,
            intelligence: intelligence,
            wisdom: wisdom,
            charisma: charisma,
            faith: faith,
            maxFaith: maxFaith,
            startingBalance: startingBalance
        )
    }
}

/// JSON-совместимое определение героя для загрузки из Content Pack
/// Статы загружаются из JSON (data-driven)
struct PackHeroDefinition: Codable {
    let id: String
    let heroClass: String?
    let name: String
    let nameRu: String?
    let description: String
    let descriptionRu: String?
    let icon: String
    let baseStats: PackHeroStats
    let abilityId: String
    let startingDeckCardIds: [String]
    let availability: String?

    func toStandard(abilities: [String: HeroAbility]) throws -> StandardHeroDefinition {
        let heroAvailability: HeroAvailability
        switch availability?.lowercased() {
        case "always_available", nil:
            heroAvailability = .alwaysAvailable
        case let str where str?.hasPrefix("requires_unlock:") == true:
            let condition = String(str!.dropFirst("requires_unlock:".count))
            heroAvailability = .requiresUnlock(condition: condition)
        case let str where str?.hasPrefix("dlc:") == true:
            let packId = String(str!.dropFirst("dlc:".count))
            heroAvailability = .dlc(packID: packId)
        default:
            heroAvailability = .alwaysAvailable
        }

        let localizedName: LocalizableText
        if name.contains(".") && !name.contains(" ") && name.first?.isLowercase == true {
            localizedName = .key(StringKey(name))
        } else {
            localizedName = .inline(LocalizedString(en: name, ru: nameRu ?? name))
        }

        let localizedDescription: LocalizableText
        if description.contains(".") && !description.contains(" ") && description.first?.isLowercase == true {
            localizedDescription = .key(StringKey(description))
        } else {
            localizedDescription = .inline(LocalizedString(en: description, ru: descriptionRu ?? description))
        }

        guard let ability = abilities[abilityId] else {
            throw PackLoadError.invalidManifest(
                reason: "Missing ability definition for '\(abilityId)' required by hero '\(id)'. " +
                        "Add it to the pack's abilities (hero_abilities.json)."
            )
        }

        let resolvedClass: HeroClass
        if let classStr = heroClass, let parsed = HeroClass(rawValue: classStr) {
            resolvedClass = parsed
        } else {
            let prefix = id.split(separator: "_").first.map(String.init) ?? ""
            resolvedClass = HeroClass(rawValue: prefix) ?? .warrior
        }

        return StandardHeroDefinition(
            id: id,
            heroClass: resolvedClass,
            name: localizedName,
            description: localizedDescription,
            icon: icon,
            baseStats: baseStats.toHeroStats(),
            specialAbility: ability,
            startingDeckCardIDs: startingDeckCardIds,
            availability: heroAvailability
        )
    }
}

// MARK: - Pack Card Definition

/// JSON-совместимое определение карты для загрузки из Content Pack с локализацией
struct PackCardDefinition: Codable {
    let id: String
    let name: String
    let nameRu: String?
    let cardType: CardType
    let rarity: CardRarity
    let description: String
    let descriptionRu: String?
    let icon: String
    let expansionSet: ExpansionSet
    let ownership: CardOwnership
    let abilities: [CardAbility]
    let faithCost: Int
    let balance: CardBalance?
    let role: CardRole?
    let power: Int?
    let defense: Int?
    let health: Int?
    let wisdom: Int?
    let realm: Realm?
    let curseType: CurseType?

    func toStandard() -> StandardCardDefinition {
        let localizedName: LocalizableText
        if name.contains(".") && !name.contains(" ") && name.first?.isLowercase == true {
            localizedName = .key(StringKey(name))
        } else {
            localizedName = .inline(LocalizedString(en: name, ru: nameRu ?? name))
        }

        let localizedDescription: LocalizableText
        if description.contains(".") && !description.contains(" ") && description.first?.isLowercase == true {
            localizedDescription = .key(StringKey(description))
        } else {
            localizedDescription = .inline(LocalizedString(en: description, ru: descriptionRu ?? description))
        }

        return StandardCardDefinition(
            id: id,
            name: localizedName,
            cardType: cardType,
            rarity: rarity,
            description: localizedDescription,
            icon: icon,
            expansionSet: expansionSet,
            ownership: ownership,
            abilities: abilities,
            faithCost: faithCost,
            balance: balance,
            role: role,
            power: power,
            defense: defense,
            health: health,
            wisdom: wisdom,
            realm: realm,
            curseType: curseType
        )
    }
}
