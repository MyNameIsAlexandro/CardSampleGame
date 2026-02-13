/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/EnemyDefinitionTests.swift
/// Назначение: Содержит реализацию файла EnemyDefinitionTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Tests for EnemyDefinition JSON decoding
/// Verifies that enemies load correctly from JSON content packs
final class EnemyDefinitionTests: XCTestCase {

    // MARK: - Helper

    /// Creates a decoder configured the same way as PackLoader
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - Basic Decoding Tests

    func testDecodeBasicEnemy() throws {
        // Given: JSON with basic enemy data
        let json = """
        {
            "id": "test_enemy",
            "name": {"en": "Test Enemy", "ru": "Тестовый Враг"},
            "description": {"en": "A test enemy.", "ru": "Тестовый враг."},
            "health": 10,
            "power": 3,
            "defense": 1,
            "difficulty": 2,
            "enemy_type": "beast",
            "rarity": "common",
            "abilities": [],
            "loot_card_ids": [],
            "faith_reward": 5,
            "balance_delta": 0
        }
        """.data(using: .utf8)!

        // When: Decoding
        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // Then: Fields should match
        XCTAssertEqual(enemy.id, "test_enemy")
        // Check that both locales are available
        XCTAssertEqual(enemy.name.en, "Test Enemy")
        XCTAssertEqual(enemy.name.ru, "Тестовый Враг")
        XCTAssertEqual(enemy.health, 10)
        XCTAssertEqual(enemy.power, 3)
        XCTAssertEqual(enemy.defense, 1)
        XCTAssertEqual(enemy.difficulty, 2)
        XCTAssertEqual(enemy.enemyType, .beast)
        XCTAssertEqual(enemy.rarity, .common)
        XCTAssertEqual(enemy.faithReward, 5)
        XCTAssertEqual(enemy.balanceDelta, 0)
    }

    func testDecodeEnemyWithSnakeCaseFields() throws {
        // Given: JSON with snake_case fields
        let json = """
        {
            "id": "snake_case_test",
            "name": {"en": "Snake Case", "ru": "Змейка"},
            "description": {"en": "Test", "ru": "Тест"},
            "health": 8,
            "power": 2,
            "defense": 1,
            "difficulty": 1,
            "enemy_type": "spirit",
            "rarity": "uncommon",
            "abilities": [],
            "loot_card_ids": ["card1", "card2"],
            "faith_reward": 3,
            "balance_delta": -5
        }
        """.data(using: .utf8)!

        // When: Decoding
        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // Then: Snake case fields should be mapped correctly
        XCTAssertEqual(enemy.enemyType, .spirit)
        XCTAssertEqual(enemy.lootCardIds, ["card1", "card2"])
        XCTAssertEqual(enemy.faithReward, 3)
        XCTAssertEqual(enemy.balanceDelta, -5)
    }

    // MARK: - Enemy Type Tests

    func testAllEnemyTypesDecodable() throws {
        let types = ["beast", "spirit", "undead", "demon", "human", "boss"]
        let expectedTypes: [EnemyType] = [.beast, .spirit, .undead, .demon, .human, .boss]

        for (jsonType, expectedType) in zip(types, expectedTypes) {
            let json = """
            {
                "id": "type_test",
                "name": {"en": "Test", "ru": "Тест"},
                "description": {"en": "Test", "ru": "Тест"},
                "health": 5,
                "power": 1,
                "defense": 0,
                "difficulty": 1,
                "enemy_type": "\(jsonType)",
                "rarity": "common",
                "abilities": [],
                "loot_card_ids": [],
                "faith_reward": 1,
                "balance_delta": 0
            }
            """.data(using: .utf8)!

            let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)
            XCTAssertEqual(enemy.enemyType, expectedType, "Failed for type: \(jsonType)")
        }
    }

    // MARK: - Enemy Ability Tests

    func testDecodeEnemyWithBonusDamageAbility() throws {
        // Given: JSON with bonus_damage ability
        let json = """
        {
            "id": "ability_test",
            "name": {"en": "Rager", "ru": "Берсерк"},
            "description": {"en": "Test", "ru": "Тест"},
            "health": 10,
            "power": 4,
            "defense": 1,
            "difficulty": 2,
            "enemy_type": "beast",
            "rarity": "uncommon",
            "abilities": [
                {
                    "id": "rage",
                    "name": {"en": "Rage", "ru": "Ярость"},
                    "description": {"en": "Extra damage", "ru": "Доп. урон"},
                    "effect": {"bonus_damage": 3}
                }
            ],
            "loot_card_ids": [],
            "faith_reward": 4,
            "balance_delta": 0
        }
        """.data(using: .utf8)!

        // When: Decoding
        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // Then: Ability should be decoded correctly
        XCTAssertEqual(enemy.abilities.count, 1)
        XCTAssertEqual(enemy.abilities[0].id, "rage")

        if case .bonusDamage(let damage) = enemy.abilities[0].effect {
            XCTAssertEqual(damage, 3)
        } else {
            XCTFail("Expected bonusDamage effect")
        }
    }

    func testDecodeEnemyWithRegenerationAbility() throws {
        // Given: JSON with regeneration ability
        let json = """
        {
            "id": "regen_test",
            "name": {"en": "Troll", "ru": "Тролль"},
            "description": {"en": "Test", "ru": "Тест"},
            "health": 15,
            "power": 3,
            "defense": 2,
            "difficulty": 3,
            "enemy_type": "beast",
            "rarity": "rare",
            "abilities": [
                {
                    "id": "regen",
                    "name": {"en": "Regeneration", "ru": "Регенерация"},
                    "description": {"en": "Heals each turn", "ru": "Лечится каждый ход"},
                    "effect": {"regeneration": 2}
                }
            ],
            "loot_card_ids": [],
            "faith_reward": 6,
            "balance_delta": 0
        }
        """.data(using: .utf8)!

        // When: Decoding
        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // Then: Regeneration ability should be decoded
        XCTAssertEqual(enemy.abilities.count, 1)
        if case .regeneration(let amount) = enemy.abilities[0].effect {
            XCTAssertEqual(amount, 2)
        } else {
            XCTFail("Expected regeneration effect")
        }
    }

    func testDecodeEnemyWithArmorAbility() throws {
        // Given: JSON with armor ability
        let json = """
        {
            "id": "armor_test",
            "name": {"en": "Guardian", "ru": "Страж"},
            "description": {"en": "Test", "ru": "Тест"},
            "health": 12,
            "power": 2,
            "defense": 4,
            "difficulty": 2,
            "enemy_type": "spirit",
            "rarity": "uncommon",
            "abilities": [
                {
                    "id": "stone_skin",
                    "name": {"en": "Stone Skin", "ru": "Каменная Кожа"},
                    "description": {"en": "Reduces damage", "ru": "Уменьшает урон"},
                    "effect": {"armor": 2}
                }
            ],
            "loot_card_ids": [],
            "faith_reward": 5,
            "balance_delta": 5
        }
        """.data(using: .utf8)!

        // When: Decoding
        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // Then: Armor ability should be decoded
        if case .armor(let amount) = enemy.abilities[0].effect {
            XCTAssertEqual(amount, 2)
        } else {
            XCTFail("Expected armor effect")
        }
    }

    func testDecodeEnemyWithApplyCurseAbility() throws {
        // Given: JSON with apply_curse ability
        let json = """
        {
            "id": "curse_test",
            "name": {"en": "Witch", "ru": "Ведьма"},
            "description": {"en": "Test", "ru": "Тест"},
            "health": 8,
            "power": 5,
            "defense": 1,
            "difficulty": 3,
            "enemy_type": "demon",
            "rarity": "rare",
            "abilities": [
                {
                    "id": "curse",
                    "name": {"en": "Curse Touch", "ru": "Проклятие"},
                    "description": {"en": "Curses on hit", "ru": "Проклинает при ударе"},
                    "effect": {"apply_curse": "weakness"}
                }
            ],
            "loot_card_ids": [],
            "faith_reward": 7,
            "balance_delta": -10
        }
        """.data(using: .utf8)!

        // When: Decoding
        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // Then: Apply curse ability should be decoded
        if case .applyCurse(let curseId) = enemy.abilities[0].effect {
            XCTAssertEqual(curseId, "weakness")
        } else {
            XCTFail("Expected applyCurse effect")
        }
    }

    // MARK: - Card Conversion Tests

    func testEnemyToCardConversion() throws {
        // Given: Enemy definition
        let json = """
        {
            "id": "card_test",
            "name": {"en": "Wild Beast", "ru": "Дикий Зверь"},
            "description": {"en": "A wild beast.", "ru": "Дикий зверь."},
            "health": 8,
            "power": 3,
            "defense": 1,
            "difficulty": 1,
            "enemy_type": "beast",
            "rarity": "common",
            "abilities": [],
            "loot_card_ids": [],
            "faith_reward": 2,
            "balance_delta": 0
        }
        """.data(using: .utf8)!

        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // When: Converting to card
        let card = enemy.toCard(localizationManager: LocalizationManager())

        // Then: Card should have correct values
        // Card name depends on system locale - just verify it's one of the localized values
        XCTAssertTrue(card.name == "Wild Beast" || card.name == "Дикий Зверь")
        XCTAssertEqual(card.type, .monster)
        XCTAssertEqual(card.health, 8)
        XCTAssertEqual(card.power, 3)
        XCTAssertEqual(card.defense, 1)
        XCTAssertEqual(card.rarity, .common)
    }

    // MARK: - Will & Resonance Behavior Tests

    func testWillFieldIsOptional() throws {
        // Given: JSON without will field (legacy format)
        let json = """
        {
            "id": "no_will",
            "name": {"en": "Beast", "ru": "Зверь"},
            "description": {"en": "Test", "ru": "Тест"},
            "health": 10, "power": 3, "defense": 1, "difficulty": 1,
            "enemy_type": "beast", "rarity": "common",
            "abilities": [], "loot_card_ids": [],
            "faith_reward": 1, "balance_delta": 0
        }
        """.data(using: .utf8)!

        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)
        XCTAssertNil(enemy.will)
        XCTAssertNil(enemy.resonanceBehavior)
    }

    func testResonanceBehaviorDecodes() throws {
        // Given: JSON with will and resonance_behavior
        let json = """
        {
            "id": "spirit_enemy",
            "name": {"en": "Spirit", "ru": "Дух"},
            "description": {"en": "Test", "ru": "Тест"},
            "health": 12, "power": 4, "defense": 2, "difficulty": 3,
            "will": 5,
            "enemy_type": "spirit", "rarity": "uncommon",
            "resonance_behavior": {
                "deepNav": {"power_delta": 2, "defense_delta": 1, "health_delta": 5, "will_delta": 3},
                "deepPrav": {"power_delta": -1, "defense_delta": -1, "health_delta": -3, "will_delta": -2}
            },
            "abilities": [], "loot_card_ids": [],
            "faith_reward": 5, "balance_delta": 0
        }
        """.data(using: .utf8)!

        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)
        XCTAssertEqual(enemy.will, 5)
        XCTAssertNotNil(enemy.resonanceBehavior)
        XCTAssertEqual(enemy.resonanceBehavior?["deepNav"]?.powerDelta, 2)
        XCTAssertEqual(enemy.resonanceBehavior?["deepNav"]?.healthDelta, 5)
        XCTAssertEqual(enemy.resonanceBehavior?["deepPrav"]?.powerDelta, -1)
    }

    // MARK: - Multiple Abilities Test

    func testDecodeEnemyWithMultipleAbilities() throws {
        // Given: Boss enemy with multiple abilities
        let json = """
        {
            "id": "boss_test",
            "name": {"en": "Leshy Guardian", "ru": "Леший-Хранитель"},
            "description": {"en": "Ancient guardian.", "ru": "Древний страж."},
            "health": 25,
            "power": 7,
            "defense": 4,
            "difficulty": 5,
            "enemy_type": "boss",
            "rarity": "legendary",
            "abilities": [
                {
                    "id": "nature_wrath",
                    "name": {"en": "Nature's Wrath", "ru": "Гнев Природы"},
                    "description": {"en": "Regenerates health", "ru": "Восстанавливает здоровье"},
                    "effect": {"regeneration": 3}
                },
                {
                    "id": "ancient_armor",
                    "name": {"en": "Ancient Armor", "ru": "Древняя Броня"},
                    "description": {"en": "Thick bark", "ru": "Толстая кора"},
                    "effect": {"armor": 2}
                }
            ],
            "loot_card_ids": ["guardian_seal", "ancient_power"],
            "faith_reward": 20,
            "balance_delta": 20
        }
        """.data(using: .utf8)!

        // When: Decoding
        let enemy = try makeDecoder().decode(EnemyDefinition.self, from: json)

        // Then: Should have two abilities
        XCTAssertEqual(enemy.abilities.count, 2)
        XCTAssertEqual(enemy.enemyType, .boss)
        XCTAssertEqual(enemy.rarity, .legendary)
        XCTAssertEqual(enemy.lootCardIds.count, 2)
    }
}
