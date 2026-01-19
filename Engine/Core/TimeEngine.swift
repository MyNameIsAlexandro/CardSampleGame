import Foundation

// MARK: - Time Engine Implementation
// Generic time management system for turn-based games.

/// Default implementation of TimeEngineProtocol
final class TimeEngine: TimeEngineProtocol {
    // MARK: - Properties

    private(set) var currentTime: Int = 0
    weak var delegate: TimeSystemDelegate?

    /// Thresholds that have been triggered (to avoid re-triggering)
    private var triggeredThresholds: Set<Int> = []

    /// Configurable threshold intervals (e.g., [3, 6, 9] or just [3] for "every 3")
    private let thresholdInterval: Int

    // MARK: - Initialization

    /// Initialize with a threshold interval (e.g., 3 for "every 3 time units")
    init(thresholdInterval: Int = 3) {
        self.thresholdInterval = thresholdInterval
    }

    // MARK: - TimeEngineProtocol

    /// Advance time by cost units
    /// Invariant: Time cannot go backwards
    func advance(cost: Int) {
        guard cost > 0 else {
            // Instant actions (cost = 0) don't advance time
            return
        }

        let previousTime = currentTime
        currentTime += cost

        // Notify delegate of each tick
        delegate?.onTimeTick(currentTime: currentTime, delta: cost)

        // Check for threshold crossings
        checkThresholdCrossings(from: previousTime, to: currentTime)
    }

    /// Check if current time has passed a threshold interval
    func checkThreshold(_ interval: Int) -> Bool {
        guard interval > 0 else { return false }
        return currentTime % interval == 0 && currentTime > 0
    }

    // MARK: - Private Methods

    private func checkThresholdCrossings(from previousTime: Int, to newTime: Int) {
        guard thresholdInterval > 0 else { return }

        // Find all threshold crossings in the range
        let previousThreshold = previousTime / thresholdInterval
        let newThreshold = newTime / thresholdInterval

        if newThreshold > previousThreshold {
            for threshold in (previousThreshold + 1)...newThreshold {
                let thresholdTime = threshold * thresholdInterval
                delegate?.onTimeThreshold(currentTime: newTime, threshold: thresholdTime)
            }
        }
    }

    // MARK: - Utility

    /// Reset time (for new game)
    func reset() {
        currentTime = 0
        triggeredThresholds.removeAll()
    }

    /// Set time directly (for save/load)
    func setTime(_ time: Int) {
        currentTime = max(0, time)
    }
}

// MARK: - Time Cost Constants

/// Standard time costs for common actions
enum StandardTimeCost: Int, TimedAction {
    case instant = 0
    case quick = 1
    case standard = 2
    case extended = 3
    case long = 4

    var timeCost: Int { rawValue }
}

// MARK: - TimedAction Extensions

/// Simple timed action wrapper
struct SimpleTimedAction: TimedAction {
    let timeCost: Int
    let actionId: String

    init(cost: Int, id: String = "") {
        self.timeCost = cost
        self.actionId = id
    }
}

/// Travel action with variable cost
struct TravelAction: TimedAction {
    let fromLocation: String
    let toLocation: String
    let isNeighbor: Bool

    var timeCost: Int {
        isNeighbor ? 1 : 2
    }
}

/// Rest action
struct RestAction: TimedAction {
    let timeCost: Int = 1
}

/// Exploration action
struct ExploreAction: TimedAction {
    let isInstant: Bool
    var timeCost: Int { isInstant ? 0 : 1 }
}
