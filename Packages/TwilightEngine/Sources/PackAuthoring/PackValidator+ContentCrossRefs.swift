/// Файл: Packages/TwilightEngine/Sources/PackAuthoring/PackValidator+ContentCrossRefs.swift
/// Назначение: Содержит реализацию файла PackValidator+ContentCrossRefs.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

extension PackValidator {
    // MARK: - Phase 3: Content Validation

    func validateContent() {
        guard let manifest = manifest else { return }

        do {
            loadedPack = try PackLoader.load(manifest: manifest, from: packURL)
            addInfo("Content", "Loaded \(loadedPack?.regions.count ?? 0) regions, \(loadedPack?.events.count ?? 0) events, \(loadedPack?.heroes.count ?? 0) heroes, \(loadedPack?.cards.count ?? 0) cards")
        } catch {
            addError("Content", "Failed to load pack content: \(error.localizedDescription)")
            return
        }

        guard let pack = loadedPack else { return }

        for (id, region) in pack.regions {
            validateRegion(id: id, region: region)
        }
        for (id, event) in pack.events {
            validateEvent(id: id, event: event)
        }
        for (id, hero) in pack.heroes {
            validateHero(id: id, hero: hero)
        }
        for (id, card) in pack.cards {
            validateCard(id: id, card: card)
        }
        for (id, enemy) in pack.enemies {
            validateEnemy(id: id, enemy: enemy)
        }
        for (id, anchor) in pack.anchors {
            validateAnchor(id: id, anchor: anchor)
        }
    }

    func validateRegion(id: String, region: RegionDefinition) {
        if region.title.en.isEmpty {
            addError("Region", "Region '\(id)' has empty English title")
        }

        if region.neighborIds.isEmpty {
            addWarning("Region", "Region '\(id)' has no neighbors (isolated)")
        }

        if region.neighborIds.contains(id) {
            addError("Region", "Region '\(id)' lists itself as neighbor")
        }
    }

    func validateEvent(id: String, event: EventDefinition) {
        if event.title.en.isEmpty {
            addError("Event", "Event '\(id)' has empty English title")
        }

        if event.choices.isEmpty {
            addWarning("Event", "Event '\(id)' has no choices")
        }

        var choiceIds = Set<String>()
        for choice in event.choices {
            if choiceIds.contains(choice.id) {
                addError("Event", "Event '\(id)' has duplicate choice ID: \(choice.id)")
            }
            choiceIds.insert(choice.id)

            if choice.label.en.isEmpty {
                addWarning("Event", "Event '\(id)' choice '\(choice.id)' has empty label")
            }
        }

        if event.weight <= 0 {
            addWarning("Event", "Event '\(id)' has non-positive weight: \(event.weight)")
        }
    }

    func validateHero(id: String, hero: StandardHeroDefinition) {
        if hero.name.isEmpty {
            addError("Hero", "Hero '\(id)' has empty name")
        }

        if hero.startingDeckCardIDs.isEmpty {
            addWarning("Hero", "Hero '\(id)' has empty starting deck")
        }

        let uniqueCards = Set(hero.startingDeckCardIDs)
        if uniqueCards.count != hero.startingDeckCardIDs.count {
            addInfo("Hero", "Hero '\(id)' has duplicate cards in starting deck")
        }
    }

    func validateCard(id: String, card: StandardCardDefinition) {
        if card.name.isEmpty {
            addError("Card", "Card '\(id)' has empty name")
        }

        if card.faithCost < 0 {
            addError("Card", "Card '\(id)' has negative faith cost: \(card.faithCost)")
        }

        if let cost = card.cost, cost < 0 {
            addError("Card", "Card '\(id)' has negative energy cost: \(cost)")
        }

        if card.exhaust && card.abilities.isEmpty && card.power == nil {
            addWarning("Card", "Card '\(id)' has exhaust but no abilities or power")
        }
    }

    func validateEnemy(id: String, enemy: EnemyDefinition) {
        if enemy.name.isEmpty {
            addError("Enemy", "Enemy '\(id)' has empty name")
        }

        if enemy.health <= 0 {
            addError("Enemy", "Enemy '\(id)' has non-positive health: \(enemy.health)")
        }

        if enemy.power < 0 {
            addError("Enemy", "Enemy '\(id)' has negative power: \(enemy.power)")
        }

        if enemy.defense < 0 {
            addWarning("Enemy", "Enemy '\(id)' has negative defense: \(enemy.defense)")
        }

        if let will = enemy.will, will < 0 {
            addError("Enemy", "Enemy '\(id)' has negative will: \(will)")
        }

        if enemy.faithReward < 0 {
            addError("Enemy", "Enemy '\(id)' has negative faith reward: \(enemy.faithReward)")
        }

        if enemy.difficulty < 1 || enemy.difficulty > 5 {
            addWarning("Enemy", "Enemy '\(id)' has invalid difficulty: \(enemy.difficulty) (expected 1-5)")
        }

        if let pattern = enemy.pattern {
            if pattern.isEmpty {
                addWarning("Enemy", "Enemy '\(id)' has empty pattern array")
            }
            for (index, step) in pattern.enumerated() {
                if step.type == .attack && step.value <= 0 {
                    addWarning("Enemy", "Enemy '\(id)' pattern step \(index) is attack with value \(step.value)")
                }
            }
        }
    }

    func validateAnchor(id: String, anchor: AnchorDefinition) {
        if anchor.title.en.isEmpty {
            addError("Anchor", "Anchor '\(id)' has empty English title")
        }

        if anchor.initialIntegrity < 0 || anchor.initialIntegrity > anchor.maxIntegrity {
            addError("Anchor", "Anchor '\(id)' has invalid initial integrity: \(anchor.initialIntegrity) (max: \(anchor.maxIntegrity))")
        }

        if anchor.maxIntegrity <= 0 {
            addError("Anchor", "Anchor '\(id)' has non-positive max integrity: \(anchor.maxIntegrity)")
        }
    }

    // MARK: - Phase 4: Cross-Reference Validation

    func validateCrossReferences() {
        guard let pack = loadedPack else { return }

        for (id, region) in pack.regions {
            for neighborId in region.neighborIds where pack.regions[neighborId] == nil {
                addError("Reference", "Region '\(id)' references non-existent neighbor '\(neighborId)'")
            }
        }

        for (id, region) in pack.regions {
            for neighborId in region.neighborIds {
                if let neighbor = pack.regions[neighborId], !neighbor.neighborIds.contains(id) {
                    addWarning("Reference", "Region '\(id)' → '\(neighborId)' is not bidirectional")
                }
            }
        }

        for (id, anchor) in pack.anchors where pack.regions[anchor.regionId] == nil {
            addError("Reference", "Anchor '\(id)' references non-existent region '\(anchor.regionId)'")
        }

        for (id, event) in pack.events {
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds where pack.regions[regionId] == nil {
                    addError("Reference", "Event '\(id)' references non-existent region '\(regionId)'")
                }
            }
        }

        for (id, hero) in pack.heroes {
            for cardId in hero.startingDeckCardIDs where pack.cards[cardId] == nil {
                addError("Reference", "Hero '\(id)' references non-existent card '\(cardId)'")
            }
        }

        for (id, enemy) in pack.enemies {
            for lootCardId in enemy.lootCardIds where pack.cards[lootCardId] == nil {
                addWarning("Reference", "Enemy '\(id)' references loot card '\(lootCardId)' not found in pack")
            }
        }

        if let manifest = manifest, let entryRegionId = manifest.entryRegionId, pack.regions[entryRegionId] == nil {
            addError("Reference", "Manifest entryRegionId '\(entryRegionId)' not found in regions")
        }

        validateDuplicateIds(pack)
    }

    func validateDuplicateIds(_ pack: LoadedPack) {
        var allIds: [String: [String]] = [:]

        for id in pack.regions.keys { allIds[id, default: []].append("Region") }
        for id in pack.events.keys { allIds[id, default: []].append("Event") }
        for id in pack.heroes.keys { allIds[id, default: []].append("Hero") }
        for id in pack.cards.keys { allIds[id, default: []].append("Card") }
        for id in pack.enemies.keys { allIds[id, default: []].append("Enemy") }
        for id in pack.anchors.keys { allIds[id, default: []].append("Anchor") }
        for id in pack.quests.keys { allIds[id, default: []].append("Quest") }
        for id in pack.behaviors.keys { allIds[id, default: []].append("Behavior") }
        for id in pack.fateCards.keys { allIds[id, default: []].append("FateCard") }

        for (id, categories) in allIds where categories.count > 1 {
            addWarning("Reference", "ID '\(id)' used in multiple categories: \(categories.joined(separator: ", "))")
        }
    }
}
