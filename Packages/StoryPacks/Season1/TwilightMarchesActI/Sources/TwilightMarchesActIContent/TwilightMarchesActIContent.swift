import Foundation

/// TwilightMarchesActI story pack
/// Provides Act I campaign content: regions, events, quests, anchors, enemies
public enum TwilightMarchesActIContent {
    /// URL to the TwilightMarchesActI content pack directory
    public static var packURL: URL? {
        Bundle.module.url(forResource: "TwilightMarchesActI", withExtension: nil)
    }

    /// Pack identifier
    public static let packId = "twilight-marches-act1"
}
