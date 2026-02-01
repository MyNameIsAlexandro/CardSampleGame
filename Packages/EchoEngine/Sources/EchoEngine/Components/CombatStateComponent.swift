import FirebladeECS

public enum EchoCombatPhase: String, Sendable {
    case setup
    case playerTurn
    case enemyReveal
    case enemyResolve
    case cleanup
    case victory
    case defeat
}

public enum VictoryType: String, Sendable {
    case killed
    case pacified
}

public enum CombatOutcome: Sendable, Equatable {
    case victory(VictoryType)
    case defeat
}

public final class CombatStateComponent: Component {
    public var phase: EchoCombatPhase
    public var round: Int
    public var isActive: Bool
    public var mulliganDone: Bool

    public init(phase: EchoCombatPhase = .setup, round: Int = 1) {
        self.phase = phase
        self.round = round
        self.isActive = true
        self.mulliganDone = false
    }
}
