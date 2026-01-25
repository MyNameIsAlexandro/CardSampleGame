import Foundation

/// CoreHeroes content pack
/// Provides base heroes and their class-specific cards
public enum CoreHeroesContent {
    /// URL to the CoreHeroes content pack directory
    public static var packURL: URL? {
        Bundle.module.url(forResource: "CoreHeroes", withExtension: nil)
    }

    /// Pack identifier
    public static let packId = "core-heroes"
}
