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

    // Card Types
    static let tmCardTypeCurse = "tm.card.type.curse"
    static let tmCardTypeSpirit = "tm.card.type.spirit"
    static let tmCardTypeArtifact = "tm.card.type.artifact"
    static let tmCardTypeRitual = "tm.card.type.ritual"

    // UI Elements
    static let uiMenuButton = "ui.menu.button"
    static let uiExit = "ui.exit"
    static let uiResult = "ui.result"
    static let uiProgressSaved = "ui.progress.saved"

    // Tooltips
    static let tooltipBalance = "tooltip.balance"

    // MARK: - Region UI (Audit v1.1 Issue #2)

    // Region States
    static let regionStateStable = "region.state.stable"
    static let regionStateBorderland = "region.state.borderland"
    static let regionStateBreach = "region.state.breach"

    // Region Info
    static let regionReputation = "region.reputation"

    // Actions
    static let actionTravel = "action.travel"
    static let actionRest = "action.rest"
    static let actionTrade = "action.trade"
    static let actionStrengthenAnchor = "action.strengthen.anchor"
    static let actionExploreRegion = "action.explore.region"

    // MARK: - Arena UI
    static let arenaTitle = "arena.title"
    static let arenaHero = "arena.hero"
    static let arenaEnemy = "arena.enemy"
    static let arenaFight = "arena.fight"
    static let arenaVictory = "arena.victory"
    static let arenaDefeat = "arena.defeat"

    // MARK: - Resonance Zones
    static let resonanceZoneDeepNav = "resonance.zone.deep.nav"
    static let resonanceZoneNav = "resonance.zone.nav"
    static let resonanceZoneYav = "resonance.zone.yav"
    static let resonanceZonePrav = "resonance.zone.prav"
    static let resonanceZoneDeepPrav = "resonance.zone.deep.prav"

    // MARK: - Fate Combat
    static let combatFateDeckCount = "combat.fate.deck.count"
    static let combatFateDiscardCount = "combat.fate.discard.count"
    static let combatFateDiscardTitle = "combat.fate.discard.title"

    // MARK: - Combat UI (Engine-First Migration)

    // Combat phases
    static let combatTurnNumber = "combat.turn.number"
    static let combatActionsRemaining = "combat.actions.remaining"

    // Combat actions
    static let combatPlayCard = "combat.action.play.card"

    // Combat stats
    static let combatAttack = "combat.stat.attack"

    // Combat messages
    static let combatVictory = "combat.message.victory"

    // MARK: - UI Strings (Audit Issue #1 - Hardcoded Strings)

    // ContentView / Save Slots
    static let uiContinue = "ui.continue"
    static let uiBack = "ui.back"
    static let uiSlotSelection = "ui.slot.selection"
    static let uiContinueGame = "ui.continue.game"
    static let uiSlotNumber = "ui.slot.number"
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
    static let statsHistory = "stats.history"
    static let statsNoSaves = "stats.no.saves"
    static let statsStartHint = "stats.start.hint"
    static let statsDone = "stats.done"
    static let statsResources = "stats.resources"
    static let statsProgress = "stats.progress"
    static let statsGamesCount = "stats.games.count"
    static let statsLongestSurvival = "stats.longest.survival"
    static let statsTurnsCount = "stats.turns.count"

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
    static let enemyDefense = "enemy.defense"
    static let enemyHealth = "enemy.health"

    // Anchor
    static let anchorOfYav = "anchor.of.yav"
    static let anchorIntegrity = "anchor.integrity"

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

    // Quest
    static let questProgress = "quest.progress"

    // Journal
    static let journalEmpty = "journal.empty"
    static let journalTitle = "journal.title"

    // Confirmations
    static let confirmationTitle = "confirmation.title"
    static let confirmRest = "confirm.rest"
    static let confirmTrade = "confirm.trade"
    static let confirmStrengthenAnchor = "confirm.strengthen.anchor"
    static let confirmExplore = "confirm.explore"

    // Warnings
    static let warningTitle = "warning.title"
    static let warningHighDanger = "warning.high.danger"
    static let actionImpossible = "action.impossible"
    static let goThroughFirst = "go.through.first"

    // MARK: - HeroSelectionView / HeroPanel

    static let heroClassDefault = "hero.class.default"

    // MARK: - GameBoardView

    static let enemyDefeated = "enemy.defeated"

    // MARK: - CardView

    static let cardStatHealth = "card.stat.health"
    static let cardStatStrength = "card.stat.strength"
    static let cardStatDefense = "card.stat.defense"

    // MARK: - PlayerHandView

    static let noCardsInHand = "no.cards.in.hand"

    // Card types for market
    static let cardTypeResource = "card.type.resource"
    static let cardTypeAttack = "card.type.attack"
    static let cardTypeDefense = "card.type.defense"
    static let cardTypeSpecial = "card.type.special"

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
    static let loadingSummary = "loading.summary"

    // MARK: - Loading Items
    static let loadingItemRegions = "loading.item.regions"
    static let loadingItemEvents = "loading.item.events"
    static let loadingItemQuests = "loading.item.quests"
    static let loadingItemAnchors = "loading.item.anchors"
    static let loadingItemHeroes = "loading.item.heroes"
    static let loadingItemCards = "loading.item.cards"
    static let loadingItemEnemies = "loading.item.enemies"
    static let loadingItemLocalization = "loading.item.localization"

    // MARK: - ViewModels/GameViewModel
    static let choiceMade = "choice.made"

    // MARK: - WorldMapView - Additional Actions (unique keys)
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

    // MARK: - Combat UI strings
    static let combatTurnsStats = "combat.turns.stats"

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

    // MARK: - Save format labels
    static let uiNoSaves = "ui.no.saves"

    // MARK: - Save Compatibility Errors (Epic 7)
    static let errorSaveNotFound = "error.save.not.found"
    static let errorIncompatibleSave = "error.incompatible.save"
    static let errorSaveDecodingFailed = "error.save.decoding.failed"

    // MARK: - CombatCalculator log messages
    static let calcHit = "calc.hit"
    static let calcMiss = "calc.miss"
    static let calcAttackVsDefense = "calc.attack.vs.defense"
    static let calcStrength = "calc.strength"
    static let calcBonusDice = "calc.bonus.dice"
    static let calcBonusDamage = "calc.bonus.damage"
    static let calcDamage = "calc.damage"
    static let calcBaseDamage = "calc.base.damage"
    static let calcHeroAbilityDice = "calc.hero.ability.dice"
    static let calcHeroAbility = "calc.hero.ability"
    static let calcCurseWeakness = "calc.curse.weakness"
    static let calcCurseShadowOfNav = "calc.curse.shadow.of.nav"

    // MARK: - Active Defense Combat System

    // Fate card context
    static let combatFateAttack = "combat.fate.attack"
    static let combatFateDefense = "combat.fate.defense"

    // Fate card result interpretations
    static let combatFateAttackGreat = "combat.fate.attack.great"
    static let combatFateAttackGood = "combat.fate.attack.good"
    static let combatFateAttackWeak = "combat.fate.attack.weak"
    static let combatFateDefenseGreat = "combat.fate.defense.great"
    static let combatFateDefenseGood = "combat.fate.defense.good"
    static let combatFateDefenseWeak = "combat.fate.defense.weak"

    // Encounter combat log
    static let encounterLogEnemyPrepares = "encounter.log.enemy.prepares"
    static let encounterLogRoundEnemyPrepares = "encounter.log.round.enemy.prepares"
    static let encounterLogPlayerWaits = "encounter.log.player.waits"
    static let encounterLogBodyDamage = "encounter.log.body.damage"
    static let encounterLogWillDamage = "encounter.log.will.damage"
    static let encounterLogPlayerTakesDamage = "encounter.log.player.takes.damage"
    static let encounterLogEnemySlain = "encounter.log.enemy.slain"
    static let encounterLogEnemyPacified = "encounter.log.enemy.pacified"
    static let encounterLogFateDraw = "encounter.log.fate.draw"
    static let encounterLogResonanceShift = "encounter.log.resonance.shift"
    static let encounterLogRageShield = "encounter.log.rage.shield"
    static let encounterLogCardPlayed = "encounter.log.card.played"
    static let encounterLogPlayerDefends = "encounter.log.player.defends"
    static let encounterLogFleeBlocked = "encounter.log.flee.blocked"
    static let encounterLogFleeFailed = "encounter.log.flee.failed"
    static let encounterLogFleeSuccess = "encounter.log.flee.success"
    static let encounterLogFleeDamage = "encounter.log.flee.damage"
    static let encounterLogEnemySummoned = "encounter.log.enemy.summoned"

    // Encounter UI
    static let encounterPhaseIntent = "encounter.phase.intent"
    static let encounterPhasePlayerAction = "encounter.phase.player.action"
    static let encounterPhaseEnemyResolution = "encounter.phase.enemy.resolution"
    static let encounterPhaseRoundEnd = "encounter.phase.round.end"
    static let encounterRoundLabel = "encounter.round.label"
    static let encounterActionAttack = "encounter.action.attack"
    static let encounterActionInfluence = "encounter.action.influence"
    static let encounterActionWait = "encounter.action.wait"
    static let encounterActionFlee = "encounter.action.flee"
    static let encounterOutcomeVictory = "encounter.outcome.victory"
    static let encounterOutcomePacified = "encounter.outcome.pacified"
    static let encounterOutcomeDefeat = "encounter.outcome.defeat"
    static let encounterOutcomeEscaped = "encounter.outcome.escaped"
    static let encounterOutcomeContinue = "encounter.outcome.continue"
    static let encounterOutcomeHpLost = "encounter.outcome.hp.lost"
    static let encounterOutcomeHpGained = "encounter.outcome.hp.gained"

    // Resonance zone names (for FateCardRevealView)
    static let resonanceDeepNav = "resonance.deep.nav"
    static let resonanceNav = "resonance.nav"
    static let resonanceYav = "resonance.yav"
    static let resonancePrav = "resonance.prav"
    static let resonanceDeepPrav = "resonance.deep.prav"

    // Enemy intent types
    static let combatIntentAttack = "combat.intent.attack"
    static let combatIntentRitual = "combat.intent.ritual"
    static let combatIntentBlock = "combat.intent.block"
    static let combatIntentBuff = "combat.intent.buff"
    static let combatIntentHeal = "combat.intent.heal"
    static let combatIntentSummon = "combat.intent.summon"

    // Enemy intent detail descriptions
    static let combatIntentDetailAttack = "combat.intent.detail.attack"
    static let combatIntentDetailRitual = "combat.intent.detail.ritual"
    static let combatIntentDetailBlock = "combat.intent.detail.block"
    static let combatIntentDetailBuff = "combat.intent.detail.buff"
    static let combatIntentDetailHeal = "combat.intent.detail.heal"
    static let combatIntentDetailSummon = "combat.intent.detail.summon"

    // New intent types
    static let combatIntentPrepare = "combat.intent.prepare"
    static let combatIntentRestoreWP = "combat.intent.restoreWP"
    static let combatIntentDebuff = "combat.intent.debuff"
    static let combatIntentDefend = "combat.intent.defend"
    static let combatIntentDetailPrepare = "combat.intent.detail.prepare"
    static let combatIntentDetailRestoreWP = "combat.intent.detail.restoreWP"
    static let combatIntentDetailDebuff = "combat.intent.detail.debuff"
    static let combatIntentDetailDefend = "combat.intent.detail.defend"

    // Faith
    static let combatFaithLabel = "combat.faith.label"
    static let combatFaithInsufficient = "combat.faith.insufficient"
    static let combatFaithCost = "combat.faith.cost"
    static let combatFaithSpent = "combat.faith.spent"

    // Fate choice
    static let fateChoiceTitle = "fate.choice.title"
    static let fateChoiceSafe = "fate.choice.safe"
    static let fateChoiceRisk = "fate.choice.risk"
    static let fateChoiceTimer = "fate.choice.timer"

    // Mulligan
    static let combatMulliganTitle = "combat.mulligan.title"
    static let combatMulliganPrompt = "combat.mulligan.prompt"
    static let combatMulliganConfirm = "combat.mulligan.confirm"
    static let combatMulliganSkip = "combat.mulligan.skip"

    // Card draw
    static let combatCardDrawn = "combat.card.drawn"

    // Escalation
    static let combatEscalationSurprise = "combat.escalation.surprise"
    static let combatEscalationRageShield = "combat.escalation.rage_shield"

    // Settings (SET-01/02)
    static let settingsTitle = "settings.title"
    static let settingsDifficulty = "settings.difficulty"
    static let settingsDifficultyEasy = "settings.difficulty.easy"
    static let settingsDifficultyNormal = "settings.difficulty.normal"
    static let settingsDifficultyHard = "settings.difficulty.hard"
    static let settingsLanguage = "settings.language"
    static let settingsResetTutorial = "settings.reset.tutorial"
    static let settingsResetAllData = "settings.reset.all.data"
    static let settingsResetConfirm = "settings.reset.confirm"
    static let settingsResetAllConfirm = "settings.reset.all.confirm"
    static let settingsDone = "settings.done"

    // Tutorial (TUT-01/02)
    static let tutorialWelcomeTitle = "tutorial.welcome.title"
    static let tutorialWelcomeBody = "tutorial.welcome.body"
    static let tutorialMapTitle = "tutorial.map.title"
    static let tutorialMapBody = "tutorial.map.body"
    static let tutorialCombatTitle = "tutorial.combat.title"
    static let tutorialCombatBody = "tutorial.combat.body"
    static let tutorialFateTitle = "tutorial.fate.title"
    static let tutorialFateBody = "tutorial.fate.body"
    static let tutorialNext = "tutorial.next"
    static let tutorialFinish = "tutorial.finish"
    static let tutorialSkip = "tutorial.skip"

    // Game Over (SAV-01)
    static let gameOverVictoryTitle = "gameover.victory.title"
    static let gameOverDefeatTitle = "gameover.defeat.title"
    static let gameOverVictoryMessage = "gameover.victory.message"
    static let gameOverDefeatReason = "gameover.defeat.reason"
    static let gameOverReturnToMenu = "gameover.return.to.menu"
    static let gameOverStats = "gameover.stats"
    static let gameOverDaysSurvived = "gameover.days.survived"
    static let gameOverQuestsCompleted = "gameover.quests.completed"

    // MARK: - Fate Card Labels (DS-04)
    static let fateCritical = "fate.critical"
    static let fateDeckEmpty = "fate.deck.empty"
    static let fateResonanceModifier = "fate.resonance.modifier"

    // MARK: - Bestiary (Epic 13)
    static let bestiaryTitle = "bestiary.title"
    static let bestiarySearch = "bestiary.search"
    static let bestiaryProgress = "bestiary.progress"
    static let bestiaryKnowledge = "bestiary.knowledge"
    static let bestiaryLevelUnknown = "bestiary.level.unknown"
    static let bestiaryLevelEncountered = "bestiary.level.encountered"
    static let bestiaryLevelStudied = "bestiary.level.studied"
    static let bestiaryLevelMastered = "bestiary.level.mastered"
    static let bestiaryStats = "bestiary.stats"
    static let bestiaryLore = "bestiary.lore"
    static let bestiaryCombatInfo = "bestiary.combat.info"
    static let bestiaryWeaknesses = "bestiary.weaknesses"
    static let bestiaryStrengths = "bestiary.strengths"
    static let bestiaryTactics = "bestiary.tactics"
    static let bestiaryPersonalStats = "bestiary.personal.stats"
    static let bestiaryEncountered = "bestiary.encountered"
    static let bestiaryDefeated = "bestiary.defeated"
    static let bestiaryPacified = "bestiary.pacified"
    static let bestiaryLastMet = "bestiary.last.met"
    static let bestiaryUnlockStudied = "bestiary.unlock.studied"
    static let bestiaryUnlockMastered = "bestiary.unlock.mastered"

    // MARK: - Enemy Types (Epic 13)
    static let enemyTypeBeast = "enemy.type.beast"
    static let enemyTypeSpirit = "enemy.type.spirit"
    static let enemyTypeUndead = "enemy.type.undead"
    static let enemyTypeDemon = "enemy.type.demon"
    static let enemyTypeHuman = "enemy.type.human"
    static let enemyTypeBoss = "enemy.type.boss"

    // MARK: - Achievements (Epic 13)
    static let achievementsTitle = "achievements.title"
    static let achievementsUnlocked = "achievements.unlocked"
    static let achievementsCategoryCombat = "achievements.category.combat"
    static let achievementsCategoryExploration = "achievements.category.exploration"
    static let achievementsCategoryKnowledge = "achievements.category.knowledge"
    static let achievementsCategoryMastery = "achievements.category.mastery"

    // MARK: - EC-01/EC-02: Weakness/Strength & Enemy Abilities
    static let combatWeaknessTriggered = "combat.weakness_triggered"
    static let combatResistanceTriggered = "combat.resistance_triggered"
    static let combatAbilityTriggered = "combat.ability_triggered"
    static let combatRegeneration = "combat.regeneration"

    // MARK: - EC-04: Mid-Combat Save
    static let combatSaveExitTitle = "combat.save_exit_title"
    static let combatSaveExitMessage = "combat.save_exit_message"
    static let combatSaveExitConfirm = "combat.save_exit_confirm"
    static let combatSaveExitCancel = "combat.save_exit_cancel"

    // MARK: - Combat Phase UI
    static let combatPhaseIntent = "combat_phase_intent"
    static let combatPhaseYourTurn = "combat_phase_your_turn"
    static let combatPhaseEnemyActs = "combat_phase_enemy_acts"
    static let combatPhaseNextRound = "combat_phase_next_round"
    static let combatFeedbackWeak = "combat_feedback_weak"
    static let combatFeedbackResist = "combat_feedback_resist"

}
