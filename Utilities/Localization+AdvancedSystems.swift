/// Файл: Utilities/Localization+AdvancedSystems.swift
/// Назначение: Содержит реализацию файла Localization+AdvancedSystems.swift.
/// Зона ответственности: Предоставляет вспомогательные утилиты и общие примитивы.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation

extension L10n {
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
    static let gameOverDefeatReasonWorldTensionMax = "gameover.defeat.reason.world.tension.max"
    static let gameOverDefeatReasonHeroDied = "gameover.defeat.reason.hero.died"
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

    // MARK: - Combat Feedback (EnemyCardView)
    static let combatFeedbackWeak = "combat_feedback_weak"
    static let combatFeedbackResist = "combat_feedback_resist"
    static let combatFeedbackRegen = "combat.feedback.regen"

    // MARK: - Combat Log
    static let combatLogTitle = "combat.log.title"

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

    // MARK: - SpriteKit Combat (EchoScenes)
    static let encounterLogPlayerAttack = "encounter.log.player.attack"
    static let encounterLogPlayerMissed = "encounter.log.player.missed"
    static let encounterLogEnemyDamage = "encounter.log.enemy.damage"
    static let encounterLogEnemyBlocked = "encounter.log.enemy.blocked"
    static let encounterLogEnemyHeals = "encounter.log.enemy.heals"
    static let encounterLogEnemyRitual = "encounter.log.enemy.ritual"
    static let encounterLogEnemyDefends = "encounter.log.enemy.defends"
    static let encounterLogNoEnergy = "encounter.log.no.energy"
    static let encounterLogRoundStart = "encounter.log.round.start"
    static let encounterLogPlayerInfluence = "encounter.log.player.influence"
    static let encounterLogInfluenceImpossible = "encounter.log.influence.impossible"
    static let encounterLogTrackSwitch = "encounter.log.track.switch"
    static let encounterIntentRitual = "encounter.intent.ritual"
    static let encounterIntentDefend = "encounter.intent.defend"
    static let encounterIntentBuff = "encounter.intent.buff"
    static let encounterIntentDebuff = "encounter.intent.debuff"
    static let encounterIntentPrepare = "encounter.intent.prepare"
    static let encounterPhaseLabel = "encounter.phase.label"
    static let encounterResultRounds = "encounter.result.rounds"
    static let encounterResultHp = "encounter.result.hp"
    static let encounterResultEnemyHp = "encounter.result.enemy.hp"
    static let combatDiscardTitle = "combat.discard.title"
    static let combatExhaustTitle = "combat.exhaust.title"
    static let combatPileEmpty = "combat.pile.empty"
    static let combatTapToClose = "combat.tap.to.close"
    static let combatCardCost = "combat.card.cost"
    static let combatKeywordExhaust = "combat.keyword.exhaust"
    static let combatFateDefenseLabel = "combat.fate.defense.label"
    static let combatFateCrit = "combat.fate.crit"
}
