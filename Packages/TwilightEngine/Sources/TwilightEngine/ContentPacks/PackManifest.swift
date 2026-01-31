import Foundation

// MARK: - Pack Manifest

/// Metadata describing a content pack
/// This is the entry point for pack loading - every pack must have a manifest
public struct PackManifest: Codable {
    // MARK: - Identity

    /// Unique pack identifier (e.g., "my-campaign-act1")
    public var packId: String

    /// Human-readable display name
    public var displayName: LocalizedString

    /// Pack description
    public var description: LocalizedString

    /// Pack version
    public var version: SemanticVersion

    /// Type of content this pack provides
    public var packType: PackType

    // MARK: - Compatibility

    /// Minimum required Core engine version
    public var coreVersionMin: SemanticVersion

    /// Maximum tested Core version (nil = any future version)
    public var coreVersionMax: SemanticVersion?

    /// Required dependencies on other packs
    public var dependencies: [PackDependency]

    /// Capabilities this pack requires from Core (for rules extensions)
    public var requiredCapabilities: [String]

    // MARK: - Content Entry Points

    /// Starting region ID for campaign packs
    public var entryRegionId: String?

    /// Starting quest ID for campaign packs
    public var entryQuestId: String?

    /// Recommended hero IDs for this campaign
    public var recommendedHeroes: [String]

    // MARK: - Character Pack Fields

    /// List of hero IDs provided by this pack (for character packs)
    public var heroIds: [String]?

    // MARK: - Story Pack Fields

    /// Minimum number of heroes required to play this story
    public var minHeroesRequired: Int?

    /// Maximum number of heroes supported
    public var maxHeroesSupported: Int?

    /// Difficulty rating (1-5)
    public var difficultyRating: Int?

    /// Estimated playtime in minutes
    public var estimatedPlaytimeMinutes: Int?

    /// Mission type: "campaign" for multi-session, "standalone" for single-session
    public var missionType: MissionType?

    // MARK: - Grouping & Organization

    /// Season this pack belongs to (e.g., "season1", "season2")
    public var season: String?

    /// Campaign ID for multi-part stories (e.g., "dark-forest")
    public var campaignId: String?

    /// Order within campaign (1 = Act I, 2 = Act II, etc.)
    public var campaignOrder: Int?

    /// Bundle ID for purchasing (e.g., "dark-forest-complete")
    public var bundleId: String?

    /// Packs required to play this one (for story continuity)
    public var requiresPacks: [String]?

    /// Localized season display name (e.g., "Season 1: Twilight")
    public var seasonDisplayName: LocalizedString?

    /// Localized campaign display name (e.g., "The Dark Forest")
    public var campaignDisplayName: LocalizedString?

    // MARK: - Metadata

    /// Pack author/publisher
    public var author: String

    /// License identifier
    public var license: String?

    /// Release date
    public var releaseDate: Date?

    /// Supported locales
    public var supportedLocales: [String]

    /// File checksums for integrity verification
    public var checksums: [String: String]?

    // MARK: - Content Paths (relative to pack root)

    /// Path to regions content
    public var regionsPath: String?

    /// Path to events content
    public var eventsPath: String?

    /// Path to quests content
    public var questsPath: String?

    /// Path to anchors content
    public var anchorsPath: String?

    /// Path to heroes content
    public var heroesPath: String?

    /// Path to hero abilities content
    public var abilitiesPath: String?

    /// Path to cards content
    public var cardsPath: String?

    /// Path to enemies content
    public var enemiesPath: String?

    /// Path to fate deck cards content
    public var fateDeckPath: String?

    /// Path to balance configuration
    public var balancePath: String?

    /// Path to behaviors JSON file (enemy AI behaviors)
    public var behaviorsPath: String?

    /// Path to localization files
    public var localizationPath: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case packId = "id"
        case displayName = "name"
        case description
        case version
        case packType = "type"
        case coreVersionMin = "core_version_min"
        case coreVersionMax = "core_version_max"
        case dependencies
        case requiredCapabilities = "required_capabilities"
        case entryRegionId = "entry_region"
        case entryQuestId = "entry_quest"
        case recommendedHeroes = "recommended_heroes"
        // Character pack fields
        case heroIds = "hero_ids"
        // Story pack fields
        case minHeroesRequired = "min_heroes_required"
        case maxHeroesSupported = "max_heroes_supported"
        case difficultyRating = "difficulty_rating"
        case estimatedPlaytimeMinutes = "estimated_playtime_minutes"
        case missionType = "mission_type"
        // Grouping & Organization
        case season
        case campaignId = "campaign_id"
        case campaignOrder = "campaign_order"
        case bundleId = "bundle_id"
        case requiresPacks = "requires_packs"
        case seasonDisplayName = "season_name"
        case campaignDisplayName = "campaign_name"
        // Metadata
        case author
        case license
        case releaseDate = "release_date"
        case supportedLocales = "locales"
        case checksums
        case regionsPath = "regions_path"
        case eventsPath = "events_path"
        case questsPath = "quests_path"
        case anchorsPath = "anchors_path"
        case heroesPath = "heroes_path"
        case abilitiesPath = "abilities_path"
        case cardsPath = "cards_path"
        case enemiesPath = "enemies_path"
        case fateDeckPath = "fate_deck_path"
        case balancePath = "balance_path"
        case behaviorsPath = "behaviors_path"
        case localizationPath = "localization_path"
    }

    // MARK: - Initialization

    public init(
        packId: String,
        displayName: LocalizedString,
        description: LocalizedString,
        version: SemanticVersion,
        packType: PackType,
        coreVersionMin: SemanticVersion,
        coreVersionMax: SemanticVersion? = nil,
        dependencies: [PackDependency] = [],
        requiredCapabilities: [String] = [],
        entryRegionId: String? = nil,
        entryQuestId: String? = nil,
        recommendedHeroes: [String] = [],
        // Character pack fields
        heroIds: [String]? = nil,
        // Story pack fields
        minHeroesRequired: Int? = nil,
        maxHeroesSupported: Int? = nil,
        difficultyRating: Int? = nil,
        estimatedPlaytimeMinutes: Int? = nil,
        missionType: MissionType? = nil,
        // Grouping & Organization
        season: String? = nil,
        campaignId: String? = nil,
        campaignOrder: Int? = nil,
        bundleId: String? = nil,
        requiresPacks: [String]? = nil,
        seasonDisplayName: LocalizedString? = nil,
        campaignDisplayName: LocalizedString? = nil,
        // Metadata
        author: String,
        license: String? = nil,
        releaseDate: Date? = nil,
        supportedLocales: [String] = ["en"],
        checksums: [String: String]? = nil,
        regionsPath: String? = nil,
        eventsPath: String? = nil,
        questsPath: String? = nil,
        anchorsPath: String? = nil,
        heroesPath: String? = nil,
        abilitiesPath: String? = nil,
        cardsPath: String? = nil,
        enemiesPath: String? = nil,
        fateDeckPath: String? = nil,
        balancePath: String? = nil,
        behaviorsPath: String? = nil,
        localizationPath: String? = nil
    ) {
        self.packId = packId
        self.displayName = displayName
        self.description = description
        self.version = version
        self.packType = packType
        self.coreVersionMin = coreVersionMin
        self.coreVersionMax = coreVersionMax
        self.dependencies = dependencies
        self.requiredCapabilities = requiredCapabilities
        self.entryRegionId = entryRegionId
        self.entryQuestId = entryQuestId
        self.recommendedHeroes = recommendedHeroes
        self.heroIds = heroIds
        self.minHeroesRequired = minHeroesRequired
        self.maxHeroesSupported = maxHeroesSupported
        self.difficultyRating = difficultyRating
        self.estimatedPlaytimeMinutes = estimatedPlaytimeMinutes
        self.missionType = missionType
        self.season = season
        self.campaignId = campaignId
        self.campaignOrder = campaignOrder
        self.bundleId = bundleId
        self.requiresPacks = requiresPacks
        self.seasonDisplayName = seasonDisplayName
        self.campaignDisplayName = campaignDisplayName
        self.author = author
        self.license = license
        self.releaseDate = releaseDate
        self.supportedLocales = supportedLocales
        self.checksums = checksums
        self.regionsPath = regionsPath
        self.eventsPath = eventsPath
        self.questsPath = questsPath
        self.anchorsPath = anchorsPath
        self.heroesPath = heroesPath
        self.abilitiesPath = abilitiesPath
        self.cardsPath = cardsPath
        self.enemiesPath = enemiesPath
        self.fateDeckPath = fateDeckPath
        self.balancePath = balancePath
        self.behaviorsPath = behaviorsPath
        self.localizationPath = localizationPath
    }

    // MARK: - Validation

    /// Validate manifest structure
    public func validate() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        // Check required fields
        if packId.isEmpty {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "manifest",
                message: "Pack ID is required"
            ))
        }

        if displayName.localized.isEmpty {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "manifest",
                message: "Display name is required"
            ))
        }

        // Validate pack ID format (lowercase, alphanumeric, hyphens)
        let validIdPattern = "^[a-z0-9][a-z0-9-]*[a-z0-9]$"
        if !packId.isEmpty,
           let regex = try? NSRegularExpression(pattern: validIdPattern),
           regex.firstMatch(in: packId, range: NSRange(packId.startIndex..., in: packId)) == nil {
            errors.append(ContentValidationError(
                type: .invalidRange,
                definitionId: "manifest.packId",
                message: "Pack ID must be lowercase alphanumeric with hyphens"
            ))
        }

        // Validate locales
        if supportedLocales.isEmpty {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "manifest.locales",
                message: "At least one locale must be supported"
            ))
        }

        // Campaign packs should have entry points (informational)
        // Note: This is a warning, not a blocking error

        return errors
    }

    /// Check if this pack is compatible with current Core version
    public func isCompatibleWithCore() -> Bool {
        let current = CoreVersion.current

        // Must meet minimum requirement
        guard current >= coreVersionMin else { return false }

        // If max is specified, must not exceed it
        if let max = coreVersionMax, current > max {
            return false
        }

        return true
    }
}

// MARK: - Manifest File Loading

public extension PackManifest {
    /// Standard manifest filename
    static let filename = "manifest.json"

    /// Custom date formatter that handles both "2026-01-01" and "2026-01-01T00:00:00Z"
    private static let flexibleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Load manifest from URL
    static func load(from url: URL) throws -> PackManifest {
        let manifestURL = url.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PackLoadError.manifestNotFound(path: manifestURL.path)
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            // Use custom strategy that handles both date-only and ISO8601 formats
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try ISO8601 first
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }

                // Fallback to date-only format "yyyy-MM-dd"
                if let date = flexibleDateFormatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(dateString)"
                )
            }
            return try decoder.decode(PackManifest.self, from: data)
        } catch let error as DecodingError {
            throw PackLoadError.invalidManifest(reason: error.localizedDescription)
        }
    }

    /// Save manifest to URL
    func save(to url: URL) throws {
        let manifestURL = url.appendingPathComponent(Self.filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: manifestURL)
    }
}
