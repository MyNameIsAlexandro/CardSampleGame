/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+ActionPipeline+Time.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+ActionPipeline+Time.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    // MARK: - Time Cost Calculation

    func calculateTimeCost(for action: TwilightGameAction) -> Int {
        switch action {
        case .travel(let toRegionId):
            guard let currentId = currentRegionId,
                  let currentRegion = regions[currentId] else {
                return 1
            }
            return currentRegion.neighborIds.contains(toRegionId) ? 1 : 2

        default:
            return action.timeCost
        }
    }

    // MARK: - Time Advancement

    func advanceTime(by days: Int) -> [StateChange] {
        var changes: [StateChange] = []

        for _ in 0..<days {
            currentDay += 1
            changes.append(.dayAdvanced(newDay: currentDay))

            if currentDay > 0 && currentDay % tensionTickInterval == 0 {
                let tensionIncrease = calculateTensionIncrease()
                worldTension = min(100, worldTension + tensionIncrease)
                changes.append(.tensionChanged(delta: tensionIncrease, newValue: worldTension))

                let degradationChanges = processWorldDegradation()
                changes.append(contentsOf: degradationChanges)
            }
        }

        return changes
    }

    func calculateTensionIncrease() -> Int {
        TwilightPressureRules.calculateTensionIncrease(
            daysPassed: currentDay,
            base: balanceConfig.pressure.pressurePerTurn
        )
    }

    func processWorldDegradation() -> [StateChange] {
        var changes: [StateChange] = []

        let degradableRegions = regions.values
            .filter { $0.state == .borderland || $0.state == .breach }
            .sorted { $0.id < $1.id }

        guard !degradableRegions.isEmpty else { return changes }

        let weights = degradableRegions.map { services.degradationRules.selectionWeight(for: $0.state) }
        let totalWeight = weights.reduce(0, +)

        if totalWeight > 0 {
            let roll = services.rng.nextInt(in: 0...(totalWeight - 1))
            var cumulative = 0
            for (index, weight) in weights.enumerated() {
                cumulative += weight
                if roll < cumulative {
                    let region = degradableRegions[index]

                    let anchorIntegrity = region.anchor?.integrity ?? 0
                    let resistProb = services.degradationRules.resistanceProbability(anchorIntegrity: anchorIntegrity)
                    let resistRoll = Double(services.rng.nextInt(in: 0...99)) / 100.0

                    if resistRoll >= resistProb {
                        if var mutableRegion = regions[region.id] {
                            let newState = degradeState(mutableRegion.state)
                            mutableRegion.state = newState
                            regions[region.id] = mutableRegion
                            changes.append(.regionStateChanged(regionId: region.id, newState: newState.rawValue))
                        }
                    }
                    break
                }
            }
        }

        return changes
    }

    func degradeState(_ state: RegionState) -> RegionState {
        switch state {
        case .stable: return .borderland
        case .borderland: return .breach
        case .breach: return .breach
        }
    }
}
