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

    // World exploration system
    @Published var worldState: WorldState = WorldState()

    // Auto-save callback
    var onAutoSave: (() -> Void)?

    // Actions per turn
    var actionsPerTurn: Int { 3 }

    var currentPlayer: Player {
        players[currentPlayerIndex]
    }

    // DEPRECATED: Old victory condition (kept for compatibility)
    // New victory: complete main quest (mainQuestStage == 5 && act_completed flags)
    var victoryThreshold: Int { 10 }

    // Game is over if victory or defeat
    var isGameOver: Bool {
        isVictory || isDefeat
    }

    // MARK: - Victory/Defeat Conditions

    /// Check quest-based victory (new system)
    func checkQuestVictory() {
        // Victory: Main quest completed (Act 5 finished)
        if worldState.mainQuestStage >= 5 && worldState.worldFlags["act5_completed"] == true {
            isVictory = true
            currentPhase = .gameOver
        }
    }

    /// Check defeat conditions
    func checkDefeatConditions() {
        // Defeat 1: Player HP = 0
        if currentPlayer.health <= 0 {
            isDefeat = true
            currentPhase = .gameOver
            return
        }

        // Defeat 2: WorldTension = 100% (world fell to Nav)
        if worldState.worldTension >= 100 {
            isDefeat = true
            currentPhase = .gameOver
            return
        }

        // Defeat 3: Critical anchor destroyed (if implemented via flags)
        if worldState.worldFlags["critical_anchor_destroyed"] == true {
            isDefeat = true
            currentPhase = .gameOver
            return
        }
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

        // Check defeat and victory conditions (new system)
        checkDefeatConditions()
        checkQuestVictory()

        if !isGameOver {
            currentPhase = .exploration
            activeEncounter = nil
            actionsRemaining = actionsPerTurn

            // Проклятие истощения: -1 действие в этом ходу
            if currentPlayer.hasCurse(.exhaustion) {
                actionsRemaining = max(1, actionsRemaining - 1)
            }

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

        // Check if a boss was defeated (for quest objectives)
        if let encounter = activeEncounter {
            worldState.markBossDefeated(bossName: encounter.name, player: currentPlayer)
        }

        // Проклятие крови: при убийстве +2 HP и баланс смещается к тьме
        if currentPlayer.hasCurse(.bloodCurse) {
            currentPlayer.heal(2)
            currentPlayer.shiftBalance(towards: .dark, amount: 5)
        }

        activeEncounter = nil
        currentPhase = .exploration

        // DEPRECATED: Old victory condition (kept for compatibility)
        // New system: quest-based victory via checkQuestVictory()
        if encountersDefeated >= victoryThreshold {
            isVictory = true
            currentPhase = .gameOver
        }

        // Check new victory conditions
        checkQuestVictory()

        // Auto-save after defeating encounter
        onAutoSave?()
    }

    // DEPRECATED: Use checkDefeatConditions() instead
    // Kept for backwards compatibility with existing code
    func checkDefeat() {
        checkDefeatConditions()
    }

    func rollDice(sides: Int = 6, count: Int = 1) -> Int {
        // Используем WorldRNG для детерминизма при тестировании
        let total = (0..<count).reduce(0) { sum, _ in
            sum + WorldRNG.shared.nextInt(in: 1...sides)
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
        // Применяем урон с учётом проклятий (fear увеличивает получаемый урон)
        currentPlayer.takeDamageWithCurses(encounterPower)
        checkDefeat()
    }
}
