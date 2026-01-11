import Foundation

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

    init(
        id: UUID = UUID(),
        name: String,
        health: Int = 10,
        maxHealth: Int = 10,
        maxHandSize: Int = 7,
        strength: Int = 0,
        dexterity: Int = 0,
        constitution: Int = 0,
        intelligence: Int = 0,
        wisdom: Int = 0,
        charisma: Int = 0
    ) {
        self.id = id
        self.name = name
        self.health = health
        self.maxHealth = maxHealth
        self.maxHandSize = maxHandSize
        self.hand = []
        self.deck = []
        self.discard = []
        self.buried = []
        self.strength = strength
        self.dexterity = dexterity
        self.constitution = constitution
        self.intelligence = intelligence
        self.wisdom = wisdom
        self.charisma = charisma
    }

    func drawCard() {
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
}
