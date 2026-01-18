import Foundation

// MARK: - World Random Number Generator
// Детерминированный RNG для воспроизводимости игрового мира
// Использует LCG (Linear Congruential Generator) - тот же алгоритм что в тестах

/// Протокол для внедрения RNG в игровой мир
protocol WorldRandomGenerator {
    mutating func nextDouble() -> Double
    mutating func nextInt(in range: Range<Int>) -> Int
    mutating func nextInt(in range: ClosedRange<Int>) -> Int
}

/// Детерминированный RNG с seed (для тестов и воспроизводимости)
struct SeededWorldRNG: WorldRandomGenerator, RandomNumberGenerator {
    private(set) var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // LCG параметры (те же что в существующих тестах)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        // Преобразуем UInt64 в Double в диапазоне [0, 1)
        return Double(next()) / Double(UInt64.max)
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        guard !range.isEmpty else { return range.lowerBound }
        let bound = UInt64(range.count)
        return range.lowerBound + Int(next() % bound)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let bound = UInt64(range.count)
        return range.lowerBound + Int(next() % bound)
    }
}

/// Системный RNG (обёртка над Swift random для единообразия интерфейса)
struct SystemWorldRNG: WorldRandomGenerator {
    mutating func nextDouble() -> Double {
        return Double.random(in: 0..<1)
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        return Int.random(in: range)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        return Int.random(in: range)
    }
}

// MARK: - WorldRNG Singleton with Injection Support

/// Глобальный RNG для игрового мира с поддержкой инъекции для тестов
final class WorldRNG {
    /// Shared instance (по умолчанию системный RNG)
    static var shared: WorldRNG = WorldRNG()

    private var rng: any WorldRandomGenerator

    /// Инициализация с системным RNG (по умолчанию)
    init() {
        self.rng = SystemWorldRNG()
    }

    /// Инициализация с seeded RNG (для тестов)
    init(seed: UInt64) {
        self.rng = SeededWorldRNG(seed: seed)
    }

    /// Установить seed для детерминированного поведения
    func setSeed(_ seed: UInt64) {
        self.rng = SeededWorldRNG(seed: seed)
    }

    /// Сбросить на системный RNG
    func resetToSystem() {
        self.rng = SystemWorldRNG()
    }

    /// Случайное Double в [0, 1)
    func nextDouble() -> Double {
        return rng.nextDouble()
    }

    /// Случайный Int в диапазоне [lowerBound, upperBound)
    func nextInt(in range: Range<Int>) -> Int {
        return rng.nextInt(in: range)
    }

    /// Случайный Int в диапазоне [lowerBound, upperBound]
    func nextInt(in range: ClosedRange<Int>) -> Int {
        return rng.nextInt(in: range)
    }

    /// Проверка вероятности (возвращает true с вероятностью p)
    func checkProbability(_ p: Double) -> Bool {
        return nextDouble() < p
    }
}
