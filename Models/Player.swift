import Foundation

// Twilight Marches: Active curse tracking
struct ActiveCurse: Identifiable, Codable {
    let id: UUID
    let type: CurseType
    var duration: Int  // turns remaining
    let sourceCard: String?  // name of card that applied curse

    init(id: UUID = UUID(), type: CurseType, duration: Int, sourceCard: String? = nil) {
        self.id = id
        self.type = type
        self.duration = duration
        self.sourceCard = sourceCard
    }
}

class Player: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var health: Int
    @Published var maxHealth: Int
    @Published var hand: [Card]
    @Published var deck: [Card]
    @Published var discard: [Card]
    @Published var buried: [Card]

    // Character stats
    @Published var strength: Int
    @Published var dexterity: Int
    @Published var constitution: Int
    @Published var intelligence: Int
    @Published var wisdom: Int
    @Published var charisma: Int

    // Hand size management
    let maxHandSize: Int

    // Hero class system
    let heroClass: HeroClass?

    // Twilight Marches mechanics
    @Published var faith: Int  // Вера - resource for powerful abilities
    @Published var maxFaith: Int
    @Published var balance: Int  // 0 (dark) to 100 (light), 50 is neutral
    @Published var activeCurses: [ActiveCurse]
    @Published var currentRealm: Realm
    @Published var spirits: [Card]  // Summoned spirits

    init(
        id: UUID = UUID(),
        name: String,
        health: Int = 10,
        maxHealth: Int = 10,
        maxHandSize: Int = 7,
        strength: Int = 5,      // Базовая сила для боя (атака = strength + d6)
        dexterity: Int = 0,
        constitution: Int = 0,
        intelligence: Int = 0,
        wisdom: Int = 0,
        charisma: Int = 0,
        faith: Int = 3,
        maxFaith: Int = 10,
        balance: Int = 50,
        currentRealm: Realm = .yav,
        heroClass: HeroClass? = nil
    ) {
        self.id = id
        self.name = name
        self.heroClass = heroClass
        self.maxHandSize = maxHandSize
        self.hand = []
        self.deck = []
        self.discard = []
        self.buried = []
        self.activeCurses = []
        self.currentRealm = currentRealm
        self.spirits = []

        // Если указан класс героя, применяем его характеристики
        if let heroClass = heroClass {
            let stats = heroClass.baseStats
            self.health = stats.health
            self.maxHealth = stats.maxHealth
            self.strength = stats.strength
            self.dexterity = stats.dexterity
            self.constitution = stats.constitution
            self.intelligence = stats.intelligence
            self.wisdom = stats.wisdom
            self.charisma = stats.charisma
            self.faith = stats.faith
            self.maxFaith = stats.maxFaith
            self.balance = stats.startingBalance
        } else {
            // Дефолтные значения для тестов
            self.health = health
            self.maxHealth = maxHealth
            self.strength = strength
            self.dexterity = dexterity
            self.constitution = constitution
            self.intelligence = intelligence
            self.wisdom = wisdom
            self.charisma = charisma
            self.faith = faith
            self.maxFaith = maxFaith
            self.balance = balance
        }
    }

    func drawCard() {
        // Auto-reshuffle discard when deck is empty
        if deck.isEmpty && !discard.isEmpty {
            reshuffleDiscard()
        }

        guard !deck.isEmpty else { return }
        let card = deck.removeFirst()
        hand.append(card)
    }

    func drawCards(count: Int) {
        for _ in 0..<count {
            drawCard()
        }
    }

    func playCard(_ card: Card) {
        guard let index = hand.firstIndex(where: { $0.id == card.id }) else { return }
        let playedCard = hand.remove(at: index)
        discard.append(playedCard)
    }

    func shuffleDeck() {
        deck.shuffle()
    }

    func reshuffleDiscard() {
        deck.append(contentsOf: discard)
        discard.removeAll()
        shuffleDeck()
    }

    func takeDamage(_ amount: Int) {
        health = max(0, health - amount)
    }

    func heal(_ amount: Int) {
        health = min(maxHealth, health + amount)
    }

    // Twilight Marches methods
    func gainFaith(_ amount: Int) {
        faith = min(maxFaith, faith + amount)
    }

    func spendFaith(_ amount: Int) -> Bool {
        guard faith >= amount else { return false }
        faith -= amount
        return true
    }

    func shiftBalance(towards: CardBalance, amount: Int) {
        switch towards {
        case .light:
            balance = min(100, balance + amount)
        case .dark:
            balance = max(0, balance - amount)
        case .neutral:
            // Move towards 50 (neutral)
            if balance > 50 {
                balance = max(50, balance - amount)
            } else if balance < 50 {
                balance = min(50, balance + amount)
            }
        }
    }

    func applyCurse(type: CurseType, duration: Int, sourceCard: String? = nil) {
        let curse = ActiveCurse(type: type, duration: duration, sourceCard: sourceCard)
        activeCurses.append(curse)
    }

    func removeCurse(type: CurseType? = nil) {
        if let specificType = type {
            activeCurses.removeAll { $0.type == specificType }
        } else {
            // Remove first curse if no type specified
            if !activeCurses.isEmpty {
                activeCurses.removeFirst()
            }
        }
    }

    func hasCurse(_ type: CurseType) -> Bool {
        return activeCurses.contains { $0.type == type }
    }

    func tickCurses() {
        // Reduce duration of all curses and remove expired ones
        for i in (0..<activeCurses.count).reversed() {
            activeCurses[i].duration -= 1
            if activeCurses[i].duration <= 0 {
                activeCurses.remove(at: i)
            }
        }
    }

    // MARK: - Curse Combat Modifiers

    /// Получить модификатор наносимого урона от проклятий
    /// weakness: -1, shadowOfNav: +3
    func getDamageDealtModifier() -> Int {
        var modifier = 0
        if hasCurse(.weakness) {
            modifier -= 1
        }
        if hasCurse(.shadowOfNav) {
            modifier += 3
        }
        return modifier
    }

    /// Получить модификатор получаемого урона от проклятий
    /// fear: +1 (больше урона получаем)
    func getDamageTakenModifier() -> Int {
        var modifier = 0
        if hasCurse(.fear) {
            modifier += 1
        }
        return modifier
    }

    /// Применить урон с учётом модификаторов проклятий
    func takeDamageWithCurses(_ baseDamage: Int) {
        let modifier = getDamageTakenModifier()
        let actualDamage = max(0, baseDamage + modifier)
        takeDamage(actualDamage)
    }

    /// Рассчитать урон с учётом модификаторов проклятий
    func calculateDamageDealt(_ baseDamage: Int) -> Int {
        let modifier = getDamageDealtModifier()
        return max(0, baseDamage + modifier)
    }

    func summonSpirit(_ spirit: Card) {
        spirits.append(spirit)
    }

    func dismissSpirit(_ spirit: Card) {
        spirits.removeAll { $0.id == spirit.id }
    }

    func travelToRealm(_ realm: Realm) {
        currentRealm = realm
    }

    var balanceState: CardBalance {
        if balance >= 70 {
            return .light
        } else if balance <= 30 {
            return .dark
        } else {
            return .neutral
        }
    }

    // Описание баланса для UI
    var balanceDescription: String {
        switch balance {
        case 0..<30:
            return L10n.balancePathDark.localized
        case 30..<70:
            return L10n.balancePathNeutral.localized
        case 70...100:
            return L10n.balancePathLight.localized
        default:
            return L10n.balancePathUnknown.localized
        }
    }

    // MARK: - Hero Class Abilities

    /// Бонус урона от способности класса
    /// - Warrior: +2 при HP ниже 50%
    /// - Shadow: +3 если цель на полном HP (targetFullHP = true)
    func getHeroClassDamageBonus(targetFullHP: Bool = false) -> Int {
        guard let heroClass = heroClass else { return 0 }

        switch heroClass {
        case .warrior:
            // Ярость: +2 к урону при HP ниже 50%
            if health < maxHealth / 2 {
                return 2
            }
        case .shadow:
            // Засада: +3 урона по полным HP
            if targetFullHP {
                return 3
            }
        default:
            break
        }
        return 0
    }

    /// Снижение получаемого урона от способности класса
    /// - Priest: -1 от тёмных источников
    func getHeroClassDamageReduction(fromDarkSource: Bool = false) -> Int {
        guard let heroClass = heroClass else { return 0 }

        switch heroClass {
        case .priest:
            // Благословение: -1 урон от тёмных источников
            if fromDarkSource {
                return 1
            }
        default:
            break
        }
        return 0
    }

    /// Бонусные кубики от способности класса (для первой атаки)
    /// - Ranger: +1 кубик при первой атаке
    func getHeroClassBonusDice(isFirstAttack: Bool) -> Int {
        guard let heroClass = heroClass else { return 0 }

        switch heroClass {
        case .ranger:
            // Выслеживание: +1 кубик при первой атаке
            if isFirstAttack {
                return 1
            }
        default:
            break
        }
        return 0
    }

    /// Проверка способности Мага: +1 вера в конце хода
    var shouldGainFaithEndOfTurn: Bool {
        return heroClass == .mage
    }

    /// Полный расчёт урона с учётом проклятий и классовых способностей
    func calculateTotalDamageDealt(_ baseDamage: Int, targetFullHP: Bool = false) -> Int {
        let curseModifier = getDamageDealtModifier()
        let heroBonus = getHeroClassDamageBonus(targetFullHP: targetFullHP)
        return max(0, baseDamage + curseModifier + heroBonus)
    }

    /// Полный расчёт получаемого урона с учётом проклятий и классовых способностей
    func takeDamageWithAllModifiers(_ baseDamage: Int, fromDarkSource: Bool = false) {
        let curseModifier = getDamageTakenModifier()
        let heroReduction = getHeroClassDamageReduction(fromDarkSource: fromDarkSource)
        let actualDamage = max(0, baseDamage + curseModifier - heroReduction)
        takeDamage(actualDamage)
    }
}
