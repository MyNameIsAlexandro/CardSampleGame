import Foundation
import Combine

// MARK: - Event Log Entry

/// Запись в журнале событий
struct EventLogEntry: Identifiable, Codable {
    let id: UUID
    let dayNumber: Int
    let timestamp: Date
    let regionName: String
    let eventTitle: String
    let choiceMade: String
    let outcome: String
    let type: EventLogType

    init(
        id: UUID = UUID(),
        dayNumber: Int,
        timestamp: Date = Date(),
        regionName: String,
        eventTitle: String,
        choiceMade: String,
        outcome: String,
        type: EventLogType
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.timestamp = timestamp
        self.regionName = regionName
        self.eventTitle = eventTitle
        self.choiceMade = choiceMade
        self.outcome = outcome
        self.type = type
    }
}

/// Тип записи в журнале
enum EventLogType: String, Codable {
    case exploration    // Исследование
    case combat         // Бой
    case choice         // Выбор
    case quest          // Квест
    case travel         // Путешествие
    case worldChange    // Изменение мира

    var icon: String {
        switch self {
        case .exploration: return "magnifyingglass"
        case .combat: return "swords"
        case .choice: return "questionmark.circle"
        case .quest: return "scroll"
        case .travel: return "figure.walk"
        case .worldChange: return "globe"
        }
    }
}

/// Событие, произошедшее в конце дня (для уведомлений)
struct DayEvent: Identifiable {
    let id = UUID()
    let day: Int
    let title: String
    let description: String
    let isNegative: Bool

    static func tensionIncrease(day: Int, newTension: Int) -> DayEvent {
        DayEvent(
            day: day,
            title: L10n.dayEventTensionTitle.localized,
            description: L10n.dayEventTensionDescription.localized(with: newTension),
            isNegative: true
        )
    }

    static func regionDegraded(day: Int, regionName: String, newState: RegionState) -> DayEvent {
        DayEvent(
            day: day,
            title: L10n.dayEventRegionDegradedTitle.localized,
            description: L10n.dayEventRegionDegradedDescription.localized(with: regionName, newState.displayName),
            isNegative: true
        )
    }

    static func worldImproving(day: Int) -> DayEvent {
        DayEvent(
            day: day,
            title: L10n.dayEventWorldImprovingTitle.localized,
            description: L10n.dayEventWorldImprovingDescription.localized,
            isNegative: false
        )
    }
}

/// Глобальное состояние мира для системы исследования
class WorldState: ObservableObject, Codable {
    // MARK: - Published Properties

    @Published var regions: [Region] = []
    @Published var worldTension: Int = 30           // 0-100, сила вторжения Нави
    @Published var lightDarkBalance: Int = 50       // 0 (dark) - 100 (light)
    @Published var mainQuestStage: Int = 1          // 1-5 актов
    @Published var activeQuests: [Quest] = []
    @Published var completedQuests: [String] = []   // ID завершенных квестов
    @Published var worldFlags: [String: Bool] = [:] // Сюжетные флаги
    @Published var allEvents: [GameEvent] = []
    @Published var currentRegionId: UUID?           // Текущий регион игрока
    @Published var daysPassed: Int = 0              // Дни в пути
    @Published var eventLog: [EventLogEntry] = []   // Журнал событий
    @Published var lastDayEvent: DayEvent?          // Последнее событие дня (для уведомлений)

    // MARK: - Computed Properties

    var currentRegion: Region? {
        guard let id = currentRegionId else { return nil }
        return regions.first { $0.id == id }
    }

    var averageRegionState: RegionState {
        let stableCount = regions.filter { $0.state == .stable }.count
        let totalCount = regions.count
        let percentage = totalCount > 0 ? (Double(stableCount) / Double(totalCount)) * 100 : 0

        switch percentage {
        case 60...100:
            return .stable
        case 30..<60:
            return .borderland
        default:
            return .breach
        }
    }

    // MARK: - Initialization

    init() {
        setupInitialWorld()
    }

    // MARK: - World Setup

    private func setupInitialWorld() {
        // DATA-DRIVEN: Load all content from ContentRegistry (JSON files)
        // Reference: ENGINE_ARCHITECTURE.md, Section 5
        // ContentRegistry is loaded at app startup via CardGameApp.ContentLoader
        let registry = ContentRegistry.shared

        // Load regions from ContentRegistry (JSON)
        regions = createRegionsFromRegistry(registry)

        // Load events from ContentRegistry (using adapters)
        allEvents = registry.getAllEventDefinitions().map { $0.toGameEvent() }

        // Load quests from ContentRegistry (using adapters)
        let initialQuests = registry.getAllQuestDefinitions().map { $0.toQuest() }
        // Main quest starts automatically
        if let mainQuest = initialQuests.first(where: { $0.questType == .main }) {
            startQuest(mainQuest)
        }

        // Set initial world parameters
        worldTension = 30
        lightDarkBalance = 50
        mainQuestStage = 1
        daysPassed = 0

        // Set starting region by ID (village)
        // Canonical starting region is "village" per game design
        if let villageDef = registry.getRegion(id: "village"),
           let villageRegion = regions.first(where: { $0.name == villageDef.title.localized }) {
            currentRegionId = villageRegion.id
        } else if let firstStable = regions.first(where: { $0.state == .stable }) {
            // Fallback to any stable region if village not found
            currentRegionId = firstStable.id
        }
    }

    /// Convert RegionDefinitions from ContentRegistry to legacy Region models
    /// This bridges the Data-Driven architecture (JSON) with existing runtime models
    private func createRegionsFromRegistry(_ registry: ContentRegistry) -> [Region] {
        let regionDefs = registry.getAllRegionDefinitions()
        var regionMap: [String: Region] = [:]

        // First pass: create regions without neighbor links
        for def in regionDefs {
            let anchor = createAnchorFromDefinition(registry.getAnchorDefinition(forRegion: def.id))
            let regionType = RegionType(rawValue: def.regionType) ?? .forest
            let regionState = RegionState(from: def.initialState)

            var region = Region(
                definitionId: def.id,
                name: def.title.localized,
                type: regionType,
                state: regionState,
                anchor: anchor,
                reputation: 0
            )
            region.updateStateFromAnchor()
            regionMap[def.id] = region
        }

        // Second pass: link neighbors using UUIDs
        for def in regionDefs {
            guard var region = regionMap[def.id] else { continue }
            region.neighborIds = def.neighborIds.compactMap { regionMap[$0]?.id }
            regionMap[def.id] = region
        }

        // Sort by name for deterministic ordering (Dictionary values order is non-deterministic)
        return Array(regionMap.values).sorted { $0.name < $1.name }
    }

    /// Create legacy Anchor from AnchorDefinition
    private func createAnchorFromDefinition(_ def: AnchorDefinition?) -> Anchor? {
        guard let def = def else { return nil }

        let anchorType = AnchorType(fromJSON: def.anchorType) ?? .shrine
        let influence = CardBalance(from: def.initialInfluence)

        return Anchor(
            name: def.title.localized,
            type: anchorType,
            integrity: def.initialIntegrity,
            influence: influence,
            power: def.power
        )
    }

    // MARK: - Region Management

    func updateRegion(_ updatedRegion: Region) {
        if let index = regions.firstIndex(where: { $0.id == updatedRegion.id }) {
            regions[index] = updatedRegion
        }
    }

    func getRegion(byId id: UUID) -> Region? {
        return regions.first { $0.id == id }
    }

    /// Получить текущий регион игрока
    func getCurrentRegion() -> Region? {
        guard let currentId = currentRegionId else { return nil }
        return getRegion(byId: currentId)
    }

    /// - Warning: Internal method. UI code should use `TwilightGameEngine.performAction(.travel(toRegionId:))`.
    /// Called by Engine for state synchronization.
    func moveToRegion(_ regionId: UUID) {
        // Отметить текущий регион как посещенный
        if let currentId = currentRegionId,
           let index = regions.firstIndex(where: { $0.id == currentId }) {
            regions[index].visited = true
        }

        // Рассчитать стоимость путешествия
        let travelCost = calculateTravelCost(to: regionId)

        // Переместиться в новый регион
        currentRegionId = regionId

        // Отметить новый регион как посещенный
        if let index = regions.firstIndex(where: { $0.id == regionId }) {
            regions[index].visited = true
        }

        // Продвинуть время корректно - каждый день обрабатывается отдельно
        // Это критично: travel cost 2 должен обработать день 3, если мы были на дне 2
        advanceTimeInternal(by: travelCost)
    }

    /// Рассчитать стоимость путешествия в регион
    /// Соседний регион: 1 день, дальний: 2 дня
    func calculateTravelCost(to targetId: UUID) -> Int {
        guard let currentId = currentRegionId,
              let currentRegion = getRegion(byId: currentId) else {
            return 1  // По умолчанию 1 день
        }

        return currentRegion.isNeighbor(targetId) ? 1 : 2
    }

    // MARK: - Time-based Degradation (Day Start Algorithm)

    /// Канонический алгоритм начала дня (см. EXPLORATION_CORE_DESIGN.md, раздел 18.1)
    /// Вызывается при каждом увеличении daysPassed
    ///
    /// ## DEPRECATED
    /// - **UI Code**: Use `TwilightGameEngine.performAction()` instead
    /// Process day start effects (tension increase, degradation checks).
    /// Called by Engine and internally by advanceTime methods.
    func processDayStart() {
        performDayStartLogic()
    }

    /// Advance day and process day start logic.
    /// - Note: Increments `daysPassed` by 1 and processes day start logic (tension, degradation, etc.)
    func advanceDayForUI() {
        daysPassed += 1
        performDayStartLogic()
    }

    /// Internal day start logic - shared by processDayStart() and advanceDayForUI()
    /// Uses TwilightPressureRules as single source of truth
    private func performDayStartLogic() {
        // 1. Каждые 3 дня — автоматическая деградация мира
        guard daysPassed > 0 && daysPassed % 3 == 0 else { return }

        // 2. Увеличить напряжение мира с ЭСКАЛАЦИЕЙ
        // Формула из TwilightPressureRules: base + (daysPassed / 10)
        // День 1-9: +3, День 10-19: +4, День 20-29: +5, ...
        let totalIncrement = TwilightPressureRules.calculateTensionIncrease(daysPassed: daysPassed)
        increaseTension(by: totalIncrement)

        // Уведомить о росте напряжения
        lastDayEvent = .tensionIncrease(day: daysPassed, newTension: worldTension)
        logWorldChange(description: L10n.logTensionIncreased.localized(with: worldTension, totalIncrement))

        // 3. Проверить деградацию региона с вероятностью (Tension/100)
        // Используем WorldRNG для детерминизма при тестировании
        let probability = Double(worldTension) / 100.0
        if WorldRNG.shared.checkProbability(probability) {
            checkRegionDegradation()
        }

        // 4. Проверить улучшение мира при низком напряжении
        if worldTension <= 20 {
            improveRandomRegion()
        }

        // 5. Проверить триггеры квестов
        checkQuestTriggers()

        // 6. Проверить глобальные триггеры мира
        checkWorldShiftTriggers()
    }

    /// Проверка деградации региона по весовому алгоритму
    /// (см. EXPLORATION_CORE_DESIGN.md, раздел 18.2)
    /// Использует DegradationRules для определения поведения
    private func checkRegionDegradation() {
        let rules = DegradationRules.current

        // 1. Выбрать случайный регион с весами из правил
        guard let selectedRegion = selectRegionForDegradation() else { return }

        // 2. Проверить сопротивление якоря (вероятностное, не пороговое)
        // P(resist) = integrity/100: чем сильнее якорь, тем выше шанс сопротивляться
        if let anchor = selectedRegion.anchor {
            let resistProb = rules.resistanceProbability(anchorIntegrity: anchor.integrity)
            if WorldRNG.shared.checkProbability(resistProb) {
                // Якорь сопротивляется — деградация не происходит
                logWorldChange(description: L10n.logAnchorResists.localized(with: selectedRegion.name, anchor.integrity))
                return
            }
        }

        // 3. Применить деградацию и уведомить
        let oldState = selectedRegion.state
        degradeRegion(selectedRegion.id, amount: rules.degradationAmount)

        // Получить новое состояние после деградации
        if let updatedRegion = getRegion(byId: selectedRegion.id), updatedRegion.state != oldState {
            lastDayEvent = .regionDegraded(day: daysPassed, regionName: updatedRegion.name, newState: updatedRegion.state)
            logWorldChange(description: L10n.logRegionDegraded.localized(with: updatedRegion.name, updatedRegion.state.displayName))
        }
    }

    /// Выбор региона для деградации с учётом весов из DegradationRules
    /// Веса определяются правилами: Stable = 0, Borderland = 1, Breach = 2
    private func selectRegionForDegradation() -> Region? {
        let rules = DegradationRules.current

        // Формируем пул регионов с весами из правил
        var weightedPool: [(region: Region, weight: Int)] = []

        for region in regions {
            let weight = rules.selectionWeight(for: region.state)
            if weight > 0 {
                weightedPool.append((region, weight))
            }
        }

        // Если нет подходящих регионов (все Stable), деградация не происходит
        // ВАЖНО: Stable регионы НЕ деградируют напрямую согласно документации
        if weightedPool.isEmpty {
            return nil
        }

        // Взвешенный случайный выбор (используем WorldRNG для детерминизма)
        let totalWeight = weightedPool.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        var randomValue = WorldRNG.shared.nextInt(in: 0..<totalWeight)
        for (region, weight) in weightedPool {
            randomValue -= weight
            if randomValue < 0 {
                return region
            }
        }

        return weightedPool.first?.region
    }

    /// Применить деградацию к конкретному региону
    /// - Parameters:
    ///   - regionId: ID региона для деградации
    ///   - amount: Урон якорю (по умолчанию из DegradationRules.current)
    private func degradeRegion(_ regionId: UUID, amount: Int? = nil) {
        guard var region = getRegion(byId: regionId) else { return }

        let degradationAmount = amount ?? DegradationRules.current.degradationAmount

        if var anchor = region.anchor {
            // Уменьшить integrity якоря на указанное значение
            anchor.integrity = max(0, anchor.integrity - degradationAmount)
            region.anchor = anchor
            region.updateStateFromAnchor()
            updateRegion(region)
        }
    }

    /// Проверка триггеров квестов (вызывается каждые 3 дня)
    private func checkQuestTriggers() {
        // Проверить условия продвижения для каждого активного квеста
        for quest in activeQuests {
            checkQuestProgress(quest)
        }
    }

    /// Проверка глобальных триггеров мира (World Shift Events)
    private func checkWorldShiftTriggers() {
        // При пороговых значениях Tension могут срабатывать глобальные события
        if worldTension >= 50 && !hasFlag("world_shift_50") {
            setFlag("world_shift_50", value: true)
            // Можно триггерить World Shift Event здесь
        }
        if worldTension >= 75 && !hasFlag("world_shift_75") {
            setFlag("world_shift_75", value: true)
        }
        if worldTension >= 90 && !hasFlag("world_shift_90") {
            setFlag("world_shift_90", value: true)
        }
    }

    /// Метод для ручного продвижения времени (для Rest, StrengthenAnchor и т.д.)
    ///
    /// ## DEPRECATED
    /// - **UI Code**: Use `TwilightGameEngine.performAction()` instead
    /// Advance time by specified number of days.
    /// Each day processes day start logic (tension, degradation, etc.)
    func advanceTime(by days: Int = 1) {
        advanceTimeInternal(by: days)
    }

    /// Internal time advancement - used by moveToRegion and other internal methods
    private func advanceTimeInternal(by days: Int) {
        for _ in 0..<days {
            daysPassed += 1
            performDayStartLogic()
        }
    }

    // MARK: - Anchor Management

    func strengthenAnchor(in regionId: UUID, amount: Int = 20) -> Bool {
        guard var region = getRegion(byId: regionId),
              var anchor = region.anchor else {
            return false
        }

        anchor.integrity = min(100, anchor.integrity + amount)
        region.anchor = anchor
        region.updateStateFromAnchor()
        updateRegion(region)

        return true
    }

    func defileAnchor(in regionId: UUID, amount: Int = 30) -> Bool {
        guard var region = getRegion(byId: regionId),
              var anchor = region.anchor else {
            return false
        }

        anchor.integrity = max(0, anchor.integrity - amount)
        anchor.influence = .dark
        region.anchor = anchor
        region.updateStateFromAnchor()
        updateRegion(region)

        // Увеличиваем напряжение мира
        increaseTension(by: 10)

        return true
    }

    func purifyAnchor(in regionId: UUID) -> Bool {
        guard var region = getRegion(byId: regionId),
              var anchor = region.anchor else {
            return false
        }

        anchor.influence = .light
        anchor.integrity = min(100, anchor.integrity + 50)
        region.anchor = anchor
        region.updateStateFromAnchor()
        updateRegion(region)

        // Уменьшаем напряжение мира
        decreaseTension(by: 15)

        return true
    }

    // MARK: - World Tension Management

    func increaseTension(by amount: Int) {
        worldTension = min(100, worldTension + amount)
        checkTensionEffects()
    }

    func decreaseTension(by amount: Int) {
        worldTension = max(0, worldTension - amount)
        checkTensionEffects()
    }

    private func checkTensionEffects() {
        // При высоком напряжении (≥80) — немедленная деградация через весовой алгоритм
        if worldTension >= 80 {
            checkRegionDegradation()
        }

        // При низком напряжении (≤20) — мир начинает восстанавливаться
        if worldTension <= 20 {
            improveRandomRegion()
        }
    }

    /// Улучшение случайного региона (при низком Tension)
    private func improveRandomRegion() {
        // Предпочитаем улучшать Breach регионы
        let breachRegions = regions.filter { $0.state == .breach }
        let borderlandRegions = regions.filter { $0.state == .borderland }

        let targetRegion: Region?
        if !breachRegions.isEmpty {
            targetRegion = WorldRNG.shared.randomElement(from: breachRegions)
        } else if !borderlandRegions.isEmpty {
            targetRegion = WorldRNG.shared.randomElement(from: borderlandRegions)
        } else {
            targetRegion = nil
        }

        guard let region = targetRegion,
              let index = regions.firstIndex(where: { $0.id == region.id }) else {
            return
        }

        var updatedRegion = regions[index]
        if var anchor = updatedRegion.anchor {
            anchor.integrity = min(100, anchor.integrity + 15)
            updatedRegion.anchor = anchor
            updatedRegion.updateStateFromAnchor()
            updateRegion(updatedRegion)
        }
    }

    // MARK: - Campaign Market System
    // See EXPLORATION_CORE_DESIGN.md, section 24

    /// Generate market cards based on current region and world state
    /// Market is formed from 3 pools: Global, Regional, Story
    func generateMarket(allCards: [Card], globalPoolSize: Int = 3, regionalPoolSize: Int = 2) -> [Card] {
        var market: [Card] = []

        // 1. Global pool (always available Sustain/Utility cards)
        let globalCards = allCards.filter { card in
            guard let role = card.role else { return false }
            return role == .sustain || role == .utility
        }
        let shuffledGlobal = WorldRNG.shared.shuffled(globalCards)
        market.append(contentsOf: shuffledGlobal.prefix(globalPoolSize))

        // 2. Regional pool (based on current region state)
        if let region = currentRegion {
            let regionalCards = getRegionalCards(allCards: allCards, regionState: region.state)
            let shuffledRegional = WorldRNG.shared.shuffled(regionalCards)
            market.append(contentsOf: shuffledRegional.prefix(regionalPoolSize))
        }

        // 3. Story pool (cards unlocked by flags)
        if let storyCard = getStoryCard(allCards: allCards) {
            market.append(storyCard)
        }

        return market
    }

    /// Get cards appropriate for the region state
    private func getRegionalCards(allCards: [Card], regionState: RegionState) -> [Card] {
        switch regionState {
        case .stable:
            // Stable regions offer Sustain and Control cards
            return allCards.filter { card in
                guard let role = card.role else { return false }
                return role == .sustain || role == .control
            }

        case .borderland:
            // Borderland offers Utility and Power cards
            return allCards.filter { card in
                guard let role = card.role else { return false }
                return role == .utility || role == .power
            }

        case .breach:
            // Breach offers Power cards (risky but rewarding)
            return allCards.filter { card in
                guard let role = card.role else { return false }
                return role == .power
            }
        }
    }

    /// Get a story card if player has the required flag
    private func getStoryCard(allCards: [Card]) -> Card? {
        // Find cards that require specific flags
        let storyCards = allCards.filter { card in
            guard let requirement = card.regionRequirement else { return false }
            return hasFlag(requirement)
        }
        return WorldRNG.shared.randomElement(from: storyCards)
    }

    /// Calculate adjusted card cost based on Light/Dark balance
    func adjustedCardCost(_ card: Card) -> Int {
        return card.adjustedFaithCost(playerBalance: lightDarkBalance)
    }

    // MARK: - Balance Management

    func shiftToLight(by amount: Int) {
        lightDarkBalance = min(100, lightDarkBalance + amount)
    }

    func shiftToDark(by amount: Int) {
        lightDarkBalance = max(0, lightDarkBalance - amount)
    }

    var balanceDescription: String {
        switch lightDarkBalance {
        case 0..<30:
            return L10n.balancePathDark.localized
        case 30..<70:
            return L10n.balancePathNeutral.localized
        case 70...100:
            return L10n.balancePathLight.localized
        default:
            return L10n.balancePathUnknown.localized
        }
    }

    // MARK: - Event Management

    func getAvailableEvents(for region: Region) -> [GameEvent] {
        return allEvents.filter { event in
            event.canOccur(in: region, worldTension: worldTension, worldFlags: worldFlags)
        }
    }

    /// Взвешенный случайный выбор события
    /// События с большим весом имеют пропорционально большую вероятность быть выбранными
    func selectWeightedRandomEvent(from events: [GameEvent]) -> GameEvent? {
        guard !events.isEmpty else { return nil }

        let totalWeight = events.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            // Используем WorldRNG для randomElement
            let index = WorldRNG.shared.nextInt(in: 0..<events.count)
            return events[index]
        }

        // Используем WorldRNG для детерминизма
        let randomValue = WorldRNG.shared.nextInt(in: 1...totalWeight)
        var cumulativeWeight = 0

        for event in events {
            cumulativeWeight += event.weight
            if randomValue <= cumulativeWeight {
                return event
            }
        }

        return events.last
    }

    func markEventCompleted(_ eventId: UUID) {
        if let index = allEvents.firstIndex(where: { $0.id == eventId }) {
            allEvents[index].completed = true
        }
    }

    // MARK: - Event Log Management

    /// Добавить запись в журнал событий
    func logEvent(
        regionName: String,
        eventTitle: String,
        choiceMade: String,
        outcome: String,
        type: EventLogType
    ) {
        let entry = EventLogEntry(
            dayNumber: daysPassed,
            regionName: regionName,
            eventTitle: eventTitle,
            choiceMade: choiceMade,
            outcome: outcome,
            type: type
        )
        eventLog.append(entry)

        // Ограничиваем журнал последними 100 записями
        if eventLog.count > 100 {
            eventLog.removeFirst(eventLog.count - 100)
        }
    }

    /// Добавить запись о путешествии
    func logTravel(from: String, to: String, days: Int) {
        let outcomeKey = days == 1 ? L10n.logTravelOutcomeDay : L10n.logTravelOutcomeDays
        logEvent(
            regionName: to,
            eventTitle: L10n.logTravelTitle.localized,
            choiceMade: L10n.logTravelChoice.localized(with: to),
            outcome: outcomeKey.localized(with: days),
            type: .travel
        )
    }

    /// Добавить запись об изменении мира
    func logWorldChange(description: String) {
        let regionName = getCurrentRegion()?.name ?? L10n.logWorld.localized
        logEvent(
            regionName: regionName,
            eventTitle: L10n.logWorldChange.localized,
            choiceMade: "-",
            outcome: description,
            type: .worldChange
        )
    }

    /// Получить последние записи журнала
    func getRecentLogEntries(count: Int = 10) -> [EventLogEntry] {
        return Array(eventLog.suffix(count))
    }

    // MARK: - Quest Management

    func startQuest(_ quest: Quest) {
        var newQuest = quest
        newQuest.stage = 1
        activeQuests.append(newQuest)
    }

    func updateQuest(_ updatedQuest: Quest) {
        if let index = activeQuests.firstIndex(where: { $0.id == updatedQuest.id }) {
            activeQuests[index] = updatedQuest

            // Если квест завершен, переместить в завершенные
            if updatedQuest.completed {
                completedQuests.append(updatedQuest.id.uuidString)
                activeQuests.remove(at: index)
            }
        }
    }

    /// Проверка прогресса квеста по флагам (вызывается из processDayStart)
    func checkQuestProgress(_ quest: Quest) {
        // Проверить, выполнены ли условия для текущих целей квеста
        for (index, objective) in quest.objectives.enumerated() {
            if objective.completed { continue }

            // Проверить флаги, связанные с целью
            if let requiredFlags = objective.requiredFlags {
                let allFlagsSet = requiredFlags.allSatisfy { hasFlag($0) }
                if allFlagsSet {
                    var updatedQuest = quest
                    updatedQuest.objectives[index].completed = true
                    updateQuest(updatedQuest)
                }
            }
        }
    }

    // MARK: - Flag Management

    /// Проверить, установлен ли флаг
    func hasFlag(_ key: String) -> Bool {
        return worldFlags[key] == true
    }

    /// Установить значение флага
    func setFlag(_ key: String, value: Bool) {
        worldFlags[key] = value
    }

    /// Получить значение флага (nil если не установлен)
    func getFlag(_ key: String) -> Bool? {
        return worldFlags[key]
    }

    /// Переключить флаг
    func toggleFlag(_ key: String) {
        worldFlags[key] = !(worldFlags[key] ?? false)
    }

    // MARK: - Apply Event Consequences

    func applyConsequences(_ consequences: EventConsequences, to player: Player, in regionId: UUID) {
        // Изменение веры
        if let faithChange = consequences.faithChange {
            if faithChange > 0 {
                player.gainFaith(faithChange)
            } else {
                _ = player.spendFaith(abs(faithChange))
            }
        }

        // Изменение здоровья
        if let healthChange = consequences.healthChange {
            if healthChange > 0 {
                player.heal(healthChange)
            } else {
                player.takeDamage(abs(healthChange))
            }
        }

        // Изменение баланса
        if let balanceChange = consequences.balanceChange {
            if balanceChange > 0 {
                shiftToLight(by: abs(balanceChange))
            } else {
                shiftToDark(by: abs(balanceChange))
            }
        }

        // Изменение напряжения мира
        if let tensionChange = consequences.tensionChange {
            if tensionChange > 0 {
                increaseTension(by: tensionChange)
            } else {
                decreaseTension(by: abs(tensionChange))
            }
        }

        // Изменение репутации
        if let reputationChange = consequences.reputationChange,
           let index = regions.firstIndex(where: { $0.id == regionId }) {
            regions[index].reputation += reputationChange
            regions[index].reputation = max(-100, min(100, regions[index].reputation))
        }

        // Изменение целостности якоря
        if let anchorChange = consequences.anchorIntegrityChange {
            if var region = getRegion(byId: regionId),
               var anchor = region.anchor {
                anchor.integrity = max(0, min(100, anchor.integrity + anchorChange))
                region.anchor = anchor
                region.updateStateFromAnchor()
                updateRegion(region)
            }
        }

        // Установка флагов (ключевая механика — события не меняют мир напрямую, а через флаги)
        // См. EXPLORATION_CORE_DESIGN.md, раздел 18.7
        // Quest progress now handled by QuestTriggerEngine via flagSet action
        if let flags = consequences.setFlags {
            for (key, value) in flags {
                setFlag(key, value: value)
            }
        }

        // Добавление карт в колоду игрока
        if let cardIDs = consequences.addCards {
            for cardID in cardIDs {
                if let card = CardFactory.shared.getCard(id: cardID) {
                    // Add card to player's discard pile (standard deck-building mechanic)
                    player.discard.append(card)
                }
            }
        }

        // Проверка триггеров изменения состояния региона
        if consequences.anchorIntegrityChange != nil {
            // Якорь изменён — это может повлиять на глобальное состояние
            checkWorldShiftTriggers()
        }

        // TODO: Добавление проклятий и артефактов
        // if let curseID = consequences.addCurse { ... }
        // if let artifactID = consequences.giveArtifact { ... }
    }

    // MARK: - Quest Management

    /// Complete a quest and give rewards to the player
    func completeQuest(_ questId: UUID, player: Player) {
        guard let index = activeQuests.firstIndex(where: { $0.id == questId }) else { return }

        var quest = activeQuests[index]
        quest.completed = true

        // Move quest from active to completed
        completedQuests.append(quest.id.uuidString)
        activeQuests.remove(at: index)

        // Give rewards
        applyQuestRewards(quest.rewards, to: player)
    }

    /// Apply quest rewards to the player
    func applyQuestRewards(_ rewards: QuestRewards, to player: Player) {
        // Faith reward
        if let faith = rewards.faith {
            player.gainFaith(faith)
        }

        // Card rewards
        if let cardIDs = rewards.cards {
            for cardID in cardIDs {
                if let card = CardFactory.shared.getCard(id: cardID) {
                    // Add card to player's discard pile
                    player.discard.append(card)
                }
            }
        }

        // TODO: Artifact rewards
        // if let artifactID = rewards.artifact { ... }

        // TODO: Experience rewards
        // if let experience = rewards.experience { ... }
    }

    /// Mark boss as defeated after combat victory
    /// Uses enemy definitionId for data-driven matching
    /// - Note: Quest progress is now handled by QuestTriggerEngine via flag triggers
    func markBossDefeated(enemyId: String) {
        if enemyId == "leshy_guardian" {
            worldFlags["leshy_guardian_defeated"] = true
            // Quest progress handled by QuestTriggerEngine when it processes flagSet action
        }
    }


    // MARK: - Narrative System (Endings & Deck Path)
    // See EXPLORATION_CORE_DESIGN.md, sections 28-34

    /// Calculate player's dominant deck path based on card balance alignment
    ///
    /// Edge case: Если в колоде нет карт со смещением (все neutral или колода пуста),
    /// путь считается нейтральным (.balance). Это корректное поведение —
    /// игрок, не делавший выбора между Светом и Тьмой, идёт путём Равновесия.
    func calculateDeckPath(playerDeck: [Card]) -> DeckPath {
        guard !playerDeck.isEmpty else { return .balance }

        var lightCount = 0
        var darkCount = 0
        var neutralCount = 0

        for card in playerDeck {
            switch card.balance {
            case .light:
                lightCount += 1
            case .dark:
                darkCount += 1
            case .neutral, .none:
                neutralCount += 1
            }
        }

        let total = playerDeck.count
        let lightRatio = Double(lightCount) / Double(total)
        let darkRatio = Double(darkCount) / Double(total)

        // Need >50% of one type to be considered on that path
        // Если нет явного большинства — путь Равновесия
        if lightRatio > 0.5 {
            return .light
        } else if darkRatio > 0.5 {
            return .dark
        } else {
            return .balance
        }
    }

    /// Determine the ending based on world state and player choices
    /// See EXPLORATION_CORE_DESIGN.md, section 32 for ending matrix
    func determineEnding(playerDeck: [Card], allEndings: [EndingProfile]) -> EndingProfile? {
        let deckPath = calculateDeckPath(playerDeck: playerDeck)

        // Calculate anchor states summary
        let stableAnchors = regions.filter { $0.state == .stable }.count
        let breachAnchors = regions.filter { $0.state == .breach }.count

        // Check each ending's conditions
        for ending in allEndings {
            let conditions = ending.conditions

            // Check WorldTension range
            if let minTension = conditions.minTension, worldTension < minTension {
                continue
            }
            if let maxTension = conditions.maxTension, worldTension > maxTension {
                continue
            }

            // Check required flags
            if let requiredFlags = conditions.requiredFlags {
                let hasAllFlags = requiredFlags.allSatisfy { hasFlag($0) }
                if !hasAllFlags {
                    continue
                }
            }

            // Check forbidden flags
            if let forbiddenFlags = conditions.forbiddenFlags {
                let hasAnyForbidden = forbiddenFlags.contains { hasFlag($0) }
                if hasAnyForbidden {
                    continue
                }
            }

            // Check deck path requirement
            if let requiredPath = conditions.deckPath, deckPath != requiredPath {
                continue
            }

            // Check anchor state requirements
            if let minStable = conditions.minStableAnchors, stableAnchors < minStable {
                continue
            }
            if let maxBreach = conditions.maxBreachAnchors, breachAnchors > maxBreach {
                continue
            }

            // Check balance range
            if let minBalance = conditions.minBalance, lightDarkBalance < minBalance {
                continue
            }
            if let maxBalance = conditions.maxBalance, lightDarkBalance > maxBalance {
                continue
            }

            // All conditions met - return this ending
            return ending
        }

        // Fallback: return first ending or nil
        return allEndings.first
    }

    /// Get summary of current state for ending evaluation
    func getEndingStateDescription(playerDeck: [Card]) -> String {
        let deckPath = calculateDeckPath(playerDeck: playerDeck)
        let stableCount = regions.filter { $0.state == .stable }.count
        let breachCount = regions.filter { $0.state == .breach }.count

        // Internal debug format - uses English keys for consistency
        return """
        Tension: \(worldTension)/100
        Balance: \(balanceDescription) (\(lightDarkBalance))
        Deck Path: \(deckPath.rawValue)
        Anchors: \(stableCount) stable, \(breachCount) breach
        Active Flags: \(worldFlags.filter { $0.value }.count)
        """
    }

    /// Check if a main quest step can be unlocked
    func canUnlockQuestStep(_ step: MainQuestStep) -> Bool {
        let conditions = step.unlockConditions

        // Check required flags
        if let requiredFlags = conditions.requiredFlags {
            let hasAllFlags = requiredFlags.allSatisfy { hasFlag($0) }
            if !hasAllFlags { return false }
        }

        // Check forbidden flags
        if let forbiddenFlags = conditions.forbiddenFlags {
            let hasAnyForbidden = forbiddenFlags.contains { hasFlag($0) }
            if hasAnyForbidden { return false }
        }

        // Check tension requirements
        if let minTension = conditions.minTension, worldTension < minTension {
            return false
        }
        if let maxTension = conditions.maxTension, worldTension > maxTension {
            return false
        }

        // Check balance requirements
        if let minBalance = conditions.minBalance, lightDarkBalance < minBalance {
            return false
        }
        if let maxBalance = conditions.maxBalance, lightDarkBalance > maxBalance {
            return false
        }

        return true
    }

    /// Check if a main quest step is completed
    func isQuestStepCompleted(_ step: MainQuestStep) -> Bool {
        let conditions = step.completionConditions

        // Check required flags
        if let requiredFlags = conditions.requiredFlags {
            let hasAllFlags = requiredFlags.allSatisfy { hasFlag($0) }
            if !hasAllFlags { return false }
        }

        // Check forbidden flags (things that must NOT have happened)
        if let forbiddenFlags = conditions.forbiddenFlags {
            let hasAnyForbidden = forbiddenFlags.contains { hasFlag($0) }
            if hasAnyForbidden { return false }
        }

        return true
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case regions
        case worldTension
        case lightDarkBalance
        case mainQuestStage
        case activeQuests
        case completedQuests
        case worldFlags
        case allEvents
        case currentRegionId
        case daysPassed
        case eventLog
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        regions = try container.decode([Region].self, forKey: .regions)
        worldTension = try container.decode(Int.self, forKey: .worldTension)
        lightDarkBalance = try container.decode(Int.self, forKey: .lightDarkBalance)
        mainQuestStage = try container.decode(Int.self, forKey: .mainQuestStage)
        activeQuests = try container.decode([Quest].self, forKey: .activeQuests)
        completedQuests = try container.decode([String].self, forKey: .completedQuests)
        worldFlags = try container.decode([String: Bool].self, forKey: .worldFlags)
        allEvents = try container.decode([GameEvent].self, forKey: .allEvents)
        currentRegionId = try container.decodeIfPresent(UUID.self, forKey: .currentRegionId)
        daysPassed = try container.decode(Int.self, forKey: .daysPassed)
        eventLog = try container.decodeIfPresent([EventLogEntry].self, forKey: .eventLog) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(regions, forKey: .regions)
        try container.encode(worldTension, forKey: .worldTension)
        try container.encode(lightDarkBalance, forKey: .lightDarkBalance)
        try container.encode(mainQuestStage, forKey: .mainQuestStage)
        try container.encode(activeQuests, forKey: .activeQuests)
        try container.encode(completedQuests, forKey: .completedQuests)
        try container.encode(worldFlags, forKey: .worldFlags)
        try container.encode(allEvents, forKey: .allEvents)
        try container.encodeIfPresent(currentRegionId, forKey: .currentRegionId)
        try container.encode(daysPassed, forKey: .daysPassed)
        try container.encode(eventLog, forKey: .eventLog)
    }
}
