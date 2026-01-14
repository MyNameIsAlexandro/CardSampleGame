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
        // TODO: Создать начальные события
        // Пока возвращаем пустой массив, создадим события в следующем шаге
        return []
    }
}
