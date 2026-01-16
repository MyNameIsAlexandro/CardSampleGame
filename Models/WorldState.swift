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

        // Проверить автоматическую деградацию мира
        checkTimeDegradation()
    }

    // MARK: - Time-based Degradation

    /// Проверка автоматической деградации мира каждые 3 дня
    func checkTimeDegradation() {
        guard daysPassed > 0 && daysPassed % 3 == 0 else { return }

        // 1. Увеличить напряжение мира
        increaseTension(by: 2)

        // 2. С вероятностью (Tension/100) деградировать случайный регион
        let probability = Double(worldTension) / 100.0
        if Double.random(in: 0...1) < probability {
            degradeRandomRegion()
        }
    }

    /// Метод для ручного продвижения времени (для Rest, StrengthenAnchor и т.д.)
    func advanceTime(by days: Int = 1) {
        daysPassed += days
        checkTimeDegradation()
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
                        addCards: ["merchant_blessing"],
                        message: "Вы приобрели благословение. Ваши силы восстановлены."
                    )
                ),
                EventChoice(
                    text: "Поторговаться за информацию (4 ✨)",
                    requirements: EventRequirements(minimumFaith: 4),
                    consequences: EventConsequences(
                        faithChange: -4,
                        setFlags: ["merchant_info": true],
                        reputationChange: 5,
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
                        balanceChange: 8,
                        reputationChange: 15,
                        setFlags: ["mountain_blessing": true],
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
                        setFlags: ["oak_wisdom": true],
                        message: "Дуб поделился древней мудростью. Вы чувствуете прилив сил и ясность разума."
                    )
                ),
                EventChoice(
                    text: "Укрепить связь дуба с землей (12 ✨)",
                    requirements: EventRequirements(minimumFaith: 12, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -12,
                        balanceChange: 15,
                        tensionChange: -15,
                        anchorIntegrityChange: 25,
                        setFlags: ["oak_strengthened": true],
                        message: "Вы усилили якорь! Священный Дуб сияет обновленной силой."
                    )
                ),
                EventChoice(
                    text: "Просто отдохнуть в тени дуба",
                    consequences: EventConsequences(
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
                        healthChange: -3,
                        faithChange: 5,
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
                        setFlags: ["witch_refused": true],
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
                    requirements: EventRequirements(minimumFaith: 15, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -15,
                        balanceChange: 20,
                        tensionChange: -10,
                        addCards: ["ancestral_blessing"],
                        setFlags: ["barrow_cleansed": true],
                        message: "Вы упокоили древних воинов. Они благословляют вас перед уходом."
                    )
                ),
                EventChoice(
                    text: "Разграбить курган и бежать",
                    consequences: EventConsequences(
                        faithChange: 5,
                        healthChange: -4,
                        balanceChange: -15,
                        addCurse: "ancestral_wrath",
                        message: "Вы захватили сокровища, но навлекли гнев предков."
                    )
                )
            ],
            oneTime: false,
            monsterCard: barrowWraithMonster
        )
        events.append(barrowEvent)

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
                        healthChange: -2,
                        faithChange: -5,
                        setFlags: ["child_quest_started": true],
                        message: "Вы уходите вглубь леса на поиски пропавшего ребенка."
                    )
                ),
                EventChoice(
                    text: "Использовать веру для поиска (8 ✨)",
                    requirements: EventRequirements(minimumFaith: 8),
                    consequences: EventConsequences(
                        faithChange: -8,
                        reputationChange: 25,
                        balanceChange: 15,
                        setFlags: ["child_saved": true],
                        message: "Ваша вера помогла найти ребенка быстро. Деревня очень благодарна!"
                    )
                ),
                EventChoice(
                    text: "Это слишком опасно, вернуться",
                    consequences: EventConsequences(
                        reputationChange: -15,
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
                        healthChange: 4,
                        faithChange: 2,
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
                    requirements: EventRequirements(minimumFaith: 20, requiredBalance: .light),
                    consequences: EventConsequences(
                        faithChange: -20,
                        balanceChange: 25,
                        tensionChange: -25,
                        anchorIntegrityChange: 40,
                        setFlags: ["realm_stabilized": true],
                        message: "Вы закрыли прорыв! Граница миров укреплена вашей верой."
                    )
                ),
                EventChoice(
                    text: "Использовать момент для получения силы",
                    requirements: EventRequirements(requiredBalance: .dark, minimumFaith: 10),
                    consequences: EventConsequences(
                        faithChange: 15,
                        healthChange: -5,
                        balanceChange: -20,
                        tensionChange: 15,
                        addCards: ["realm_power", "nav_essence"],
                        addCurse: "realm_corruption",
                        message: "Вы вытянули силу из прорыва, но Навь пометила вас."
                    )
                ),
                EventChoice(
                    text: "Бежать от сдвига",
                    consequences: EventConsequences(
                        healthChange: -3,
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
}
