/// Файл: Utilities/Localization+WorldAndNavigation.swift
/// Назначение: Содержит реализацию файла Localization+WorldAndNavigation.swift.
/// Зона ответственности: Предоставляет вспомогательные утилиты и общие примитивы.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation

/// Ключи локализации для карты мира, регионов, журнала и навигационных действий.
extension L10n {
    // Region UI
    static let regionStateStable = "region.state.stable"
    static let regionStateBorderland = "region.state.borderland"
    static let regionStateBreach = "region.state.breach"
    static let regionReputation = "region.reputation"

    // Region descriptions
    static let regionDescStable = "region.desc.stable"
    static let regionDescBorderland = "region.desc.borderland"
    static let regionDescBreach = "region.desc.breach"

    // Actions
    static let actionTravel = "action.travel"
    static let actionRest = "action.rest"
    static let actionTrade = "action.trade"
    static let actionStrengthenAnchor = "action.strengthen.anchor"
    static let actionExploreRegion = "action.explore.region"
    static let actionExplore = "action.explore"
    static let actionTravelTo = "action.travel.to"
    static let actionRegionFar = "action.region.far"
    static let actionMoveToRegionHint = "action.move.to.region.hint"
    static let actionRegionNotDirectlyAccessible = "action.region.not.directly.accessible"
    static let actionImpossible = "action.impossible"
    static let actionRestHeal = "action.rest.heal"
    static let actionTradeName = "action.trade.name"
    static let actionExploreName = "action.explore.name"
    static let actionAnchorCost = "action.anchor.cost"

    // World map
    static let worldLoading = "world.loading"
    static let worldEvent = "world.event"
    static let dayNumber = "day.number"
    static let worldLabel = "world.label"
    static let daysInJourney = "days.in.journey"
    static let nothingFound = "nothing.found"
    static let noEventsInRegion = "no.events.in.region"
    static let cardsReceived = "cards.received"
    static let addedToDeck = "added.to.deck"
    static let youAreHere = "you.are.here"
    static let availableActions = "available.actions"
    static let dayWord1 = "day.word.1"
    static let dayWord234 = "day.word.234"
    static let questProgress = "quest.progress"
    static let heroClassDefault = "hero.class.default"

    // Region/anchor meta
    static let enemyDefense = "enemy.defense"
    static let enemyHealth = "enemy.health"
    static let anchorOfYav = "anchor.of.yav"
    static let anchorIntegrity = "anchor.integrity"
    static let balanceLight = "balance.light"
    static let balanceNeutral = "balance.neutral"
    static let balanceDark = "balance.dark"
    static let tmBalanceLightGenitive = "tm.balance.light.genitive"
    static let tmBalanceNeutralGenitive = "tm.balance.neutral.genitive"
    static let tmBalanceDarkGenitive = "tm.balance.dark.genitive"

    // Journal
    static let journalEmpty = "journal.empty"
    static let journalTitle = "journal.title"
    static let journalEntryTravel = "journal.entry.travel"
    static let journalEntryTravelChoice = "journal.entry.travel.choice"
    static let journalEntryTravelOutcome = "journal.entry.travel.outcome"
    static let journalEntryExplore = "journal.entry.explore"
    static let journalEntryExploreChoice = "journal.entry.explore.choice"
    static let journalEntryExploreNothing = "journal.entry.explore.nothing"
    static let journalRestTitle = "journal.rest.title"
    static let journalRestChoice = "journal.rest.choice"
    static let journalRestOutcome = "journal.rest.outcome"
    static let journalAnchorTitle = "journal.anchor.title"
    static let journalAnchorChoice = "journal.anchor.choice"
    static let journalAnchorOutcome = "journal.anchor.outcome"
    static let journalChoiceMade = "journal.choice.made"

    // Confirmations
    static let confirmationTitle = "confirmation.title"
    static let confirmTravel = "confirm.travel"
    static let confirmRest = "confirm.rest"
    static let confirmTrade = "confirm.trade"
    static let confirmStrengthenAnchor = "confirm.strengthen.anchor"
    static let confirmExplore = "confirm.explore"

    // Warnings & world errors
    static let warningTitle = "warning.title"
    static let warningHighDanger = "warning.high.danger"
    static let goThroughFirst = "go.through.first"
    static let errorUnknown = "error.unknown"
    static let errorRegionFar = "error.region.far"
    static let errorRegionInaccessible = "error.region.inaccessible"
    static let errorHealthLow = "error.health.low"
    static let errorInsufficientResource = "error.insufficient.resource"
    static let errorInCombat = "error.in.combat"
    static let errorFinishEvent = "error.finish.event"
    static let errorActionFailed = "error.action.failed"
}
