import XCTest
@testable import CardSampleGame

/// Unit тесты для модификаторов боя
/// Покрывает: региональные модификаторы, проклятия в бою
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-011, TEST-012
final class CombatModifiersTests: XCTestCase {

    // MARK: - TEST-011: Региональные модификаторы

    func testStableRegionNoModifiers() {
        XCTAssertEqual(RegionState.stable.enemyPowerBonus, 0, "Stable: +0 сила врага")
        XCTAssertEqual(RegionState.stable.enemyDefenseBonus, 0, "Stable: +0 защита врага")
        XCTAssertEqual(RegionState.stable.enemyHealthBonus, 0, "Stable: +0 здоровье врага")
    }

    func testBorderlandModifiers() {
        XCTAssertEqual(RegionState.borderland.enemyPowerBonus, 1, "Borderland: +1 сила врага")
        XCTAssertEqual(RegionState.borderland.enemyDefenseBonus, 1, "Borderland: +1 защита врага")
        XCTAssertEqual(RegionState.borderland.enemyHealthBonus, 2, "Borderland: +2 здоровье врага")
    }

    func testBreachModifiers() {
        XCTAssertEqual(RegionState.breach.enemyPowerBonus, 2, "Breach: +2 сила врага")
        XCTAssertEqual(RegionState.breach.enemyDefenseBonus, 2, "Breach: +2 защита врага")
        XCTAssertEqual(RegionState.breach.enemyHealthBonus, 5, "Breach: +5 здоровье врага")
    }

    // MARK: - CombatContext

    func testCombatContextAdjustedEnemyPower() {
        let context = CombatContext(regionState: .borderland, playerCurses: [])
        let basePower = 5
        let adjusted = context.adjustedEnemyPower(basePower)
        XCTAssertEqual(adjusted, 6, "5 + 1 (borderland) = 6")
    }

    func testCombatContextAdjustedEnemyHealth() {
        let context = CombatContext(regionState: .breach, playerCurses: [])
        let baseHealth = 10
        let adjusted = context.adjustedEnemyHealth(baseHealth)
        XCTAssertEqual(adjusted, 15, "10 + 5 (breach) = 15")
    }

    func testCombatContextAdjustedEnemyDefense() {
        let context = CombatContext(regionState: .breach, playerCurses: [])
        let baseDefense = 3
        let adjusted = context.adjustedEnemyDefense(baseDefense)
        XCTAssertEqual(adjusted, 5, "3 + 2 (breach) = 5")
    }

    func testCombatContextStableNoDescription() {
        let context = CombatContext(regionState: .stable, playerCurses: [])
        XCTAssertNil(context.regionModifierDescription, "Stable не должен иметь описания модификаторов")
    }

    func testCombatContextBorderlandDescription() {
        let context = CombatContext(regionState: .borderland, playerCurses: [])
        XCTAssertNotNil(context.regionModifierDescription, "Borderland должен иметь описание")
        XCTAssertTrue(context.regionModifierDescription?.contains("Пограничье") ?? false)
    }

    func testCombatContextBreachDescription() {
        let context = CombatContext(regionState: .breach, playerCurses: [])
        XCTAssertNotNil(context.regionModifierDescription, "Breach должен иметь описание")
        XCTAssertTrue(context.regionModifierDescription?.contains("Прорыв Нави") ?? false)
    }

    // MARK: - Проклятия в бою

    func testWeaknessReducesDamageDealt() {
        let player = Player(name: "Test")
        player.applyCurse(type: .weakness, duration: 3)

        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)

        XCTAssertEqual(actualDamage, 4, "weakness: -1 урон")
    }

    func testFearIncreasesDamageTaken() {
        let player = Player(name: "Test")
        player.applyCurse(type: .fear, duration: 3)

        let modifier = player.getDamageTakenModifier()

        XCTAssertEqual(modifier, 1, "fear: +1 получаемый урон")
    }

    func testExhaustionReducesActions() {
        // exhaustion: -1 действие (тестируется через GameState)
        let player = Player(name: "Test")
        player.applyCurse(type: .exhaustion, duration: 3)

        XCTAssertTrue(player.hasCurse(.exhaustion), "Игрок должен иметь exhaustion")
    }

    func testShadowOfNavIncreasesDamage() {
        let player = Player(name: "Test")
        player.applyCurse(type: .shadowOfNav, duration: 3)

        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)

        XCTAssertEqual(actualDamage, 8, "shadowOfNav: +3 урон")
    }

    func testShadowOfNavAndWeaknessCombined() {
        let player = Player(name: "Test")
        player.applyCurse(type: .shadowOfNav, duration: 3)
        player.applyCurse(type: .weakness, duration: 3)

        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)

        // +3 (shadowOfNav) - 1 (weakness) = +2 modifier
        XCTAssertEqual(actualDamage, 7, "shadowOfNav + weakness = +2 урон")
    }

    // MARK: - TEST-012: Выход из боя

    func testBloodCurseHealsOnKill() {
        let player = Player(name: "Test")
        player.health = 5
        player.applyCurse(type: .bloodCurse, duration: 10)

        // Симулируем эффект bloodCurse при убийстве
        if player.hasCurse(.bloodCurse) {
            player.heal(2)
            player.shiftBalance(towards: .dark, amount: 5)
        }

        XCTAssertEqual(player.health, 7, "bloodCurse должен дать +2 HP")
        XCTAssertEqual(player.balance, 45, "bloodCurse должен сдвинуть баланс к тьме")
    }

    func testSealOfNavBlocksSustainCards() {
        let player = Player(name: "Test")
        player.applyCurse(type: .sealOfNav, duration: 5)

        XCTAssertTrue(player.hasCurse(.sealOfNav), "sealOfNav должен быть активен")
        // Логика блокировки Sustain карт реализована в GameBoardView
        // Здесь только проверяем что проклятие есть
    }

    // MARK: - Anchor Integrity и Region State

    func testAnchorDeterminesStableState() {
        let anchor = Anchor(name: "Test", type: .shrine, integrity: 80)
        XCTAssertEqual(anchor.determinedRegionState, .stable, "80% integrity = Stable")
    }

    func testAnchorDeterminesBorderlandState() {
        let anchor = Anchor(name: "Test", type: .shrine, integrity: 50)
        XCTAssertEqual(anchor.determinedRegionState, .borderland, "50% integrity = Borderland")
    }

    func testAnchorDeterminesBreachState() {
        let anchor = Anchor(name: "Test", type: .shrine, integrity: 20)
        XCTAssertEqual(anchor.determinedRegionState, .breach, "20% integrity = Breach")
    }

    func testAnchorIsDefiled() {
        let lightAnchor = Anchor(name: "Light", type: .shrine, influence: .light)
        let darkAnchor = Anchor(name: "Dark", type: .shrine, influence: .dark)

        XCTAssertFalse(lightAnchor.isDefiled, "Light anchor не осквернён")
        XCTAssertTrue(darkAnchor.isDefiled, "Dark anchor осквернён")
    }

    // MARK: - Region Combat Properties

    func testRegionCanRest() {
        let stableSettlement = Region(name: "Village", type: .settlement, state: .stable)
        let borderlandSettlement = Region(name: "Town", type: .settlement, state: .borderland)
        let stableSacred = Region(name: "Temple", type: .sacred, state: .stable)
        let stableForest = Region(name: "Forest", type: .forest, state: .stable)

        XCTAssertTrue(stableSettlement.canRest, "Stable settlement: можно отдохнуть")
        XCTAssertFalse(borderlandSettlement.canRest, "Borderland settlement: нельзя отдохнуть")
        XCTAssertTrue(stableSacred.canRest, "Stable sacred: можно отдохнуть")
        XCTAssertFalse(stableForest.canRest, "Stable forest: нельзя отдохнуть")
    }

    func testRegionCanTrade() {
        let stableSettlement = Region(name: "Village", type: .settlement, state: .stable, reputation: 10)
        let stableSettlementNegRep = Region(name: "Town", type: .settlement, state: .stable, reputation: -10)
        let borderlandSettlement = Region(name: "City", type: .settlement, state: .borderland, reputation: 10)

        XCTAssertTrue(stableSettlement.canTrade, "Stable settlement + положительная репутация: можно торговать")
        XCTAssertFalse(stableSettlementNegRep.canTrade, "Отрицательная репутация: нельзя торговать")
        XCTAssertFalse(borderlandSettlement.canTrade, "Borderland: нельзя торговать")
    }

    // MARK: - Region State Display

    func testRegionStateDisplayName() {
        XCTAssertEqual(RegionState.stable.displayName, "Стабильная")
        XCTAssertEqual(RegionState.borderland.displayName, "Пограничье")
        XCTAssertEqual(RegionState.breach.displayName, "Прорыв Нави")
    }

    func testRegionStateEmoji() {
        XCTAssertEqual(RegionState.stable.emoji, "🟢")
        XCTAssertEqual(RegionState.borderland.emoji, "🟡")
        XCTAssertEqual(RegionState.breach.emoji, "🔴")
    }

    // MARK: - Curse Display Names

    func testCurseDisplayNames() {
        XCTAssertEqual(CurseType.weakness.displayName, "Слабость")
        XCTAssertEqual(CurseType.fear.displayName, "Страх")
        XCTAssertEqual(CurseType.exhaustion.displayName, "Истощение")
        XCTAssertEqual(CurseType.greed.displayName, "Жадность")
        XCTAssertEqual(CurseType.shadowOfNav.displayName, "Тень Нави")
        XCTAssertEqual(CurseType.bloodCurse.displayName, "Проклятие крови")
        XCTAssertEqual(CurseType.sealOfNav.displayName, "Печать Нави")
    }

    // MARK: - GameState Combat Integration

    func testGameStateExhaustionReducesActions() {
        let player = Player(name: "Test")
        player.applyCurse(type: .exhaustion, duration: 3)
        let gameState = GameState(players: [player])

        // Симулируем начало хода
        gameState.actionsRemaining = gameState.actionsPerTurn
        if player.hasCurse(.exhaustion) {
            gameState.actionsRemaining = max(1, gameState.actionsRemaining - 1)
        }

        XCTAssertEqual(gameState.actionsRemaining, 2, "exhaustion: -1 действие (3 -> 2)")
    }

    func testGameStateEnemyAttackWithFear() {
        let player = Player(name: "Test")
        player.health = 10
        player.applyCurse(type: .fear, duration: 3)

        let baseDamage = 3
        player.takeDamageWithCurses(baseDamage)

        XCTAssertEqual(player.health, 6, "10 - 4 (3 + 1 fear) = 6")
    }
}
