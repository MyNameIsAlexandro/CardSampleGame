import XCTest
@testable import PackEditorKit

final class RealPackLoadTests: XCTestCase {

    func testLoadCoreHeroesPack() throws {
        let store = PackStore()
        // Navigate from PackEditorKit package root up to project root
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/PackEditorKitTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // PackEditorKit/
            .deletingLastPathComponent() // Packages/
        let coreHeroesURL = packageRoot
            .appendingPathComponent("CharacterPacks/CoreHeroes/Sources/CoreHeroesContent/Resources/CoreHeroes")

        do {
            try store.loadPack(from: coreHeroesURL)
        } catch {
            XCTFail("Failed to load CoreHeroes pack: \(error)")
            return
        }

        XCTAssertGreaterThan(store.heroes.count, 0, "Should have loaded heroes")
        XCTAssertGreaterThan(store.cards.count, 0, "Should have loaded cards")
        print("Loaded \(store.heroes.count) heroes, \(store.cards.count) cards")
    }

    func testLoadTwilightMarchesActIPack() throws {
        let store = PackStore()
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let actIURL = packageRoot
            .appendingPathComponent("StoryPacks/Season1/TwilightMarchesActI/Sources/TwilightMarchesActIContent/Resources/TwilightMarchesActI")

        do {
            try store.loadPack(from: actIURL)
        } catch {
            XCTFail("Failed to load TwilightMarchesActI pack: \(error)")
            return
        }

        XCTAssertGreaterThan(store.enemies.count, 0, "Should have loaded enemies")
        XCTAssertGreaterThan(store.regions.count, 0, "Should have loaded regions")
        print("Loaded \(store.enemies.count) enemies, \(store.regions.count) regions, \(store.cards.count) cards, \(store.events.count) events")
    }
}
