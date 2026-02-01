import Testing
@testable import TwilightEngine

@Suite("EnginePlayerManager Tests", .serialized)
struct EnginePlayerManagerTests {

    private func makeEngine() -> TwilightGameEngine {
        TestContentLoader.loadContentPacksIfNeeded()
        let registry = ContentRegistry.shared
        return TwilightGameEngine(registry: registry)
    }

    // MARK: - Basic State

    @Test("Initialize from hero sets stats from HeroRegistry")
    func testInitializeFromHero() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "Test", heroId: "zhrets", startingDeck: [])

        #expect(engine.player.name == "Test")
        #expect(engine.player.heroId == "zhrets")
        #expect(engine.player.health > 0)
        #expect(engine.player.maxHealth > 0)
    }

    @Test("Initialize without hero uses balance config defaults")
    func testInitializeWithoutHero() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "Default", heroId: nil, startingDeck: [])

        #expect(engine.player.name == "Default")
        #expect(engine.player.heroId == nil)
        #expect(engine.player.health > 0)
        #expect(engine.player.strength == 5)
    }

    // MARK: - Curses

    @Test("Apply curse adds to active curses")
    func testApplyCurse() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        engine.player.applyCurse(type: .weakness, duration: 3)

        #expect(engine.player.activeCurses.count == 1)
        #expect(engine.player.hasCurse(.weakness))
    }

    @Test("Remove curse by type")
    func testRemoveCurseByType() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        engine.player.applyCurse(type: .weakness, duration: 3)
        engine.player.applyCurse(type: .fear, duration: 2)
        engine.player.removeCurse(type: .weakness)

        #expect(!engine.player.hasCurse(.weakness))
        #expect(engine.player.hasCurse(.fear))
    }

    @Test("Tick curses reduces duration and removes expired")
    func testTickCurses() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        engine.player.applyCurse(type: .weakness, duration: 1)
        engine.player.applyCurse(type: .fear, duration: 2)
        engine.player.tickCurses()

        #expect(engine.player.activeCurses.count == 1)
        #expect(engine.player.hasCurse(.fear))
        #expect(!engine.player.hasCurse(.weakness))
    }

    @Test("Curse damage dealt modifier: weakness -1, shadowOfNav +3")
    func testCurseDamageDealtModifier() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])

        #expect(engine.player.getCurseDamageDealtModifier() == 0)

        engine.player.applyCurse(type: .weakness, duration: 3)
        #expect(engine.player.getCurseDamageDealtModifier() == -1)

        engine.player.applyCurse(type: .shadowOfNav, duration: 3)
        #expect(engine.player.getCurseDamageDealtModifier() == 2) // -1 + 3
    }

    @Test("Curse damage taken modifier: fear +1")
    func testCurseDamageTakenModifier() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])

        #expect(engine.player.getCurseDamageTakenModifier() == 0)

        engine.player.applyCurse(type: .fear, duration: 3)
        #expect(engine.player.getCurseDamageTakenModifier() == 1)
    }

    // MARK: - Damage Calculation

    @Test("Calculate damage dealt includes curse modifiers")
    func testCalculateDamageDealt() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])

        #expect(engine.player.calculateDamageDealt(5) == 5)

        engine.player.applyCurse(type: .weakness, duration: 3)
        #expect(engine.player.calculateDamageDealt(5) == 4)
    }

    @Test("Take damage with modifiers applies curse bonus")
    func testTakeDamageWithModifiers() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        let startHealth = engine.player.health

        engine.player.applyCurse(type: .fear, duration: 3)
        engine.player.takeDamageWithModifiers(3) // 3 + 1 fear = 4

        #expect(engine.player.health == startHealth - 4)
    }

    @Test("Take damage cannot go below zero")
    func testTakeDamageFloor() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        engine.player.takeDamageWithModifiers(999)

        #expect(engine.player.health == 0)
    }

    // MARK: - Setters

    @Test("SetMaxHealth clamps health to new max")
    func testSetMaxHealthClampsHealth() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        engine.player.health = 20
        engine.player.setMaxHealth(10)

        #expect(engine.player.maxHealth == 10)
        #expect(engine.player.health == 10)
    }

    @Test("SetFaith clamps to valid range")
    func testSetFaithClamps() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        engine.player.setFaith(999)

        #expect(engine.player.faith == engine.player.maxFaith)

        engine.player.setFaith(-5)
        #expect(engine.player.faith == 0)
    }


    @Test("Engine setPlayerHealth routes through player")
    func testEngineSetPlayerHealth() {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "T", heroId: nil, startingDeck: [])
        engine.player.setHealth(5)

        #expect(engine.player.health == 5)
    }
}
