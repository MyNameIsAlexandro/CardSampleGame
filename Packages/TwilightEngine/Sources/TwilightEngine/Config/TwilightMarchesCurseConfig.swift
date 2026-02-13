/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Config/TwilightMarchesCurseConfig.swift
/// Назначение: Содержит реализацию файла TwilightMarchesCurseConfig.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Curse Configuration

/// Curse types in Twilight Marches.
public enum TwilightCurseType: String, Codable, CaseIterable, Sendable {
    case weakness
    case fear
    case exhaustion
    case greed
    case shadowOfNav
    case bloodCurse
    case sealOfNav
}

/// Curse definition (static data).
public struct TwilightCurseDefinition: Sendable {
    public let type: TwilightCurseType
    public let name: String
    public let description: String
    public let removalCost: Int
    public let damageModifier: Int      // Modifier to damage dealt
    public let damageTakenModifier: Int // Modifier to damage received
    public let actionModifier: Int      // Modifier to actions per turn
    public let specialEffect: String?   // ID of special effect

    public static let definitions: [TwilightCurseType: TwilightCurseDefinition] = [
        .weakness: TwilightCurseDefinition(
            type: .weakness,
            name: L10n.curseWeaknessName.localized,
            description: L10n.curseWeaknessDescription.localized,
            removalCost: 2,
            damageModifier: -1,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: nil
        ),
        .fear: TwilightCurseDefinition(
            type: .fear,
            name: L10n.curseFearName.localized,
            description: L10n.curseFearDescription.localized,
            removalCost: 2,
            damageModifier: 0,
            damageTakenModifier: 1,
            actionModifier: 0,
            specialEffect: nil
        ),
        .exhaustion: TwilightCurseDefinition(
            type: .exhaustion,
            name: L10n.curseExhaustionName.localized,
            description: L10n.curseExhaustionDescription.localized,
            removalCost: 3,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: -1,
            specialEffect: nil
        ),
        .greed: TwilightCurseDefinition(
            type: .greed,
            name: L10n.curseGreedName.localized,
            description: L10n.curseGreedDescription.localized,
            removalCost: 4,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "balance_shift_dark"
        ),
        .shadowOfNav: TwilightCurseDefinition(
            type: .shadowOfNav,
            name: L10n.curseShadowOfNavName.localized,
            description: L10n.curseShadowOfNavDescription.localized,
            removalCost: 5,
            damageModifier: 3,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "balance_shift_dark_on_combat"
        ),
        .bloodCurse: TwilightCurseDefinition(
            type: .bloodCurse,
            name: L10n.curseBloodCurseName.localized,
            description: L10n.curseBloodCurseDescription.localized,
            removalCost: 6,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "heal_on_kill_dark"
        ),
        .sealOfNav: TwilightCurseDefinition(
            type: .sealOfNav,
            name: L10n.curseSealOfNavName.localized,
            description: L10n.curseSealOfNavDescription.localized,
            removalCost: 8,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "block_sustain_cards"
        )
    ]

    public static func get(_ type: TwilightCurseType) -> TwilightCurseDefinition? {
        definitions[type]
    }
}
