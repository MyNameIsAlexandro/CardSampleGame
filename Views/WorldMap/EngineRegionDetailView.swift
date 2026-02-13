/// Файл: Views/WorldMap/EngineRegionDetailView.swift
/// Назначение: Содержит реализацию файла EngineRegionDetailView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct EngineRegionDetailView: View {
    let region: EngineRegionState
    @ObservedObject var vm: GameEngineObservable
    let cardFactory: CardFactory
    let onDismiss: () -> Void
    var onRegionChange: ((EngineRegionState?) -> Void)? = nil

    @State private var showingActionConfirmation = false
    @State private var selectedAction: EngineRegionAction?
    @State private var eventToShow: GameEvent?
    @State private var showingNoEventsAlert = false
    @State private var showingActionError = false
    @State private var actionErrorMessage = ""
    @State private var showingCardNotification = false
    @State private var receivedCardNames: [String] = []

    enum EngineRegionAction {
        case travel
        case rest
        case trade
        case strengthenAnchor
        case explore
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HeroPanel(vm: vm)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        regionHeader

                        if region.state != .stable {
                            riskInfoSection
                        }

                        Divider()

                        if let anchor = region.anchor {
                            anchorSection(anchor: anchor)
                            Divider()
                        }

                        actionsSection
                    }
                    .padding()
                }
            }
            .background(AppColors.backgroundSystem)
            .navigationTitle(region.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.uiClose.localized) {
                        onDismiss()
                    }
                }
            }
            .alert(actionConfirmationTitle, isPresented: $showingActionConfirmation) {
                Button(L10n.buttonConfirm.localized) {
                    if let action = selectedAction {
                        performAction(action)
                    }
                }
                Button(L10n.uiCancel.localized, role: .cancel) { }
            } message: {
                Text(actionConfirmationMessage)
            }
            .alert(L10n.nothingFound.localized, isPresented: $showingNoEventsAlert) {
                Button(L10n.buttonUnderstood.localized, role: .cancel) { }
            } message: {
                Text(L10n.noEventsInRegion.localized)
            }
            .alert(L10n.actionImpossible.localized, isPresented: $showingActionError) {
                Button(L10n.buttonUnderstood.localized, role: .cancel) { }
            } message: {
                Text(actionErrorMessage)
            }
            .sheet(item: $eventToShow) { event in
                EventView(
                    vm: vm,
                    event: event,
                    regionId: region.id,
                    onChoiceSelected: { choice in
                        handleEventChoice(choice, event: event)
                    },
                    onDismiss: {
                        eventToShow = nil
                        vm.engine.performAction(.dismissCurrentEvent)
                    }
                )
            }
            .onChange(of: vm.engine.currentEvent?.id) { _ in
                if let event = vm.engine.currentEvent {
                    eventToShow = event
                }
            }
            .overlay {
                if showingCardNotification && !receivedCardNames.isEmpty {
                    CardReceivedNotificationOverlay(
                        isPresented: $showingCardNotification,
                        cardNames: receivedCardNames
                    )
                }
            }
        }
    }

    var regionHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: region.type.icon)
                    .font(.largeTitle)
                    .foregroundColor(stateColor)

                VStack(alignment: .leading) {
                    Text(region.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.muted)

                    HStack {
                        Text(region.state.emoji)
                        Text(region.state.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(stateColor)
                    }
                }

                Spacer()

                if isPlayerHere {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "person.fill")
                        Text(L10n.youAreHere.localized)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.backgroundSystem)
                    .padding(.horizontal, Spacing.smd)
                    .padding(.vertical, Spacing.xs)
                    .background(AppColors.primary)
                    .cornerRadius(CornerRadius.lg)
                }
            }

            Text(regionDescription)
                .font(.body)
                .foregroundColor(AppColors.muted)
        }
    }

    var regionDescription: String {
        switch region.state {
        case .stable:
            return L10n.regionDescStable.localized
        case .borderland:
            return L10n.regionDescBorderland.localized
        case .breach:
            return L10n.regionDescBreach.localized
        }
    }

    var riskInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(region.state == .breach ? AppColors.danger : AppColors.warning)
                Text(L10n.warningTitle.localized)
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Text(L10n.warningHighDanger.localized)
                .font(.caption)
                .foregroundColor(AppColors.muted)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(region.state == .breach ? AppColors.danger.opacity(0.1) : AppColors.warning.opacity(0.1))
        )
    }

    func anchorSection(anchor: EngineAnchorState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(L10n.anchorOfYav.localized)
                .font(.headline)

            HStack(spacing: Spacing.md) {
                Image(systemName: "flame")
                    .font(.title)
                    .foregroundColor(AppColors.power)
                    .frame(width: Sizes.iconHero, height: Sizes.iconHero)
                    .background(Circle().fill(AppColors.power.opacity(Opacity.faint)))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(anchor.name)
                        .font(.subheadline)
                        .fontWeight(.bold)

                    HStack(spacing: Spacing.xxs) {
                        Text(L10n.anchorIntegrity.localized + ":")
                            .font(.caption2)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AppColors.secondary.opacity(Opacity.faint))
                                    .frame(height: Sizes.progressMedium)

                                Rectangle()
                                    .fill(anchorIntegrityColor(anchor.integrity))
                                    .frame(
                                        width: geometry.size.width * CGFloat(anchor.integrity) / 100,
                                        height: Sizes.progressMedium
                                    )
                            }
                        }
                        .frame(height: Sizes.progressMedium)

                        Text("\(anchor.integrity)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(anchorIntegrityColor(anchor.integrity))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.backgroundTertiary)
            )
        }
    }

    var isPlayerHere: Bool {
        region.id == vm.engine.currentRegionId
    }

    var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(L10n.availableActions.localized)
                .font(.headline)

            VStack(spacing: Spacing.sm) {
                if !isPlayerHere {
                    let canTravel = vm.engine.canTravelTo(regionId: region.id)
                    let routingHint = vm.engine.getRoutingHint(to: region.id)
                    let travelCost = vm.engine.calculateTravelCost(to: region.id)
                    let dayWord = travelCost == 1 ? L10n.dayWord1.localized : L10n.dayWord234.localized

                    actionButton(
                        title: canTravel ? L10n.actionTravelTo.localized(with: travelCost, dayWord) : L10n.actionRegionFar.localized,
                        icon: canTravel ? "arrow.right.circle.fill" : "xmark.circle",
                        color: canTravel ? AppColors.primary : AppColors.secondary,
                        enabled: canTravel
                    ) {
                        selectedAction = .travel
                        showingActionConfirmation = true
                    }

                    if canTravel {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(AppColors.muted)
                            Text(L10n.actionMoveToRegionHint.localized)
                                .font(.caption)
                                .foregroundColor(AppColors.muted)
                        }
                        .padding(.vertical, Spacing.sm)
                    } else {
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(AppColors.warning)
                            if !routingHint.isEmpty {
                                Text(L10n.goThroughFirst.localized(with: routingHint.joined(separator: ", ")))
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                            } else {
                                Text(L10n.actionRegionNotDirectlyAccessible.localized)
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                    }
                }

                if isPlayerHere {
                    actionButton(
                        title: L10n.actionRestHeal.localized(with: 3),
                        icon: "bed.double.fill",
                        color: AppColors.success,
                        enabled: region.canRest
                    ) {
                        selectedAction = .rest
                        showingActionConfirmation = true
                    }

                    actionButton(
                        title: L10n.actionTradeName.localized,
                        icon: "cart.fill",
                        color: AppColors.warning,
                        enabled: region.canTrade
                    ) {
                        selectedAction = .trade
                        showingActionConfirmation = true
                    }

                    if region.anchor != nil {
                        actionButton(
                            title: L10n.actionAnchorCost.localized(with: 5, 20),
                            icon: "hammer.fill",
                            color: AppColors.dark,
                            enabled: vm.engine.player.canAffordFaith(5)
                        ) {
                            selectedAction = .strengthenAnchor
                            showingActionConfirmation = true
                        }
                    }

                    let hasEvents = vm.engine.hasAvailableEventsInCurrentRegion()
                    actionButton(
                        title: L10n.actionExploreName.localized,
                        icon: "magnifyingglass",
                        color: AppColors.info,
                        enabled: hasEvents
                    ) {
                        selectedAction = .explore
                        showingActionConfirmation = true
                    }
                }
            }
        }
    }

    func actionButton(
        title: String,
        icon: String,
        color: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding()
            .foregroundColor(enabled ? .white : AppColors.muted)
            .background(enabled ? color : AppColors.cardBackground)
            .cornerRadius(CornerRadius.md)
        }
        .disabled(!enabled)
    }

    var stateColor: Color {
        switch region.state {
        case .stable: return AppColors.success
        case .borderland: return AppColors.warning
        case .breach: return AppColors.danger
        }
    }

    func anchorIntegrityColor(_ integrity: Int) -> Color {
        switch integrity {
        case 70...100: return AppColors.success
        case 30..<70: return AppColors.warning
        default: return AppColors.danger
        }
    }

    var actionConfirmationTitle: String {
        guard let action = selectedAction else { return L10n.confirmationTitle.localized }
        switch action {
        case .travel: return L10n.actionTravel.localized
        case .rest: return L10n.actionRest.localized
        case .trade: return L10n.actionTrade.localized
        case .strengthenAnchor: return L10n.actionStrengthenAnchor.localized
        case .explore: return L10n.actionExploreRegion.localized
        }
    }

    var actionConfirmationMessage: String {
        guard let action = selectedAction else { return "" }
        switch action {
        case .travel:
            let days = vm.engine.calculateTravelCost(to: region.id)
            let dayWord = days == 1 ? L10n.dayWord1.localized : L10n.dayWord234.localized
            return L10n.confirmTravel.localized(with: region.name, days, dayWord)
        case .rest:
            return L10n.confirmRest.localized(with: 3)
        case .trade:
            return L10n.confirmTrade.localized
        case .strengthenAnchor:
            return L10n.confirmStrengthenAnchor.localized(with: 5, 20)
        case .explore:
            return L10n.confirmExplore.localized
        }
    }

    func performAction(_ action: EngineRegionAction) {
        switch action {
        case .travel:
            let result = vm.engine.performAction(.travel(toRegionId: region.id))
            if result.success {
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalEntryTravel.localized,
                    choiceMade: L10n.journalEntryTravelChoice.localized,
                    outcome: L10n.journalEntryTravelOutcome.localized(with: region.name),
                    type: .travel
                )
                if let newRegion = vm.engine.regionsArray.first(where: { $0.id == vm.engine.currentRegionId }) {
                    onRegionChange?(newRegion)
                } else {
                    onDismiss()
                }
            } else {
                actionErrorMessage = errorMessage(for: result.error)
                showingActionError = true
            }

        case .rest:
            let result = vm.engine.performAction(.rest)
            if result.success {
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalRestTitle.localized,
                    choiceMade: L10n.journalRestChoice.localized,
                    outcome: L10n.journalRestOutcome.localized,
                    type: .exploration
                )
            }

        case .trade:
            break

        case .strengthenAnchor:
            let result = vm.engine.performAction(.strengthenAnchor)
            if result.success {
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalAnchorTitle.localized,
                    choiceMade: L10n.journalAnchorChoice.localized,
                    outcome: L10n.journalAnchorOutcome.localized,
                    type: .worldChange
                )
            }

        case .explore:
            let result = vm.engine.performAction(.explore)
            if result.success {
                if result.currentEvent == nil {
                    showingNoEventsAlert = true
                    vm.engine.addLogEntry(
                        regionName: region.name,
                        eventTitle: L10n.journalEntryExplore.localized,
                        choiceMade: L10n.journalEntryExploreChoice.localized,
                        outcome: L10n.journalEntryExploreNothing.localized,
                        type: .exploration
                    )
                }
            }
        }
    }

    func errorMessage(for error: ActionError?) -> String {
        guard let error = error else { return L10n.errorUnknown.localized }
        switch error {
        case .regionNotNeighbor:
            return L10n.errorRegionFar.localized
        case .regionNotAccessible:
            return L10n.errorRegionInaccessible.localized
        case .healthTooLow:
            return L10n.errorHealthLow.localized
        case .insufficientResources(let resource, let required, let available):
            return L10n.errorInsufficientResource.localized(with: resource, required, available)
        case .invalidAction:
            return error.localizedDescription
        case .combatInProgress:
            return L10n.errorInCombat.localized
        case .eventInProgress:
            return L10n.errorFinishEvent.localized
        default:
            return L10n.errorActionFailed.localized(with: "\(error)")
        }
    }

    func handleEventChoice(_ choice: EventChoice, event: GameEvent) {
        var cardsToNotify: [String] = []
        if let cardIDs = choice.consequences.addCards {
            for cardID in cardIDs {
                if let card = cardFactory.getCard(id: cardID) {
                    cardsToNotify.append(card.name)
                }
            }
        }

        if let choiceIndex = event.choices.firstIndex(where: { $0.id == choice.id }) {
            let result = vm.engine.performAction(.chooseEventOption(eventId: event.id, choiceIndex: choiceIndex))

            if result.success {
                let logType: EventLogType = event.eventType == .combat ? .combat : .exploration
                let outcomeMessage = choice.consequences.message ?? L10n.journalChoiceMade.localized
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: event.title,
                    choiceMade: choice.text,
                    outcome: outcomeMessage,
                    type: logType
                )
            }
        }

        eventToShow = nil
        vm.engine.performAction(.dismissCurrentEvent)

        if !cardsToNotify.isEmpty {
            receivedCardNames = cardsToNotify
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingCardNotification = true
                }
            }
        }
    }
}
