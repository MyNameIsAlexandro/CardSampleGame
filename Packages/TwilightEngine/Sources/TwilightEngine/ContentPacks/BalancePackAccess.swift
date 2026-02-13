/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/BalancePackAccess.swift
/// Назначение: Содержит реализацию файла BalancePackAccess.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

/// Stub balance pack access for gate tests
public struct BalancePackAccess {
    let config: BalanceConfiguration?

    public var allKeys: [String] { [] }

    /// Returns a balance value for the given key.
    /// - Parameter key: The balance configuration key.
    /// - Returns: The value, or nil if not found.
    public func value(for key: String) -> Any? { nil }
}
