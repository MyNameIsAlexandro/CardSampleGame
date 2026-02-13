/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentRegistry+TestingSupport.swift
/// Назначение: Содержит реализацию файла ContentRegistry+TestingSupport.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension ContentRegistry {
    @_spi(Testing)
    public func resetForTesting() {
        unloadAllPacks()
    }

    @_spi(Testing)
    public func registerMockContent(
        regions: [String: RegionDefinition] = [:],
        events: [String: EventDefinition] = [:],
        quests: [String: QuestDefinition] = [:],
        anchors: [String: AnchorDefinition] = [:],
        heroes: [String: StandardHeroDefinition] = [:],
        cards: [String: StandardCardDefinition] = [:],
        enemies: [String: EnemyDefinition] = [:],
        fateCards: [String: FateCard] = [:],
        behaviors: [String: BehaviorDefinition] = [:],
        abilities: [String: HeroAbility] = [:],
        balanceConfig: BalanceConfiguration? = nil
    ) {
        replaceTestingContent(
            regions: regions,
            events: events,
            quests: quests,
            anchors: anchors,
            heroes: heroes,
            cards: cards,
            enemies: enemies,
            fateCards: fateCards,
            behaviors: behaviors,
            abilities: abilities,
            balanceConfig: balanceConfig
        )
    }

    @_spi(Testing)
    @discardableResult
    public func loadMockPack(_ pack: LoadedPack) -> LoadedPack {
        registerMockPackForTesting(pack)
    }

    @_spi(Testing)
    public func checkIdCollisions() -> [(entityType: String, id: String, packs: [String])] {
        var collisions: [(entityType: String, id: String, packs: [String])] = []

        var regionSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for regionId in pack.regions.keys {
                regionSources[regionId, default: []].append(packId)
            }
        }
        for (id, sources) in regionSources where sources.count > 1 {
            collisions.append(("Region", id, sources))
        }

        var eventSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for eventId in pack.events.keys {
                eventSources[eventId, default: []].append(packId)
            }
        }
        for (id, sources) in eventSources where sources.count > 1 {
            collisions.append(("Event", id, sources))
        }

        var heroSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for heroId in pack.heroes.keys {
                heroSources[heroId, default: []].append(packId)
            }
        }
        for (id, sources) in heroSources where sources.count > 1 {
            collisions.append(("Hero", id, sources))
        }

        var cardSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for cardId in pack.cards.keys {
                cardSources[cardId, default: []].append(packId)
            }
        }
        for (id, sources) in cardSources where sources.count > 1 {
            collisions.append(("Card", id, sources))
        }

        return collisions
    }
}
