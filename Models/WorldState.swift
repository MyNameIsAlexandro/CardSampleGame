import Foundation
import Combine

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
        // Создаем начальные регионы (MVP: 3 региона)
        regions = createInitialRegions()

        // Создаем начальные события
        allEvents = createInitialEvents()

        // Создаем начальные квесты (Act I)
        let initialQuests = createInitialQuests()
        // Main quest starts automatically
        if let mainQuest = initialQuests.first(where: { $0.questType == .main }) {
            startQuest(mainQuest)
        }

        // Устанавливаем начальные параметры
        worldTension = 30
        lightDarkBalance = 50
        mainQuestStage = 1
        daysPassed = 0

        // Стартовый регион - первый стабильный регион
        if let firstStable = regions.first(where: { $0.state == .stable }) {
            currentRegionId = firstStable.id
        }
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

    func moveToRegion(_ regionId: UUID) {
        // Отметить текущий регион как посещенный
        if let currentId = currentRegionId,
           let index = regions.firstIndex(where: { $0.id == currentId }) {
            regions[index].visited = true
        }

        // Переместиться в новый регион
        currentRegionId = regionId
        daysPassed += 1

        // Отметить новый регион как посещенный
        if let index = regions.firstIndex(where: { $0.id == regionId }) {
            regions[index].visited = true
        }

        // Проверить автоматическую деградацию мира
        checkTimeDegradation()
    }

    // MARK: - Time-based Degradation (Day Start Algorithm)

    /// Канонический алгоритм начала дня (см. EXPLORATION_CORE_DESIGN.md, раздел 18.1)
    /// Вызывается при каждом увеличении daysPassed
    func processDayStart() {
        // 1. Каждые 3 дня — автоматическая деградация мира
        guard daysPassed > 0 && daysPassed % 3 == 0 else { return }

        // 2. Увеличить напряжение мира (+2 каждые 3 дня)
        increaseTension(by: 2)

        // 3. Проверить деградацию региона с вероятностью (Tension/100)
        let probability = Double(worldTension) / 100.0
        if Double.random(in: 0...1) < probability {
            checkRegionDegradation()
        }

        // 4. Проверить триггеры квестов
        checkQuestTriggers()

        // 5. Проверить глобальные триггеры мира
        checkWorldShiftTriggers()
    }

    /// Проверка автоматической деградации мира (legacy alias)
    func checkTimeDegradation() {
        processDayStart()
    }

    /// Проверка деградации региона по весовому алгоритму
    /// (см. EXPLORATION_CORE_DESIGN.md, раздел 18.2)
    private func checkRegionDegradation() {
        // 1. Выбрать случайный регион с весами (Borderland:1, Breach:2, Stable:0)
        guard let selectedRegion = selectRegionForDegradation() else { return }

        // 2. Проверить сопротивление якоря
        if let anchor = selectedRegion.anchor, anchor.integrity > 50 {
            // Якорь сопротивляется — деградация не происходит
            // Можно добавить лог или UI-уведомление
            return
        }

        // 3. Применить деградацию
        degradeRegion(selectedRegion.id)
    }

    /// Выбор региона для деградации с учётом весов
    /// Веса: Stable = 0 (не деградирует), Borderland = 1, Breach = 2
    private func selectRegionForDegradation() -> Region? {
        // Формируем пул регионов с весами
        var weightedPool: [(region: Region, weight: Int)] = []

        for region in regions {
            let weight: Int
            switch region.state {
            case .stable:
                weight = 0  // Stable регионы не деградируют напрямую
            case .borderland:
                weight = 1  // Borderland имеет вес 1
            case .breach:
                weight = 2  // Breach имеет вес 2 (более вероятен)
            }

            if weight > 0 {
                weightedPool.append((region, weight))
            }
        }

        // Если нет подходящих регионов, деградируем случайный stable
        if weightedPool.isEmpty {
            return regions.filter { $0.state == .stable }.randomElement()
        }

        // Взвешенный случайный выбор
        let totalWeight = weightedPool.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        var randomValue = Int.random(in: 0..<totalWeight)
        for (region, weight) in weightedPool {
            randomValue -= weight
            if randomValue < 0 {
                return region
            }
        }

        return weightedPool.first?.region
    }

    /// Применить деградацию к конкретному региону
    private func degradeRegion(_ regionId: UUID) {
        guard var region = getRegion(byId: regionId) else { return }

        if var anchor = region.anchor {
            // Уменьшить integrity якоря на 20
            anchor.integrity = max(0, anchor.integrity - 20)
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
    func advanceTime(by days: Int = 1) {
        for _ in 0..<days {
            daysPassed += 1
            processDayStart()
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
            targetRegion = breachRegions.randomElement()
        } else if !borderlandRegions.isEmpty {
            targetRegion = borderlandRegions.randomElement()
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
        let shuffledGlobal = globalCards.shuffled()
        market.append(contentsOf: shuffledGlobal.prefix(globalPoolSize))

        // 2. Regional pool (based on current region state)
        if let region = currentRegion {
            let regionalCards = getRegionalCards(allCards: allCards, regionState: region.state)
            let shuffledRegional = regionalCards.shuffled()
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
        return storyCards.randomElement()
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
            return "Путь Тьмы"
        case 30..<70:
            return "Нейтральный"
        case 70...100:
            return "Путь Света"
        default:
            return "Неизвестно"
        }
    }

    // MARK: - Event Management

    func getAvailableEvents(for region: Region) -> [GameEvent] {
        return allEvents.filter { event in
            event.canOccur(in: region)
        }
    }

    func markEventCompleted(_ eventId: UUID) {
        if let index = allEvents.firstIndex(where: { $0.id == eventId }) {
            allEvents[index].completed = true
        }
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
        var flagsChanged = false
        if let flags = consequences.setFlags {
            for (key, value) in flags {
                setFlag(key, value: value)
                flagsChanged = true
            }
        }

        // Если флаги изменились — проверить прогресс квестов
        if flagsChanged {
            checkQuestObjectivesByFlags(player)
        }

        // Добавление карт в колоду игрока
        if let cardIDs = consequences.addCards {
            for cardID in cardIDs {
                if let card = TwilightMarchesCards.getCardByID(cardID) {
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
                if let card = TwilightMarchesCards.getCardByID(cardID) {
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

    // MARK: - Quest Trigger System

    /// Check and update quest objectives based on world flags
    func checkQuestObjectivesByFlags(_ player: Player) {
        for i in 0..<activeQuests.count {
            var quest = activeQuests[i]
            var questUpdated = false

            // Main Quest - Objective 0: Learn about anchors from elder
            if quest.questType == .main && quest.objectives.count > 0 && !quest.objectives[0].completed {
                if worldFlags["main_quest_started"] == true {
                    quest.objectives[0].completed = true
                    questUpdated = true
                    print("Quest objective completed: \(quest.objectives[0].description)")
                }
            }

            // Main Quest - Objective 2: Find Sacred Oak
            if quest.questType == .main && quest.objectives.count > 2 && !quest.objectives[1].completed {
                if worldFlags["found_sacred_oak"] == true {
                    quest.objectives[1].completed = true
                    questUpdated = true
                    print("Quest objective completed: \(quest.objectives[1].description)")
                }
            }

            // Main Quest - Objective 3: Strengthen Oak or find ally
            if quest.questType == .main && quest.objectives.count > 3 && !quest.objectives[2].completed {
                if worldFlags["oak_strengthened"] == true || worldFlags["found_ally"] == true {
                    quest.objectives[2].completed = true
                    questUpdated = true
                    print("Quest objective completed: \(quest.objectives[2].description)")
                }
            }

            // Main Quest - Objective 4: Explore breach in Black Lowlands
            if quest.questType == .main && quest.objectives.count > 4 && !quest.objectives[3].completed {
                if worldFlags["explored_black_lowlands"] == true {
                    quest.objectives[3].completed = true
                    questUpdated = true
                    print("Quest objective completed: \(quest.objectives[3].description)")
                }
            }

            // Main Quest - Objective 5: Defeat Leshy-Guardian
            if quest.questType == .main && quest.objectives.count > 5 && !quest.objectives[4].completed {
                if worldFlags["leshy_guardian_defeated"] == true ||
                   worldFlags["leshy_guardian_peaceful"] == true ||
                   worldFlags["leshy_guardian_corrupted"] == true {
                    quest.objectives[4].completed = true
                    questUpdated = true
                    print("Quest objective completed: \(quest.objectives[4].description)")
                }
            }

            // Check if all objectives are completed
            if questUpdated {
                let allCompleted = quest.objectives.allSatisfy { $0.completed }
                if allCompleted {
                    completeQuest(quest.id, player: player)
                } else {
                    activeQuests[i] = quest
                }
            }
        }
    }

    /// Check quest objectives when visiting a region
    func checkQuestObjectivesByRegion(regionId: UUID, player: Player) {
        guard let region = getRegion(byId: regionId) else { return }

        // Main Quest - Objective 2: Find Sacred Oak
        if region.name == "Священный Дуб" {
            worldFlags["found_sacred_oak"] = true
            checkQuestObjectivesByFlags(player)
        }

        // Main Quest - Objective 4: Explore Black Lowlands
        if region.name == "Чёрная Низина" {
            worldFlags["explored_black_lowlands"] = true
            checkQuestObjectivesByFlags(player)
        }
    }

    /// Check quest objectives when an event is completed
    func checkQuestObjectivesByEvent(eventTitle: String, choiceText: String, player: Player) {
        // Main Quest - Objective 1: Talk to elder
        if eventTitle == "Просьба Старосты" && choiceText.contains("Согласиться") {
            worldFlags["main_quest_started"] = true
            checkQuestObjectivesByFlags(player)
        }

        // Main Quest - Objective 3: Strengthen Oak
        if eventTitle == "Мудрость Священного Дуба" && choiceText.contains("укрепить") {
            worldFlags["oak_strengthened"] = true
            checkQuestObjectivesByFlags(player)
        }

        // Main Quest - Objective 5: Boss defeated
        if eventTitle == "Леший-Хранитель" {
            if choiceText.contains("бой") {
                // Combat will set the flag via combat victory
                // This is handled in GameState after combat
            } else if choiceText.contains("договориться") {
                worldFlags["leshy_guardian_peaceful"] = true
                checkQuestObjectivesByFlags(player)
            } else if choiceText.contains("тьмы") {
                worldFlags["leshy_guardian_corrupted"] = true
                checkQuestObjectivesByFlags(player)
            }
        }
    }

    /// Mark boss as defeated after combat victory
    func markBossDefeated(bossName: String, player: Player) {
        if bossName == "Леший-Хранитель" {
            worldFlags["leshy_guardian_defeated"] = true
            checkQuestObjectivesByFlags(player)
        }
    }

    // MARK: - Data Creation (for MVP)

    private func createInitialRegions() -> [Region] {
        // АКТ I - 7 регионов (2 Stable, 3 Borderland, 2 Breach)

        // 1. Деревня у тракта (Stable) - стартовая точка
        let villageAnchor = Anchor(
            name: "Часовня Света",
            type: .chapel,
            integrity: 85,
            influence: .light,
            power: 6
        )
        var village = Region(
            name: "Деревня у тракта",
            type: .settlement,
            state: .stable,
            anchor: villageAnchor,
            reputation: 30
        )
        village.updateStateFromAnchor()

        // 2. Священный Дуб (Stable) - точка силы
        let oakAnchor = Anchor(
            name: "Священный Дуб Велеса",
            type: .sacredTree,
            integrity: 90,
            influence: .light,
            power: 8
        )
        var oak = Region(
            name: "Священный Дуб",
            type: .sacred,
            state: .stable,
            anchor: oakAnchor,
            reputation: 25
        )
        oak.updateStateFromAnchor()

        // 3. Дремучий Лес (Borderland) - первая опасная зона
        let forestAnchor = Anchor(
            name: "Каменный Идол",
            type: .stoneIdol,
            integrity: 55,
            influence: .neutral,
            power: 5
        )
        var forest = Region(
            name: "Дремучий Лес",
            type: .forest,
            state: .borderland,
            anchor: forestAnchor,
            reputation: 0
        )
        forest.updateStateFromAnchor()

        // 4. Болото Нави (Borderland) - зона искажения
        let swampAnchor = Anchor(
            name: "Осквернённый Родник",
            type: .spring,
            integrity: 45,
            influence: .dark,
            power: 4
        )
        var swamp = Region(
            name: "Болото Нави",
            type: .swamp,
            state: .borderland,
            anchor: swampAnchor,
            reputation: -15
        )
        swamp.updateStateFromAnchor()

        // 5. Горный Перевал (Borderland) - путь к узлу
        let mountainAnchor = Anchor(
            name: "Курган Предков",
            type: .barrow,
            integrity: 50,
            influence: .neutral,
            power: 5
        )
        var mountain = Region(
            name: "Горный Перевал",
            type: .mountain,
            state: .borderland,
            anchor: mountainAnchor,
            reputation: 5
        )
        mountain.updateStateFromAnchor()

        // 6. Разлом Курганов (Breach) - первый узел вторжения
        let breachAnchor = Anchor(
            name: "Разрушенное Капище",
            type: .shrine,
            integrity: 15,
            influence: .dark,
            power: 3
        )
        var breach = Region(
            name: "Разлом Курганов",
            type: .wasteland,
            state: .breach,
            anchor: breachAnchor,
            reputation: -40
        )
        breach.updateStateFromAnchor()

        // 7. Чёрная Низина (Breach) - финал Акта I
        // Нет якоря - полностью разрушен
        var darkLowland = Region(
            name: "Чёрная Низина",
            type: .swamp,
            state: .breach,
            anchor: nil,
            reputation: -60
        )
        darkLowland.updateStateFromAnchor()

        return [village, oak, forest, swamp, mountain, breach, darkLowland]
    }

    private func createInitialEvents() -> [GameEvent] {
        var events: [GameEvent] = []

        // 1. COMBAT EVENT: Встреча с лешим (Forest guardian)
        let leshyMonster = Card(
            id: UUID(),
            name: "Леший",
            type: .monster,
            rarity: .uncommon,
            description: "Древний страж леса, чья сила растет от гнева.",
            power: 4,
            defense: 8,
            health: 12,
            cost: nil,
            abilities: [],
            balance: .neutral
        )

        let leshyEvent = GameEvent(
            eventType: .combat,
            title: "Встреча с Лешим",
            description: "Из чащи появляется древний страж леса. Его глаза горят зеленым огнем, а ветви скрипят угрожающе. Леший преграждает путь.",
            regionTypes: [.forest, .swamp],
            regionStates: [.borderland, .breach],
            choices: [
                EventChoice(
                    text: "Вступить в бой с духом леса",
                    requirements: EventRequirements(minimumHealth: 3),
                    consequences: EventConsequences(
                        faithChange: 1,
                        message: "Приготовьтесь к бою!"
                    )
                ),
                EventChoice(
                    text: "Попытаться задобрить дарами (стоит 5 ✨)",
                    requirements: EventRequirements(minimumFaith: 5),
                    consequences: EventConsequences(
                        faithChange: -5,
                        balanceChange: 5,
                        tensionChange: -5,
                        message: "Леший принял дары и пропустил вас. Лес стал спокойнее."
                    )
                ),
                EventChoice(
                    text: "Отступить и обойти стороной",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: nil,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: -5,
                        message: "Вы отступили, избежав конфликта, но потеряли уважение местных духов."
                    )
                )
            ],
            oneTime: false,
            monsterCard: leshyMonster
        )
        events.append(leshyEvent)

        // 2. RITUAL/CHOICE EVENT: Древний ритуал
        let ritualEvent = GameEvent(
            eventType: .ritual,
            title: "Древний Ритуал",
            description: "Вы находите место силы - старинное капище с угасающим пламенем. Вы чувствуете, что можете либо возродить святилище Света, либо осквернить его силой Тьмы для получения власти.",
            regionTypes: [.forest, .sacred, .mountain],
            regionStates: [.stable, .borderland],
            choices: [
                EventChoice(
                    text: "Возродить святилище Света (10 ✨)",
                    requirements: EventRequirements(minimumFaith: 10, minimumHealth: nil, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -10,
                        balanceChange: 15,
                        tensionChange: -10,
                        anchorIntegrityChange: 20,
                        message: "Святилище возрождено! Свет Яви становится сильнее в этом регионе."
                    )
                ),
                EventChoice(
                    text: "Осквернить ритуал для получения силы",
                    requirements: EventRequirements(requiredBalance: .dark),
                    consequences: EventConsequences(
                        faithChange: 15,
                        balanceChange: -20,
                        tensionChange: 15,
                        addCards: ["dark_power_card"],
                        anchorIntegrityChange: -30,
                        message: "Вы получили темную силу, но Навь усилилась в этом месте."
                    )
                ),
                EventChoice(
                    text: "Не вмешиваться и уйти",
                    consequences: EventConsequences(
                        message: "Вы оставили место силы нетронутым."
                    )
                )
            ],
            oneTime: true
        )
        events.append(ritualEvent)

        // 3. NARRATIVE EVENT: Странник на развилке
        let wandererEvent = GameEvent(
            eventType: .narrative,
            title: "Странник на Развилке",
            description: "Старый путник сидит у костра. Он предлагает поделиться знаниями о мире в обмен на помощь.",
            regionTypes: [.forest, .settlement, .mountain],
            regionStates: [.stable, .borderland],
            choices: [
                EventChoice(
                    text: "Выслушать рассказы странника (3 ✨)",
                    requirements: EventRequirements(minimumFaith: 3),
                    consequences: EventConsequences(
                        faithChange: -3,
                        healthChange: nil,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["met_wanderer": true],
                        anchorIntegrityChange: nil,
                        message: "Странник рассказал вам о древних путях и тайнах мира."
                    )
                ),
                EventChoice(
                    text: "Помочь ему припасами",
                    consequences: EventConsequences(
                        faithChange: -2,
                        healthChange: nil,
                        balanceChange: 5,
                        tensionChange: nil,
                        reputationChange: 10,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: nil,
                        anchorIntegrityChange: nil,
                        message: "Странник благодарен за помощь и благословляет ваш путь."
                    )
                ),
                EventChoice(
                    text: "Пройти мимо",
                    consequences: EventConsequences(
                        message: "Вы продолжили свой путь."
                    )
                )
            ],
            oneTime: true
        )
        events.append(wandererEvent)

        // 4. EXPLORATION EVENT: Заброшенный храм
        let templeEvent = GameEvent(
            eventType: .exploration,
            title: "Заброшенный Храм",
            description: "Вы находите руины древнего храма. Внутри чувствуется присутствие силы, но и опасность.",
            regionTypes: [.settlement, .wasteland, .sacred],
            regionStates: [.borderland, .breach],
            choices: [
                EventChoice(
                    text: "Тщательно исследовать храм",
                    requirements: EventRequirements(minimumHealth: 5),
                    consequences: EventConsequences(
                        faithChange: 8,
                        healthChange: -3,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: ["ancient_blessing"],
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: nil,
                        anchorIntegrityChange: nil,
                        message: "Вы нашли древнюю реликвию, но исследование было опасным."
                    )
                ),
                EventChoice(
                    text: "Быстро осмотреть и уйти",
                    consequences: EventConsequences(
                        faithChange: 3,
                        message: "Вы нашли немного ценностей и быстро покинули опасное место."
                    )
                ),
                EventChoice(
                    text: "Обойти храм стороной",
                    consequences: EventConsequences(
                        message: "Вы решили не рисковать."
                    )
                )
            ],
            oneTime: false
        )
        events.append(templeEvent)

        // 5. WORLD SHIFT EVENT: Усиление Нави
        let breachEvent = GameEvent(
            eventType: .worldShift,
            title: "Прорыв Нави",
            description: "Граница между мирами истончается. Темные силы пытаются прорваться в Явь через слабый якорь.",
            regionTypes: [.forest, .swamp, .settlement, .wasteland],
            regionStates: [.breach],
            choices: [
                EventChoice(
                    text: "Укрепить якорь своей верой (15 ✨)",
                    requirements: EventRequirements(minimumFaith: 15),
                    consequences: EventConsequences(
                        faithChange: -15,
                        balanceChange: 10,
                        tensionChange: -20,
                        anchorIntegrityChange: 30,
                        message: "Вы закрыли прорыв! Регион стабилизировался."
                    )
                ),
                EventChoice(
                    text: "Отступить и предупредить других",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: nil,
                        balanceChange: nil,
                        tensionChange: 10,
                        reputationChange: 5,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: nil,
                        anchorIntegrityChange: -10,
                        message: "Вы предупредили о прорыве, но Навь усилилась."
                    )
                ),
                EventChoice(
                    text: "Попытаться использовать силу прорыва",
                    requirements: EventRequirements(requiredBalance: .dark),
                    consequences: EventConsequences(
                        faithChange: 10,
                        healthChange: -5,
                        balanceChange: -15,
                        tensionChange: 5,
                        addCurse: "breach_corruption",
                        message: "Вы получили силу Нави, но она оставила след на вашей душе."
                    )
                )
            ],
            oneTime: false
        )
        events.append(breachEvent)

        // 6. UNIVERSAL EVENT: Дикий зверь (works in all regions)
        let beastMonster = Card(
            id: UUID(),
            name: "Дикий Зверь",
            type: .monster,
            rarity: .common,
            description: "Озверевшее создание, искаженное влиянием Нави.",
            power: 3,
            defense: 6,
            health: 8,
            cost: nil,
            abilities: [],
            balance: .dark
        )

        let beastEvent = GameEvent(
            eventType: .combat,
            title: "Дикий Зверь",
            description: "Из-за деревьев выскакивает озверевшее существо с горящими красными глазами. Оно рычит и готовится к атаке!",
            regionTypes: [], // Empty = all region types
            regionStates: [.stable, .borderland, .breach], // All states
            choices: [
                EventChoice(
                    text: "Сразиться со зверем",
                    requirements: EventRequirements(minimumHealth: 2),
                    consequences: EventConsequences(
                        message: "Вы вступаете в бой!"
                    )
                ),
                EventChoice(
                    text: "Попытаться испугать зверя (5 ✨)",
                    requirements: EventRequirements(minimumFaith: 5),
                    consequences: EventConsequences(
                        faithChange: -5,
                        message: "Вы используете силу веры, чтобы отпугнуть зверя."
                    )
                ),
                EventChoice(
                    text: "Убежать",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: -1,
                        message: "Вы убегаете, но зверь успевает ранить вас."
                    )
                )
            ],
            oneTime: false,
            monsterCard: beastMonster
        )
        events.append(beastEvent)

        // 7. SETTLEMENT EVENT: Торговец на тракте
        let merchantEvent = GameEvent(
            eventType: .narrative,
            title: "Торговец на Тракте",
            description: "Вы встречаете странствующего торговца. У него есть интересные товары, но цены высоки.",
            regionTypes: [.settlement],
            regionStates: [.stable, .borderland],
            choices: [
                EventChoice(
                    text: "Купить благословение (8 ✨)",
                    requirements: EventRequirements(minimumFaith: 8),
                    consequences: EventConsequences(
                        faithChange: -8,
                        healthChange: 3,
                        balanceChange: 5,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: ["merchant_blessing"],
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: nil,
                        anchorIntegrityChange: nil,
                        message: "Вы приобрели благословение. Ваши силы восстановлены."
                    )
                ),
                EventChoice(
                    text: "Поторговаться за информацию (4 ✨)",
                    requirements: EventRequirements(minimumFaith: 4),
                    consequences: EventConsequences(
                        faithChange: -4,
                        healthChange: nil,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: 5,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["merchant_info": true],
                        anchorIntegrityChange: nil,
                        message: "Торговец рассказал о путях и опасностях впереди."
                    )
                ),
                EventChoice(
                    text: "Просто поговорить и идти дальше",
                    consequences: EventConsequences(
                        message: "Вы обменялись новостями и продолжили путь."
                    )
                )
            ],
            oneTime: false
        )
        events.append(merchantEvent)

        // 8. MOUNTAIN EVENT: Перевал и горный дух
        let mountainSpiritMonster = Card(
            id: UUID(),
            name: "Горный Дух",
            type: .monster,
            rarity: .uncommon,
            description: "Древний страж горных троп, испытывающий путников.",
            power: 5,
            defense: 10,
            health: 14,
            cost: nil,
            abilities: [],
            balance: .neutral
        )

        let mountainEvent = GameEvent(
            eventType: .combat,
            title: "Испытание Перевала",
            description: "На горном перевале появляется каменный дух. Он говорит: 'Докажи свою силу или вернись назад, смертный!'",
            regionTypes: [.mountain],
            regionStates: [.stable, .borderland, .breach],
            choices: [
                EventChoice(
                    text: "Принять вызов духа",
                    requirements: EventRequirements(minimumHealth: 4),
                    consequences: EventConsequences(
                        faithChange: 2,
                        message: "Вы принимаете вызов горного духа!"
                    )
                ),
                EventChoice(
                    text: "Предложить дар горам (10 ✨)",
                    requirements: EventRequirements(minimumFaith: 10),
                    consequences: EventConsequences(
                        faithChange: -10,
                        healthChange: nil,
                        balanceChange: 8,
                        tensionChange: nil,
                        reputationChange: 15,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["mountain_blessing": true],
                        anchorIntegrityChange: nil,
                        message: "Горный дух принял дар. Он благословил ваш путь через перевал."
                    )
                ),
                EventChoice(
                    text: "Отступить с перевала",
                    consequences: EventConsequences(
                        message: "Вы спускаетесь вниз, не приняв вызов."
                    )
                )
            ],
            oneTime: true,
            monsterCard: mountainSpiritMonster
        )
        events.append(mountainEvent)

        // 9. SACRED EVENT: Священный Дуб
        let oakEvent = GameEvent(
            eventType: .ritual,
            title: "Мудрость Священного Дуба",
            description: "Древний дуб шепчет вам на языке ветра. Вы чувствуете его древнюю силу и мудрость веков.",
            regionTypes: [.sacred, .forest],
            regionStates: [.stable, .borderland],
            choices: [
                EventChoice(
                    text: "Медитировать под дубом (6 ✨)",
                    requirements: EventRequirements(minimumFaith: 6),
                    consequences: EventConsequences(
                        faithChange: -6,
                        healthChange: 5,
                        balanceChange: 10,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["oak_wisdom": true],
                        anchorIntegrityChange: nil,
                        message: "Дуб поделился древней мудростью. Вы чувствуете прилив сил и ясность разума."
                    )
                ),
                EventChoice(
                    text: "Укрепить связь дуба с землей (12 ✨)",
                    requirements: EventRequirements(minimumFaith: 12, minimumHealth: nil, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -12,
                        healthChange: nil,
                        balanceChange: 15,
                        tensionChange: -15,
                        reputationChange: nil,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["oak_strengthened": true],
                        anchorIntegrityChange: 25,
                        message: "Вы усилили якорь! Священный Дуб сияет обновленной силой."
                    )
                ),
                EventChoice(
                    text: "Просто отдохнуть в тени дуба",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: 2,
                        message: "Вы отдохнули под защитой древнего дуба."
                    )
                )
            ],
            oneTime: false
        )
        events.append(oakEvent)

        // 10. SWAMP EVENT: Болотная ведьма
        let swampWitchEvent = GameEvent(
            eventType: .narrative,
            title: "Болотная Ведьма",
            description: "Среди болотных туманов появляется старая ведьма. Она предлагает сделку: знания в обмен на часть вашей сущности.",
            regionTypes: [.swamp],
            regionStates: [.borderland, .breach],
            choices: [
                EventChoice(
                    text: "Принять сделку ведьмы",
                    requirements: EventRequirements(minimumHealth: 4),
                    consequences: EventConsequences(
                        faithChange: 5,
                        healthChange: -3,
                        balanceChange: -10,
                        addCards: ["witch_knowledge", "dark_pact"],
                        addCurse: "witch_mark",
                        setFlags: ["witch_pact": true],
                        message: "Ведьма дала вам темные знания, но вы чувствуете проклятие на своей душе."
                    )
                ),
                EventChoice(
                    text: "Отказаться и попросить о помощи (7 ✨)",
                    requirements: EventRequirements(minimumFaith: 7),
                    consequences: EventConsequences(
                        faithChange: -7,
                        healthChange: 2,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["witch_refused": true],
                        anchorIntegrityChange: nil,
                        message: "Ведьма уважает вашу стойкость и дает небольшую помощь без платы."
                    )
                ),
                EventChoice(
                    text: "Уйти, не связываясь с ведьмой",
                    consequences: EventConsequences(
                        message: "Вы обходите ведьму стороной и продолжаете путь через болото."
                    )
                )
            ],
            oneTime: true
        )
        events.append(swampWitchEvent)

        // 11. WASTELAND EVENT: Разлом Курганов
        let barrowWraithMonster = Card(
            id: UUID(),
            name: "Курганный Призрак",
            type: .monster,
            rarity: .rare,
            description: "Древний воин, восставший из кургана под влиянием Нави.",
            power: 6,
            defense: 8,
            health: 16,
            cost: nil,
            abilities: [],
            balance: .dark
        )

        let barrowEvent = GameEvent(
            eventType: .combat,
            title: "Стражи Курганов",
            description: "Древние курганы вскрываются, и из них поднимаются призрачные воины. Они защищают сокровища предков.",
            regionTypes: [.wasteland],
            regionStates: [.breach],
            choices: [
                EventChoice(
                    text: "Сразиться с призраками",
                    requirements: EventRequirements(minimumHealth: 5),
                    consequences: EventConsequences(
                        message: "Вы вступаете в бой с древними стражами!"
                    )
                ),
                EventChoice(
                    text: "Провести ритуал упокоения (15 ✨)",
                    requirements: EventRequirements(minimumFaith: 15, minimumHealth: nil, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -15,
                        healthChange: nil,
                        balanceChange: 20,
                        tensionChange: -10,
                        reputationChange: nil,
                        addCards: ["ancestral_blessing"],
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["barrow_cleansed": true],
                        anchorIntegrityChange: nil,
                        message: "Вы упокоили древних воинов. Они благословляют вас перед уходом."
                    )
                ),
                EventChoice(
                    text: "Разграбить курган и бежать",
                    consequences: EventConsequences(
                        faithChange: 5,
                        healthChange: -4,
                        balanceChange: -15,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: nil,
                        addCurse: "ancestral_wrath",
                        giveArtifact: nil,
                        setFlags: nil,
                        anchorIntegrityChange: nil,
                        message: "Вы захватили сокровища, но навлекли гнев предков."
                    )
                )
            ],
            oneTime: false,
            monsterCard: barrowWraithMonster
        )
        events.append(barrowEvent)

        // 11. BOSS EVENT: Леший-Хранитель (Final Boss of Act I)
        let leshyGuardianBoss = TwilightMarchesCards.createLeshyGuardianBoss()
        let bossEvent = GameEvent(
            eventType: .combat,
            title: "Леший-Хранитель",
            description: "Перед вами возвышается древний страж Сумрачных Пределов. Леший-Хранитель - существо невиданной силы, чьи корни уходят в самые основы мира. Зелёное пламя в его глазах горит вечностью. Это финальное испытание Акта I.",
            regionTypes: [.swamp],
            regionStates: [.breach],
            choices: [
                EventChoice(
                    text: "Вступить в решающий бой",
                    requirements: EventRequirements(minimumFaith: 10, minimumHealth: 8),
                    consequences: EventConsequences(
                        message: "Последняя битва начинается! Судьба Сумрачных Пределов решается здесь!"
                    )
                ),
                EventChoice(
                    text: "Попытаться договориться (20 ✨)",
                    requirements: EventRequirements(minimumFaith: 20, minimumHealth: nil, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -20,
                        healthChange: nil,
                        balanceChange: 15,
                        tensionChange: -20,
                        reputationChange: nil,
                        addCards: ["guardian_seal"],
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["leshy_guardian_peaceful": true],
                        anchorIntegrityChange: nil,
                        message: "Хранитель видит свет в вашей душе и соглашается помочь вам. Он вручает вам печать защитника."
                    )
                ),
                EventChoice(
                    text: "Использовать силу тьмы (15 ✨)",
                    requirements: EventRequirements(minimumFaith: 15, minimumHealth: nil, requiredBalance: .dark),
                    consequences: EventConsequences(
                        faithChange: -15,
                        healthChange: -5,
                        balanceChange: -20,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: ["corrupted_power"],
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["leshy_guardian_corrupted": true],
                        anchorIntegrityChange: nil,
                        message: "Вы обрушиваете на хранителя силу тьмы. Он ослабевает, но часть его сущности входит в вас..."
                    )
                )
            ],
            questLinks: [], // Will be linked to main quest ID dynamically
            oneTime: true,
            monsterCard: leshyGuardianBoss
        )
        events.append(bossEvent)

        // 12. QUEST EVENT: Деревенский староста (Main Quest trigger)
        let elderEvent = GameEvent(
            eventType: .narrative,
            title: "Просьба Старосты",
            description: "Деревенский староста просит о помощи. Навь усиливается, и деревне нужен защитник, способный укрепить якоря и противостоять тьме.",
            regionTypes: [.settlement],
            regionStates: [.stable, .borderland],
            choices: [
                EventChoice(
                    text: "Согласиться помочь деревне",
                    consequences: EventConsequences(
                        faithChange: 3,
                        reputationChange: 20,
                        setFlags: ["main_quest_started": true, "helped_village": true],
                        message: "Староста благодарен. Он рассказывает о трех главных якорях, которые нужно укрепить."
                    )
                ),
                EventChoice(
                    text: "Попросить награду (10 ✨)",
                    consequences: EventConsequences(
                        faithChange: 10,
                        reputationChange: 5,
                        setFlags: ["main_quest_started": true, "mercenary_path": true],
                        message: "Староста соглашается заплатить. Вы берете задание как наемник."
                    )
                ),
                EventChoice(
                    text: "Отказать и идти своим путем",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: nil,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: -10,
                        setFlags: ["refused_main_quest": true],
                        message: "Староста разочарован вашим отказом."
                    )
                )
            ],
            questLinks: ["main_quest_act1"],
            oneTime: true
        )
        events.append(elderEvent)

        // 13. SIDE QUEST: Потерянный ребенок
        let lostChildEvent = GameEvent(
            eventType: .narrative,
            title: "Плач в Лесу",
            description: "Вы слышите детский плач в чаще. Местные говорят, что ребенок пропал три дня назад.",
            regionTypes: [.forest, .swamp],
            regionStates: [.borderland, .breach],
            choices: [
                EventChoice(
                    text: "Отправиться на поиски ребенка",
                    requirements: EventRequirements(minimumHealth: 4),
                    consequences: EventConsequences(
                        faithChange: -5,
                        healthChange: -2,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: nil,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["child_quest_started": true],
                        anchorIntegrityChange: nil,
                        message: "Вы уходите вглубь леса на поиски пропавшего ребенка."
                    )
                ),
                EventChoice(
                    text: "Использовать веру для поиска (8 ✨)",
                    requirements: EventRequirements(minimumFaith: 8),
                    consequences: EventConsequences(
                        faithChange: -8,
                        healthChange: nil,
                        balanceChange: 15,
                        tensionChange: nil,
                        reputationChange: 25,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["child_saved": true],
                        anchorIntegrityChange: nil,
                        message: "Ваша вера помогла найти ребенка быстро. Деревня очень благодарна!"
                    )
                ),
                EventChoice(
                    text: "Это слишком опасно, вернуться",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: nil,
                        balanceChange: nil,
                        tensionChange: nil,
                        reputationChange: -15,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: nil,
                        anchorIntegrityChange: nil,
                        message: "Вы решаете не рисковать. Судьба ребенка остается неизвестной."
                    )
                )
            ],
            questLinks: ["side_quest_lost_child"],
            oneTime: true
        )
        events.append(lostChildEvent)

        // 14. REST EVENT: Привал у костра
        let campEvent = GameEvent(
            eventType: .narrative,
            title: "Безопасное Место для Привала",
            description: "Вы находите укрытое место, подходящее для отдыха. Можно развести костер и восстановить силы.",
            regionTypes: [.forest, .mountain, .settlement],
            regionStates: [.stable, .borderland],
            choices: [
                EventChoice(
                    text: "Отдохнуть и восстановиться",
                    consequences: EventConsequences(
                        faithChange: 2,
                        healthChange: 4,
                        message: "Вы отдохнули у костра. Силы восстановлены."
                    )
                ),
                EventChoice(
                    text: "Провести ритуал очищения (5 ✨)",
                    requirements: EventRequirements(minimumFaith: 5),
                    consequences: EventConsequences(
                        faithChange: -5,
                        healthChange: 3,
                        balanceChange: 5,
                        message: "Ритуал очищения освежил тело и дух."
                    )
                ),
                EventChoice(
                    text: "Быстро перекусить и идти дальше",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: 1,
                        message: "Вы немного отдохнули и продолжили путь."
                    )
                )
            ],
            oneTime: false
        )
        events.append(campEvent)

        // 15. WORLD SHIFT: Сдвиг границ (Act I critical event)
        let realmShiftEvent = GameEvent(
            eventType: .worldShift,
            title: "Сдвиг Границ Миров",
            description: "Граница между Явью и Навью содрогается. Вы чувствуете, как реальность искажается вокруг вас. Это критический момент.",
            regionTypes: [], // All regions
            regionStates: [.breach],
            choices: [
                EventChoice(
                    text: "Стабилизировать границу верой (20 ✨)",
                    requirements: EventRequirements(minimumFaith: 20, minimumHealth: nil, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -20,
                        healthChange: nil,
                        balanceChange: 25,
                        tensionChange: -25,
                        reputationChange: nil,
                        addCards: nil,
                        addCurse: nil,
                        giveArtifact: nil,
                        setFlags: ["realm_stabilized": true],
                        anchorIntegrityChange: 40,
                        message: "Вы закрыли прорыв! Граница миров укреплена вашей верой."
                    )
                ),
                EventChoice(
                    text: "Использовать момент для получения силы",
                    requirements: EventRequirements(minimumFaith: 10, minimumHealth: nil, requiredBalance: .dark),
                    consequences: EventConsequences(
                        faithChange: 15,
                        healthChange: -5,
                        balanceChange: -20,
                        tensionChange: 15,
                        reputationChange: nil,
                        addCards: ["realm_power", "nav_essence"],
                        addCurse: "realm_corruption",
                        giveArtifact: nil,
                        setFlags: nil,
                        anchorIntegrityChange: nil,
                        message: "Вы вытянули силу из прорыва, но Навь пометила вас."
                    )
                ),
                EventChoice(
                    text: "Бежать от сдвига",
                    consequences: EventConsequences(
                        faithChange: nil,
                        healthChange: -3,
                        balanceChange: nil,
                        tensionChange: 20,
                        anchorIntegrityChange: -20,
                        message: "Вы бежите, но сдвиг усиливается. Мир становится опаснее."
                    )
                )
            ],
            questLinks: ["main_quest_act1"],
            oneTime: false
        )
        events.append(realmShiftEvent)

        return events
    }

    // MARK: - Initial Quests (Act I)

    private func createInitialQuests() -> [Quest] {
        var quests: [Quest] = []

        // MAIN QUEST: Путь Защитника (5 stages)
        let mainQuest = Quest(
            id: UUID(),
            title: "Путь Защитника",
            description: "Деревня в опасности. Навь усиливается с каждым днем. Вы должны укрепить три главных якоря и защитить границу между мирами.",
            questType: .main,
            stage: 0,
            objectives: [
                QuestObjective(
                    description: "Узнать о трех главных якорях от старосты",
                    completed: false
                ),
                QuestObjective(
                    description: "Найти Священный Дуб",
                    completed: false
                ),
                QuestObjective(
                    description: "Укрепить Дуб или найти союзника",
                    completed: false
                ),
                QuestObjective(
                    description: "Исследовать прорыв Нави в Чёрной Низине",
                    completed: false
                ),
                QuestObjective(
                    description: "Победить Лешего-Хранителя",
                    completed: false
                )
            ],
            rewards: QuestRewards(
                faith: 20,
                cards: ["defender_blessing", "anchor_power"],
                artifact: "guardian_seal",
                experience: 100
            ),
            completed: false
        )
        quests.append(mainQuest)

        // SIDE QUEST 1: Потерянный ребенок
        let lostChildQuest = Quest(
            id: UUID(),
            title: "Потерянный Ребенок",
            description: "Маленький ребенок пропал в лесу три дня назад. Его родители в отчаянии. Лес становится все опаснее с каждым часом.",
            questType: .side,
            stage: 0,
            objectives: [
                QuestObjective(
                    description: "Найти следы ребенка в лесу",
                    completed: false
                ),
                QuestObjective(
                    description: "Спасти ребенка от лесных духов",
                    completed: false
                ),
                QuestObjective(
                    description: "Вернуть ребенка в деревню",
                    completed: false
                )
            ],
            rewards: QuestRewards(
                faith: 8,
                cards: ["village_gratitude"],
                experience: 30
            ),
            completed: false
        )
        quests.append(lostChildQuest)

        // SIDE QUEST 2: Торговые пути
        let tradeRoutesQuest = Quest(
            id: UUID(),
            title: "Безопасность Торговых Путей",
            description: "Торговцы жалуются на участившиеся нападения на дорогах. Нужно очистить три ключевых участка пути.",
            questType: .side,
            stage: 0,
            objectives: [
                QuestObjective(
                    description: "Очистить лесную дорогу от тварей",
                    completed: false
                ),
                QuestObjective(
                    description: "Защитить караван через горный перевал",
                    completed: false
                ),
                QuestObjective(
                    description: "Договориться с лешим о безопасном проходе",
                    completed: false
                )
            ],
            rewards: QuestRewards(
                faith: 12,
                cards: ["merchant_discount", "trade_blessing"],
                experience: 40
            ),
            completed: false
        )
        quests.append(tradeRoutesQuest)

        // SIDE QUEST 3: Сделка с ведьмой
        let witchQuestLight = Quest(
            id: UUID(),
            title: "Тайна Болотной Ведьмы",
            description: "Болотная ведьма знает древние секреты. Она может помочь в борьбе с Навью, но за какую цену?",
            questType: .side,
            stage: 0,
            objectives: [
                QuestObjective(
                    description: "Найти ведьму в болоте",
                    completed: false
                ),
                QuestObjective(
                    description: "Выслушать её предложение",
                    completed: false
                ),
                QuestObjective(
                    description: "Сделать выбор: принять сделку или найти другой путь",
                    completed: false
                )
            ],
            rewards: QuestRewards(
                faith: 10,
                cards: ["witch_knowledge"],
                experience: 35
            ),
            completed: false
        )
        quests.append(witchQuestLight)

        // SIDE QUEST 4: Курганы предков
        let barrowQuest = Quest(
            id: UUID(),
            title: "Проклятие Курганов",
            description: "Древние курганы вскрылись, и мертвые восстали. Нужно упокоить духов предков или победить их.",
            questType: .side,
            stage: 0,
            objectives: [
                QuestObjective(
                    description: "Исследовать Разлом Курганов",
                    completed: false
                ),
                QuestObjective(
                    description: "Найти причину пробуждения мертвых",
                    completed: false
                ),
                QuestObjective(
                    description: "Упокоить духов или победить призраков",
                    completed: false
                )
            ],
            rewards: QuestRewards(
                faith: 15,
                cards: ["ancestral_blessing", "warrior_spirit"],
                artifact: "ancient_relic",
                experience: 50
            ),
            completed: false
        )
        quests.append(barrowQuest)

        // SIDE QUEST 5: Странствующий монах
        let monkQuest = Quest(
            id: UUID(),
            title: "Испытание Монаха",
            description: "Странствующий монах предлагает испытание духа. Пройдя его, вы обретете мудрость и силу.",
            questType: .side,
            stage: 0,
            objectives: [
                QuestObjective(
                    description: "Найти монаха в священном месте",
                    completed: false
                ),
                QuestObjective(
                    description: "Пройти три испытания: тела, разума и духа",
                    completed: false
                ),
                QuestObjective(
                    description: "Доказать свою чистоту намерений",
                    completed: false
                )
            ],
            rewards: QuestRewards(
                faith: 18,
                cards: ["inner_peace", "spiritual_armor"],
                experience: 45
            ),
            completed: false
        )
        quests.append(monkQuest)

        // SIDE QUEST 6: Дух горного перевала
        let mountainSpiritQuest = Quest(
            id: UUID(),
            title: "Благословение Гор",
            description: "Горный дух испытывает путников. Докажите свою силу или мудрость, чтобы получить благословение перевала.",
            questType: .side,
            stage: 0,
            objectives: [
                QuestObjective(
                    description: "Добраться до горного перевала",
                    completed: false
                ),
                QuestObjective(
                    description: "Встретить горного духа",
                    completed: false
                ),
                QuestObjective(
                    description: "Пройти испытание или принести достойный дар",
                    completed: false
                )
            ],
            rewards: QuestRewards(
                faith: 10,
                cards: ["mountain_blessing", "stone_armor"],
                experience: 35
            ),
            completed: false
        )
        quests.append(mountainSpiritQuest)

        return quests
    }

    // MARK: - Narrative System (Endings & Deck Path)
    // See EXPLORATION_CORE_DESIGN.md, sections 28-34

    /// Calculate player's dominant deck path based on card balance alignment
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

        return """
        Напряжение: \(worldTension)/100
        Баланс: \(balanceDescription) (\(lightDarkBalance))
        Путь колоды: \(deckPath.rawValue)
        Якоря: \(stableCount) stable, \(breachCount) breach
        Активные флаги: \(worldFlags.filter { $0.value }.count)
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
    }
}
