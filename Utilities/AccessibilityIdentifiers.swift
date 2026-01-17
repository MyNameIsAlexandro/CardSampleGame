import Foundation

/// Централизованные accessibility identifiers для UI тестов
/// Используйте эти константы вместо строковых литералов
enum AccessibilityIdentifiers {

    // MARK: - WorldMapView

    enum WorldMap {
        static let view = "worldMapView"
        static let playerInfoBar = "playerInfoBar"
        static let worldInfoBar = "worldInfoBar"
        static let regionsList = "regionsList"

        static func regionCard(_ regionId: UUID) -> String {
            "regionCard_\(regionId.uuidString)"
        }

        static func regionCard(name: String) -> String {
            "regionCard_\(name)"
        }
    }

    // MARK: - RegionDetailView

    enum RegionDetail {
        static let view = "regionDetailView"
        static let anchorInfo = "anchorInfo"
        static let stateIndicator = "stateIndicator"

        // Actions
        static let actionTravel = "action_travel"
        static let actionRest = "action_rest"
        static let actionTrade = "action_trade"
        static let actionExplore = "action_explore"
        static let actionStrengthenAnchor = "action_strengthenAnchor"
    }

    // MARK: - EventView

    enum Event {
        static let view = "eventView"
        static let title = "eventTitle"
        static let description = "eventDescription"
        static let consequencesPreview = "consequencesPreview"
        static let closeButton = "closeEvent"

        static func choice(_ choiceId: UUID) -> String {
            "choice_\(choiceId.uuidString)"
        }

        static func choice(index: Int) -> String {
            "choice_\(index)"
        }
    }

    // MARK: - CombatView

    enum Combat {
        static let view = "combatView"
        static let monsterCard = "monsterCard"
        static let playerStats = "playerStats"
        static let actionBar = "actionBar"
        static let combatLog = "combatLog"
        static let playerHand = "playerHand"

        // Actions
        static let attackButton = "attackButton"
        static let endTurnButton = "endTurnButton"
        static let fleeButton = "fleeButton"

        static func handCard(_ cardId: UUID) -> String {
            "handCard_\(cardId.uuidString)"
        }
    }

    // MARK: - GameBoardView

    enum GameBoard {
        static let view = "gameBoardView"
        static let topBar = "topBar"
        static let encounterArea = "encounterArea"
        static let marketView = "marketView"
        static let deckInfo = "deckInfo"
        static let phaseProgress = "phaseProgress"

        static let pauseButton = "pauseButton"
        static let nextPhaseButton = "nextPhaseButton"
        static let rollDiceButton = "rollDiceButton"
    }

    // MARK: - MainMenu / ContentView

    enum MainMenu {
        static let view = "mainMenuView"
        static let continueButton = "continueButton"
        static let newGameButton = "newGameButton"
        static let loadGameButton = "loadGameButton"
        static let settingsButton = "settingsButton"
    }
}
