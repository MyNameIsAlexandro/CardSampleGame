import Foundation

struct Card: Identifiable, Codable, Hashable {
    let id: UUID
    let definitionId: String  // Content Pack ID (e.g., "leshy_guardian" for enemies)
    let name: String
    let type: CardType
    let rarity: CardRarity
    let description: String
    let imageURL: String?

    // Stats
    var power: Int?
    var defense: Int?
    var health: Int?
    var cost: Int?

    // Abilities and traits
    var abilities: [CardAbility]
    var traits: [String]

    // Card-specific properties
    var damageType: DamageType?
    var range: Int?

    // Twilight Marches mechanics
    var balance: CardBalance?  // Light/Dark alignment
    var realm: Realm?  // Yav/Nav/Prav
    var curseType: CurseType?  // For curse cards
    var expansionSet: String?  // For DLC/expansions tracking
    var role: CardRole?  // Functional role in campaign (Sustain/Control/Power/Utility)
    var regionRequirement: String?  // Required region flag to purchase (for story pool)
    var faithCost: Int  // Cost in faith to purchase from market

    init(
        id: UUID = UUID(),
        definitionId: String = "",
        name: String,
        type: CardType,
        rarity: CardRarity = .common,
        description: String,
        imageURL: String? = nil,
        power: Int? = nil,
        defense: Int? = nil,
        health: Int? = nil,
        cost: Int? = nil,
        abilities: [CardAbility] = [],
        traits: [String] = [],
        damageType: DamageType? = nil,
        range: Int? = nil,
        balance: CardBalance? = nil,
        realm: Realm? = nil,
        curseType: CurseType? = nil,
        expansionSet: String? = nil,
        role: CardRole? = nil,
        regionRequirement: String? = nil,
        faithCost: Int = 3
    ) {
        self.id = id
        self.definitionId = definitionId
        self.name = name
        self.type = type
        self.rarity = rarity
        self.description = description
        self.imageURL = imageURL
        self.power = power
        self.defense = defense
        self.health = health
        self.cost = cost
        self.abilities = abilities
        self.traits = traits
        self.damageType = damageType
        self.range = range
        self.balance = balance
        self.realm = realm
        self.curseType = curseType
        self.expansionSet = expansionSet
        self.role = role
        self.regionRequirement = regionRequirement
        self.faithCost = faithCost
    }

    /// Calculate adjusted cost based on player's Light/Dark balance
    /// See EXPLORATION_CORE_DESIGN.md, section 23.4
    func adjustedFaithCost(playerBalance: Int) -> Int {
        guard let cardBalance = balance else { return faithCost }

        switch cardBalance {
        case .light:
            // Light cards cheaper when player is aligned to light (>50)
            let discount = max(0, (playerBalance - 50) / 20)  // 0 to +2 discount
            return max(1, faithCost - discount)

        case .dark:
            // Dark cards cheaper when player is aligned to dark (<50)
            let discount = max(0, (50 - playerBalance) / 20)  // 0 to +2 discount
            return max(1, faithCost - discount)

        case .neutral:
            return faithCost  // Neutral always base cost
        }
    }
}

struct CardAbility: Identifiable, Hashable {
    let id: UUID
    let stringId: String?
    let name: String
    let description: String
    let effect: AbilityEffect

    init(
        id: UUID = UUID(),
        stringId: String? = nil,
        name: String,
        description: String,
        effect: AbilityEffect
    ) {
        self.id = id
        self.stringId = stringId
        self.name = name
        self.description = description
        self.effect = effect
    }
}

// MARK: - CardAbility Codable

extension CardAbility: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameRu = "name_ru"
        case description
        case descriptionRu = "description_ru"
        case effect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode id as UUID first, then as String
        if let uuidId = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuidId
            self.stringId = nil
        } else if let stringId = try? container.decode(String.self, forKey: .id) {
            self.stringId = stringId
            // Generate deterministic UUID from string
            self.id = UUID(uuidString: stringId.stableUUID) ?? UUID()
        } else {
            self.id = UUID()
            self.stringId = nil
        }

        // Handle localized name
        let name = try container.decode(String.self, forKey: .name)
        let nameRu = try container.decodeIfPresent(String.self, forKey: .nameRu)
        if Locale.current.language.languageCode?.identifier == "ru", let ru = nameRu {
            self.name = ru
        } else {
            self.name = name
        }

        // Handle localized description
        let description = try container.decode(String.self, forKey: .description)
        let descriptionRu = try container.decodeIfPresent(String.self, forKey: .descriptionRu)
        if Locale.current.language.languageCode?.identifier == "ru", let ru = descriptionRu {
            self.description = ru
        } else {
            self.description = description
        }

        self.effect = try container.decode(AbilityEffect.self, forKey: .effect)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let stringId = stringId {
            try container.encode(stringId, forKey: .id)
        } else {
            try container.encode(id, forKey: .id)
        }
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(effect, forKey: .effect)
    }
}

private extension String {
    var stableUUID: String {
        var hash: UInt64 = 5381
        for char in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        let hex = String(format: "%016llX", hash)
        let padded = hex.padding(toLength: 32, withPad: "0", startingAt: 0)
        let chars = Array(padded)
        return "\(String(chars[0..<8]))-\(String(chars[8..<12]))-\(String(chars[12..<16]))-\(String(chars[16..<20]))-\(String(chars[20..<32]))"
    }
}

enum AbilityEffect: Hashable {
    case damage(amount: Int, type: DamageType)
    case heal(amount: Int)
    case drawCards(count: Int)
    case addDice(count: Int)
    case reroll
    case explore
    case custom(String)

    // Twilight Marches mechanics
    case applyCurse(type: CurseType, duration: Int)  // Apply curse
    case removeCurse(type: CurseType?)  // Remove specific or any curse
    case summonSpirit(power: Int, realm: Realm)  // Summon spirit guardian
    case shiftBalance(towards: CardBalance, amount: Int)  // Shift light/dark balance
    case travelRealm(to: Realm)  // Travel between Yav/Nav/Prav
    case gainFaith(amount: Int)  // Gain faith resource
    case sacrifice(cost: Int, benefit: String)  // Sacrifice health/cards for benefit

    // Additional effects from JSON
    case permanentStat(stat: String, amount: Int)
    case temporaryStat(stat: String, amount: Int, duration: Int)
}

// MARK: - AbilityEffect Codable

extension AbilityEffect: Codable {
    private enum CodingKeys: String, CodingKey {
        case damage
        case heal
        case drawCards = "draw_cards"
        case addDice = "add_dice"
        case reroll
        case explore
        case custom
        case applyCurse = "apply_curse"
        case removeCurse = "remove_curse"
        case summonSpirit = "summon_spirit"
        case shiftBalance = "shift_balance"
        case travelRealm = "travel_realm"
        case gainFaith = "gain_faith"
        case faith
        case sacrifice
        case permanentStat = "permanent_stat"
        case temporaryStat = "temporary_stat"
    }

    private struct DamageValue: Codable {
        let amount: Int
        let type: String
    }

    private struct CurseValue: Codable {
        let type: String
        let duration: Int?
    }

    private struct SpiritValue: Codable {
        let power: Int
        let realm: String
    }

    private struct BalanceValue: Codable {
        let towards: String
        let amount: Int
    }

    private struct StatValue: Codable {
        let stat: String
        let amount: Int
        let duration: Int?
    }

    private struct SacrificeValue: Codable {
        let cost: Int
        let benefit: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try each effect type
        if let damageValue = try container.decodeIfPresent(DamageValue.self, forKey: .damage) {
            self = .damage(amount: damageValue.amount, type: DamageType(rawValue: damageValue.type) ?? .physical)
        } else if let healAmount = try container.decodeIfPresent(Int.self, forKey: .heal) {
            self = .heal(amount: healAmount)
        } else if let drawCount = try container.decodeIfPresent(Int.self, forKey: .drawCards) {
            self = .drawCards(count: drawCount)
        } else if let diceCount = try container.decodeIfPresent(Int.self, forKey: .addDice) {
            self = .addDice(count: diceCount)
        } else if (try? container.decodeIfPresent(Bool.self, forKey: .reroll)) == true {
            self = .reroll
        } else if (try? container.decodeIfPresent(Bool.self, forKey: .explore)) == true {
            self = .explore
        } else if let curseValue = try container.decodeIfPresent(CurseValue.self, forKey: .applyCurse) {
            self = .applyCurse(type: CurseType(rawValue: curseValue.type) ?? .weakness, duration: curseValue.duration ?? 1)
        } else if let curseString = try container.decodeIfPresent(String.self, forKey: .applyCurse) {
            // Simple format: "apply_curse": "weakness"
            self = .applyCurse(type: CurseType(rawValue: curseString) ?? .weakness, duration: 1)
        } else if let curseType = try container.decodeIfPresent(String.self, forKey: .removeCurse) {
            self = .removeCurse(type: CurseType(rawValue: curseType))
        } else if let spiritValue = try container.decodeIfPresent(SpiritValue.self, forKey: .summonSpirit) {
            self = .summonSpirit(power: spiritValue.power, realm: Realm(rawValue: spiritValue.realm) ?? .yav)
        } else if let balanceValue = try container.decodeIfPresent(BalanceValue.self, forKey: .shiftBalance) {
            self = .shiftBalance(towards: CardBalance(rawValue: balanceValue.towards) ?? .neutral, amount: balanceValue.amount)
        } else if let realmString = try container.decodeIfPresent(String.self, forKey: .travelRealm) {
            self = .travelRealm(to: Realm(rawValue: realmString) ?? .yav)
        } else if let faithAmount = try container.decodeIfPresent(Int.self, forKey: .gainFaith) {
            self = .gainFaith(amount: faithAmount)
        } else if let faithAmount = try container.decodeIfPresent(Int.self, forKey: .faith) {
            // Alias for gain_faith
            self = .gainFaith(amount: faithAmount)
        } else if let sacrificeValue = try container.decodeIfPresent(SacrificeValue.self, forKey: .sacrifice) {
            self = .sacrifice(cost: sacrificeValue.cost, benefit: sacrificeValue.benefit)
        } else if let statValue = try container.decodeIfPresent(StatValue.self, forKey: .permanentStat) {
            self = .permanentStat(stat: statValue.stat, amount: statValue.amount)
        } else if let statValue = try container.decodeIfPresent(StatValue.self, forKey: .temporaryStat) {
            self = .temporaryStat(stat: statValue.stat, amount: statValue.amount, duration: statValue.duration ?? 1)
        } else if let customString = try container.decodeIfPresent(String.self, forKey: .custom) {
            self = .custom(customString)
        } else {
            // Default to custom with unknown
            self = .custom("unknown")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .damage(let amount, let type):
            try container.encode(DamageValue(amount: amount, type: type.rawValue), forKey: .damage)
        case .heal(let amount):
            try container.encode(amount, forKey: .heal)
        case .drawCards(let count):
            try container.encode(count, forKey: .drawCards)
        case .addDice(let count):
            try container.encode(count, forKey: .addDice)
        case .reroll:
            try container.encode(true, forKey: .reroll)
        case .explore:
            try container.encode(true, forKey: .explore)
        case .custom(let string):
            try container.encode(string, forKey: .custom)
        case .applyCurse(let type, let duration):
            try container.encode(CurseValue(type: type.rawValue, duration: duration), forKey: .applyCurse)
        case .removeCurse(let type):
            try container.encode(type?.rawValue, forKey: .removeCurse)
        case .summonSpirit(let power, let realm):
            try container.encode(SpiritValue(power: power, realm: realm.rawValue), forKey: .summonSpirit)
        case .shiftBalance(let towards, let amount):
            try container.encode(BalanceValue(towards: towards.rawValue, amount: amount), forKey: .shiftBalance)
        case .travelRealm(let realm):
            try container.encode(realm.rawValue, forKey: .travelRealm)
        case .gainFaith(let amount):
            try container.encode(amount, forKey: .gainFaith)
        case .sacrifice(let cost, let benefit):
            try container.encode(SacrificeValue(cost: cost, benefit: benefit), forKey: .sacrifice)
        case .permanentStat(let stat, let amount):
            try container.encode(StatValue(stat: stat, amount: amount, duration: nil), forKey: .permanentStat)
        case .temporaryStat(let stat, let amount, let duration):
            try container.encode(StatValue(stat: stat, amount: amount, duration: duration), forKey: .temporaryStat)
        }
    }
}
