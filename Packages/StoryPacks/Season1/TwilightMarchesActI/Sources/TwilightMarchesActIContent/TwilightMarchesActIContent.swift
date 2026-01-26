import Foundation

/// TwilightMarchesActI story pack
/// Provides Act I campaign content: regions, events, quests, anchors, enemies
public enum TwilightMarchesActIContent {
    /// URL to the TwilightMarchesActI.pack binary file
    public static var packURL: URL? {
        Bundle.module.url(forResource: "TwilightMarchesActI", withExtension: "pack")
    }

    /// Pack identifier
    public static let packId = "twilight-marches-act1"
}
