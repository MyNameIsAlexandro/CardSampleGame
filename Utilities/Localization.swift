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
    static let buttonSelectHeroFirst = "button.select.hero.first"

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

    // MARK: - UI Strings (Audit Issue #1 - Hardcoded Strings)

    // ContentView / Save Slots
    static let uiContinue = "ui.continue"
    static let uiBack = "ui.back"
    static let uiSlotSelection = "ui.slot.selection"
    static let uiContinueGame = "ui.continue.game"
    static let uiSlotNumber = "ui.slot.number"
    static let uiTurnNumber = "ui.turn.number"
    static let uiVictories = "ui.victories"
    static let uiLoad = "ui.load"
    static let uiNewGame = "ui.new.game"
    static let uiEmptySlot = "ui.empty.slot"
    static let uiStartNewGame = "ui.start.new.game"
    static let uiDeleteConfirm = "ui.delete.confirm"
    static let uiOverwriteConfirm = "ui.overwrite.confirm"
    static let uiDeleteSave = "ui.delete.save"
    static let uiOverwriteSave = "ui.overwrite.save"
    static let uiCancel = "ui.cancel"
    static let uiDelete = "ui.delete"
    static let uiOverwrite = "ui.overwrite"

    // EventView
    static let eventChooseAction = "event.choose.action"
    static let eventRequiresFaith = "event.requires.faith"
    static let eventYouHaveFaith = "event.you.have.faith"
    static let eventRequiresHealth = "event.requires.health"
    static let eventYouHaveHealth = "event.you.have.health"
    static let eventRequiresPath = "event.requires.path"
    static let eventYourPath = "event.your.path"
    static let eventFaithChange = "event.faith.change"
    static let eventHealthChange = "event.health.change"
    static let eventBalanceToLight = "event.balance.to.light"
    static let eventBalanceToDark = "event.balance.to.dark"
    static let eventReputationChange = "event.reputation.change"
    static let eventReceiveCard = "event.receive.card"
    static let eventReceiveCurse = "event.receive.curse"
    static let eventChoiceMade = "event.choice.made"
    static let eventCombatVictoryMessage = "event.combat.victory.message"
    static let eventCombatDefeatMessage = "event.combat.defeat.message"
    static let eventCombatFledMessage = "event.combat.fled.message"

    // UI Common
    static let uiClose = "ui.close"

    // Balance (genitive form)
    static let tmBalanceLightGenitive = "tm.balance.light.genitive"
    static let tmBalanceNeutralGenitive = "tm.balance.neutral.genitive"
    static let tmBalanceDarkGenitive = "tm.balance.dark.genitive"

    // StatisticsView
    static let statsTitle = "stats.title"
    static let statsGameName = "stats.game.name"
    static let statsGeneral = "stats.general"
    static let statsLeaderboard = "stats.leaderboard"
    static let statsHistory = "stats.history"
    static let statsNoSaves = "stats.no.saves"
    static let statsStartHint = "stats.start.hint"
    static let statsDone = "stats.done"
    static let statsResources = "stats.resources"
    static let statsProgress = "stats.progress"
    static let statsGamesCount = "stats.games.count"
    static let statsBestResult = "stats.best.result"
    static let statsLongestSurvival = "stats.longest.survival"
    static let statsTurnsCount = "stats.turns.count"
    static let statsVictoriesLabel = "stats.victories.label"
    static let statsTurnsLabel = "stats.turns.label"

    // CombatView additional
    static let combatVs = "combat.vs"
    static let combatAttackRollTitle = "combat.attack.roll"
    static let combatDamageCalcTitle = "combat.damage.calc.title"
    static let combatBaseValue = "combat.base.value"
    static let combatTotalDamage = "combat.total.damage"

    // Combat UI labels (Audit v2.1 Item 5)
    static let combatShield = "combat.shield"
    static let combatDefend = "combat.defend"
    static let combatFallen = "combat.fallen"
    static let combatStatsTurns = "combat.stats.turns"
    static let combatStatsDamageDealt = "combat.stats.damage.dealt"
    static let combatStatsDamageTaken = "combat.stats.damage.taken"
    static let combatStatsCardsPlayed = "combat.stats.cards.played"
    static let combatAttackVsDefense = "combat.attack.vs.defense"

    // MARK: - WorldMapView (Full localization - Audit v2.1)

    // Loading & Alerts
    static let worldLoading = "world.loading"
    static let worldEvent = "world.event"
    static let buttonUnderstood = "button.understood"
    static let dayNumber = "day.number"
    static let worldLabel = "world.label"
    static let daysInJourney = "days.in.journey"
    static let buttonConfirm = "button.confirm"
    static let nothingFound = "nothing.found"
    static let noEventsInRegion = "no.events.in.region"
    static let cardsReceived = "cards.received"
    static let addedToDeck = "added.to.deck"
    static let buttonGreat = "button.great"
    static let youAreHere = "you.are.here"

    // Region descriptions
    static let regionDescStable = "region.desc.stable"
    static let regionDescBorderland = "region.desc.borderland"
    static let regionDescBreach = "region.desc.breach"

    // Combat modifiers
    static let combatModifiers = "combat.modifiers"
    static let enemyStrength = "enemy.strength"
    static let enemyDefense = "enemy.defense"
    static let enemyHealth = "enemy.health"

    // Anchor
    static let anchorOfYav = "anchor.of.yav"
    static let anchorIntegrity = "anchor.integrity"
    static let anchorInfluence = "anchor.influence"

    // Balance names
    static let balanceLight = "balance.light"
    static let balanceNeutral = "balance.neutral"
    static let balanceDark = "balance.dark"

    // Actions
    static let availableActions = "available.actions"
    static let dayWord1 = "day.word.1"
    static let dayWord234 = "day.word.234"
    static let actionTravelTo = "action.travel.to"
    static let actionRegionFar = "action.region.far"
    static let actionMoveToRegionHint = "action.move.to.region.hint"
    static let actionRegionNotDirectlyAccessible = "action.region.not.directly.accessible"
    static let actionRestWithHealth = "action.rest.with.health"
    static let actionStrengthenAnchorCost = "action.strengthen.anchor.cost"

    // Quest
    static let activeQuestsInRegion = "active.quests.in.region"
    static let questProgress = "quest.progress"

    // Journal
    static let journalEmpty = "journal.empty"
    static let journalTitle = "journal.title"

    // Confirmations
    static let confirmationTitle = "confirmation.title"
    static let confirmTravelTo = "confirm.travel.to"
    static let confirmRest = "confirm.rest"
    static let confirmTrade = "confirm.trade"
    static let confirmStrengthenAnchor = "confirm.strengthen.anchor"
    static let confirmExplore = "confirm.explore"
    static let locationUnknown = "location.unknown"

    // Log entries
    static let logEventRest = "log.event.rest"
    static let logChoiceRest = "log.choice.rest"
    static let logOutcomeHealthRestored = "log.outcome.health.restored"
    static let logEventStrengthenAnchor = "log.event.strengthen.anchor"
    static let logChoiceFaithSpent = "log.choice.faith.spent"
    static let logOutcomeAnchorStrengthened = "log.outcome.anchor.strengthened"

    // Warnings
    static let warningTitle = "warning.title"
    static let warningHighDanger = "warning.high.danger"
    static let actionImpossible = "action.impossible"
    static let goThroughFirst = "go.through.first"

    // MARK: - HeroSelectionView / HeroPanel

    static let heroClassDefault = "hero.class.default"
    static let heroSelectTitle = "hero.select.title"
    static let heroSelectSubtitle = "hero.select.subtitle"
    static let heroStartGame = "hero.start.game"
    static let heroSelectClass = "hero.select.class"
    static let heroPath = "hero.path"
    static let pathLight = "path.light"
    static let pathDark = "path.dark"
    static let pathBalance = "path.balance"

    // MARK: - GameBoardView

    static let enemyDefeated = "enemy.defeated"
    static let returningToEvent = "returning.to.event"
    static let rollResult = "roll.result"
    static let enemyAttacksYou = "enemy.attacks.you"
    static let marketplace = "marketplace"
    static let noCardsForPurchase = "no.cards.for.purchase"
    static let victoryMessage = "victory.message"
    static let defeatMessage = "defeat.message"
    static let buttonBuy = "button.buy"

    // MARK: - CardView

    static let cardStatHealth = "card.stat.health"
    static let cardStatStrength = "card.stat.strength"
    static let cardStatDefense = "card.stat.defense"

    // MARK: - PlayerHandView

    static let noCardsInHand = "no.cards.in.hand"

    // MARK: - GameBoardView (Full localization - Audit v2.1)

    // Combat alerts
    static let combatAlertSuccess = "combat.alert.success"
    static let combatAlertFail = "combat.alert.fail"
    static let combatRollResultSuccess = "combat.roll.result.success"
    static let combatRollResultFail = "combat.roll.result.fail"
    static let combatEnemyAttackTitle = "combat.enemy.attack.title"
    static let combatEnemyAttackMessage = "combat.enemy.attack.message"

    // Pause menu
    static let worldMap = "world.map"

    // Stats display
    static let statsEncountersDefeated = "stats.encounters.defeated"
    static let statsTurnsMade = "stats.turns.made"
    static let statsTurnsSurvived = "stats.turns.survived"

    // Card types for market
    static let cardTypeResource = "card.type.resource"
    static let cardTypeAttack = "card.type.attack"
    static let cardTypeDefense = "card.type.defense"
    static let cardTypeSpecial = "card.type.special"

    // Phase progress bar labels
    static let phaseProgressExploration = "phase.progress.exploration"
    static let phaseProgressEncounter = "phase.progress.encounter"
    static let phaseProgressPlayerTurn = "phase.progress.player.turn"
    static let phaseProgressEnemyTurn = "phase.progress.enemy.turn"
    static let phaseProgressEndTurn = "phase.progress.end.turn"

    // MARK: - Models/ExplorationModels - Combat Modifiers
    static let combatModifierBorderland = "combat.modifier.borderland"
    static let combatModifierBreach = "combat.modifier.breach"

    // MARK: - Models/ExplorationModels - RegionType
    static let regionTypeForest = "region.type.forest"
    static let regionTypeSwamp = "region.type.swamp"
    static let regionTypeMountain = "region.type.mountain"
    static let regionTypeSettlement = "region.type.settlement"
    static let regionTypeWater = "region.type.water"
    static let regionTypeWasteland = "region.type.wasteland"
    static let regionTypeSacred = "region.type.sacred"

    // MARK: - Models/ExplorationModels - AnchorType
    static let anchorTypeShrine = "anchor.type.shrine"
    static let anchorTypeBarrow = "anchor.type.barrow"
    static let anchorTypeSacredTree = "anchor.type.sacred.tree"
    static let anchorTypeStoneIdol = "anchor.type.stone.idol"
    static let anchorTypeSpring = "anchor.type.spring"
    static let anchorTypeChapel = "anchor.type.chapel"
    static let anchorTypeTemple = "anchor.type.temple"
    static let anchorTypeCross = "anchor.type.cross"

    // MARK: - Models/ExplorationModels - EventType
    static let eventTypeCombat = "event.type.combat"
    static let eventTypeRitual = "event.type.ritual"
    static let eventTypeNarrative = "event.type.narrative"
    static let eventTypeExploration = "event.type.exploration"
    static let eventTypeWorldShift = "event.type.world.shift"

    // MARK: - Models/Player - Balance path
    static let balancePathDark = "balance.path.dark"
    static let balancePathNeutral = "balance.path.neutral"
    static let balancePathLight = "balance.path.light"
    static let balancePathUnknown = "balance.path.unknown"

    // MARK: - CardGameApp - Loading messages
    static let loadingDefault = "loading.default"
    static let loadingSearchPacks = "loading.search.packs"
    static let loadingContent = "loading.content"
    static let loadingContentNotFound = "loading.content.not.found"
    static let loadingReady = "loading.ready"
    static let loadingContentLoaded = "loading.content.loaded"
    static let loadingError = "loading.error"
    static let appTitle = "app.title"

    // MARK: - Content Cache messages
    static let loadingValidatingCache = "loading.validating.cache"
    static let loadingFromCache = "loading.from.cache"
    static let loadingSavingCache = "loading.saving.cache"

    // MARK: - ViewModels/GameViewModel
    static let defaultPlayerName = "default.player.name"
    static let regionUnknown = "region.unknown"
    static let journalEntryRest = "journal.entry.rest"
    static let journalEntryRestChoice = "journal.entry.rest.choice"
    static let journalEntryRestOutcome = "journal.entry.rest.outcome"
    static let journalEntryAnchor = "journal.entry.anchor"
    static let journalEntryAnchorChoice = "journal.entry.anchor.choice"
    static let journalEntryAnchorOutcome = "journal.entry.anchor.outcome"
    static let choiceMade = "choice.made"

    // MARK: - WorldMapView - Additional Actions (unique keys)
    static let actionTravelFar = "action.travel.far"
    static let actionExplore = "action.explore"
    static let confirmTravel = "confirm.travel"

    // MARK: - WorldMapView - Journal entries
    static let journalEntryTravel = "journal.entry.travel"
    static let journalEntryTravelChoice = "journal.entry.travel.choice"
    static let journalEntryTravelOutcome = "journal.entry.travel.outcome"
    static let journalEntryExplore = "journal.entry.explore"
    static let journalEntryExploreChoice = "journal.entry.explore.choice"
    static let journalEntryExploreNothing = "journal.entry.explore.nothing"

    // MARK: - WorldMapView - Error messages
    static let errorUnknown = "error.unknown"
    static let errorRegionFar = "error.region.far"
    static let errorRegionInaccessible = "error.region.inaccessible"
    static let errorHealthLow = "error.health.low"
    static let errorInsufficientResource = "error.insufficient.resource"
    static let errorInCombat = "error.in.combat"
    static let errorFinishEvent = "error.finish.event"
    static let errorActionFailed = "error.action.failed"

    // MARK: - GameViewModel Journal entries (used in GameViewModel.swift)
    static let journalRestTitle = "journal.rest.title"
    static let journalRestChoice = "journal.rest.choice"
    static let journalRestOutcome = "journal.rest.outcome"
    static let journalAnchorTitle = "journal.anchor.title"
    static let journalAnchorChoice = "journal.anchor.choice"
    static let journalAnchorOutcome = "journal.anchor.outcome"
    static let journalChoiceMade = "journal.choice.made"

    // MARK: - WorldMapView - Action buttons (localized titles)
    static let actionRestHeal = "action.rest.heal"
    static let actionTradeName = "action.trade.name"
    static let actionExploreName = "action.explore.name"
    static let actionAnchorCost = "action.anchor.cost"

    // MARK: - CurseType display names
    static let curseWeakness = "curse.weakness"
    static let curseFear = "curse.fear"
    static let curseExhaustion = "curse.exhaustion"
    static let curseGreed = "curse.greed"
    static let curseShadowOfNav = "curse.shadow.of.nav"
    static let curseBloodCurse = "curse.blood.curse"
    static let curseSealOfNav = "curse.seal.of.nav"

    // MARK: - DayEvent notifications
    static let dayEventTensionTitle = "dayevent.tension.title"
    static let dayEventTensionDescription = "dayevent.tension.description"
    static let dayEventRegionDegradedTitle = "dayevent.region.degraded.title"
    static let dayEventRegionDegradedDescription = "dayevent.region.degraded.description"
    static let dayEventWorldImprovingTitle = "dayevent.world.improving.title"
    static let dayEventWorldImprovingDescription = "dayevent.world.improving.description"

    // MARK: - World log messages
    static let logTensionIncreased = "log.tension.increased"
    static let logAnchorResists = "log.anchor.resists"
    static let logRegionDegraded = "log.region.degraded"
    static let logWorldChange = "log.world.change"
    static let logWorld = "log.world"

    // MARK: - Travel log messages
    static let logTravelTitle = "log.travel.title"
    static let logTravelChoice = "log.travel.choice"
    static let logTravelOutcomeDay = "log.travel.outcome.day"
    static let logTravelOutcomeDays = "log.travel.outcome.days"

    // MARK: - Combat UI strings
    static let combatTurnsStats = "combat.turns.stats"
    static let combatActionCost = "combat.action.cost"
    static let combatMonsterDefeated = "combat.monster.defeated"
    static let combatContinue = "combat.continue"
    static let combatReturn = "combat.return"
    static let combatHitResult = "combat.hit.result"
    static let combatMissResult = "combat.miss.result"
    static let combatDiceRoll = "combat.dice.roll"
    static let combatDefenseValue = "combat.defense.value"
    static let combatDamageValue = "combat.damage.value"

    // MARK: - Combat log messages
    static let combatLogBattleStartEnemy = "combat.log.battle.start.enemy"
    static let combatLogActionsInfo = "combat.log.actions.info"
    static let combatLogHit = "combat.log.hit"
    static let combatLogMissed = "combat.log.miss"
    static let combatLogCover = "combat.log.cover"
    static let combatLogStrengthBonus = "combat.log.strength.bonus"
    static let combatLogInsufficientFaith = "combat.log.insufficient.faith"
    static let combatLogFaithSpent = "combat.log.faith.spent"
    static let combatLogShieldCard = "combat.log.shield.card"
    static let combatLogAttackBonus = "combat.log.attack.bonus"
    static let combatLogSpellCast = "combat.log.spell.cast"
    static let combatLogCardPlayed = "combat.log.card.played"
    static let combatLogHealEffect = "combat.log.heal.effect"
    static let combatLogDamageEffect = "combat.log.damage.effect"
    static let combatLogDrawCards = "combat.log.draw.cards"
    static let combatLogFaithGained = "combat.log.faith.gained"
    static let combatLogCurseRemoved = "combat.log.curse.removed"
    static let combatLogBonusDice = "combat.log.bonus.dice"
    static let combatLogReroll = "combat.log.reroll"
    static let combatLogBalanceShift = "combat.log.balance.shift"
    static let combatLogCurseDamage = "combat.log.curse.damage"
    static let combatLogSpiritSummoned = "combat.log.spirit.summoned"
    static let combatLogSpiritAttack = "combat.log.spirit.attack"

    // MARK: - Realm names
    static let realmYav = "realm.yav"
    static let realmNav = "realm.nav"
    static let realmPrav = "realm.prav"

    // MARK: - Hero Classes
    static let heroClassWarrior = "hero.class.warrior"
    static let heroClassMage = "hero.class.mage"
    static let heroClassRanger = "hero.class.ranger"
    static let heroClassPriest = "hero.class.priest"
    static let heroClassShadow = "hero.class.shadow"

    static let heroClassWarriorDesc = "hero.class.warrior.desc"
    static let heroClassMageDesc = "hero.class.mage.desc"
    static let heroClassRangerDesc = "hero.class.ranger.desc"
    static let heroClassPriestDesc = "hero.class.priest.desc"
    static let heroClassShadowDesc = "hero.class.shadow.desc"

    static let heroAbilityWarrior = "hero.ability.warrior"
    static let heroAbilityMage = "hero.ability.mage"
    static let heroAbilityRanger = "hero.ability.ranger"
    static let heroAbilityPriest = "hero.ability.priest"
    static let heroAbilityShadow = "hero.ability.shadow"

    // MARK: - Curse Definitions
    static let curseWeaknessName = "curse.weakness.name"
    static let curseWeaknessDescription = "curse.weakness.description"
    static let curseFearName = "curse.fear.name"
    static let curseFearDescription = "curse.fear.description"
    static let curseExhaustionName = "curse.exhaustion.name"
    static let curseExhaustionDescription = "curse.exhaustion.description"
    static let curseGreedName = "curse.greed.name"
    static let curseGreedDescription = "curse.greed.description"
    static let curseShadowOfNavName = "curse.shadow.of.nav.name"
    static let curseShadowOfNavDescription = "curse.shadow.of.nav.description"
    static let curseBloodCurseName = "curse.blood.curse.name"
    static let curseBloodCurseDescription = "curse.blood.curse.description"
    static let curseSealOfNavName = "curse.seal.of.nav.name"
    static let curseSealOfNavDescription = "curse.seal.of.nav.description"

    // MARK: - Hero Ability Definitions
    static let abilityWarriorRageName = "ability.warrior.rage.name"
    static let abilityWarriorRageDesc = "ability.warrior.rage.desc"
    static let abilityMageMeditationName = "ability.mage.meditation.name"
    static let abilityMageMeditationDesc = "ability.mage.meditation.desc"
    static let abilityRangerTrackingName = "ability.ranger.tracking.name"
    static let abilityRangerTrackingDesc = "ability.ranger.tracking.desc"
    static let abilityPriestBlessingName = "ability.priest.blessing.name"
    static let abilityPriestBlessingDesc = "ability.priest.blessing.desc"
    static let abilityShadowAmbushName = "ability.shadow.ambush.name"
    static let abilityShadowAmbushDesc = "ability.shadow.ambush.desc"

    // MARK: - Action Errors
    static let errorInvalidAction = "error.invalid.action"
    static let errorRegionNotAccessible = "error.region.not.accessible"
    static let errorRegionNotNeighbor = "error.region.not.neighbor"
    static let errorActionNotAvailable = "error.action.not.available"
    static let errorInsufficientResources = "error.insufficient.resources"
    static let errorHealthTooLow = "error.health.too.low"
    static let errorGameNotInProgress = "error.game.not.in.progress"
    static let errorCombatInProgress = "error.combat.in.progress"
    static let errorEventInProgress = "error.event.in.progress"
    static let errorNoActiveEvent = "error.no.active.event"
    static let errorNoActiveCombat = "error.no.active.combat"
    static let errorEventNotFound = "error.event.not.found"
    static let errorInvalidChoiceIndex = "error.invalid.choice.index"
    static let errorChoiceRequirementsNotMet = "error.choice.requirements.not.met"
    static let errorCardNotInHand = "error.card.not.in.hand"
    static let errorNotEnoughActions = "error.not.enough.actions"
    static let errorInvalidTarget = "error.invalid.target"
}
