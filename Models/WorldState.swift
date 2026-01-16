import Foundation
import Combine

/// Глобальное состояние мира для системы исследования
class WorldState: ObservableObject {
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
        // При высоком напряжении регионы деградируют
        if worldTension >= 80 {
            degradeRandomRegion()
        }

        // При низком напряжении регионы улучшаются
        if worldTension <= 20 {
            improveRandomRegion()
        }
    }

    private func degradeRandomRegion() {
        let stableRegions = regions.filter { $0.state == .stable }
        guard let randomRegion = stableRegions.randomElement(),
              let index = regions.firstIndex(where: { $0.id == randomRegion.id }) else {
            return
        }

        var region = regions[index]
        if var anchor = region.anchor {
            anchor.integrity = max(0, anchor.integrity - 20)
            region.anchor = anchor
            region.updateStateFromAnchor()
            updateRegion(region)
        }
    }

    private func improveRandomRegion() {
        let breachRegions = regions.filter { $0.state == .breach }
        guard let randomRegion = breachRegions.randomElement(),
              let index = regions.firstIndex(where: { $0.id == randomRegion.id }) else {
            return
        }

        var region = regions[index]
        if var anchor = region.anchor {
            anchor.integrity = min(100, anchor.integrity + 15)
            region.anchor = anchor
            region.updateStateFromAnchor()
            updateRegion(region)
        }
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

        // Установка флагов
        if let flags = consequences.setFlags {
            for (key, value) in flags {
                worldFlags[key] = value
            }
        }

        // TODO: Добавление карт, проклятий, артефактов
    }

    // MARK: - Data Creation (for MVP)

    private func createInitialRegions() -> [Region] {
        // Регион 1: Стабильный лес
        let forestAnchor = Anchor(
            name: "Священный Дуб Велеса",
            type: .sacredTree,
            integrity: 85,
            influence: .light,
            power: 7
        )

        let forest = Region(
            name: "Лес Велеса",
            type: .forest,
            state: .stable,
            anchor: forestAnchor,
            reputation: 20
        )

        // Регион 2: Пограничное болото
        let swampAnchor = Anchor(
            name: "Каменная Баба",
            type: .stoneIdol,
            integrity: 55,
            influence: .neutral,
            power: 5
        )

        var swamp = Region(
            name: "Болота Нави",
            type: .swamp,
            state: .borderland,
            anchor: swampAnchor,
            reputation: -10
        )
        swamp.updateStateFromAnchor()

        // Регион 3: Прорыв в деревне
        let villageAnchor = Anchor(
            name: "Разрушенная Часовня",
            type: .chapel,
            integrity: 15,
            influence: .dark,
            power: 3
        )

        var village = Region(
            name: "Забытая Деревня",
            type: .settlement,
            state: .breach,
            anchor: villageAnchor,
            reputation: -50
        )
        village.updateStateFromAnchor()

        return [forest, swamp, village]
    }

    private func createInitialEvents() -> [GameEvent] {
        var events: [GameEvent] = []

        // 1. COMBAT EVENT: Встреча с лешим (Forest guardian)
        let leshyMonster = Card(
            id: UUID(),
            name: "Леший",
            description: "Древний страж леса, чья сила растет от гнева.",
            type: .enemy,
            rarity: .uncommon,
            cost: nil,
            power: 4,
            health: 12,
            defense: 8,
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
                    requirements: EventRequirements(minimumFaith: 10, requiredBalance: .light),
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
                        setFlags: ["met_wanderer": true],
                        message: "Странник рассказал вам о древних путях и тайнах мира."
                    )
                ),
                EventChoice(
                    text: "Помочь ему припасами",
                    consequences: EventConsequences(
                        faithChange: -2,
                        balanceChange: 5,
                        reputationChange: 10,
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
                        addCards: ["ancient_blessing"],
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
                        tensionChange: 10,
                        reputationChange: 5,
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

        return events
    }
}
