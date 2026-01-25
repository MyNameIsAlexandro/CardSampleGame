import Foundation

/// Deterministic random number generator for world events
/// Uses a seeded approach for reproducible results
public final class WorldRNG {
    public static let shared = WorldRNG()

    private var seed: UInt64
    private var state: UInt64

    public init(seed: UInt64 = 0) {
        self.seed = seed
        self.state = seed
    }

    public func setSeed(_ seed: UInt64) {
        self.seed = seed
        self.state = seed
    }

    public func currentSeed() -> UInt64 {
        return seed
    }

    public func currentState() -> UInt64 {
        return state
    }

    public func restoreState(_ state: UInt64) {
        self.state = state
    }

    /// Reset to system randomness (non-deterministic)
    public func resetToSystem() {
        self.seed = UInt64.random(in: 0...UInt64.max)
        self.state = seed
    }

    /// Generate next random UInt64 using xorshift64
    public func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Generate random Int in range
    public func nextInt(in range: ClosedRange<Int>) -> Int {
        let random = next()
        let rangeSize = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(random % rangeSize)
    }

    /// Generate random Double in 0..<1
    public func nextDouble() -> Double {
        return Double(next()) / Double(UInt64.max)
    }

    /// Generate random Bool
    public func nextBool() -> Bool {
        return next() % 2 == 0
    }

    /// Generate random Bool with probability
    public func nextBool(probability: Double) -> Bool {
        return nextDouble() < probability
    }

    /// Shuffle array in place
    public func shuffle<T>(_ array: inout [T]) {
        for i in stride(from: array.count - 1, through: 1, by: -1) {
            let j = nextInt(in: 0...i)
            array.swapAt(i, j)
        }
    }

    /// Return shuffled copy of array
    public func shuffled<T>(_ array: [T]) -> [T] {
        var copy = array
        shuffle(&copy)
        return copy
    }

    /// Pick random element from array
    public func randomElement<T>(from array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let index = nextInt(in: 0...(array.count - 1))
        return array[index]
    }
}
