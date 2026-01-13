import Foundation
import Combine

enum GamePhase {
    case setup
    case exploration
    case encounter
    case playerTurn
    case enemyTurn
    case endTurn
    case gameOver
}

class GameState: ObservableObject {
    @Published var currentPhase: GamePhase = .setup
    @Published var players: [Player]
    @Published var currentPlayerIndex: Int = 0
    @Published var encounterDeck: [Card]
    @Published var locationDeck: [Card]
    @Published var activeEncounter: Card?
    @Published var turnNumber: Int = 0
    @Published var diceRoll: Int?
    @Published var encountersDefeated: Int = 0
    @Published var isVictory: Bool = false
    @Published var isDefeat: Bool = false
    @Published var actionsRemaining: Int = 3

    // Marketplace for deck-building
    @Published var marketCards: [Card] = []

    // Auto-save callback
    var onAutoSave: (() -> Void)?

    // Actions per turn
    var actionsPerTurn: Int { 3 }

    var currentPlayer: Player {
        players[currentPlayerIndex]
    }

    // Win condition: defeat 10 encounters
    var victoryThreshold: Int { 10 }

    // Game is over if victory or defeat
    var isGameOver: Bool {
        isVictory || isDefeat
    }

    init(players: [Player]) {
        self.players = players
        self.encounterDeck = []
        self.locationDeck = []
    }

    func startGame() {
        currentPhase = .exploration
        turnNumber = 1
        isVictory = false
        isDefeat = false
        encountersDefeated = 0
        activeEncounter = nil

        // Deal initial hands
        for player in players {
            player.shuffleDeck()
            player.drawCards(count: player.maxHandSize)
        }
    }

    // Purchase card from market
    func purchaseCard(_ card: Card) -> Bool {
        guard let cardCost = card.cost else { return false }

        // Check if player has enough faith
        if currentPlayer.spendFaith(cardCost) {
            // Remove card from market
            if let index = marketCards.firstIndex(where: { $0.id == card.id }) {
                marketCards.remove(at: index)
            }

            // Add card to player's discard pile (standard deck-building mechanic)
            currentPlayer.discard.append(card)

            return true
        }

        return false
    }

    func nextPhase() {
        switch currentPhase {
        case .setup:
            currentPhase = .exploration
        case .exploration:
            currentPhase = .encounter
        case .encounter:
            currentPhase = .playerTurn
        case .playerTurn:
            currentPhase = .enemyTurn
        case .enemyTurn:
            currentPhase = .endTurn
        case .endTurn:
            endTurn()
        case .gameOver:
            break
        }
    }

    func endTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count

        if currentPlayerIndex == 0 {
            turnNumber += 1
        }

        // Tick curses at end of turn
        currentPlayer.tickCurses()

        // Check defeat condition
        checkDefeat()

        if !isGameOver {
            currentPhase = .exploration
            activeEncounter = nil
            actionsRemaining = actionsPerTurn

            // NEW: Discard all cards and draw 5 new ones (deck-building mechanic)
            let player = currentPlayer
            // Discard all cards in hand
            player.discard.append(contentsOf: player.hand)
            player.hand.removeAll()

            // Draw 5 new cards
            player.drawCards(count: 5)

            // Regenerate faith
            currentPlayer.gainFaith(1)
        }

        // Auto-save after turn ends
        onAutoSave?()
    }

    func defeatEncounter() {
        encountersDefeated += 1
        activeEncounter = nil
        currentPhase = .exploration

        // Check victory condition
        if encountersDefeated >= victoryThreshold {
            isVictory = true
            currentPhase = .gameOver
        }

        // Auto-save after defeating encounter
        onAutoSave?()
    }

    func checkDefeat() {
        // Player loses if health reaches 0
        if currentPlayer.health <= 0 {
            isDefeat = true
            currentPhase = .gameOver
        }
    }

    func rollDice(sides: Int = 6, count: Int = 1) -> Int {
        let total = (0..<count).reduce(0) { sum, _ in
            sum + Int.random(in: 1...sides)
        }
        diceRoll = total
        return total
    }

    func drawEncounter() {
        guard !encounterDeck.isEmpty else { return }
        activeEncounter = encounterDeck.removeFirst()
        currentPhase = .encounter
    }

    func useAction() -> Bool {
        guard actionsRemaining > 0 else { return false }
        actionsRemaining -= 1
        return true
    }

    func enemyPhaseAction() {
        // Enemy attacks during their phase
        guard let encounter = activeEncounter else { return }

        let encounterPower = encounter.power ?? 3
        currentPlayer.health = max(0, currentPlayer.health - encounterPower)
        checkDefeat()
    }
}
