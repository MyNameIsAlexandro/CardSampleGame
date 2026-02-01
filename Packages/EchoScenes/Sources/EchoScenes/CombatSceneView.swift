import SwiftUI
import SpriteKit
import EchoEngine
import TwilightEngine

/// SwiftUI wrapper for CombatScene via SpriteView.
public struct CombatSceneView: View {
    let scene: CombatScene

    public init(
        enemyDefinition: EnemyDefinition,
        playerName: String = "Hero",
        playerHealth: Int = 10,
        playerMaxHealth: Int? = nil,
        playerStrength: Int = 5,
        playerDeck: [Card] = [],
        fateCards: [FateCard] = [],
        resonance: Float = 0,
        seed: UInt64 = 42,
        size: CGSize = CGSize(width: 390, height: 700),
        onCombatEnd: ((CombatOutcome) -> Void)? = nil,
        onCombatEndWithResult: ((EchoCombatResult) -> Void)? = nil
    ) {
        let s = CombatScene(size: size)
        s.scaleMode = .aspectFill
        s.configure(
            enemyDefinition: enemyDefinition,
            playerName: playerName,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth ?? playerHealth,
            playerStrength: playerStrength,
            playerDeck: playerDeck,
            fateCards: fateCards,
            resonance: resonance,
            seed: seed
        )
        s.onCombatEnd = onCombatEnd
        s.onCombatEndWithResult = onCombatEndWithResult
        self.scene = s
    }

    public var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
