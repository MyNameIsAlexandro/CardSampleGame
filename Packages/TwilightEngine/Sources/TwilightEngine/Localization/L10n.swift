/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Localization/L10n.swift
/// Назначение: Содержит реализацию файла L10n.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Engine Localization Keys
// Engine should not hardcode any specific language as "truth".
// This enum maps engine-level labels/errors to stable string keys.
//
// Resolution is delegated to the host app via `Localizable.strings` (NSBundle localization).
// If a key is missing, `NSLocalizedString` will fall back to returning the key itself.

/// Localization keys used by the TwilightEngine package.
public enum L10n: CaseIterable {
    // MARK: - Region States
    case regionStateStable
    case regionStateBorderland
    case regionStateBreach

    // MARK: - Region Types
    case regionTypeForest
    case regionTypeSwamp
    case regionTypeMountain
    case regionTypeSettlement
    case regionTypeWater
    case regionTypeWasteland
    case regionTypeSacred

    // MARK: - Combat Modifiers
    case combatModifierBorderland
    case combatModifierBreach

    // MARK: - Anchor Types
    case anchorTypeShrine
    case anchorTypeBarrow
    case anchorTypeSacredTree
    case anchorTypeStoneIdol
    case anchorTypeSpring
    case anchorTypeChapel
    case anchorTypeTemple
    case anchorTypeCross

    // MARK: - Event Types
    case eventTypeCombat
    case eventTypeRitual
    case eventTypeNarrative
    case eventTypeExploration
    case eventTypeWorldShift

    // MARK: - Encounter Actions
    case encounterActionAttack
    case encounterActionFlee

    // MARK: - Curses (display names)
    case curseWeakness
    case curseFear
    case curseExhaustion
    case curseGreed
    case curseShadowOfNav
    case curseBloodCurse
    case curseSealOfNav

    // MARK: - Curse Names (full)
    case curseWeaknessName
    case curseFearName
    case curseExhaustionName
    case curseGreedName
    case curseShadowOfNavName
    case curseBloodCurseName
    case curseSealOfNavName

    // MARK: - Curse Descriptions
    case curseWeaknessDescription
    case curseFearDescription
    case curseExhaustionDescription
    case curseGreedDescription
    case curseShadowOfNavDescription
    case curseBloodCurseDescription
    case curseSealOfNavDescription

    // MARK: - Combat Calculator
    case calcHit
    case calcMiss
    case calcAttackVsDefense
    case calcStrength
    case calcBonusDice
    case calcBonusDamage
    case calcDamage
    case calcBaseDamage
    case calcHeroAbilityDice
    case calcHeroAbility
    case calcCurseWeakness
    case calcCurseShadowOfNav

    // MARK: - World Balance
    case worldBalanceYavStrong
    case worldBalanceTwilight
    case worldBalanceNavAdvances

    // MARK: - Player Defaults
    case playerDefaultName

    // MARK: - Day Events
    case dayEventTensionIncreaseTitle
    case dayEventTensionIncreaseDescription
    case dayEventRegionDegradedTitle
    case dayEventRegionDegradedDescription
    case dayEventWorldImprovingTitle
    case dayEventWorldImprovingDescription

    // MARK: - Journal
    case journalEntryTravel
    case journalEntryTravelChoice
    case journalEntryTravelOutcome
    case journalEntryExplore
    case journalEntryExploreChoice
    case journalEntryExploreNothing
    case journalRestTitle
    case journalRestChoice
    case journalRestOutcome
    case journalAnchorTitle
    case journalAnchorChoice
    case journalAnchorOutcome
    case journalChoiceMade

    // MARK: - Card Ownership
    case cardOwnershipUniversal
    case cardOwnershipHeroSignature
    case cardOwnershipClassSpecific
    case cardOwnershipExpansion
    case cardOwnershipRequiresUnlock

    // MARK: - Mini-Games
    case miniGameCombatVictory
    case miniGameCombatDefeat
    case miniGamePuzzleVictory
    case miniGamePuzzleDefeat
    case miniGameSkillCheckVictory
    case miniGameSkillCheckDefeat

    // MARK: - Error Messages
    case errorInvalidAction
    case errorInvalidActionNoCurrentRegion
    case errorInvalidActionMarketNotInitialized
    case errorInvalidActionCardNotInMarket
    case errorInvalidActionUnknownCard
    case errorInvalidActionDefileRequiresDarkAlignment
    case errorInvalidActionAnchorAlreadyDark
    case errorInvalidActionEventNotCombatEncounter
    case errorInvalidActionFateDeckUnavailable
    case errorInvalidActionMiniGameUnavailable
    case errorInvalidActionEventNotMiniGame
    case errorInvalidActionMiniGameChallengeMismatch
    case errorRegionNotAccessible
    case errorRegionNotNeighbor
    case errorActionNotAvailable
    case errorInsufficientResources
    case errorHealthTooLow
    case errorGameNotInProgress
    case errorCombatInProgress
    case errorEventInProgress
    case errorNoActiveEvent
    case errorNoActiveCombat
    case errorEventNotFound
    case errorInvalidChoiceIndex
    case errorChoiceRequirementsNotMet
    case errorChoiceRequirementsMinFaith
    case errorChoiceRequirementsMinHealth
    case errorChoiceRequirementsMinBalance
    case errorChoiceRequirementsMaxBalance
    case errorChoiceRequirementsRequiredBalance
    case errorChoiceRequirementsMissingFlags
    case errorChoiceRequirementsForbiddenFlags
    case errorChoiceRequirementsGeneric
    case errorCardNotInHand
    case errorNotEnoughActions
    case errorInvalidTarget

    // MARK: - Localized String

    public var localized: String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }

    // MARK: - Localized with Arguments

    public func localized(with args: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: args)
    }

    // MARK: - Key Mapping

    public var key: String {
        switch self {
        case .regionStateStable: return "region.state.stable"
        case .regionStateBorderland: return "region.state.borderland"
        case .regionStateBreach: return "region.state.breach"

        case .regionTypeForest: return "region.type.forest"
        case .regionTypeSwamp: return "region.type.swamp"
        case .regionTypeMountain: return "region.type.mountain"
        case .regionTypeSettlement: return "region.type.settlement"
        case .regionTypeWater: return "region.type.water"
        case .regionTypeWasteland: return "region.type.wasteland"
        case .regionTypeSacred: return "region.type.sacred"

        case .combatModifierBorderland: return "combat.modifier.borderland"
        case .combatModifierBreach: return "combat.modifier.breach"

        case .anchorTypeShrine: return "anchor.type.shrine"
        case .anchorTypeBarrow: return "anchor.type.barrow"
        case .anchorTypeSacredTree: return "anchor.type.sacred.tree"
        case .anchorTypeStoneIdol: return "anchor.type.stone.idol"
        case .anchorTypeSpring: return "anchor.type.spring"
        case .anchorTypeChapel: return "anchor.type.chapel"
        case .anchorTypeTemple: return "anchor.type.temple"
        case .anchorTypeCross: return "anchor.type.cross"

        case .eventTypeCombat: return "event.type.combat"
        case .eventTypeRitual: return "event.type.ritual"
        case .eventTypeNarrative: return "event.type.narrative"
        case .eventTypeExploration: return "event.type.exploration"
        case .eventTypeWorldShift: return "event.type.world.shift"

        case .encounterActionAttack: return "encounter.action.attack"
        case .encounterActionFlee: return "encounter.action.flee"

        case .curseWeakness: return "curse.weakness"
        case .curseFear: return "curse.fear"
        case .curseExhaustion: return "curse.exhaustion"
        case .curseGreed: return "curse.greed"
        case .curseShadowOfNav: return "curse.shadow.of.nav"
        case .curseBloodCurse: return "curse.blood.curse"
        case .curseSealOfNav: return "curse.seal.of.nav"

        case .curseWeaknessName: return "curse.weakness.name"
        case .curseFearName: return "curse.fear.name"
        case .curseExhaustionName: return "curse.exhaustion.name"
        case .curseGreedName: return "curse.greed.name"
        case .curseShadowOfNavName: return "curse.shadow.of.nav.name"
        case .curseBloodCurseName: return "curse.blood.curse.name"
        case .curseSealOfNavName: return "curse.seal.of.nav.name"

        case .curseWeaknessDescription: return "curse.weakness.description"
        case .curseFearDescription: return "curse.fear.description"
        case .curseExhaustionDescription: return "curse.exhaustion.description"
        case .curseGreedDescription: return "curse.greed.description"
        case .curseShadowOfNavDescription: return "curse.shadow.of.nav.description"
        case .curseBloodCurseDescription: return "curse.blood.curse.description"
        case .curseSealOfNavDescription: return "curse.seal.of.nav.description"

        case .calcHit: return "calc.hit"
        case .calcMiss: return "calc.miss"
        case .calcAttackVsDefense: return "calc.attack.vs.defense"
        case .calcStrength: return "calc.strength"
        case .calcBonusDice: return "calc.bonus.dice"
        case .calcBonusDamage: return "calc.bonus.damage"
        case .calcDamage: return "calc.damage"
        case .calcBaseDamage: return "calc.base.damage"
        case .calcHeroAbilityDice: return "calc.hero.ability.dice"
        case .calcHeroAbility: return "calc.hero.ability"
        case .calcCurseWeakness: return "calc.curse.weakness"
        case .calcCurseShadowOfNav: return "calc.curse.shadow.of.nav"

        case .worldBalanceYavStrong: return "world.balance.yav.strong"
        case .worldBalanceTwilight: return "world.balance.twilight"
        case .worldBalanceNavAdvances: return "world.balance.nav.advances"

        case .playerDefaultName: return "player.default.name"

        case .dayEventTensionIncreaseTitle: return "day.event.tension.increase.title"
        case .dayEventTensionIncreaseDescription: return "day.event.tension.increase.description"
        case .dayEventRegionDegradedTitle: return "day.event.region.degraded.title"
        case .dayEventRegionDegradedDescription: return "day.event.region.degraded.description"
        case .dayEventWorldImprovingTitle: return "day.event.world.improving.title"
        case .dayEventWorldImprovingDescription: return "day.event.world.improving.description"

        case .journalEntryTravel: return "journal.entry.travel"
        case .journalEntryTravelChoice: return "journal.entry.travel.choice"
        case .journalEntryTravelOutcome: return "journal.entry.travel.outcome"
        case .journalEntryExplore: return "journal.entry.explore"
        case .journalEntryExploreChoice: return "journal.entry.explore.choice"
        case .journalEntryExploreNothing: return "journal.entry.explore.nothing"
        case .journalRestTitle: return "journal.rest.title"
        case .journalRestChoice: return "journal.rest.choice"
        case .journalRestOutcome: return "journal.rest.outcome"
        case .journalAnchorTitle: return "journal.anchor.title"
        case .journalAnchorChoice: return "journal.anchor.choice"
        case .journalAnchorOutcome: return "journal.anchor.outcome"
        case .journalChoiceMade: return "journal.choice.made"

        case .cardOwnershipUniversal: return "card.ownership.universal"
        case .cardOwnershipHeroSignature: return "card.ownership.hero.signature"
        case .cardOwnershipClassSpecific: return "card.ownership.class.specific"
        case .cardOwnershipExpansion: return "card.ownership.expansion"
        case .cardOwnershipRequiresUnlock: return "card.ownership.requires.unlock"

        case .miniGameCombatVictory: return "minigame.combat.victory"
        case .miniGameCombatDefeat: return "minigame.combat.defeat"
        case .miniGamePuzzleVictory: return "minigame.puzzle.victory"
        case .miniGamePuzzleDefeat: return "minigame.puzzle.defeat"
        case .miniGameSkillCheckVictory: return "minigame.skillcheck.victory"
        case .miniGameSkillCheckDefeat: return "minigame.skillcheck.defeat"

        case .errorInvalidAction: return "error.invalid.action"
        case .errorInvalidActionNoCurrentRegion: return "error.invalid.action.no_current_region"
        case .errorInvalidActionMarketNotInitialized: return "error.invalid.action.market_not_initialized"
        case .errorInvalidActionCardNotInMarket: return "error.invalid.action.card_not_in_market"
        case .errorInvalidActionUnknownCard: return "error.invalid.action.unknown_card"
        case .errorInvalidActionDefileRequiresDarkAlignment: return "error.invalid.action.defile_requires_dark_alignment"
        case .errorInvalidActionAnchorAlreadyDark: return "error.invalid.action.anchor_already_dark"
        case .errorInvalidActionEventNotCombatEncounter: return "error.invalid.action.event_not_combat_encounter"
        case .errorInvalidActionFateDeckUnavailable: return "error.invalid.action.fate_deck_unavailable"
        case .errorInvalidActionMiniGameUnavailable: return "error.invalid.action.mini_game_unavailable"
        case .errorInvalidActionEventNotMiniGame: return "error.invalid.action.event_not_mini_game"
        case .errorInvalidActionMiniGameChallengeMismatch: return "error.invalid.action.mini_game_challenge_mismatch"
        case .errorRegionNotAccessible: return "error.region.not.accessible"
        case .errorRegionNotNeighbor: return "error.region.not.neighbor"
        case .errorActionNotAvailable: return "error.action.not.available"
        case .errorInsufficientResources: return "error.insufficient.resources"
        case .errorHealthTooLow: return "error.health.too.low"
        case .errorGameNotInProgress: return "error.game.not.in.progress"
        case .errorCombatInProgress: return "error.combat.in.progress"
        case .errorEventInProgress: return "error.event.in.progress"
        case .errorNoActiveEvent: return "error.no.active.event"
        case .errorNoActiveCombat: return "error.no.active.combat"
        case .errorEventNotFound: return "error.event.not.found"
        case .errorInvalidChoiceIndex: return "error.invalid.choice.index"
        case .errorChoiceRequirementsNotMet: return "error.choice.requirements.not.met"
        case .errorChoiceRequirementsMinFaith: return "error.choice.requirements.min.faith"
        case .errorChoiceRequirementsMinHealth: return "error.choice.requirements.min.health"
        case .errorChoiceRequirementsMinBalance: return "error.choice.requirements.min.balance"
        case .errorChoiceRequirementsMaxBalance: return "error.choice.requirements.max.balance"
        case .errorChoiceRequirementsRequiredBalance: return "error.choice.requirements.required.balance"
        case .errorChoiceRequirementsMissingFlags: return "error.choice.requirements.missing.flags"
        case .errorChoiceRequirementsForbiddenFlags: return "error.choice.requirements.forbidden.flags"
        case .errorChoiceRequirementsGeneric: return "error.choice.requirements.generic"
        case .errorCardNotInHand: return "error.card.not.in.hand"
        case .errorNotEnoughActions: return "error.not.enough.actions"
        case .errorInvalidTarget: return "error.invalid.target"
        }
    }
}
