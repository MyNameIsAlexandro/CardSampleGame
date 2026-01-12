import Foundation

// MARK: - Localization Helper
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Localization Keys
enum L10n {
    // Main Screen
    static let gameTitle = "game.title"
    static let characterSelectTitle = "character.select.title"
    static let characterStats = "character.stats"
    static let characterAbilities = "character.abilities"
    static let buttonStartAdventure = "button.start.adventure"

    // Game Board
    static let turnLabel = "turn.label"
    static let buttonNextPhase = "button.next.phase"
    static let buttonExplore = "button.explore"
    static let buttonRollDice = "button.roll.dice"
    static let diceResult = "dice.result"
    static let diceRollTitle = "dice.roll.title"
    static let diceRollMessage = "dice.roll.message"
    static let buttonOk = "button.ok"

    // Game Phases
    static let phaseSetup = "phase.setup"
    static let phaseExploration = "phase.exploration"
    static let phaseEncounter = "phase.encounter"
    static let phaseCombat = "phase.combat"
    static let phaseEndTurn = "phase.end.turn"
    static let phaseGameOver = "phase.game.over"

    // Encounter
    static let encounterActive = "encounter.active"

    // Deck
    static let deckEncounters = "deck.encounters"
    static let deckLocations = "deck.locations"
    static let deckCards = "deck.cards"

    // Player Hand
    static let playerHandTitle = "player.hand.title"
    static let playerDiscardPile = "player.discard.pile"
    static let playerDeckRemaining = "player.deck.remaining"

    // Card Types
    static let cardTypeCharacter = "card.type.character"
    static let cardTypeWeapon = "card.type.weapon"
    static let cardTypeSpell = "card.type.spell"
    static let cardTypeArmor = "card.type.armor"
    static let cardTypeItem = "card.type.item"
    static let cardTypeBlessing = "card.type.blessing"
    static let cardTypeMonster = "card.type.monster"
    static let cardTypeLocation = "card.type.location"
    static let cardTypeAlly = "card.type.ally"

    // Stats
    static let statHealth = "stat.health"
    static let statPower = "stat.power"
    static let statDefense = "stat.defense"
    static let statStrength = "stat.strength"
    static let statDexterity = "stat.dexterity"
    static let statConstitution = "stat.constitution"
    static let statIntelligence = "stat.intelligence"
    static let statWisdom = "stat.wisdom"
    static let statCharisma = "stat.charisma"

    // Rarity
    static let rarityCommon = "rarity.common"
    static let rarityUncommon = "rarity.uncommon"
    static let rarityRare = "rarity.rare"
    static let rarityEpic = "rarity.epic"
    static let rarityLegendary = "rarity.legendary"

    // Damage Types
    static let damagePhysical = "damage.physical"
    static let damageFire = "damage.fire"
    static let damageCold = "damage.cold"
    static let damageLightning = "damage.lightning"
    static let damagePoison = "damage.poison"
    static let damageAcid = "damage.acid"
    static let damageHoly = "damage.holy"
    static let damageShadow = "damage.shadow"

    // Actions
    static let actionPlay = "action.play"
    static let actionDiscard = "action.discard"
    static let actionExamine = "action.examine"
}
