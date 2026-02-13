/// Файл: Utilities/Localization+CoreAndRules.swift
/// Назначение: Содержит реализацию файла Localization+CoreAndRules.swift.
/// Зона ответственности: Предоставляет вспомогательные утилиты и общие примитивы.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation

/// Базовые ключи локализации: стартовый экран, правила, общие UI-строки.
extension L10n {
    // Main Screen
    static let characterSelectTitle = "character.select.title"
    static let characterStats = "character.stats"
    static let characterAbilities = "character.abilities"
    static let buttonStartAdventure = "button.start.adventure"
    static let buttonSelectHeroFirst = "button.select.hero.first"

    // Game Board
    static let buttonOk = "button.ok"

    // Game Phases
    static let phaseExploration = "phase.exploration"
    static let phaseEncounter = "phase.encounter"
    static let phasePlayerTurn = "phase.player.turn"
    static let phaseEnemyTurn = "phase.enemy.turn"
    static let phaseEndTurn = "phase.end.turn"

    // Card Types
    static let cardTypeCharacter = "card.type.character"
    static let cardTypeWeapon = "card.type.weapon"
    static let cardTypeSpell = "card.type.spell"
    static let cardTypeArmor = "card.type.armor"
    static let cardTypeItem = "card.type.item"
    static let cardTypeBlessing = "card.type.blessing"
    static let cardTypeMonster = "card.type.monster"
    static let cardTypeLocation = "card.type.location"
    static let cardTypeAlly = "card.type.ally"

    // Stats
    static let statHealth = "stat.health"
    static let statPower = "stat.power"
    static let statDefense = "stat.defense"

    // Rarity
    static let rarityCommon = "rarity.common"
    static let rarityUncommon = "rarity.uncommon"
    static let rarityRare = "rarity.rare"
    static let rarityEpic = "rarity.epic"
    static let rarityLegendary = "rarity.legendary"

    // Rules
    static let rulesTitle = "rules.title"
    static let rulesObjectiveTitle = "rules.objective.title"
    static let rulesObjectiveContent = "rules.objective.content"
    static let rulesPhasesTitle = "rules.phases.title"
    static let rulesPhasesContent = "rules.phases.content"
    static let rulesPhaseExploration = "rules.phase.exploration"
    static let rulesPhaseEncounter = "rules.phase.encounter"
    static let rulesPhasePlayerTurn = "rules.phase.player.turn"
    static let rulesPhaseEnemyTurn = "rules.phase.enemy.turn"
    static let rulesPhaseEndTurn = "rules.phase.endturn"
    static let rulesCardsTitle = "rules.cards.title"
    static let rulesCardsContent = "rules.cards.content"
    static let rulesResourcesTitle = "rules.resources.title"
    static let rulesResourcesContent = "rules.resources.content"
    static let rulesActionsTitle = "rules.actions.title"
    static let rulesActionsContent = "rules.actions.content"
    static let rulesDiceTitle = "rules.dice.title"
    static let rulesDiceContent = "rules.dice.content"
    static let rulesVictoryTitle = "rules.victory.title"
    static let rulesVictoryContent = "rules.victory.content"
    static let rulesTipsTitle = "rules.tips.title"
    static let rulesTipsContent = "rules.tips.content"

    // Twilight Marches
    static let tmGameTitle = "tm.game.title"
    static let tmGameSubtitle = "tm.game.subtitle"
    static let tmCardTypeCurse = "tm.card.type.curse"
    static let tmCardTypeSpirit = "tm.card.type.spirit"
    static let tmCardTypeArtifact = "tm.card.type.artifact"
    static let tmCardTypeRitual = "tm.card.type.ritual"

    // Common UI
    static let uiMenuButton = "ui.menu.button"
    static let uiExit = "ui.exit"
    static let uiResult = "ui.result"
    static let uiProgressSaved = "ui.progress.saved"
    static let uiClose = "ui.close"
    static let uiContinue = "ui.continue"
    static let uiBack = "ui.back"
    static let uiCancel = "ui.cancel"
    static let uiDelete = "ui.delete"
    static let uiOverwrite = "ui.overwrite"
    static let uiLoad = "ui.load"
    static let uiNewGame = "ui.new.game"
    static let uiNoSaves = "ui.no.saves"
    static let buttonConfirm = "button.confirm"
    static let buttonUnderstood = "button.understood"
    static let buttonGreat = "button.great"

    // Tooltips
    static let tooltipBalance = "tooltip.balance"
}
