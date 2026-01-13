import Foundation
import Combine

enum GamePhase {
    case setup
    case exploration
    case encounter
    case combat
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

    // Auto-save callback
    var onAutoSave: (() -> Void)?

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

        // Deal initial hands
        for player in players {
            player.shuffleDeck()
            player.drawCards(count: player.maxHandSize)
        }
    }

    func nextPhase() {
        switch currentPhase {
        case .setup:
            currentPhase = .exploration
        case .exploration:
            currentPhase = .encounter
        case .encounter:
            currentPhase = .combat
        case .combat:
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

            // Draw cards to hand size
            let player = currentPlayer
            let cardsToDraw = player.maxHandSize - player.hand.count
            if cardsToDraw > 0 {
                player.drawCards(count: cardsToDraw)
            }

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
}
