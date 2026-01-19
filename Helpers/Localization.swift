import Foundation

// MARK: - Localization Helper
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Localization Keys
enum L10n {
    // Main Screen
    static let gameTitle = "game.title"
    static let characterSelectTitle = "character.select.title"
    static let characterStats = "character.stats"
    static let characterAbilities = "character.abilities"
    static let buttonStartAdventure = "button.start.adventure"

    // Game Board
    static let turnLabel = "turn.label"
    static let buttonNextPhase = "button.next.phase"
    static let buttonExplore = "button.explore"
    static let buttonRollDice = "button.roll.dice"
    static let diceResult = "dice.result"
    static let diceRollTitle = "dice.roll.title"
    static let diceRollMessage = "dice.roll.message"
    static let buttonOk = "button.ok"

    // Game Phases
    static let phaseSetup = "phase.setup"
    static let phaseExploration = "phase.exploration"
    static let phaseEncounter = "phase.encounter"
    static let phasePlayerTurn = "phase.player.turn"
    static let phaseEnemyTurn = "phase.enemy.turn"
    static let phaseEndTurn = "phase.end.turn"
    static let phaseGameOver = "phase.game.over"

    // Encounter
    static let encounterActive = "encounter.active"

    // Deck
    static let deckEncounters = "deck.encounters"
    static let deckLocations = "deck.locations"
    static let deckCards = "deck.cards"

    // Player Hand
    static let playerHandTitle = "player.hand.title"
    static let playerDiscardPile = "player.discard.pile"
    static let playerDeckRemaining = "player.deck.remaining"

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
    static let statStrength = "stat.strength"
    static let statDexterity = "stat.dexterity"
    static let statConstitution = "stat.constitution"
    static let statIntelligence = "stat.intelligence"
    static let statWisdom = "stat.wisdom"
    static let statCharisma = "stat.charisma"

    // Rarity
    static let rarityCommon = "rarity.common"
    static let rarityUncommon = "rarity.uncommon"
    static let rarityRare = "rarity.rare"
    static let rarityEpic = "rarity.epic"
    static let rarityLegendary = "rarity.legendary"

    // Damage Types
    static let damagePhysical = "damage.physical"
    static let damageFire = "damage.fire"
    static let damageCold = "damage.cold"
    static let damageLightning = "damage.lightning"
    static let damagePoison = "damage.poison"
    static let damageAcid = "damage.acid"
    static let damageHoly = "damage.holy"
    static let damageShadow = "damage.shadow"

    // Actions
    static let actionPlay = "action.play"
    static let actionDiscard = "action.discard"
    static let actionExamine = "action.examine"

    // Rules
    static let rulesTitle = "rules.title"
    static let rulesButton = "rules.button"

    // Rules Sections
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

    // MARK: - Twilight Marches
    static let tmGameTitle = "tm.game.title"
    static let tmGameSubtitle = "tm.game.subtitle"

    // Realms
    static let tmRealmYav = "tm.realm.yav"
    static let tmRealmNav = "tm.realm.nav"
    static let tmRealmPrav = "tm.realm.prav"

    // Balance
    static let tmBalanceLight = "tm.balance.light"
    static let tmBalanceNeutral = "tm.balance.neutral"
    static let tmBalanceDark = "tm.balance.dark"

    // Resources
    static let tmResourceFaith = "tm.resource.faith"
    static let tmResourceBalance = "tm.resource.balance"

    // Card Types
    static let tmCardTypeCurse = "tm.card.type.curse"
    static let tmCardTypeSpirit = "tm.card.type.spirit"
    static let tmCardTypeArtifact = "tm.card.type.artifact"
    static let tmCardTypeRitual = "tm.card.type.ritual"

    // Curse Types
    static let tmCurseBlindness = "tm.curse.type.blindness"
    static let tmCurseMuteness = "tm.curse.type.muteness"
    static let tmCurseWeakness = "tm.curse.type.weakness"
    static let tmCurseForgetfulness = "tm.curse.type.forgetfulness"
    static let tmCurseSickness = "tm.curse.type.sickness"
    static let tmCurseMadness = "tm.curse.type.madness"
    static let tmCurseTransformation = "tm.curse.type.transformation"

    // UI Elements
    static let uiMenuButton = "ui.menu.button"
    static let uiPauseMenu = "ui.pause.menu"
    static let uiResume = "ui.resume"
    static let uiSaveGame = "ui.save.game"
    static let uiRules = "ui.rules"
    static let uiExit = "ui.exit"
    static let uiRoll = "ui.roll"
    static let uiResult = "ui.result"
    static let uiEncounters = "ui.encounters"
    static let uiYourDeck = "ui.your.deck"
    static let uiDiscard = "ui.discard"
    static let uiActiveEncounter = "ui.active.encounter"
    static let uiExplore = "ui.explore"
    static let uiDeckInfo = "ui.deck.info"
    static let uiHandTitle = "ui.hand.title"
    static let uiGameSaved = "ui.game.saved"
    static let uiProgressSaved = "ui.progress.saved"

    // Victory/Defeat
    static let uiVictoryTitle = "ui.victory.title"
    static let uiDefeatTitle = "ui.defeat.title"
    static let uiEncountersDefeated = "ui.encounters.defeated"
    static let uiTurnsTaken = "ui.turns.taken"
    static let uiTurnsSurvived = "ui.turns.survived"
    static let uiReturnMenu = "ui.return.menu"

    // Tooltips
    static let tooltipHealth = "tooltip.health"
    static let tooltipFaith = "tooltip.faith"
    static let tooltipBalance = "tooltip.balance"
    static let tooltipNextPhase = "tooltip.next.phase"

    // MARK: - Region UI (Audit v1.1 Issue #2)

    // Region States
    static let regionStateStable = "region.state.stable"
    static let regionStateBorderland = "region.state.borderland"
    static let regionStateBreach = "region.state.breach"

    // Region Info
    static let regionReputation = "region.reputation"
    static let regionCurrentLocation = "region.current.location"

    // Actions
    static let actionTravel = "action.travel"
    static let actionRest = "action.rest"
    static let actionTrade = "action.trade"
    static let actionStrengthenAnchor = "action.strengthen.anchor"
    static let actionExploreRegion = "action.explore.region"

    // MARK: - Combat UI (Engine-First Migration)

    // Combat phases
    static let combatTitle = "combat.title"
    static let combatTurnNumber = "combat.turn.number"
    static let combatActionsRemaining = "combat.actions.remaining"
    static let combatPlayerTurn = "combat.phase.player.turn"
    static let combatEnemyTurn = "combat.phase.enemy.turn"
    static let combatEndTurn = "combat.phase.end.turn"
    static let combatOver = "combat.phase.over"

    // Combat actions
    static let combatAttackButton = "combat.action.attack"
    static let combatEndTurnButton = "combat.action.end.turn"
    static let combatFleeButton = "combat.action.flee"
    static let combatPlayCard = "combat.action.play.card"

    // Combat stats
    static let combatHP = "combat.stat.hp"
    static let combatAttack = "combat.stat.attack"
    static let combatDefense = "combat.stat.defense"
    static let combatStrength = "combat.stat.strength"

    // Combat messages
    static let combatVictory = "combat.message.victory"
    static let combatDefeat = "combat.message.defeat"
    static let combatFled = "combat.message.fled"
    static let combatHit = "combat.message.hit"
    static let combatMiss = "combat.message.miss"
    static let combatDamage = "combat.message.damage"

    // Combat log
    static let combatLogTitle = "combat.log.title"
    static let combatLogBattleStart = "combat.log.battle.start"
    static let combatLogActionsPerTurn = "combat.log.actions.per.turn"
    static let combatLogEnemyAttacks = "combat.log.enemy.attacks"
    static let combatLogSpiritAttacks = "combat.log.spirit.attacks"
    static let combatLogMeditation = "combat.log.meditation"
    static let combatLogTurnSeparator = "combat.log.turn.separator"

    // Combat card effects
    static let combatEffectHeal = "combat.effect.heal"
    static let combatEffectDamage = "combat.effect.damage"
    static let combatEffectDrawCards = "combat.effect.draw.cards"
    static let combatEffectGainFaith = "combat.effect.gain.faith"
    static let combatEffectSpendFaith = "combat.effect.spend.faith"
    static let combatEffectRemoveCurse = "combat.effect.remove.curse"
    static let combatEffectBonusDice = "combat.effect.bonus.dice"
    static let combatEffectShiftBalance = "combat.effect.shift.balance"
    static let combatEffectSummonSpirit = "combat.effect.summon.spirit"
    static let combatEffectSacrifice = "combat.effect.sacrifice"

    // Combat attack breakdown
    static let combatAttackRoll = "combat.attack.roll"
    static let combatDamageCalc = "combat.damage.calc"
    static let combatBaseDamage = "combat.damage.base"

    // Hand UI
    static let combatYourHand = "combat.your.hand"
    static let combatTapToPlay = "combat.tap.to.play"
    static let combatNotEnoughFaith = "combat.not.enough.faith"
}
